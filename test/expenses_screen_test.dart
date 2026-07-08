import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/screens/expenses/expenses_screen.dart';
import 'package:prosperflow/src/widgets/primary_button.dart';

Widget _app() => const MaterialApp(home: ExpensesScreen());

void _usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('expenses list shows weekly total banner and expense cards',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app());

    expect(find.text("THIS WEEK'S TOTAL"), findsOneWidget);
    // 8,500 + 18,000 + 10,000 + 5,800.
    expect(find.text('₦42,300'), findsOneWidget);

    expect(find.text('Delivery Cost'), findsOneWidget);
    expect(find.text('-₦8,500'), findsOneWidget);
    expect(find.text('Stall Rent'), findsOneWidget);
    expect(find.text('Friday, 3 July'), findsOneWidget);
  });

  testWidgets('FAB opens Add Expense sheet and adds an expense',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app());

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
    // Total banner recomputes: 42,300 + 3,200.
    expect(find.text('₦45,500'), findsOneWidget);
  });

  testWidgets('incomplete Add Expense form is rejected with a toast',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app());

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('DESCRIPTION'), findsOneWidget); // sheet stays open
  });
}
