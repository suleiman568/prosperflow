import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/local_database.dart';
import '../../../core/offline/pending_sync_repository.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/sale.dart';

class SalesRepository {
  SalesRepository({
    required AppDatabase database,
    required PendingSyncRepository pendingSyncRepository,
    required ConnectivityService connectivityService,
    SupabaseClient? client,
  }) : _database = database,
       _pendingSyncRepository = pendingSyncRepository,
       _connectivityService = connectivityService,
       _client = client ?? SupabaseService.client;

  static const _tableName = 'sales';
  static const _productsTableName = 'products';

  final AppDatabase _database;
  final PendingSyncRepository _pendingSyncRepository;
  final ConnectivityService _connectivityService;
  final SupabaseClient _client;
  bool _isSyncing = false;
  bool _hasStartedStartupSync = false;

  Future<List<Sale>> fetchSales() async {
    return fetchLocalSales();
  }

  Future<List<Sale>> fetchLocalSales() async {
    debugPrint('SALES_LOCAL_FETCH');
    try {
      final rows = await _database.customSelect('''
SELECT id,
       customer_id,
       product_id,
       quantity,
       unit_price,
       total_amount,
       payment_status,
       sale_date,
       created_at,
       sync_status
FROM sales
WHERE is_deleted = 0
ORDER BY COALESCE(sale_date, created_at, updated_at, id) DESC
''').get();

      return rows.map((row) {
        return Sale(
          id: row.read<String>('id'),
          customerId: row.read<String>('customer_id'),
          productId: row.read<String>('product_id'),
          quantity: row.read<int>('quantity'),
          unitPrice: row.read<num>('unit_price').toDouble(),
          totalAmount: row.read<num>('total_amount').toDouble(),
          paymentStatus: row.read<String>('payment_status'),
          saleDate: DateTime.tryParse(
            row.readNullable<String>('sale_date') ?? '',
          ),
          createdAt: DateTime.tryParse(
            row.readNullable<String>('created_at') ?? '',
          ),
          syncStatus: row.read<String>('sync_status'),
        );
      }).toList();
    } catch (error) {
      debugPrint('SALES_LOCAL_FETCH_FAILED: $error');
      return const [];
    }
  }

  void maybeSyncPendingChangesInBackground({
    required VoidCallback onSynced,
    bool startup = false,
    bool force = false,
  }) {
    if (startup) {
      if (_hasStartedStartupSync) {
        return;
      }
      _hasStartedStartupSync = true;
    }

    if (_isSyncing && !force) {
      return;
    }

    unawaited(() async {
      await syncPendingChanges();
      onSynced();
    }());
  }

  void resetStartupSync() {
    _hasStartedStartupSync = false;
  }

  Future<Sale> createSale(Sale sale) async {
    final localSale = Sale(
      id: sale.id.isEmpty ? _newUuid() : sale.id,
      customerId: sale.customerId,
      productId: sale.productId,
      quantity: sale.quantity,
      unitPrice: sale.unitPrice,
      totalAmount: sale.totalAmount == 0
          ? sale.quantity * sale.unitPrice
          : sale.totalAmount,
      paymentStatus: sale.paymentStatus,
      saleDate: sale.saleDate ?? DateTime.now(),
      createdAt: sale.createdAt ?? DateTime.now(),
      syncStatus: 'pending',
    );

    await _upsertLocalSale(localSale, syncStatus: 'pending', isDeleted: 0);
    debugPrint('SALES_LOCAL_SAVE');

    final stockUpdates = <String, int>{};
    final nextStock = await _applyProductStockDelta(
      localSale.productId,
      -localSale.quantity,
    );
    if (nextStock != null) {
      stockUpdates[localSale.productId] = nextStock;
    }
    await _queueSync(
      localSale,
      action: PendingSyncAction.create,
      stockUpdates: stockUpdates,
    );
    debugPrint('SALES_CREATED_LOCAL');
    unawaited(_syncIfOnline());

    return localSale;
  }

