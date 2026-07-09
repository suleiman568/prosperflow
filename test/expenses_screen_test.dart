import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/screens/expenses/expenses_screen.dart';
import 'package:prosperflow/src/widgets/primary_button.dart';

import 'helpers.dart';

void main() {
  testWidgets('expenses list shows weekly total banner and expense cards',
      (tester) async {
    usePhoneSurface(tester);
    await pumpWithStore(tester, const ExpensesScreen());
    await tester.pump();

    expect(find.text("THIS WEEK'S TOTAL"), findsOneWidget);
    // Weekly only: 8,500 + 18,000 + 10,000 + 5,800 — the 40-day-old
    // ₦6,400 expense is excluded from the banner but shown in the list.
    expect(find.text('₦42,300'), findsOneWidget);

    expect(find.text('Delivery Cost'), findsNWidgets(2));
    expect(find.text('-₦8,500'), findsOneWidget);
    expect(find.text('-₦6,400'), findsOneWidget);
    expect(find.text('Stall Rent'), findsOneWidget);
  });

  testWidgets('FAB opens Add Expense sheet and adds an expense',
      (tester) async {
    usePhoneSurface(tester);
    await pumpWithStore(tester, const ExpensesScreen());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Add Expense'), findsNWidgets(2)); // title + button

    await tester.enterText(
        find.widgetWithText(TextField, 'Delivery Cost'), 'Generator fuel');
    await tester.enterText(find.widgetWithText(TextField, '8500'), '3200');
    await tester.tap(find.text('Transport'));
    await tester.pump();
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(find.text('Generator fuel'), findsOneWidget);
    expect(find.text('-₦3,200'), findsOneWidget);
    // Weekly banner recomputes: 42,300 + 3,200.
    expect(find.text('₦45,500'), findsOneWidget);
  });

  testWidgets('incomplete Add Expense form is rejected with a toast',
      (tester) async {
    usePhoneSurface(tester);
    await pumpWithStore(tester, const ExpensesScreen());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('DESCRIPTION'), findsOneWidget); // sheet stays open
  });

  testWidgets('swipe-to-delete removes the expense and updates the total',
      (tester) async {
    usePhoneSurface(tester);
    final store = fixtureStore();
    await pumpWithStore(tester, const ExpensesScreen(), store: store);
    await tester.pump();

    await tester.drag(find.text('Stall Rent'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('Delete Stall Rent?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Stall Rent'), findsNothing);
    // Weekly banner recomputes: 42,300 − 10,000.
    expect(find.text('₦32,300'), findsOneWidget);
  });

  testWidgets('long-press also offers delete (mouse-friendly fallback)',
      (tester) async {
    usePhoneSurface(tester);
    await pumpWithStore(tester, const ExpensesScreen());
    await tester.pump();

    await tester.longPress(find.text('Fuel/Transport'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Fuel/Transport?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Fuel/Transport'), findsNothing);
  });
}
