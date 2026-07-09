import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/auth/auth_service.dart';
import 'package:prosperflow/src/data/app_scope.dart';
import 'package:prosperflow/src/screens/dashboard/dashboard_screen.dart';
import 'package:prosperflow/src/screens/record_sale/record_sale_screen.dart';
import 'package:prosperflow/src/widgets/primary_button.dart';

import 'helpers.dart';

void main() {
  testWidgets('total recomputes live from the qty stepper', (tester) async {
    usePhoneSurface(tester);
    await pumpWithStore(tester, const RecordSaleScreen());
    await tester.pump();

    // Palm Oil (25L) at ₦9,200, qty 1.
    expect(find.text('₦9,200'), findsNWidgets(2)); // price/unit + total

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('₦18,400'), findsOneWidget);

    // Min quantity is 1.
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('credit payment shows the customer-name warning and blocks save',
      (tester) async {
    usePhoneSurface(tester);
    await pumpWithStore(tester, const RecordSaleScreen());
    await tester.pump();

    expect(
        find.text('⚠ Customer name is required for credit sales'), findsNothing);

    await tester.tap(find.text('Credit'));
    await tester.pump();
    expect(find.text('⚠ Customer name is required for credit sales'),
        findsOneWidget);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();
    expect(find.byType(RecordSaleScreen), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('delivery toggle reveals the location field', (tester) async {
    usePhoneSurface(tester);
    await pumpWithStore(tester, const RecordSaleScreen());
    await tester.pump();

    expect(find.text('DELIVERY LOCATION'), findsNothing);
    await tester.tap(find.text('Delivery'));
    await tester.pump();
    expect(find.text('DELIVERY LOCATION'), findsOneWidget);
  });

  testWidgets('product picker changes product and stock label', (tester) async {
    usePhoneSurface(tester);
    await pumpWithStore(tester, const RecordSaleScreen());
    await tester.pump();

    await tester.tap(find.text('Palm Oil (25L)'));
    await tester.pumpAndSettle();
    expect(find.text('Choose product'), findsOneWidget);

    await tester.tap(find.text('Yam (per tuber)'));
    await tester.pumpAndSettle();
    expect(find.text('Yam (per tuber)'), findsOneWidget);
    expect(find.text('28 in stock'), findsOneWidget);
    expect(find.text('₦2,500'), findsNWidgets(2));
  });

  testWidgets('saving a sale writes to the store and decrements stock',
      (tester) async {
    usePhoneSurface(tester);
    final store = fixtureStore();
    await tester.pumpWidget(
      AppScope(
        store: store,
        auth: FakeAuthService(signedIn: true),
        child: MaterialApp(
          home: const RecordSaleScreen(),
          routes: {'/dashboard': (_) => const DashboardScreen()},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add)); // qty 2
    await tester.pump();
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    // Navigated to the dashboard.
    expect(find.text('Welcome back, Prosper 👋'), findsOneWidget);

    final products = await store.watchProducts().first;
    expect(products.firstWhere((p) => p.id == 'p1').stock, 40); // 42 − 2

    final today = await store.watchTodayStats().first;
    expect(today.total, 28400 + 2 * 9200);
    expect(today.count, 3);
  });
}
