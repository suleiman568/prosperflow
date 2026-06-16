import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/local_database.dart';
import '../../../core/offline/pending_sync_repository.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/product.dart';

class ProductsRepository {
  ProductsRepository({
    required AppDatabase database,
    required PendingSyncRepository pendingSyncRepository,
    required ConnectivityService connectivityService,
    SupabaseClient? client,
  }) : _database = database,
       _pendingSyncRepository = pendingSyncRepository,
       _connectivityService = connectivityService,
       _client = client ?? SupabaseService.client;

  static const _tableName = 'products';

  final AppDatabase _database;
  final PendingSyncRepository _pendingSyncRepository;
  final ConnectivityService _connectivityService;
  final SupabaseClient _client;
  bool _isSyncing = false;
  bool _isHydrating = false;
  DateTime? _lastHydratedAt;

  static const _minimumHydrationInterval = Duration(minutes: 1);

  Future<List<Product>> fetchProducts() async {
    return fetchLocalProducts();
  }

  Future<List<Product>> fetchLocalProducts() async {
    debugPrint('PRODUCTS_LOCAL_FETCH');
    final rows = await _database.customSelect('''
SELECT id,
       name,
       sku,
       category,
       cost_price,
       selling_price,
       stock_quantity,
       reorder_level,
       created_at
FROM products
WHERE is_deleted = 0
ORDER BY COALESCE(created_at, updated_at, id) ASC
''').get();

    return rows.map((row) {
      return Product(
        id: row.read<String>('id'),
        name: row.read<String>('name'),
        sku: row.read<String>('sku'),
        category: row.read<String>('category'),
        costPrice: row.read<double>('cost_price'),
        sellingPrice: row.read<double>('selling_price'),
        quantityInStock: row.read<int>('stock_quantity'),
        reorderLevel: row.read<int>('reorder_level'),
        createdAt: DateTime.tryParse(
          row.readNullable<String>('created_at') ?? '',
        ),
      );
    }).toList();
  }

  Future<Product> createProduct(Product product) async {
    final localProduct = Product(
      id: product.id.isEmpty ? _newUuid() : product.id,
      name: product.name,
      sku: product.sku,
      category: product.category,
      costPrice: product.costPrice,
      sellingPrice: product.sellingPrice,
      quantityInStock: product.quantityInStock,
      reorderLevel: product.reorderLevel,
      createdAt: product.createdAt ?? DateTime.now(),
    );

    await _upsertLocalProduct(
      localProduct,
      syncStatus: 'pending',
      isDeleted: 0,
    );
    await _pendingSyncRepository.enqueue(
      tableName: _tableName,
      recordId: localProduct.id,
      action: PendingSyncAction.create,
      payload: _remotePayload(localProduct),
    );
    unawaited(_syncIfOnline());

    return localProduct;
  }

  Future<Product> updateProduct(Product product) async {
    await _upsertLocalProduct(product, syncStatus: 'pending', isDeleted: 0);
    await _pendingSyncRepository.enqueue(
      tableName: _tableName,
      recordId: product.id,
      action: PendingSyncAction.update,
      payload: _remotePayload(product),
    );
    unawaited(_syncIfOnline());

    return product;
  }

