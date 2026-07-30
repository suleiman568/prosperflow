import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/data/memory_store.dart';
import 'package:prosperflow/src/data/models.dart';
import 'package:prosperflow/src/screens/dashboard/dashboard_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets('dashboard streams greeting, stats, alerts, and credits', (
    tester,
  ) async {
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

  testWidgets('a single sale and a single debtor read in the singular', (
    tester,
  ) async {
    usePhoneSurface(tester);
    Sale saleOf(
      String id,
      Product p,
      PaymentMethod method,
      DateTime when, {
      String? who,
    }) => Sale(
      id: id,
      productId: p.id,
      productName: p.name,
      qty: 1,
      unitPrice: p.sellPrice,
      unitCost: p.buyPrice,
      total: p.sellPrice,
      method: method,
      fulfilment: Fulfilment.walkIn,
      customerName: who,
      soldAt: when,
    );
    final now = DateTime.now();
    final store = MemoryStore(
      products: fixtureProducts,
      sales: [
        // One sale today; the credit sale is older, so today = 1 and week = 2.
        saleOf('s1', palm, PaymentMethod.cash, now),
        saleOf(
          'c1',
          yam,
          PaymentMethod.credit,
          now.subtract(const Duration(days: 3)),
          who: 'Ada Obi',
        ),
      ],
      credits: [
        Credit(
          saleId: 'c1',
          customerName: 'Ada Obi',
          amount: 2500,
          product: 'Yam (per tuber) × 1',
          status: CreditStatus.owed,
          soldAt: DateTime.now(),
        ),
      ],
    );
    await pumpWithStore(tester, const DashboardScreen(), store: store);
    await tester.pump();

    // Not "1 sales today" / "1 customers →".
    expect(find.text('1 sale today'), findsOneWidget);
    expect(find.text('2 sales'), findsOneWidget); // week: both sales
    await tester.scrollUntilVisible(
      find.text('OUTSTANDING CREDITS'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1 customer →'), findsOneWidget);
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
