import 'dart:convert';

import 'package:drift/drift.dart';

import 'local_database.dart';

class PendingSyncRepository {
  const PendingSyncRepository(this._database);

  final AppDatabase _database;

  Future<void> enqueue({
    required String tableName,
    required String recordId,
    required PendingSyncAction action,
    required Map<String, dynamic> payload,
  }) async {
    await _database.customStatement(
      '''
INSERT INTO pending_sync (
  table_name,
  record_id,
  action,
  payload,
  updated_at
) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
''',
      [tableName, recordId, action.value, jsonEncode(payload)],
    );
  }

  Future<List<PendingSyncItem>> fetchPending({
    required String tableName,
  }) async {
    final rows = await _database
        .customSelect(
          '''
SELECT id, table_name, record_id, action, payload, attempt_count
FROM pending_sync
WHERE table_name = ?
ORDER BY created_at ASC, id ASC
''',
          variables: [Variable.withString(tableName)],
        )
        .get();

    return rows.map((row) {
      return PendingSyncItem(
        id: row.read<int>('id'),
        tableName: row.read<String>('table_name'),
        recordId: row.read<String>('record_id'),
        action: PendingSyncAction.fromValue(row.read<String>('action')),
        payload:
            jsonDecode(row.read<String>('payload')) as Map<String, dynamic>,
        attemptCount: row.read<int>('attempt_count'),
      );
    }).toList();
  }

  Future<void> markSynced(int id) async {
    await _database.customStatement('DELETE FROM pending_sync WHERE id = ?', [
      id,
    ]);
  }

  Future<void> markFailed(int id, Object error) async {
    await _database.customStatement(
      '''
UPDATE pending_sync
SET attempt_count = attempt_count + 1,
    last_error = ?,
    updated_at = CURRENT_TIMESTAMP
WHERE id = ?
''',
      [error.toString(), id],
    );
  }
}

enum PendingSyncAction {
  create('create'),
  update('update'),
  delete('delete');

  const PendingSyncAction(this.value);

  final String value;

  static PendingSyncAction fromValue(String value) {
    return PendingSyncAction.values.firstWhere(
      (action) => action.value == value,
      orElse: () => PendingSyncAction.update,
    );
  }
}

class PendingSyncItem {
  const PendingSyncItem({
    required this.id,
    required this.tableName,
    required this.recordId,
    required this.action,
    required this.payload,
    required this.attemptCount,
  });

  final int id;
  final String tableName;
  final String recordId;
  final PendingSyncAction action;
  final Map<String, dynamic> payload;
  final int attemptCount;
}
