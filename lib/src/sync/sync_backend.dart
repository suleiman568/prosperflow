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
    'stock_adjustment': 'stock_adjustments',
  };

  @override
  bool get canPush => _client.auth.currentSession != null;

  @override
  Future<void> apply(
    String entity,
    String op,
    Map<String, dynamic> payload,
  ) async {
    final table = _tables[entity]!;
    final pk = entity == 'credit' ? 'sale_id' : 'id';
    final row = {...payload, 'trader_id': _client.auth.currentUser!.id};

    if (op == 'create') {
      // An insert that row-level security refuses fails its WITH CHECK and
      // comes back as an error, so this path is already loud.
      await _client.from(table).upsert(row, onConflict: pk);
    } else {
      final id = row.remove(pk);
      row.remove('trader_id'); // never update ownership
      // An update that matches no row — because RLS filtered it out, or the
      // row does not exist — is answered with 204, exactly like a successful
      // one, and postgrest treats any 2xx as success. Without asking for the
      // affected rows back there is no way to tell the two apart, and the
      // engine would drop the mutation from the outbox as though it had been
      // saved. Selecting makes the refusal an error, so the outbox keeps it
      // and the pending count stays visible to the trader.
      final affected = await _client
          .from(table)
          .update(row)
          .eq(pk, id as Object)
          .select();
      if (affected.isEmpty) {
        throw StateError(
          'Update to $table/$id affected no rows — it is owned by another '
          'trader, or no longer exists.',
        );
      }
    }
  }
}
