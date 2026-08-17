import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/data/db/app_database.dart';
import 'package:prosperflow/src/data/drift_store.dart';
import 'package:prosperflow/src/data/memory_store.dart';
import 'package:prosperflow/src/screens/credits/credits_screen.dart';
import 'package:prosperflow/src/screens/dashboard/dashboard_screen.dart';
import 'package:prosperflow/src/screens/expenses/expenses_screen.dart';
import 'package:prosperflow/src/screens/products/products_screen.dart';
import 'package:prosperflow/src/screens/reports/reports_screen.dart';
import 'package:prosperflow/src/sync/sync_backend.dart';
import 'package:prosperflow/src/sync/sync_engine.dart';
import 'package:prosperflow/src/widgets/money_text.dart';
import 'package:prosperflow/src/widgets/skeleton.dart';
import 'package:prosperflow/src/widgets/sync_widgets.dart';

import 'helpers.dart';

/// Serves pages of pulled rows, and can be told to fail the pull part-way so
/// the "restore finished" marker can be tested against an interrupted one.
class RestoreBackend implements SyncBackend {
  final remote = <String, List<List<Map<String, dynamic>>>>{};

  /// Entity whose pull should blow up, standing in for the connection dying
  /// mid-restore.
  String? failOn;

  /// Runs as a page is fetched, so a test can drop a sign-in into the middle
  /// of a pull — the only place the ownership races live.
  Future<void> Function(String entity)? onFetch;

  @override
  bool get canPush => true;

  @override
  Future<void> apply(
    String entity,
    String op,
    Map<String, dynamic> payload, {
    required String trader,
  }) async {}

  @override
  Future<PullPage> fetchSince(
    String entity,
    PullCursor? cursor, {
    int limit = 200,
  }) async {
    if (entity == failOn) throw Exception('connection lost');
    await onFetch?.call(entity);
    final pages = remote[entity] ?? const [];
    // Cursors carry the page index, so paging works without the fake needing
    // to model watermarks — this test is about the restore flag, not paging.
    final index = cursor?.lastId == null ? 0 : int.parse(cursor!.lastId!);
    if (index >= pages.length) return const PullPage(rows: [], cursor: null);
    final last = index == pages.length - 1;
    return PullPage(
      rows: pages[index],
      cursor: last ? null : PullCursor(DateTime.utc(2026), '${index + 1}'),
    );
  }
}

Map<String, dynamic> productRow(String id) => {
  'id': id,
  'name': 'Palm Oil $id',
  'unit': 'bottles',
  'buy_price': 6800,
  'sell_price': 9200,
  'low_stock_threshold': 10,
  'updated_at': DateTime.utc(2026).toIso8601String(),
  'deleted': false,
  SupabaseSyncBackend.watermarkColumn: DateTime.utc(2026).toIso8601String(),
};

/// Stands in for an engine mid-restore in the widget tests.
class StubSyncEngine implements SyncEngine {
  StubSyncEngine({
    this.restoring = false,
    this.restoredRows = 0,
    this.online = true,
  });

  final bool restoring;
  final int restoredRows;
  final bool online;

  @override
  SyncState get state => SyncState(
    online: online,
    pendingSales: 0,
    pendingTotal: 0,
    restoring: restoring,
    restoredRows: restoredRows,
  );

  @override
  Stream<SyncState> watchState() => Stream.value(state);

  @override
  Future<SyncResult> syncNow() async => const SyncResult(pushedSales: 0);

  @override
  Future<void> refreshRestoreState({bool nothingToRestore = false}) async {}

  @override
  void dispose() {}
}

