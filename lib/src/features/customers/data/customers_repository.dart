import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/local_database.dart';
import '../../../core/offline/pending_sync_repository.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/customer.dart';

class CustomersRepository {
  CustomersRepository({
    required AppDatabase database,
    required PendingSyncRepository pendingSyncRepository,
    required ConnectivityService connectivityService,
    SupabaseClient? client,
  }) : _database = database,
       _pendingSyncRepository = pendingSyncRepository,
       _connectivityService = connectivityService,
       _client = client ?? SupabaseService.client;

  static const _tableName = 'customers';

  final AppDatabase _database;
  final PendingSyncRepository _pendingSyncRepository;
  final ConnectivityService _connectivityService;
  final SupabaseClient _client;
  bool _isSyncing = false;
  bool _isHydratingCustomers = false;
  bool _hasStartedStartupHydration = false;
  DateTime? _lastHydratedAt;

  static const _minimumHydrationInterval = Duration(minutes: 1);

  Future<List<Customer>> fetchCustomers() async {
    return fetchLocalCustomers();
  }

  void maybeHydrateFromRemoteInBackground({
    required VoidCallback onHydrated,
    bool force = false,
    bool startup = false,
  }) {
    if (startup) {
      if (_hasStartedStartupHydration) {
        return;
      }
      _hasStartedStartupHydration = true;
    }

    if (_isHydratingCustomers) {
      return;
    }

    final lastHydratedAt = _lastHydratedAt;
    if (!force &&
        lastHydratedAt != null &&
        DateTime.now().difference(lastHydratedAt) < _minimumHydrationInterval) {
      return;
    }

    unawaited(() async {
      final didHydrate = await hydrateFromRemote(force: force);
      if (didHydrate) {
        onHydrated();
      }
    }());
  }

  void resetStartupHydration() {
    _hasStartedStartupHydration = false;
  }

  Future<List<Customer>> fetchLocalCustomers() async {
    final customers = await _fetchLocalCustomers();
    debugPrint('Loaded customers from local DB');
    return customers;
  }

  Future<Customer> createCustomer(Customer customer) async {
    final localCustomer = Customer(
      id: customer.id.isEmpty ? _newUuid() : customer.id,
      name: customer.name,
      email: customer.email,
      phone: customer.phone,
      company: customer.company,
      createdAt: customer.createdAt ?? DateTime.now(),
    );

    await _upsertLocalCustomer(
      localCustomer,
      syncStatus: 'pending',
      isDeleted: 0,
    );
    debugPrint('Saved customer locally');
    await _pendingSyncRepository.enqueue(
      tableName: _tableName,
      recordId: localCustomer.id,
      action: PendingSyncAction.create,
      payload: _remotePayload(localCustomer),
    );
    debugPrint('Queued customer sync');
    unawaited(_syncIfOnline());

    return localCustomer;
  }

  Future<Customer> updateCustomer(Customer customer) async {
    await _upsertLocalCustomer(customer, syncStatus: 'pending', isDeleted: 0);
    debugPrint('Saved customer locally');
    await _pendingSyncRepository.enqueue(
      tableName: _tableName,
      recordId: customer.id,
      action: PendingSyncAction.update,
      payload: _remotePayload(customer),
    );
    debugPrint('Queued customer sync');
    unawaited(_syncIfOnline());

    return customer;
  }

