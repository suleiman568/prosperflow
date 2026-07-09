import 'package:supabase_flutter/supabase_flutter.dart';

/// Applies one outbox mutation to the server, idempotently — replays after
/// a dropped response must never double-count a sale (Backend Plan §5).
abstract class SyncBackend {
  /// True when a signed-in session exists to push under.
  bool get canPush;

  Future<void> apply(String entity, String op, Map<String, dynamic> payload);
}

/// Supabase implementation: `create` ops upsert on the client UUID (safe to
/// replay), `update` ops patch by primary key. Every row is stamped with the
/// signed-in trader's id — RLS rejects anything else.
class SupabaseSyncBackend implements SyncBackend {
  SupabaseSyncBackend(this._client);

  final SupabaseClient _client;

  static const _tables = {
    'product': 'products',
    'sale': 'sales',
    'expense': 'expenses',
    'credit': 'credits',
  };

  @override
  bool get canPush => _client.auth.currentSession != null;

  @override
  Future<void> apply(
      String entity, String op, Map<String, dynamic> payload) async {
    final table = _tables[entity]!;
    final pk = entity == 'credit' ? 'sale_id' : 'id';
    final row = {...payload, 'trader_id': _client.auth.currentUser!.id};

    if (op == 'create') {
      await _client.from(table).upsert(row, onConflict: pk);
    } else {
      final id = row.remove(pk);
      row.remove('trader_id'); // never update ownership
      await _client.from(table).update(row).eq(pk, id as Object);
    }
  }
}