void main() {
  group('knowing a phone is still waiting for its ledger', () {
    late AppDatabase db;
    late DriftStore store;
    late RestoreBackend backend;
    late StreamController<bool> connectivity;
    DriftSyncEngine? engine;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      store = DriftStore(db);
      backend = RestoreBackend();
      connectivity = StreamController<bool>.broadcast();
      await store.bindToTrader('trader-a');
    });

    tearDown(() async {
      engine?.dispose();
      await connectivity.close();
      await db.close();
    });

    DriftSyncEngine makeEngine({bool online = true}) {
      engine?.dispose();
      return engine = DriftSyncEngine(
        db,
        backend,
        connectivity: connectivity.stream,
        initiallyOnline: online,
        writeDebounce: const Duration(milliseconds: 10),
      );
    }

    test('a device that has never pulled is still waiting', () async {
      final sync = makeEngine();

      await sync.refreshRestoreState();

      expect(sync.state.restoring, isTrue);
    });

    test('it stops waiting once the whole ledger is through', () async {
      backend.remote['product'] = [
        [productRow('p1')],
      ];
      final sync = makeEngine();
      await sync.refreshRestoreState();

      await sync.syncNow();

      expect(sync.state.restoring, isFalse);
    });

    test('a restore cut off part-way is still owed', () async {
      // Products land, then the connection dies before the sales that go with
      // them. Calling that finished would tell a trader who has been selling
      // for a year that they have no sales.
      backend.remote['product'] = [
        [productRow('p1')],
      ];
      backend.failOn = 'sale';
      final sync = makeEngine();
      await sync.refreshRestoreState();

      await sync.syncNow();

      expect(sync.state.restoring, isTrue);

      // The retry finishes the job.
      backend.failOn = null;
      await sync.syncNow();
      expect(sync.state.restoring, isFalse);
    });

    test('a finished restore is still finished after a restart', () async {
      backend.remote['product'] = [
        [productRow('p1')],
      ];
      final first = makeEngine();
      await first.refreshRestoreState();
      await first.syncNow();

      // The app is closed and reopened: a new engine over the same database.
      final second = makeEngine();
      await second.refreshRestoreState();

      expect(second.state.restoring, isFalse);
    });

    test('a brand new account is not waiting for anything', () async {
      final sync = makeEngine();

      await sync.refreshRestoreState(nothingToRestore: true);

      expect(sync.state.restoring, isFalse);
      // And it stays that way, so signing back in on this phone does not put
      // the trader in front of a restore that has nothing to fetch.
      final reopened = makeEngine();
      await reopened.refreshRestoreState();
      expect(reopened.state.restoring, isFalse);
    });

    test('signing out and back in does not skip the restore', () async {
      backend.remote['product'] = [
        [productRow('p1')],
      ];
      final sync = makeEngine();
      await sync.refreshRestoreState();
      await sync.syncNow();
      expect(sync.state.restoring, isFalse);

      // Somebody else takes the phone, which wipes trader-a's ledger from it.
      await store.bindToTrader('trader-b');
      final theirs = makeEngine();
      await theirs.refreshRestoreState();
      expect(theirs.state.restoring, isTrue);

      // trader-a comes back to a phone that no longer holds their data. The
      // old marker would say otherwise and leave them looking at an empty
      // ledger described as empty.
      await store.bindToTrader('trader-a');
      final again = makeEngine();
      await again.refreshRestoreState();
      expect(again.state.restoring, isTrue);
    });

    test('one engine, phone changing hands mid-pull, still waiting', () async {
      // The engine is built once at startup and outlives every session, so a
      // handover happens *inside* a live engine rather than between two of
      // them. Making a fresh one per trader — as the test above does, to check
      // what survives a restart — would step around the case where a pull for
      // the outgoing trader is still unwinding as the incoming one arrives.
      backend.remote['product'] = [
        [productRow('p1')],
      ];
      final sync = makeEngine();
      await sync.refreshRestoreState();
      await sync.syncNow();
      expect(sync.state.restoring, isFalse);

      // The phone changes hands part-way through trader-a's next pull.
      backend.onFetch = (entity) async {
        if (entity != 'sale') return;
        backend.onFetch = null;
        await store.bindToTrader('trader-b');
        await sync.refreshRestoreState();
      };

      await sync.syncNow();

      // trader-b is owed a restore and must keep being told so. The pull that
      // was in flight belonged to somebody else's ledger and has no business
      // reporting it finished.
      expect(sync.state.restoring, isTrue);
      expect(sync.state.restoredRows, 0);
    });

    test('progress is published while the rows are still coming', () async {
      backend.remote['product'] = [
        [productRow('p1'), productRow('p2')],
        [productRow('p3')],
      ];
      final sync = makeEngine();
      await sync.refreshRestoreState();

      final seen = <SyncState>[];
      final sub = sync.watchState().listen(seen.add);
      await sync.syncNow();
      await sub.cancel();

      // A count that climbs while the restore is still running is the whole
      // point: a still screen is indistinguishable from a stuck one.
      final during = seen.where((s) => s.restoring && s.restoredRows > 0);
      expect(during, isNotEmpty);
      expect(during.map((s) => s.restoredRows).toList(), contains(2));
    });
  });

  group('what a waiting phone shows', () {
    testWidgets('Products says the data is coming, not that there is none', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await pumpWithStore(
        tester,
        const ProductsScreen(),
        store: MemoryStore(products: const []),
        sync: StubSyncEngine(restoring: true),
      );
      // Pumped rather than settled: the restore spinner never stops, so
      // pumpAndSettle would wait for it forever.
      await tester.pump();

      expect(find.text('Restoring your data'), findsOneWidget);
      // The dangerous message: it invites a trader to type in products they
      // already own, minting new ids for stock the restore is about to
      // deliver, and leaving the ledger holding everything twice.
      expect(find.text('No products yet'), findsNothing);
      expect(find.text('Add product'), findsNothing);
    });

    testWidgets('once the restore is done the empty state is the truth', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await pumpWithStore(
        tester,
        const ProductsScreen(),
        store: MemoryStore(products: const []),
        sync: StubSyncEngine(),
      );
      await tester.pumpAndSettle();

      expect(find.text('No products yet'), findsOneWidget);
      expect(find.text('Restoring your data'), findsNothing);
    });

    testWidgets('a waiting phone with no connection says so instead', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await pumpWithStore(
        tester,
        const ProductsScreen(),
        store: MemoryStore(products: const []),
        sync: StubSyncEngine(restoring: true, online: false),
      );
      await tester.pumpAndSettle();

      // A spinner would promise progress that cannot happen until the
      // connection comes back.
      expect(find.text('Waiting for a connection'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('the count appears once rows have landed', (tester) async {
      usePhoneSurface(tester);
      await pumpWithStore(
        tester,
        const ProductsScreen(),
        store: MemoryStore(products: const []),
        sync: StubSyncEngine(restoring: true, restoredRows: 340),
      );
      await tester.pump();

      expect(find.text('340 items so far'), findsOneWidget);
    });

    testWidgets('Expenses and Credits hold the same line', (tester) async {
      usePhoneSurface(tester);
      await pumpWithStore(
        tester,
        const ExpensesScreen(),
        store: MemoryStore(products: const [], expenses: const []),
        sync: StubSyncEngine(restoring: true),
      );
      await tester.pump();
      expect(find.text('Restoring your data'), findsOneWidget);
      expect(find.text('No expenses yet'), findsNothing);

      await pumpWithStore(
        tester,
        const CreditsScreen(),
        store: MemoryStore(products: const [], credits: const []),
        sync: StubSyncEngine(restoring: true),
      );
      await tester.pump();
      expect(find.text('Restoring your data'), findsOneWidget);
      expect(find.text('All credits collected!'), findsNothing);
    });

    testWidgets('the sync row reports the restore ahead of anything else', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final state = StubSyncEngine(restoring: true, restoredRows: 12).state;
      await pumpWithStore(
        tester,
        Scaffold(body: SyncStatusRow(state: state)),
        sync: StubSyncEngine(restoring: true, restoredRows: 12),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('⏳ Restoring your data — 12 items so far'),
        findsOneWidget,
      );
    });
  });

  group('what a waiting phone shows on its figures', () {
    // The fixtures give every one of these something to render, so each test
    // is about the restore hiding it rather than about there being nothing.
    testWidgets("the day's takings are a skeleton, not zero", (tester) async {
      usePhoneSurface(tester);
      await pumpWithStore(
        tester,
        const DashboardScreen(),
        sync: StubSyncEngine(restoring: true),
      );
      await tester.pump();

      // ₦0 is a number a trader can act on — it says the morning's sales are
      // gone. A skeleton says the app does not know yet, which is the truth.
      // The dashboard's only skeletons are the two stat cards', so their
      // presence and absence is exactly the thing under test.
      expect(find.byType(Skeleton), findsWidgets);
      expect(find.text('Today\'s Sales'), findsOneWidget);
      expect(find.byType(MoneyText), findsNothing);
    });

    testWidgets('the figures come back once the restore is done', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await pumpWithStore(
        tester,
        const DashboardScreen(),
        sync: StubSyncEngine(),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Skeleton), findsNothing);
      expect(find.byType(MoneyText), findsWidgets);
    });

    testWidgets('no low stock alarm over half-arrived stock', (tester) async {
      usePhoneSurface(tester);
      // The fixtures include a product below its threshold, so the alert is
      // on screen whenever it is allowed to be.
      await pumpWithStore(
        tester,
        const DashboardScreen(),
        sync: StubSyncEngine(restoring: true),
      );
      await tester.pump();
      expect(find.text('Low Stock Alert'), findsNothing);

      await pumpWithStore(
        tester,
        const DashboardScreen(),
        sync: StubSyncEngine(),
      );
      await tester.pumpAndSettle();
      expect(find.text('Low Stock Alert'), findsOneWidget);
    });

    testWidgets('no debt total until all the debts are in', (tester) async {
      usePhoneSurface(tester);
      await pumpWithStore(
        tester,
        const DashboardScreen(),
        sync: StubSyncEngine(restoring: true),
      );
      await tester.pump();
      expect(find.text('OUTSTANDING CREDITS'), findsNothing);

      await pumpWithStore(
        tester,
        const DashboardScreen(),
        sync: StubSyncEngine(),
      );
      await tester.pumpAndSettle();
      expect(find.text('OUTSTANDING CREDITS'), findsOneWidget);
    });

    testWidgets('Reports waits rather than reporting a partial profit', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await pumpWithStore(
        tester,
        const ReportsScreen(),
        sync: StubSyncEngine(restoring: true, restoredRows: 58),
      );
      await tester.pump();

      expect(find.text('Restoring your data'), findsOneWidget);
      expect(find.text('58 items so far'), findsOneWidget);
      // Sales are pulled before the expenses that offset them, so a profit
      // computed now is one no period of trading ever produced.
      expect(find.text('NET PROFIT'), findsNothing);
      expect(find.text('NET LOSS'), findsNothing);
    });

    testWidgets('Reports reports again once the ledger is whole', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await pumpWithStore(
        tester,
        const ReportsScreen(),
        sync: StubSyncEngine(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Restoring your data'), findsNothing);
      expect(
        find.text('NET PROFIT').evaluate().length +
            find.text('NET LOSS').evaluate().length,
        1,
      );
    });

    testWidgets('an export is refused while the ledger is still arriving', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await pumpWithStore(
        tester,
        const ReportsScreen(),
        sync: StubSyncEngine(restoring: true),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Export report'));
      await tester.pump();

      // Everything else on screen corrects itself as rows land. A file does
      // not: it leaves the phone, or it is filed as the record of a month
      // that had not finished arriving.
      expect(
        find.text('⏳ Still restoring — export when it has finished'),
        findsOneWidget,
      );
      expect(find.text('Export report'), findsNothing);
    });
  });
}
