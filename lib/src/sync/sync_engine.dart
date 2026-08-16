import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/db/app_database.dart';
import '../utils/streams.dart';
import '../data/drift_store.dart';
import 'sync_backend.dart';
import 'pull_ingest.dart';

/// What the sync UI needs to render the design's offline states (§6):
/// the offline pill, the "waiting to sync" row, and the backup toasts.
class SyncState {
  const SyncState({
    required this.online,
    required this.pendingSales,
    required this.pendingTotal,
    this.lastSyncAt,
    this.restoring = false,
    this.restoredRows = 0,
  });

  final bool online;

  /// Sales waiting to sync — the number the trader sees ("🕓 3 sales…").
  final int pendingSales;

  /// All queued mutations (sales, stock updates, expenses, credits).
  final int pendingTotal;

  final DateTime? lastSyncAt;

  /// True while this device still owes the signed-in trader the first full
  /// pull of their ledger.
  ///
  /// It is what separates the two reasons a screen can be empty. A trader on a
  /// new phone has everything on the server and nothing here yet; a trader
  /// who has genuinely not added anything looks identical. Telling the first
  /// one "No products yet" invites them to type their products in again,
  /// minting new ids for stock they already own and doubling the ledger the
  /// restore is about to deliver.
  final bool restoring;

  /// Rows brought down so far in the restore currently running.
  ///
  /// Deliberately a count of what has arrived rather than a percentage: the
  /// server never says how many rows are coming, so a proportion would have to
  /// be invented. A number that climbs is honest and still shows progress.
  final int restoredRows;

  bool get hasPending => pendingTotal > 0;
}

class SyncResult {
  const SyncResult({
    required this.pushedSales,
    this.pulledRows = 0,
    this.failed = false,
  });

  final int pushedSales;

  /// Rows brought down from the server — non-zero on a fresh install or a
  /// device that has been away, zero on a routine sync.
  final int pulledRows;

  final bool failed;
}

/// The app's sync surface. [DriftSyncEngine] is production; [NoopSyncEngine]
/// serves the web preview and tests that don't exercise sync.
abstract class SyncEngine {
  SyncState get state;

  Stream<SyncState> watchState();

  /// Manual sync (the ↻ icon / sync row). Safe to call anytime.
  Future<SyncResult> syncNow();

  /// Re-reads whether this device still owes the signed-in trader a restore,
  /// and publishes it before anything renders.
  ///
  /// Awaited on every path into the signed-in app, rather than left to resolve
  /// on its own, because the answer decides which of two opposite messages an
  /// empty screen shows. Resolving it a frame late would put "No products yet"
  /// in front of a trader whose products are still on their way.
  ///
  /// Pass [nothingToRestore] when the account was just created, which is the
  /// one case where an empty ledger is known to be the whole truth.
  Future<void> refreshRestoreState({bool nothingToRestore = false});

  void dispose();
}

/// Flushes the Drift outbox to a [SyncBackend] in seq order, in batches,
/// whenever connectivity allows: on start, on reconnect, after each local
/// write (debounced), on manual sync, and with exponential backoff after
/// failures.
class DriftSyncEngine implements SyncEngine {
  DriftSyncEngine(
    this._db,
    this._backend, {
    required Stream<bool> connectivity,
    bool initiallyOnline = true,
    Duration writeDebounce = const Duration(seconds: 2),
    PullIngest? ingest,
  }) : _online = initiallyOnline,
       _ingest = ingest ?? PullIngest(_db, DriftStore(_db)) {
    _connectivitySub = connectivity.listen(_onConnectivity);
    _outboxSub = _db
        .customSelect('SELECT 1', readsFrom: {_db.outbox})
        .watch()
        .listen((_) => _onOutboxChanged(writeDebounce));
  }

  static const _batchSize = 100;
  static const _maxBackoff = Duration(minutes: 10);
  static const _pullPageSize = 200;

  /// Entities are pulled in this order so a row never lands before what it
  /// refers to: products before the sales and adjustments that point at them,
  /// sales before the credits opened against them.
  static const _pullOrder = [
    'product',
    'stock_adjustment',
    'sale',
    'expense',
    'credit',
  ];

  /// How far each pull rewinds before resuming.
  ///
  /// A watermark is stamped when a transaction starts, not when it commits, so
  /// a slow write can land behind a cursor that has already passed it. Without
  /// re-covering a window those rows would never be seen. Ingest upserts on
  /// client-generated keys, so the repeated rows cost a write and change
  /// nothing.
  static const _pullOverlap = Duration(minutes: 2);

