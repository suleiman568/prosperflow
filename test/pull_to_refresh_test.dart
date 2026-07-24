import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/sync/sync_engine.dart';
import 'package:prosperflow/src/screens/credits/credits_screen.dart';
import 'package:prosperflow/src/screens/dashboard/dashboard_screen.dart';
import 'package:prosperflow/src/screens/expenses/expenses_screen.dart';
import 'package:prosperflow/src/screens/products/products_screen.dart';
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

Future<void> _pullToRefresh(WidgetTester tester) async {
  await tester.fling(
    find.byType(RefreshIndicator),
    const Offset(0, 400),
    1000,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Products pull-to-refresh runs a manual sync', (tester) async {
    usePhoneSurface(tester);
    final sync = _RecordingSyncEngine();
    await pumpWithStore(tester, const ProductsScreen(),
        store: fixtureStore(), sync: sync);
    await tester.pumpAndSettle();

    expect(find.byType(PullToSync), findsOneWidget);
    await _pullToRefresh(tester);

    expect(sync.syncs, 1);
  });

  testWidgets('Expenses pull-to-refresh runs a manual sync', (tester) async {
    usePhoneSurface(tester);
    final sync = _RecordingSyncEngine();
    await pumpWithStore(tester, const ExpensesScreen(),
        store: fixtureStore(), sync: sync);
    await tester.pumpAndSettle();

    await _pullToRefresh(tester);

    expect(sync.syncs, 1);
  });

  testWidgets('Credits pull-to-refresh runs a manual sync', (tester) async {
    usePhoneSurface(tester);
    final sync = _RecordingSyncEngine();
    await pumpWithStore(tester, const CreditsScreen(),
        store: fixtureStore(), sync: sync);
    await tester.pumpAndSettle();

    await _pullToRefresh(tester);

    expect(sync.syncs, 1);
  });

  testWidgets('Dashboard pull-to-refresh runs a manual sync', (tester) async {
    usePhoneSurface(tester, height: 1600);
    final sync = _RecordingSyncEngine();
    await pumpWithStore(tester, const DashboardScreen(),
        store: fixtureStore(), sync: sync);
    await tester.pumpAndSettle();

    await _pullToRefresh(tester);

    expect(sync.syncs, 1);
  });
}
