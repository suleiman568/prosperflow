import 'package:drift/drift.dart';

QueryExecutor openDatabaseConnection() {
  return _WebMemoryDatabase();
}

class _WebMemoryDatabase extends QueryExecutor {
  final List<Map<String, Object?>> _customers = [];
  final List<Map<String, Object?>> _products = [];
  final List<Map<String, Object?>> _pendingSync = [];
  var _nextPendingSyncId = 1;

  @override
  SqlDialect get dialect => SqlDialect.sqlite;

  @override
  QueryExecutor beginExclusive() => this;

  @override
  TransactionExecutor beginTransaction() => _WebMemoryTransaction(this);

  @override
  Future<void> close() async {}

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) async => true;

  @override
  Future<void> runBatched(BatchedStatements statements) async {
    for (final argumentSet in statements.arguments) {
      final statement = statements.statements[argumentSet.statementIndex];
      await runCustom(statement, argumentSet.arguments);
    }
  }

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) async {
    final normalized = _normalize(statement);
    final variables = args ?? const [];

    if (normalized.startsWith('insert into customers')) {
      _upsertCustomer(
        variables,
        isRemoteHydration: _isRemoteHydration(normalized),
      );
      return;
    }

    if (normalized.startsWith('insert into products')) {
      _upsertProduct(
        variables,
        isRemoteHydration: _isRemoteHydration(normalized),
      );
      return;
    }

    if (normalized.startsWith('update customers set is_deleted')) {
      _softDeleteCustomer(
        variables,
        isSyncedDelete: normalized.contains("sync_status = 'synced'"),
      );
      return;
    }

    if (normalized.startsWith('update products set is_deleted')) {
      _softDeleteProduct(
        variables,
        isSyncedDelete: normalized.contains("sync_status = 'synced'"),
      );
      return;
    }

    if (normalized.startsWith('insert into pending_sync')) {
      _insertPendingSync(variables);
      return;
    }

    if (normalized.startsWith('delete from pending_sync')) {
      _pendingSync.removeWhere((row) => row['id'] == variables[0]);
      return;
    }

    if (normalized.startsWith('update pending_sync')) {
      _markPendingSyncFailed(variables);
      return;
    }

    if (normalized.startsWith('delete from customers')) {
      _customers.removeWhere((row) => row['id'] == variables[0]);
      return;
    }

    if (normalized.startsWith('delete from products')) {
      _products.removeWhere((row) => row['id'] == variables[0]);
    }
  }

  @override
  Future<int> runDelete(String statement, List<Object?> args) async {
    await runCustom(statement, args);
    return 0;
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) async {
    await runCustom(statement, args);
    return 0;
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) async {
    final normalized = _normalize(statement);

    if (normalized == 'select 1') {
      return [
        {'1': 1},
      ];
    }

    if (normalized.startsWith('select id, name, email, phone, company')) {
      final rows = _customers
          .where((row) => row['is_deleted'] != 1)
          .map((row) => Map<String, Object?>.from(row))
          .toList();
      rows.sort((a, b) {
        final aKey = (a['created_at'] ?? a['updated_at'] ?? a['id']).toString();
        final bKey = (b['created_at'] ?? b['updated_at'] ?? b['id']).toString();
        return aKey.compareTo(bKey);
      });
      return rows;
    }

    if (normalized.startsWith('select id, name, sku, category')) {
      final rows = _products
          .where((row) => row['is_deleted'] != 1)
          .map((row) => Map<String, Object?>.from(row))
          .toList();
      rows.sort((a, b) {
        final aKey = (a['created_at'] ?? a['updated_at'] ?? a['id']).toString();
        final bKey = (b['created_at'] ?? b['updated_at'] ?? b['id']).toString();
        return aKey.compareTo(bKey);
      });
      return rows;
    }

    if (normalized.startsWith('select id, table_name, record_id')) {
      final tableName = args.first?.toString();
      return _pendingSync
          .where((row) => row['table_name'] == tableName)
          .map((row) => Map<String, Object?>.from(row))
          .toList();
    }

    return const [];
  }

  @override
  Future<int> runUpdate(String statement, List<Object?> args) async {
    await runCustom(statement, args);
    return 0;
  }

  void _upsertCustomer(
    List<Object?> variables, {
    required bool isRemoteHydration,
  }) {
    final id = variables[0]?.toString() ?? '';
    final existingIndex = _customers.indexWhere((row) => row['id'] == id);
    if (isRemoteHydration &&
        existingIndex >= 0 &&
        _customers[existingIndex]['sync_status'] == 'pending') {
      return;
    }
    final row = <String, Object?>{
      'id': id,
      'user_id': variables[1],
      'name': variables[2]?.toString() ?? '',
      'email': variables[3]?.toString() ?? '',
      'phone': variables[4]?.toString() ?? '',
      'company': variables[5]?.toString() ?? '',
      'sync_status': isRemoteHydration
          ? 'synced'
          : variables[6]?.toString() ?? 'pending',
      'is_deleted': _asInt(variables[isRemoteHydration ? 6 : 7]),
      'last_synced_at': isRemoteHydration ? variables[7]?.toString() : null,
      'created_at': variables[8]?.toString(),
      'updated_at': variables[9]?.toString(),
    };

    if (existingIndex >= 0) {
      _customers[existingIndex] = {
        ..._customers[existingIndex],
        ...row,
        'created_at':
            _customers[existingIndex]['created_at'] ?? row['created_at'],
      };
    } else {
      _customers.add(row);
    }
  }

  void _softDeleteCustomer(
    List<Object?> variables, {
    required bool isSyncedDelete,
  }) {
    final id = variables[isSyncedDelete ? 2 : 1]?.toString();
    final existingIndex = _customers.indexWhere((row) => row['id'] == id);
    if (existingIndex >= 0) {
      _customers[existingIndex] = {
        ..._customers[existingIndex],
        'is_deleted': 1,
        'sync_status': isSyncedDelete ? 'synced' : 'pending',
        'last_synced_at': isSyncedDelete ? variables[0]?.toString() : null,
        'updated_at': variables[isSyncedDelete ? 1 : 0]?.toString(),
      };
    }
  }

  void _upsertProduct(
    List<Object?> variables, {
    required bool isRemoteHydration,
  }) {
    final id = variables[0]?.toString() ?? '';
    final existingIndex = _products.indexWhere((row) => row['id'] == id);
    if (isRemoteHydration &&
        existingIndex >= 0 &&
        _products[existingIndex]['sync_status'] == 'pending') {
      return;
    }
    final row = <String, Object?>{
      'id': id,
      'user_id': variables[1],
      'name': variables[2]?.toString() ?? '',
      'sku': variables[3]?.toString() ?? '',
      'category': variables[4]?.toString() ?? '',
      'cost_price': _asDouble(variables[5]),
      'selling_price': _asDouble(variables[6]),
      'stock_quantity': _asInt(variables[7]),
      'reorder_level': _asInt(variables[8]),
      'sync_status': isRemoteHydration
          ? 'synced'
          : variables[9]?.toString() ?? 'pending',
      'is_deleted': _asInt(variables[isRemoteHydration ? 9 : 10]),
      'last_synced_at': isRemoteHydration ? variables[10]?.toString() : null,
      'created_at': variables[11]?.toString(),
      'updated_at': variables[12]?.toString(),
    };

    if (existingIndex >= 0) {
      _products[existingIndex] = {
        ..._products[existingIndex],
        ...row,
        'created_at':
            _products[existingIndex]['created_at'] ?? row['created_at'],
      };
    } else {
      _products.add(row);
    }
  }

  void _softDeleteProduct(
    List<Object?> variables, {
    required bool isSyncedDelete,
  }) {
    final id = variables[isSyncedDelete ? 2 : 1]?.toString();
    final existingIndex = _products.indexWhere((row) => row['id'] == id);
    if (existingIndex >= 0) {
      _products[existingIndex] = {
        ..._products[existingIndex],
        'is_deleted': 1,
        'sync_status': isSyncedDelete ? 'synced' : 'pending',
        'last_synced_at': isSyncedDelete ? variables[0]?.toString() : null,
        'updated_at': variables[isSyncedDelete ? 1 : 0]?.toString(),
      };
    }
  }

  void _insertPendingSync(List<Object?> variables) {
    _pendingSync.add({
      'id': _nextPendingSyncId++,
      'table_name': variables[0]?.toString() ?? '',
      'record_id': variables[1]?.toString() ?? '',
      'action': variables[2]?.toString() ?? 'update',
      'payload': variables[3]?.toString() ?? '{}',
      'attempt_count': 0,
    });
  }

  void _markPendingSyncFailed(List<Object?> variables) {
    final id = variables[1];
    final existingIndex = _pendingSync.indexWhere((row) => row['id'] == id);
    if (existingIndex >= 0) {
      final row = _pendingSync[existingIndex];
      _pendingSync[existingIndex] = {
        ...row,
        'attempt_count': ((row['attempt_count'] as int?) ?? 0) + 1,
        'last_error': variables[0]?.toString(),
      };
    }
  }

  String _normalize(String statement) {
    return statement.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  bool _isRemoteHydration(String normalizedStatement) {
    return normalizedStatement.contains('last_synced_at') &&
        normalizedStatement.contains("sync_status = 'synced'");
  }

  double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse((value ?? '0').toString()) ?? 0;
  }

  int _asInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse((value ?? '0').toString()) ?? 0;
  }
}

class _WebMemoryTransaction extends _WebMemoryDatabase
    implements TransactionExecutor {
  _WebMemoryTransaction(this._delegate);

  final _WebMemoryDatabase _delegate;

  @override
  bool get supportsNestedTransactions => false;

  @override
  Future<void> rollback() async {}

  @override
  Future<void> send() async {}

  @override
  QueryExecutor beginExclusive() => _delegate.beginExclusive();

  @override
  TransactionExecutor beginTransaction() => _delegate.beginTransaction();

  @override
  Future<void> close() => _delegate.close();

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) => _delegate.ensureOpen(user);

  @override
  Future<void> runBatched(BatchedStatements statements) =>
      _delegate.runBatched(statements);

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) =>
      _delegate.runCustom(statement, args);

  @override
  Future<int> runDelete(String statement, List<Object?> args) =>
      _delegate.runDelete(statement, args);

  @override
  Future<int> runInsert(String statement, List<Object?> args) =>
      _delegate.runInsert(statement, args);

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) => _delegate.runSelect(statement, args);

  @override
  Future<int> runUpdate(String statement, List<Object?> args) =>
      _delegate.runUpdate(statement, args);
}