  Future<bool> hasSalesForProduct(String id) async {
    if (!await _canUseSupabase()) {
      return false;
    }

    try {
      final rows = await _client
          .from('sales')
          .select('id')
          .eq('product_id', id)
          .limit(1);
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> deleteProduct(String id) async {
    await _database.customStatement(
      '''
UPDATE products
SET is_deleted = 1,
    sync_status = 'pending',
    updated_at = ?
WHERE id = ?
''',
      [DateTime.now().toIso8601String(), id],
    );
    await _pendingSyncRepository.enqueue(
      tableName: _tableName,
      recordId: id,
      action: PendingSyncAction.delete,
      payload: const {},
    );
    unawaited(_syncIfOnline());
  }

  Future<void> syncPendingChanges() async {
    if (_isSyncing) {
      return;
    }

    _isSyncing = true;
    try {
      if (!await _canUseSupabase()) {
        return;
      }

      final items = await _pendingSyncRepository.fetchPending(
        tableName: _tableName,
      );

      for (final item in items) {
        if (!await _canUseSupabase()) {
          return;
        }

        final didSync = await _syncItem(item);
        if (!didSync) {
          return;
        }
        await _pendingSyncRepository.markSynced(item.id);
        await _markLocalSynced(item);
      }
    } catch (_) {
      // Product sync is best-effort; queued rows remain pending for retry.
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> hydrateFromRemote() async {
    if (_isHydrating) {
      return false;
    }

    final lastHydratedAt = _lastHydratedAt;
    if (lastHydratedAt != null &&
        DateTime.now().difference(lastHydratedAt) < _minimumHydrationInterval) {
      return false;
    }

    _isHydrating = true;
    try {
      if (!await _canUseSupabase()) {
        return false;
      }

      if (_isSyncing) {
        return false;
      }

      await syncPendingChanges();

      if (!await _canUseSupabase()) {
        return false;
      }

      debugPrint('PRODUCTS_SUPABASE_FETCH');
      final rows = await _client.from(_tableName).select();
      for (final row in rows) {
        await _upsertRemoteProduct(
          Product.fromJson(row),
          userId: (row['user_id'] ?? _client.auth.currentUser?.id)?.toString(),
        );
      }
      _lastHydratedAt = DateTime.now();
      return true;
    } catch (_) {
      // Product hydration is best-effort; local rows remain the UI source.
      return false;
    } finally {
      _isHydrating = false;
    }
  }

  Future<void> _upsertLocalProduct(
    Product product, {
    required String syncStatus,
    required int isDeleted,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _database.customStatement(
      '''
INSERT INTO products (
  id,
  user_id,
  name,
  sku,
  category,
  cost_price,
  selling_price,
  stock_quantity,
  reorder_level,
  sync_status,
  is_deleted,
  created_at,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
  name = excluded.name,
  sku = excluded.sku,
  category = excluded.category,
  cost_price = excluded.cost_price,
  selling_price = excluded.selling_price,
  stock_quantity = excluded.stock_quantity,
  reorder_level = excluded.reorder_level,
  sync_status = excluded.sync_status,
  is_deleted = excluded.is_deleted,
  updated_at = excluded.updated_at
''',
      [
        product.id,
        _client.auth.currentUser?.id,
        product.name,
        product.sku,
        product.category,
        product.costPrice,
        product.sellingPrice,
        product.quantityInStock,
        product.reorderLevel,
        syncStatus,
        isDeleted,
        product.createdAt?.toIso8601String() ?? now,
        now,
      ],
    );
  }

  Future<void> _upsertRemoteProduct(
    Product product, {
    required String? userId,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _database.customStatement(
      '''
INSERT INTO products (
  id,
  user_id,
  name,
  sku,
  category,
  cost_price,
  selling_price,
  stock_quantity,
  reorder_level,
  sync_status,
  is_deleted,
  last_synced_at,
  created_at,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'synced', ?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
  user_id = excluded.user_id,
  name = excluded.name,
  sku = excluded.sku,
  category = excluded.category,
  cost_price = excluded.cost_price,
  selling_price = excluded.selling_price,
  stock_quantity = excluded.stock_quantity,
  reorder_level = excluded.reorder_level,
  sync_status = 'synced',
  is_deleted = excluded.is_deleted,
  last_synced_at = excluded.last_synced_at,
  updated_at = excluded.updated_at
WHERE products.sync_status != 'pending'
''',
      [
        product.id,
        userId,
        product.name,
        product.sku,
        product.category,
        product.costPrice,
        product.sellingPrice,
        product.quantityInStock,
        product.reorderLevel,
        0,
        now,
        product.createdAt?.toIso8601String() ?? now,
        now,
      ],
    );
  }

  Future<void> _syncIfOnline() async {
    try {
      await syncPendingChanges();
    } catch (_) {
      // Product sync is best-effort; queued rows remain pending for retry.
    }
  }

  Future<bool> _syncItem(PendingSyncItem item) async {
    if (!await _canUseSupabase()) {
      return false;
    }

    switch (item.action) {
      case PendingSyncAction.create:
        await _client.from(_tableName).upsert({
          ...item.payload,
          'id': item.recordId,
          'user_id': _client.auth.currentUser!.id,
        });
      case PendingSyncAction.update:
        await _client
            .from(_tableName)
            .update(item.payload)
            .eq('id', item.recordId);
      case PendingSyncAction.delete:
        await _client.from(_tableName).delete().eq('id', item.recordId);
    }
    return true;
  }

  Future<bool> _canUseSupabase() async {
    try {
      return _connectivityService.isOnline();
    } catch (_) {
      return false;
    }
  }

  Future<void> _markLocalSynced(PendingSyncItem item) async {
    if (item.action == PendingSyncAction.delete) {
      final now = DateTime.now().toIso8601String();
      await _database.customStatement(
        '''
UPDATE products
SET is_deleted = 1,
    sync_status = 'synced',
    last_synced_at = ?,
    updated_at = ?
WHERE id = ?
''',
        [now, now, item.recordId],
      );
      return;
    }

    final now = DateTime.now().toIso8601String();
    await _database.customStatement(
      '''
UPDATE products
SET sync_status = 'synced',
    last_synced_at = ?,
    updated_at = ?
WHERE id = ?
''',
      [now, now, item.recordId],
    );
  }

  Map<String, dynamic> _remotePayload(Product product) {
    return {
      'name': product.name,
      'sku': product.sku,
      'category': product.category,
      'cost_price': product.costPrice,
      'selling_price': product.sellingPrice,
      'stock_quantity': product.quantityInStock,
      'reorder_level': product.reorderLevel,
    };
  }

  String _newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String section(int start, int end) {
      return bytes
          .sublist(start, end)
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
    }

    return [
      section(0, 4),
      section(4, 6),
      section(6, 8),
      section(8, 10),
      section(10, 16),
    ].join('-');
  }
}

class ProductDeleteBlockedException implements Exception {
  const ProductDeleteBlockedException();

  @override
  String toString() {
    return 'This product has sales and cannot be deleted. Delete the related sales first, or keep the product for sales history.';
  }
}
