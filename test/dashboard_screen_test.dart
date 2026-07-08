import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/screens/dashboard/dashboard_screen.dart';

Widget _app() => const MaterialApp(home: DashboardScreen());

void main() {
  testWidgets('dashboard shows greeting, stats, alerts, and actions',
      (tester) async {
    await tester.pumpWidget(_app());

    expect(find.text('Welcome back, Prosper 👋'), findsOneWidget);

    // Stat cards with demo totals.
    expect(find.text("Today's Sales"), findsOneWidget);
    expect(find.text('₦48,500'), findsOneWidget);
    expect(find.text('12 sales today'), findsOneWidget);
    expect(find.text('This Week'), findsOneWidget);
    expect(find.text('₦312,000'), findsOneWidget);

    // Low stock alert lists the two products at/below threshold.
    expect(find.text('Low Stock Alert'), findsOneWidget);
    expect(find.text('Vegetable Oil — 3 bottles left'), findsOneWidget);
    expect(find.text('Bottled Water — 8 packs left'), findsOneWidget);

    // Quick actions.
    for (final label in ['Record Sale', 'Products', 'Expenses', 'Reports']) {
      expect(find.text(label), findsWidgets);
    }

    // Credits banner total (18,400 + 30,000 + 20,100) — below the fold.
    await tester.scrollUntilVisible(
      find.text('OUTSTANDING CREDITS'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('OUTSTANDING CREDITS'), findsOneWidget);
    expect(find.text('₦68,500'), findsOneWidget);
    expect(find.text('3 customers →'), findsOneWidget);
  });
}
