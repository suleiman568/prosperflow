import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/screens/dashboard/dashboard_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets('dashboard streams greeting, stats, alerts, and credits',
      (tester) async {
    usePhoneSurface(tester);
    await pumpWithStore(tester, const DashboardScreen());
    await tester.pump();

    expect(find.text('Welcome back, Prosper 👋'), findsOneWidget);

    // Stats computed from fixture sales.
    expect(find.text("Today's Sales"), findsOneWidget);
    expect(find.text('₦28,400'), findsOneWidget);
    expect(find.text('2 sales today'), findsOneWidget);
    expect(find.text('This Week'), findsOneWidget);
    expect(find.text('₦103,800'), findsOneWidget);
    expect(find.text('6 sales'), findsOneWidget);

    // Low stock alert from products at/below threshold.
    expect(find.text('Low Stock Alert'), findsOneWidget);
    expect(find.text('Vegetable Oil — 3 bottles left'), findsOneWidget);
    expect(find.text('Bottled Water — 8 packs left'), findsOneWidget);

    // Quick actions.
    for (final label in ['Record Sale', 'Products', 'Expenses', 'Reports']) {
      expect(find.text(label), findsWidgets);
    }

    // Credits banner from open credits (18,400 + 30,000 + 21,000).
    await tester.scrollUntilVisible(
      find.text('OUTSTANDING CREDITS'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('₦69,400'), findsOneWidget);
    expect(find.text('3 customers →'), findsOneWidget);
  });

  testWidgets('credits banner hides when nothing is owed', (tester) async {
    usePhoneSurface(tester);
    final store = fixtureStore();
    for (final credit in fixtureCredits) {
      await store.markCreditPaid(credit.saleId);
    }
    await pumpWithStore(tester, const DashboardScreen(), store: store);
    await tester.pump();

    expect(find.text('OUTSTANDING CREDITS'), findsNothing);
  });
}
