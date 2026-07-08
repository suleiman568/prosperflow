import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/screens/reports/reports_screen.dart';

Widget _app() => const MaterialApp(home: ReportsScreen());

void _usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('week report shows profit, totals, and breakdowns',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app());

    // Profit = 312,000 − 42,300.
    expect(find.text('NET PROFIT'), findsOneWidget);
    expect(find.text('₦269,700'), findsOneWidget);
    expect(find.text("📈 You're on track! Great week."), findsOneWidget);

    expect(find.text('₦312,000'), findsOneWidget);
    expect(find.text('67 transactions'), findsOneWidget);
    expect(find.text('₦42,300'), findsOneWidget);
    expect(find.text('12 items'), findsOneWidget);

    // Top products bars.
    expect(find.text('68% of sales'), findsOneWidget);
    expect(find.text('22% of sales'), findsOneWidget);

    // Payment breakdown amounts (weekly).
    expect(find.text('₦140,400'), findsOneWidget);
    expect(find.text('₦118,560'), findsOneWidget);
    expect(find.text('₦37,440'), findsOneWidget);
    expect(find.text('₦15,600'), findsOneWidget);
  });

  testWidgets('switching period scales the report', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app());

    await tester.tap(find.text('Month'));
    await tester.pump();

    // 312,000 × 4.3 and 42,300 × 4.3.
    expect(find.text('₦1,341,600'), findsOneWidget);
    expect(find.text('₦181,890'), findsOneWidget);
    expect(find.text('₦1,159,710'), findsOneWidget); // profit
    expect(find.text("📈 You're on track! Great month."), findsOneWidget);
    expect(find.text('288 transactions'), findsOneWidget); // 67 × 4.3 rounded

    await tester.tap(find.text('All'));
    await tester.pump();
    expect(find.text("📈 You're on track! Great run."), findsOneWidget);
    expect(find.text('₦4,056,000'), findsOneWidget); // 312,000 × 13
  });
}