  Future<Sale> updateSale(Sale sale) async {
    final existing = await _fetchLocalSale(sale.id);
    if (existing == null) {
      throw StateError('Sale not found.');
    }

    final updatedSale = Sale(
      id: sale.id,
      customerId: sale.customerId,
      productId: sale.productId,
      quantity: sale.quantity,
      unitPrice: sale.unitPrice,
      totalAmount: sale.totalAmount == 0
          ? sale.quantity * sale.unitPrice
          : sale.totalAmount,
      paymentStatus: sale.paymentStatus,
      saleDate: sale.saleDate ?? existing.saleDate ?? DateTime.now(),
      createdAt: sale.createdAt ?? existing.createdAt,
      syncStatus: 'pending',
    );

    await _upsertLocalSale(updatedSale, syncStatus: 'pending', isDeleted: 0);
    debugPrint('SALES_LOCAL_SAVE');

    final stockUpdates = <String, int>{};
    if (existing.productId == updatedSale.productId) {
      final delta = existing.quantity - updatedSale.quantity;
      if (delta != 0) {
        final nextStock = await _applyProductStockDelta(
          updatedSale.productId,
          delta,
        );
        if (nextStock != null) {
          stockUpdates[updatedSale.productId] = nextStock;
        }
      }
    } else {
      final updatedProductStock = await _applyProductStockDelta(
        updatedSale.productId,
        -updatedSale.quantity,
      );
      if (updatedProductStock != null) {
        stockUpdates[updatedSale.productId] = updatedProductStock;
      }
      final existingProductStock = await _applyProductStockDelta(
        existing.productId,
        existing.quantity,
      );
      if (existingProductStock != null) {
        stockUpdates[existing.productId] = existingProductStock;
      }
    }

    await _queueSync(
      updatedSale,
      action: PendingSyncAction.update,
      stockUpdates: stockUpdates,
    );
    unawaited(_syncIfOnline());

    return updatedSale;
  }

