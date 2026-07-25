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
