import 'package:supabase_flutter/supabase_flutter.dart';

/// Raised to abandon sync work whose trader is no longer the one it started
/// under, because the phone changed hands part-way through.
///
/// Not a failure, and nothing to retry: the work belonged to a ledger this
/// device no longer holds. The sign-in that caused it starts its own sync.
class TraderChanged implements Exception {
  @override
  String toString() => 'TraderChanged: the database changed hands mid-sync';
}

/// Where a delta pull has reached, per entity.
///
/// A timestamp alone is not a position: now() is transaction time, so every
/// row one transaction writes shares a watermark — recording a sale stamps the
/// sale, the product and the credit identically. Paging on the timestamp alone
/// would skip the rest of a tied group when a page boundary landed inside it.
/// The primary key breaks the tie, which is why the server indexes
/// (trader_id, server_updated_at, pk).
class PullCursor {
  const PullCursor(this.watermark, this.lastId);

  final DateTime watermark;

  /// Null means "start at [watermark]" rather than "resume after a row" —
  /// used when a pull deliberately rewinds to re-cover a window.
  final String? lastId;

  String encode() => '${watermark.toIso8601String()}|${lastId ?? ''}';

  static PullCursor? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('|');
    final at = DateTime.tryParse(parts.first);
    if (at == null) return null;
    final id = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
    return PullCursor(at, id);
  }

  /// Steps back so the next pull re-covers [by].
  ///
  /// A watermark is stamped when a transaction starts, not when it commits, so
  /// a long transaction can land rows behind a cursor that has already moved
  /// past them — they would never be seen again. Re-covering a window catches
  /// them. Rows have client-generated primary keys and ingest upserts, so
  /// seeing one twice costs a write and changes nothing.
  PullCursor rewound(Duration by) => PullCursor(watermark.subtract(by), null);
}

/// One page of pulled rows.
class PullPage {
  const PullPage({required this.rows, required this.cursor});

  final List<Map<String, dynamic>> rows;

  /// Where to resume, or null when the entity is fully caught up.
  final PullCursor? cursor;

  bool get isEmpty => rows.isEmpty;
}

/// Applies one outbox mutation to the server, idempotently — replays after
/// a dropped response must never double-count a sale (Backend Plan §5).
abstract class SyncBackend {
  /// True when a signed-in session exists to push under.
  bool get canPush;

  /// Sends one mutation on behalf of [trader].
  ///
  /// Throws [TraderChanged] if the signed-in session is somebody else by the
  /// time it goes out, rather than filing the row under whoever happens to be
  /// signed in.
  Future<void> apply(
    String entity,
    String op,
    Map<String, dynamic> payload, {
    required String trader,
  });

  /// Reads up to [limit] rows of [entity] changed at or after [cursor], in
  /// (server_updated_at, primary key) order.
  ///
  /// Returns a cursor positioned after the last row, or null once the entity
  /// is caught up, so the caller can page without holding server state.
  Future<PullPage> fetchSince(
    String entity,
    PullCursor? cursor, {
    int limit = 200,
  });
}

/// Supabase implementation: `create` ops upsert on the client UUID (safe to
/// replay), `update` ops patch by primary key. Every row is stamped with the
/// signed-in trader's id — RLS rejects anything else.
class SupabaseSyncBackend implements SyncBackend {
  SupabaseSyncBackend(this._client);

  final SupabaseClient _client;

  /// The server-maintained watermark every pull orders and filters on.
  static const watermarkColumn = 'server_updated_at';

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
    Map<String, dynamic> payload, {
    required String trader,
  }) async {
    final table = _tables[entity]!;
    final pk = entity == 'credit' ? 'sale_id' : 'id';

    // The session is read once and that same value does the stamping. This is
    // the read that decides whose ledger the row joins, so the check belongs
    // here rather than only at the caller: the caller checked who owns the
    // local database, but a sign-in can complete between there and here, and
    // then the row would be filed under whoever happened to be signed in when
    // it went out. Nothing awaits between the check and the use, so no
    // sign-in can land in the gap.
    final signedIn = _client.auth.currentUser?.id;
    if (signedIn != trader) throw TraderChanged();
    final row = {...payload, 'trader_id': signedIn};

    if (op == 'create') {
      // An insert that row-level security refuses fails its WITH CHECK and
      // comes back as an error, so this path is already loud.
      //
      // First writer wins: a create never rewrites a row that is already
      // there. Creates describe something that happened once, so a second one
      // for the same key is either a replay of a push whose response was lost
      // or two devices reconstructing the same past event — and in both cases
      // what the server already holds is at least as good as what is being
      // sent. Merging instead would let a replayed create undo the edits made
      // since, and would let a device that upgraded with a staler view of a
      // pre-v6 product overwrite the opening another had already established,
      // moving stock under everyone who had it right.
      await _client
          .from(table)
          .upsert(row, onConflict: pk, ignoreDuplicates: true);
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

  @override
  Future<PullPage> fetchSince(
    String entity,
    PullCursor? cursor, {
    int limit = 200,
  }) async {
    final table = _tables[entity]!;
    final pk = entity == 'credit' ? 'sale_id' : 'id';

    // Row-level security already restricts this to the signed-in trader, so
    // there is no trader filter here to get wrong.
    var query = _client.from(table).select();
    if (cursor != null) {
      final at = cursor.watermark.toUtc().toIso8601String();
      query = cursor.lastId == null
          // Rewound: re-cover from the watermark inclusive.
          ? query.gte(watermarkColumn, at)
          // Resuming after a specific row: everything later, plus the rest of
          // that row's tied group.
          : query.or(
              '$watermarkColumn.gt.$at,'
              'and($watermarkColumn.eq.$at,$pk.gt.${cursor.lastId})',
            );
    }

    final rows = await query
        .order(watermarkColumn, ascending: true)
        .order(pk, ascending: true)
        .limit(limit);

    final list = rows.cast<Map<String, dynamic>>();
    if (list.length < limit) {
      // Caught up: no more pages for this entity in this pass.
      return PullPage(rows: list, cursor: null);
    }
    final last = list.last;
    return PullPage(
      rows: list,
      cursor: PullCursor(
        DateTime.parse(last[watermarkColumn] as String),
        last[pk] as String,
      ),
    );
  }
}
