import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/data/memory_store.dart';
import 'package:prosperflow/src/data/models.dart';
import 'package:prosperflow/src/screens/credits/credits_screen.dart';
import 'package:prosperflow/src/theme/tokens.dart';

import 'helpers.dart';

void main() {
  testWidgets('credits list shows total banner and per-customer cards', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await pumpWithStore(tester, const CreditsScreen());
    await tester.pump();

    expect(find.text('TOTAL OUTSTANDING'), findsOneWidget);
    // 18,400 + 30,000 + 21,000.
    expect(find.text('₦69,400'), findsOneWidget);

    expect(find.text('Chioma Ojo'), findsOneWidget);
    expect(find.text('Palm Oil (25L) × 2'), findsOneWidget);
    expect(find.text('₦18,400'), findsOneWidget);
    expect(find.text('Mark as Paid'), findsNWidgets(3));
  });

  testWidgets('mark as paid removes the card and updates the total', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await pumpWithStore(tester, const CreditsScreen());
    await tester.pump();

    await tester.tap(find.text('Mark as Paid').first);
    await tester.pumpAndSettle();

    expect(find.text('Chioma Ojo'), findsNothing);
    // 69,400 − 18,400.
    expect(find.text('₦51,000'), findsOneWidget);
  });

  testWidgets('each card shows how long the credit has been owed', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await pumpWithStore(tester, const CreditsScreen());
    await tester.pump();

    // Fixtures: Chioma 3 days, Abike 5 days, Okoro 6 days ago — all recent, so
    // the age label stays in the (orange) not-yet-overdue colour.
    expect(find.text('Owed for 3 days'), findsOneWidget);
    expect(find.text('Owed for 5 days'), findsOneWidget);
    expect(find.text('Owed for 6 days'), findsOneWidget);
    final recent = tester.widget<Text>(find.text('Owed for 3 days'));
    expect(recent.style?.color, AppColors.accentOrange);
  });

  testWidgets('a long-overdue credit is flagged in red', (tester) async {
    usePhoneSurface(tester);
    final store = MemoryStore(
      credits: [
        Credit(
          saleId: 'old1',
          customerName: 'Tunde Bakare',
          amount: 5000,
          product: 'Rice (50kg) × 1',
          status: CreditStatus.owed,
          soldAt: DateTime.now().subtract(const Duration(days: 40)),
        ),
      ],
    );
    await pumpWithStore(tester, const CreditsScreen(), store: store);
    await tester.pump();

    final label = tester.widget<Text>(find.text('Owed for 1 month'));
    expect(label.style?.color, AppColors.accentRed);
  });

  testWidgets('collecting every credit shows the empty state', (tester) async {
    usePhoneSurface(tester);
    await pumpWithStore(tester, const CreditsScreen());
    await tester.pump();

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Mark as Paid').first);
      await tester.pumpAndSettle();
    }

    expect(find.text('All credits collected!'), findsOneWidget);
    expect(find.text('No customers owe you money.'), findsOneWidget);
    expect(find.text('TOTAL OUTSTANDING'), findsNothing);
  });
}