  final AppDatabase _db;
  final SyncBackend _backend;
  final PullIngest _ingest;

  bool _online;
  DateTime? _lastSyncAt;
  int _pendingSales = 0;
  int _pendingTotal = 0;
  bool _flushing = false;
  bool _restoring = false;
  int _restoredRows = 0;

  /// Whose restore [_restoring] and [_restoredRows] are describing.
  ///
  /// The engine is built once at startup and outlives any session, so a pull
  /// still unwinding for the trader who just handed the phone over must not
  /// write its result into the state the incoming trader's screens are reading
  /// — "finished" said about the wrong ledger is exactly the empty state this
  /// change exists to suppress. Every durable write here is already guarded by
  /// [_assertStillOwnedBy] inside its transaction; this is the same discipline
  /// for the copy held in memory, which had none.
  String? _restoreOwner;

  /// A sync asked for while one was already running. Held rather than
  /// dropped, and run once the current one lets go.
  bool _resyncRequested = false;
  Duration _backoff = const Duration(seconds: 30);
  Timer? _retryTimer;
  Timer? _debounceTimer;
  late final StreamSubscription<bool> _connectivitySub;
  late final StreamSubscription<void> _outboxSub;
  final _states = StreamController<SyncState>.broadcast();

  @override
  SyncState get state => SyncState(
    online: _online,
    pendingSales: _pendingSales,
    pendingTotal: _pendingTotal,
    lastSyncAt: _lastSyncAt,
    restoring: _restoring,
    restoredRows: _restoredRows,
  );

  @override
  Stream<SyncState> watchState() {
    Stream<SyncState> currentThenUpdates() async* {
      yield state;
      yield* _states.stream;
    }

    // Multi-listen safe (several widgets watch sync state at once).
    return MultiListenStream(currentThenUpdates);
  }

  void _emit() {
    if (!_states.isClosed) _states.add(state);
  }

  Future<void> _refreshPending() async {
    final rows = await _db.select(_db.outbox).get();
    _pendingTotal = rows.length;
    _pendingSales = rows.where((r) => r.entity == 'sale').length;
    _emit();
  }

  void _onConnectivity(bool online) {
    if (online == _online) return;
    _online = online;
    _resetBackoff();
    _emit();
    if (online) unawaited(syncNow());
  }

