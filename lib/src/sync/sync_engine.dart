import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/db/app_database.dart';
import 'sync_backend.dart';

/// What the sync UI needs to render the design's offline states (§6):
/// the offline pill, the "waiting to sync" row, and the backup toasts.
class SyncState {
  const SyncState({
    required this.online,
    required this.pendingSales,
    required this.pendingTotal,
    this.lastSyncAt,
  });

  final bool online;

  /// Sales waiting to sync — the number the trader sees ("🕓 3 sales…").
  final int pendingSales;

  /// All queued mutations (sales, stock updates, expenses, credits).
  final int pendingTotal;

  final DateTime? lastSyncAt;

  bool get hasPending => pendingTotal > 0;
}

class SyncResult {
  const SyncResult({required this.pushedSales, this.failed = false});

  final int pushedSales;
  final bool failed;
}

/// The app's sync surface. [DriftSyncEngine] is production; [NoopSyncEngine]
/// serves the web preview and tests that don't exercise sync.
abstract class SyncEngine {
  SyncState get state;

  Stream<SyncState> watchState();

  /// Manual sync (the ↻ icon / sync row). Safe to call anytime.
  Future<SyncResult> syncNow();

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
  }) : _online = initiallyOnline {
    _connectivitySub = connectivity.listen(_onConnectivity);
    _outboxSub = _db
        .customSelect('SELECT 1', readsFrom: {_db.outbox})
        .watch()
        .listen((_) => _onOutboxChanged(writeDebounce));
  }

  static const _batchSize = 100;
  static const _maxBackoff = Duration(minutes: 10);

  final AppDatabase _db;
  final SyncBackend _backend;

  bool _online;
  DateTime? _lastSyncAt;
  int _pendingSales = 0;
  int _pendingTotal = 0;
  bool _flushing = false;
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
      );

  @override
  Stream<SyncState> watchState() async* {
    yield state;
    yield* _states.stream;
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
    await _refreshPending();
    if (!_online || !_backend.canPush || _flushing) {
      return const SyncResult(pushedSales: 0, failed: false);
    }
    _flushing = true;
    var pushedSales = 0;
    try {
      while (true) {
        final rows = await (_db.select(_db.outbox)
              ..orderBy([(o) => OrderingTerm.asc(o.seq)])
              ..limit(_batchSize))
            .get();
        if (rows.isEmpty) break;
        for (final row in rows) {
          await _backend.apply(
            row.entity,
            row.op,
            jsonDecode(row.payloadJson) as Map<String, dynamic>,
          );
          if (row.entity == 'sale') pushedSales++;
          await _db.transaction(() async {
            await (_db.delete(_db.outbox)
                  ..where((o) => o.seq.equals(row.seq)))
                .go();
            await _markSynced(row.entity, row.entityId);
          });
        }
      }
      _lastSyncAt = DateTime.now();
      _resetBackoff();
      return SyncResult(pushedSales: pushedSales);
    } catch (_) {
      _scheduleRetry();
      return SyncResult(pushedSales: pushedSales, failed: true);
    } finally {
      _flushing = false;
      await _refreshPending();
    }
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
        await (_db.update(_db.credits)
              ..where((c) => c.saleId.equals(entityId)))
            .write(const CreditsCompanion(synced: Value(true)));
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
  Stream<SyncState> watchState() => Stream.value(state);

  @override
  Future<SyncResult> syncNow() async => const SyncResult(pushedSales: 0);

  @override
  void dispose() {}
}
