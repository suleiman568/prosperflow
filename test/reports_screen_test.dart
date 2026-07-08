import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/screens/reports/reports_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets('week report computes profit, totals, and breakdowns',
      (tester) async {
    usePhoneSurface(tester, height: 1700);
    await pumpWithStore(tester, const ReportsScreen());
    await tester.pump();

    // Sales ₦103,800 − expenses ₦42,300.
    expect(find.text('NET PROFIT'), findsOneWidget);
    expect(find.text('₦61,500'), findsOneWidget);
    expect(find.text("📈 You're on track! Great week."), findsOneWidget);

    expect(find.text('₦103,800'), findsOneWidget);
    expect(find.text('6 transactions'), findsOneWidget);
    expect(find.text('₦42,300'), findsOneWidget);
    expect(find.text('4 items'), findsOneWidget);

    // Top products by revenue: Yam ₦40,000 (39%), Palm Oil ₦36,800 (35%).
    expect(find.text('39% of sales'), findsOneWidget);
    expect(find.text('35% of sales'), findsOneWidget);

    // Payment breakdown: credit sales still owed count as credit.
    expect(find.text('₦18,400'), findsOneWidget); // cash
    expect(find.text('₦10,000'), findsOneWidget); // transfer
    expect(find.text('₦6,000'), findsOneWidget); // POS
    expect(find.text('₦69,400'), findsOneWidget); // credit
  });

  testWidgets('collected credits count as cash in the breakdown',
      (tester) async {
    usePhoneSurface(tester, height: 1700);
    final store = fixtureStore();
    await store.markCreditPaid('c1'); // ₦18,400 collected
    await pumpWithStore(tester, const ReportsScreen(), store: store);
    await tester.pump();

    // Cash 18,400 + 18,400; credit 69,400 − 18,400.
    expect(find.text('₦36,800'), findsOneWidget);
    expect(find.text('₦51,000'), findsOneWidget);
  });

  testWidgets('switching period changes the window', (tester) async {
    usePhoneSurface(tester, height: 1700);
    await pumpWithStore(tester, const ReportsScreen());
    await tester.pump();

    await tester.tap(find.text('All'));
    await tester.pump();
    await tester.pump(); // stream delivers the new period's report

    // All-time expenses include the 40-day-old ₦6,400: total ₦48,700.
    expect(find.text('₦48,700'), findsOneWidget);
    expect(find.text('5 items'), findsOneWidget);
    expect(find.text("📈 You're on track! Great run."), findsOneWidget);
  });
}