  void _onOutboxChanged(Duration debounce) {
    unawaited(_refreshPending());
    if (!_online) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => unawaited(syncNow()));
  }

  void _resetBackoff() {
    _backoff = const Duration(seconds: 30);
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(_backoff, () => unawaited(syncNow()));
    final doubled = _backoff * 2;
    _backoff = doubled > _maxBackoff ? _maxBackoff : doubled;
  }

  @override
  Future<SyncResult> syncNow() async {
    // Claimed synchronously, before the first await. Checking it after one
    // would let two calls arriving in the same turn both get past the guard
    // and run at once.
    if (_flushing) {
      // Remember the request instead of dropping it. A sign-in kicks a sync
      // for the trader taking the phone over, and that kick arrives while the
      // previous trader's sync is still unwinding — dropped, the new trader
      // would sit on an empty ledger until some unrelated trigger fired,
      // which is the very failure the pull exists to fix.
      _resyncRequested = true;
      return const SyncResult(pushedSales: 0, failed: false);
    }
    _flushing = true;

    var pushedSales = 0;
    try {
      await _refreshPending();
      if (!_online || !_backend.canPush) {
        return const SyncResult(pushedSales: 0, failed: false);
      }

      // Everything below is done on behalf of one trader and stops the moment
      // the database belongs to somebody else. The engine outlives any single
      // session — it is built once at startup — so a sign-in can land in the
      // middle of a sync that is still writing.
      final trader = await DriftStore.ownerOf(_db);
      if (trader == null) {
        return const SyncResult(pushedSales: 0, failed: false);
      }

      while (true) {
        final rows =
            await (_db.select(_db.outbox)
                  ..orderBy([(o) => OrderingTerm.asc(o.seq)])
                  ..limit(_batchSize))
                .get();
        if (rows.isEmpty) break;
        for (final row in rows) {
          // Pushing now would send the previous trader's queued work under the
          // new session, where row-level security stamps it with the wrong
          // owner on insert and refuses it on update. The backend re-checks
          // against its own session before sending, which is what closes the
          // gap between this check and the row going out.
          await _assertStillOwnedBy(trader);
          await _backend.apply(
            row.entity,
            row.op,
            jsonDecode(row.payloadJson) as Map<String, dynamic>,
            trader: trader,
          );
          if (row.entity == 'sale') pushedSales++;
          await _db.transaction(() async {
            await _assertStillOwnedBy(trader);
            await (_db.delete(
              _db.outbox,
            )..where((o) => o.seq.equals(row.seq))).go();
            await _markSynced(row.entity, row.entityId);
          });
        }
      }
      // Pull after pushing, never before: local work is the trader's most
      // recent intent, and pushing it first means the rows coming back already
      // reflect it instead of contradicting it.
      final pulledRows = await _pull(trader);

      _lastSyncAt = DateTime.now();
      _resetBackoff();
      return SyncResult(pushedSales: pushedSales, pulledRows: pulledRows);
    } on TraderChanged {
      // Abandoned, not failed. There is nothing here to retry — this work
      // belonged to a ledger the device no longer holds — and no backoff to
      // schedule, because the sign-in that took it over kicks its own sync.
      return SyncResult(pushedSales: pushedSales, failed: false);
    } catch (_) {
      _scheduleRetry();
      return SyncResult(pushedSales: pushedSales, failed: true);
    } finally {
      _flushing = false;
      await _refreshPending();
      if (_resyncRequested) {
        _resyncRequested = false;
        unawaited(syncNow());
      }
    }
  }

  @override
  Future<void> refreshRestoreState({bool nothingToRestore = false}) async {
    final trader = await DriftStore.ownerOf(_db);
    if (trader == null) {
      // Signed out: there is no ledger to be waiting for.
      _restoreOwner = null;
      _restoring = false;
      _restoredRows = 0;
      _emit();
      return;
    }
    if (nothingToRestore) await _markRestored(trader);
    _restoreOwner = trader;
    _restoring = !await _hasRestored(trader);
    _restoredRows = 0;
    _emit();
  }

  static String _restoreKey(String trader) =>
      '${DriftStore.restoreKeyPrefix}$trader';

  Future<bool> _hasRestored(String trader) async {
    final row = await (_db.select(
      _db.meta,
    )..where((m) => m.key.equals(_restoreKey(trader)))).getSingleOrNull();
    return row != null;
  }

  Future<void> _markRestored(String trader) async {
    await _db.transaction(() async {
      await _assertStillOwnedBy(trader);
      await _db
          .into(_db.meta)
          .insertOnConflictUpdate(
            MetaCompanion.insert(key: _restoreKey(trader), value: 'yes'),
          );
    });
  }

  /// Guards a write against the phone having changed hands. Call it inside
  /// the transaction that does the writing, so the check and the write commit
  /// together — checking outside leaves the gap the race needs.
  Future<void> _assertStillOwnedBy(String trader) async {
    if (await DriftStore.ownerOf(_db) != trader) throw TraderChanged();
  }

  /// Brings down everything changed since this device last looked.
  ///
  /// A fresh install has no cursor, so it starts at the beginning and pages
  /// through the trader's whole history — the case where signing in on a new
  /// phone showed an empty ledger even though the data was on the server.
  Future<int> _pull(String trader) async {
    var total = 0;

    try {
      for (final entity in _pullOrder) {
        var cursor = PullCursor.decode(
          await _readCursor(entity, trader),
        )?.rewound(_pullOverlap);

        while (true) {
          final page = await _backend.fetchSince(
            entity,
            cursor,
            limit: _pullPageSize,
          );
          if (page.isEmpty) break;

          await _ingest.apply(entity, page.rows, trader: trader);
          total += page.rows.length;
          if (_restoring && _restoreOwner == trader) {
            // Published per page rather than at the end, so a trader watching
            // a year of history come down sees the count climb instead of a
            // still screen they cannot tell from a stuck one.
            _restoredRows = total;
            _emit();
          }

          // Record where the page ended before fetching the next one, so an
          // interrupted first sync resumes instead of starting over.
          final reached = _watermarkOf(entity, page.rows.last);
          if (reached != null) await _writeCursor(entity, reached, trader);

          if (page.cursor == null) break;
          cursor = page.cursor;
        }
      }
      // Only once every entity is through. A pull that dies half way has
      // brought down products but not the sales against them, and calling that
      // restored would swap "your data is coming" for "you have no sales" on a
      // ledger that has them — so the marker waits, and the retry finishes the
      // job.
      await _markRestored(trader);
      // Only if the screens are still showing this trader's restore. The
      // durable marker is keyed by trader and so is safe to write regardless;
      // the published flag is a single field, and clearing it for a ledger
      // nobody is looking at any more would hand the incoming trader the
      // ordinary empty state over data that has not arrived.
      if (_restoreOwner == trader) _restoring = false;
    } finally {
      // Settled even when the pull died part-way, and settled from the events
      // rather than from a list of what this run happened to touch. Cursors
      // advance durably per page, so a pull that fails after ingesting a
      // product has already recorded that it holds it — and the two-minute
      // rewind will not reach back far enough to fetch it again. Anything
      // left reading the placeholder zero would stay there.
      await _ingest.settleStock();
    }
    return total;
  }

  PullCursor? _watermarkOf(String entity, Map<String, dynamic> row) {
    final at = row[SupabaseSyncBackend.watermarkColumn];
    if (at is! String) return null;
    final pk = entity == 'credit' ? 'sale_id' : 'id';
    final id = row[pk];
    if (id is! String) return null;
    return PullCursor(DateTime.parse(at), id);
  }

  /// Cursors are keyed by trader as well as entity.
  ///
  /// A cursor is a claim about one ledger — "this device holds everything up
  /// to here" — so it is meaningless applied to another. Naming the trader in
  /// the key means a straggling write from the outgoing trader's pull lands
  /// somewhere the incoming trader will never read, instead of quietly
  /// becoming their starting position and skipping their history.
  static String _cursorKey(String entity, String trader) =>
      '${DriftStore.cursorKeyPrefix}$trader:$entity';

  Future<String?> _readCursor(String entity, String trader) async {
    final row =
        await (_db.select(_db.meta)
              ..where((m) => m.key.equals(_cursorKey(entity, trader))))
            .getSingleOrNull();
    return row?.value;
  }

  Future<void> _writeCursor(
    String entity,
    PullCursor cursor,
    String trader,
  ) async {
    await _db.transaction(() async {
      await _assertStillOwnedBy(trader);
      await _db
          .into(_db.meta)
          .insertOnConflictUpdate(
            MetaCompanion.insert(
              key: _cursorKey(entity, trader),
              value: cursor.encode(),
            ),
          );
    });
  }

  Future<void> _markSynced(String entity, String entityId) async {
    switch (entity) {
      case 'product':
        await (_db.update(_db.products)..where((p) => p.id.equals(entityId)))
            .write(const ProductsCompanion(synced: Value(true)));
      case 'sale':
        await (_db.update(_db.sales)..where((s) => s.id.equals(entityId)))
            .write(const SalesCompanion(synced: Value(true)));
      case 'expense':
        await (_db.update(_db.expenses)..where((e) => e.id.equals(entityId)))
            .write(const ExpensesCompanion(synced: Value(true)));
      case 'credit':
        await (_db.update(_db.credits)..where((c) => c.saleId.equals(entityId)))
            .write(const CreditsCompanion(synced: Value(true)));
      case 'stock_adjustment':
        await (_db.update(_db.stockAdjustments)
              ..where((a) => a.id.equals(entityId)))
            .write(const StockAdjustmentsCompanion(synced: Value(true)));
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _debounceTimer?.cancel();
    _connectivitySub.cancel();
    _outboxSub.cancel();
    _states.close();
  }
}

/// Always-online, nothing-pending engine for the web preview and for
/// widget tests that don't exercise sync.
class NoopSyncEngine implements SyncEngine {
  NoopSyncEngine({DateTime? lastSyncAt}) : _lastSyncAt = lastSyncAt;

  final DateTime? _lastSyncAt;

  @override
  SyncState get state => SyncState(
    online: true,
    pendingSales: 0,
    pendingTotal: 0,
    lastSyncAt: _lastSyncAt,
  );

  @override
  Stream<SyncState> watchState() =>
      MultiListenStream(() => Stream.value(state));

  @override
  Future<SyncResult> syncNow() async => const SyncResult(pushedSales: 0);

  @override
  Future<void> refreshRestoreState({bool nothingToRestore = false}) async {}

  @override
  void dispose() {}
}
