import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/screens/expenses/expenses_screen.dart';
import 'package:prosperflow/src/screens/products/products_screen.dart';

import 'helpers.dart';

void main() {
  Future<void> openAddProduct(WidgetTester tester) async {
    await pumpWithStore(tester, const ProductsScreen(), store: fixtureStore());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add)); // the FAB
    await tester.pumpAndSettle();
    expect(find.text('PRODUCT NAME'), findsOneWidget); // sheet is open
  }

  testWidgets('a dirty form confirms before discarding on back',
      (tester) async {
    usePhoneSurface(tester);
    await openAddProduct(tester);

    // Type something, then trigger the system back button.
    await tester.enterText(find.byType(TextField).first, 'Palm Oil');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // The confirm dialog is up and the sheet is still open behind it.
    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.text('PRODUCT NAME'), findsOneWidget);

    // "Keep editing" dismisses the dialog and keeps the sheet.
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('PRODUCT NAME'), findsOneWidget);

    // Back again, then "Discard" closes the sheet.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('PRODUCT NAME'), findsNothing);
  });

  testWidgets('a clean form dismisses straight away, no dialog',
      (tester) async {
    usePhoneSurface(tester);
    await openAddProduct(tester);

    // No input entered — back should just close the sheet.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('PRODUCT NAME'), findsNothing);
  });

  testWidgets('Add Expense also guards a dirty form', (tester) async {
    usePhoneSurface(tester);
    await pumpWithStore(tester, const ExpensesScreen(), store: fixtureStore());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add)); // the FAB
    await tester.pumpAndSettle();
    expect(find.text('DESCRIPTION'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Fuel');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
  });
}
