import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/app.dart';
import 'package:prosperflow/src/auth/auth_service.dart';
import 'package:prosperflow/src/data/app_scope.dart';
import 'package:prosperflow/src/data/models.dart';
import 'package:prosperflow/src/sync/sync_engine.dart';

import 'helpers.dart';

/// Exercises the full app the way a user does — tab navigation, revisiting
/// screens, switching report periods — to catch stream-subscription bugs
/// that single-screen tests can't (e.g. "Stream has already been listened
/// to" from re-listening to a cached single-subscription stream).
void main() {
  testWidgets('navigating between all screens repeatedly never crashes',
      (tester) async {
    usePhoneSurface(tester);
    final store = fixtureStore();

    await tester.pumpWidget(AppScope(
      store: store,
      auth: FakeAuthService(signedIn: true),
      sync: NoopSyncEngine(lastSyncAt: DateTime.now()),
      child: const ProsperFlowApp(),
    ));
    await tester.pump();

    Future<void> goTab(String label) async {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    // Two full laps around the tab bar — the second lap re-subscribes to
    // every screen's streams.
    for (var lap = 0; lap < 2; lap++) {
      await goTab('Products');
      await goTab('Reports');

      // Flip through report periods (rebuilds the report StreamBuilder).
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await goTab('Credits');
      await goTab('Home');
    }

    // Expenses is reached from the dashboard quick action.
    await tester.tap(find.text('Expenses'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text("THIS WEEK'S TOTAL"), findsOneWidget);

    // A write while Expenses is on screen re-emits on every open stream.
    await store.addExpense(
      description: 'Repro expense',
      amount: 100,
      category: ExpenseCategory.other,
      spentOn: DateTime.now(),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Repro expense'), findsOneWidget);
  });
}