  Future<void> deleteSale(Sale sale) async {
    final existing = await _fetchLocalSale(sale.id);
    if (existing == null) {
      return;
    }

    final stockUpdates = <String, int>{};
    final nextStock = await _applyProductStockDelta(
      existing.productId,
      existing.quantity,
    );
    if (nextStock != null) {
      stockUpdates[existing.productId] = nextStock;
    }

    await _database.customStatement(
      '''
UPDATE sales
SET is_deleted = 1,
    sync_status = 'pending',
    updated_at = ?
WHERE id = ?
''',
      [DateTime.now().toIso8601String(), sale.id],
    );
    debugPrint('SALES_LOCAL_SAVE');

    await _queueSync(
      existing,
      action: PendingSyncAction.delete,
      stockUpdates: stockUpdates,
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

        await _syncItem(item);
        await _pendingSyncRepository.markSynced(item.id);
        await _markLocalSynced(item);
      }
      await _syncPendingProductStockUpdates();
    } catch (_) {
      // Sales sync is best-effort; queued rows remain pending for retry.
    } finally {
      _isSyncing = false;
    }
  }

  Future<Sale?> _fetchLocalSale(String id) async {
    final rows = await _database
        .customSelect(
          '''
SELECT id,
       customer_id,
       product_id,
       quantity,
       unit_price,
       total_amount,
       payment_status,
       sale_date,
       created_at,
       sync_status
FROM sales
WHERE id = ?
LIMIT 1
''',
          variables: [Variable.withString(id)],
        )
        .get();
    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;
    return Sale(
      id: row.read<String>('id'),
      customerId: row.read<String>('customer_id'),
      productId: row.read<String>('product_id'),
      quantity: row.read<int>('quantity'),
      unitPrice: row.read<num>('unit_price').toDouble(),
      totalAmount: row.read<num>('total_amount').toDouble(),
      paymentStatus: row.read<String>('payment_status'),
      saleDate: DateTime.tryParse(row.readNullable<String>('sale_date') ?? ''),
      createdAt: DateTime.tryParse(
        row.readNullable<String>('created_at') ?? '',
      ),
      syncStatus: row.read<String>('sync_status'),
    );
  }

  Future<void> _upsertLocalSale(
    Sale sale, {
    required String syncStatus,
    required int isDeleted,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _database.customStatement(
      '''
INSERT INTO sales (
  id,
  user_id,
  customer_id,
  product_id,
  quantity,
  unit_price,
  total_amount,
  payment_status,
  sale_date,
  sync_status,
  is_deleted,
  created_at,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
  customer_id = excluded.customer_id,
  product_id = excluded.product_id,
  quantity = excluded.quantity,
  unit_price = excluded.unit_price,
  total_amount = excluded.total_amount,
  payment_status = excluded.payment_status,
  sale_date = excluded.sale_date,
  sync_status = excluded.sync_status,
  is_deleted = excluded.is_deleted,
  updated_at = excluded.updated_at
''',
      [
        sale.id,
        _client.auth.currentUser?.id,
        sale.customerId,
        sale.productId,
        sale.quantity,
        sale.unitPrice,
        sale.totalAmount,
        sale.paymentStatus,
        sale.saleDate?.toIso8601String(),
        syncStatus,
        isDeleted,
        sale.createdAt?.toIso8601String() ?? now,
        now,
      ],
    );
  }

  Future<int?> _applyProductStockDelta(String productId, int delta) async {
    final rows = await _database
        .customSelect(
          '''
SELECT stock_quantity
FROM products
WHERE id = ? AND is_deleted = 0
LIMIT 1
''',
          variables: [Variable.withString(productId)],
        )
        .get();
    if (rows.isEmpty) {
      return null;
    }

    final current = rows.first.read<int>('stock_quantity');
    final next = current + delta;

    await _database.customStatement(
      '''
UPDATE products
SET stock_quantity = ?,
    sync_status = 'pending',
    updated_at = ?
WHERE id = ?
''',
      [next, DateTime.now().toIso8601String(), productId],
    );
    debugPrint('SALES_LOCAL_STOCK_UPDATE');
    return next;
  }

  Future<void> _queueSync(
    Sale sale, {
    required PendingSyncAction action,
    required Map<String, int> stockUpdates,
  }) async {
    await _pendingSyncRepository.enqueue(
      tableName: _tableName,
      recordId: sale.id,
      action: action,
      payload: _remotePayload(sale),
    );
    debugPrint('SALES_PENDING_SYNC_QUEUED');

    for (final entry in stockUpdates.entries) {
      await _pendingSyncRepository.enqueue(
        tableName: _productsTableName,
        recordId: entry.key,
        action: PendingSyncAction.update,
        payload: {'stock_quantity': entry.value},
      );
      debugPrint('SALES_PENDING_SYNC_QUEUED');
    }
  }

  Future<void> _syncItem(PendingSyncItem item) async {
    switch (item.action) {
      case PendingSyncAction.create:
        await _client.from(_tableName).upsert({
          ..._salePayloadFromItem(item),
          'id': item.recordId,
          'user_id': _client.auth.currentUser!.id,
        });
      case PendingSyncAction.update:
        await _client
            .from(_tableName)
            .update(_salePayloadFromItem(item))
            .eq('id', item.recordId);
      case PendingSyncAction.delete:
        await _client.from(_tableName).delete().eq('id', item.recordId);
    }
  }

  Future<void> _syncPendingProductStockUpdates() async {
    final items = await _pendingSyncRepository.fetchPending(
      tableName: _productsTableName,
    );

    for (final item in items) {
      if (!await _canUseSupabase()) {
        return;
      }
      if (!_isProductStockUpdate(item)) {
        continue;
      }

      try {
        await _client
            .from(_productsTableName)
            .update(item.payload)
            .eq('id', item.recordId);
        await _pendingSyncRepository.markSynced(item.id);
        await _markLocalProductSynced(item.recordId);
      } catch (error) {
        await _pendingSyncRepository.markFailed(item.id, error);
      }
    }
  }

  Map<String, dynamic> _salePayloadFromItem(PendingSyncItem item) {
    final salePayload = item.payload['sale'];
    if (salePayload == null) {
      final payload = Map<String, dynamic>.from(item.payload);
      payload.remove('stock_updates');
      return payload;
    }
    if (salePayload is Map<String, dynamic>) {
      return salePayload;
    }
    return Map<String, dynamic>.from(salePayload as Map);
  }

  bool _isProductStockUpdate(PendingSyncItem item) {
    return item.tableName == _productsTableName &&
        item.action == PendingSyncAction.update &&
        item.payload.length == 1 &&
        item.payload.containsKey('stock_quantity');
  }

  Future<void> _markLocalSynced(PendingSyncItem item) async {
    final now = DateTime.now().toIso8601String();
    if (item.action == PendingSyncAction.delete) {
      await _database.customStatement(
        '''
UPDATE sales
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

    await _database.customStatement(
      '''
UPDATE sales
SET sync_status = 'synced',
    last_synced_at = ?,
    updated_at = ?
WHERE id = ?
''',
      [now, now, item.recordId],
    );
  }

  Future<void> _markLocalProductSynced(String productId) async {
    final now = DateTime.now().toIso8601String();
    await _database.customStatement(
      '''
UPDATE products
SET sync_status = 'synced',
    last_synced_at = ?,
    updated_at = ?
WHERE id = ?
''',
      [now, now, productId],
    );
  }

  Future<void> _syncIfOnline() async {
    try {
      await syncPendingChanges();
    } catch (_) {
      // Sales sync is best-effort; queued rows remain pending for retry.
    }
  }

  Future<bool> _canUseSupabase() async {
    try {
      return _connectivityService.isOnline();
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _remotePayload(Sale sale) {
    return sale.toInsertJson();
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
