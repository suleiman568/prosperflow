import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/data/memory_store.dart';
import 'package:prosperflow/src/data/models.dart';
import 'package:prosperflow/src/sync/sync_engine.dart';
import 'package:prosperflow/src/screens/credits/credits_screen.dart';
import 'package:prosperflow/src/screens/dashboard/dashboard_screen.dart';
import 'package:prosperflow/src/screens/expenses/expenses_screen.dart';
import 'package:prosperflow/src/screens/products/products_screen.dart';
import 'package:prosperflow/src/widgets/error_state.dart';
import 'package:prosperflow/src/widgets/sync_widgets.dart';

import 'helpers.dart';

/// Counts manual syncs so we can prove a pull-to-refresh reached the engine.
class _RecordingSyncEngine extends NoopSyncEngine {
  int syncs = 0;

  @override
  Future<SyncResult> syncNow() async {
    syncs++;
    return const SyncResult(pushedSales: 0);
  }
}

/// Products whose stream errors immediately, to reach the error state.
class _ErrorStore extends MemoryStore {
  @override
  Stream<List<Product>> watchProducts() =>
      Stream.error(Exception('load failed'));
}

/// Products whose stream never emits, holding the loading skeleton state.
class _PendingStore extends MemoryStore {
  @override
  Stream<List<Product>> watchProducts() => const Stream.empty();
}

/// Errors on the first subscription, then serves real data on the retry — to
/// prove a pull from the error panel re-subscribes and recovers the screen.
class _FlakyProductStore extends MemoryStore {
  _FlakyProductStore() : super(products: fixtureProducts);

  int _subscriptions = 0;

  @override
  Stream<List<Product>> watchProducts() {
    _subscriptions++;
    return _subscriptions == 1
        ? Stream<List<Product>>.error(Exception('load failed'))
        : super.watchProducts();
  }
}

Future<void> _pullToRefresh(WidgetTester tester) async {
  await tester.fling(find.byType(RefreshIndicator), const Offset(0, 400), 1000);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Products pull-to-refresh runs a manual sync', (tester) async {
    usePhoneSurface(tester);
    final sync = _RecordingSyncEngine();
    await pumpWithStore(
      tester,
      const ProductsScreen(),
      store: fixtureStore(),
      sync: sync,
    );
    await tester.pumpAndSettle();

    expect(find.byType(PullToSync), findsOneWidget);
    await _pullToRefresh(tester);

    expect(sync.syncs, 1);
  });

  testWidgets('Products pull-to-refresh works in the empty state', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final sync = _RecordingSyncEngine();
    await pumpWithStore(
      tester,
      const ProductsScreen(),
      store: MemoryStore(),
      sync: sync,
    );
    await tester.pumpAndSettle();

    // The empty panel is showing, and it is still pull-to-refreshable.
    expect(find.text('No products yet'), findsOneWidget);
    expect(find.byType(PullToSync), findsOneWidget);
    await _pullToRefresh(tester);

    expect(sync.syncs, 1);
  });

  testWidgets('Products pull-to-refresh works in the loading state', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final sync = _RecordingSyncEngine();
    await pumpWithStore(
      tester,
      const ProductsScreen(),
      store: _PendingStore(),
      sync: sync,
    );
    await tester.pump();

    // Loading skeletons are showing, and the list is pull-to-refreshable.
    expect(find.byType(PullToSync), findsOneWidget);
    // Manual pumps only — the skeleton shimmer never settles.
    await tester.fling(
      find.byType(RefreshIndicator),
      const Offset(0, 400),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(sync.syncs, 1);
  });

  testWidgets('Products pull-to-refresh works in the error state', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final sync = _RecordingSyncEngine();
    await pumpWithStore(
      tester,
      const ProductsScreen(),
      store: _ErrorStore(),
      sync: sync,
    );
    await tester.pumpAndSettle();

    // The error panel is showing, and it is still pull-to-refreshable — the
    // moment a user most wants to retry a sync.
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.byType(PullToSync), findsOneWidget);
    await _pullToRefresh(tester);

    expect(sync.syncs, 1);
  });

  testWidgets('pull from the error state re-subscribes and recovers the screen', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final sync = _RecordingSyncEngine();
    await pumpWithStore(
      tester,
      const ProductsScreen(),
      store: _FlakyProductStore(),
      sync: sync,
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);

    // Pulling must do what "Try again" does — reset the failed subscription —
    // in addition to backing up. Otherwise the screen stays stuck on the error.
    await _pullToRefresh(tester);

    expect(find.byType(ErrorState), findsNothing);
    expect(find.text('Palm Oil (25L)'), findsOneWidget);
    expect(sync.syncs, 1);
    // The sync's completion toast must survive the subscription reset — the
    // reset re-keys the StreamBuilder, so the sync has to run first.
    expect(find.text('✅ Everything is backed up'), findsOneWidget);
  });

  testWidgets('Expenses pull-to-refresh runs a manual sync', (tester) async {
    usePhoneSurface(tester);
    final sync = _RecordingSyncEngine();
    await pumpWithStore(
      tester,
      const ExpensesScreen(),
      store: fixtureStore(),
      sync: sync,
    );
    await tester.pumpAndSettle();

    await _pullToRefresh(tester);

    expect(sync.syncs, 1);
  });

  testWidgets('Credits pull-to-refresh runs a manual sync', (tester) async {
    usePhoneSurface(tester);
    final sync = _RecordingSyncEngine();
    await pumpWithStore(
      tester,
      const CreditsScreen(),
      store: fixtureStore(),
      sync: sync,
    );
    await tester.pumpAndSettle();

    await _pullToRefresh(tester);

    expect(sync.syncs, 1);
  });

  testWidgets('Dashboard pull-to-refresh runs a manual sync', (tester) async {
    usePhoneSurface(tester, height: 1600);
    final sync = _RecordingSyncEngine();
    await pumpWithStore(
      tester,
      const DashboardScreen(),
      store: fixtureStore(),
      sync: sync,
    );
    await tester.pumpAndSettle();

    await _pullToRefresh(tester);

    expect(sync.syncs, 1);
  });
}