  Future<void> deleteCustomer(String id) async {
    await _database.customStatement(
      '''
UPDATE customers
SET is_deleted = 1,
    sync_status = 'pending',
    updated_at = ?
WHERE id = ?
''',
      [DateTime.now().toIso8601String(), id],
    );
    debugPrint('Saved customer locally');
    await _pendingSyncRepository.enqueue(
      tableName: _tableName,
      recordId: id,
      action: PendingSyncAction.delete,
      payload: const {},
    );
    debugPrint('Queued customer sync');
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
    } catch (error) {
      debugPrint('Customer Supabase sync failed silently: $error');
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> hydrateFromRemote({bool force = false}) async {
    if (_isHydratingCustomers) {
      return false;
    }

    final lastHydratedAt = _lastHydratedAt;
    if (!force &&
        lastHydratedAt != null &&
        DateTime.now().difference(lastHydratedAt) < _minimumHydrationInterval) {
      return false;
    }

    _isHydratingCustomers = true;
    try {
      if (!await _canUseSupabase()) {
        return false;
      }

      if (!_isSyncing) {
        await syncPendingChanges();
      }

      if (!await _canUseSupabase()) {
        return false;
      }

      final rows = await _client.from(_tableName).select();
      for (final row in rows) {
        await _upsertRemoteCustomer(
          Customer.fromJson(row),
          userId: (row['user_id'] ?? _client.auth.currentUser?.id)?.toString(),
          isDeleted: _asInt(row['is_deleted']),
        );
      }
      _lastHydratedAt = DateTime.now();
      return true;
    } catch (error) {
      debugPrint('Customer Supabase hydration failed silently: $error');
      return false;
    } finally {
      _isHydratingCustomers = false;
    }
  }

  Future<List<Customer>> _fetchLocalCustomers() async {
    final rows = await _database.customSelect('''
SELECT id, name, email, phone, company, created_at
FROM customers
WHERE is_deleted = 0
ORDER BY COALESCE(created_at, updated_at, id) ASC
''').get();

    return rows.map((row) {
      return Customer(
        id: row.read<String>('id'),
        name: row.read<String>('name'),
        email: row.read<String>('email'),
        phone: row.read<String>('phone'),
        company: row.read<String>('company'),
        createdAt: DateTime.tryParse(
          row.readNullable<String>('created_at') ?? '',
        ),
      );
    }).toList();
  }

  Future<void> _upsertLocalCustomer(
    Customer customer, {
    required String syncStatus,
    required int isDeleted,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _database.customStatement(
      '''
INSERT INTO customers (
  id,
  user_id,
  name,
  email,
  phone,
  company,
  sync_status,
  is_deleted,
  created_at,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  company = excluded.company,
  sync_status = excluded.sync_status,
  is_deleted = excluded.is_deleted,
  updated_at = excluded.updated_at
''',
      [
        customer.id,
        _client.auth.currentUser?.id,
        customer.name,
        customer.email,
        customer.phone,
        customer.company,
        syncStatus,
        isDeleted,
        customer.createdAt?.toIso8601String() ?? now,
        now,
      ],
    );
  }

  Future<void> _upsertRemoteCustomer(
    Customer customer, {
    required String? userId,
    required int isDeleted,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _database.customStatement(
      '''
INSERT INTO customers (
  id,
  user_id,
  name,
  email,
  phone,
  company,
  sync_status,
  is_deleted,
  last_synced_at,
  created_at,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, 'synced', ?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
  user_id = excluded.user_id,
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone,
  company = excluded.company,
  sync_status = 'synced',
  is_deleted = excluded.is_deleted,
  last_synced_at = excluded.last_synced_at,
  updated_at = excluded.updated_at
WHERE customers.sync_status != 'pending'
  AND ? = ?
''',
      [
        customer.id,
        userId,
        customer.name,
        customer.email,
        customer.phone,
        customer.company,
        isDeleted,
        now,
        customer.createdAt?.toIso8601String() ?? now,
        now,
        'remote_hydration',
        'remote_hydration',
      ],
    );
  }

  Future<void> _syncIfOnline() async {
    await syncPendingChanges();
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
      final isOnline = await _connectivityService.isOnline();
      if (!isOnline) {
        debugPrint('Skipped Supabase fetch while offline');
      }
      return isOnline;
    } catch (_) {
      debugPrint('Skipped Supabase fetch while offline');
      return false;
    }
  }

  Future<void> _markLocalSynced(PendingSyncItem item) async {
    if (item.action == PendingSyncAction.delete) {
      final now = DateTime.now().toIso8601String();
      await _database.customStatement(
        '''
UPDATE customers
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
UPDATE customers
SET sync_status = 'synced',
    last_synced_at = ?,
    updated_at = ?
WHERE id = ?
''',
      [
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
        item.recordId,
      ],
    );
  }

  Map<String, dynamic> _remotePayload(Customer customer) {
    return {
      'name': customer.name,
      'email': customer.email,
      'phone': customer.phone,
      'company': customer.company,
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

  int _asInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse((value ?? '0').toString()) ?? 0;
  }
}
