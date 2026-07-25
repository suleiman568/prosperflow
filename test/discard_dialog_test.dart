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

  testWidgets('a dirty form confirms before discarding on back', (
    tester,
  ) async {
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

  testWidgets('a clean form dismisses straight away, no dialog', (
    tester,
  ) async {
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

  Future<void> openAddExpense(WidgetTester tester) async {
    await pumpWithStore(tester, const ExpensesScreen(), store: fixtureStore());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add)); // the FAB
    await tester.pumpAndSettle();
    expect(find.text('DESCRIPTION'), findsOneWidget);
  }

  testWidgets('Add Expense: a category-only change is dirty', (tester) async {
    usePhoneSurface(tester);
    await openAddExpense(tester);

    // No text entered — only switch the category away from the default.
    await tester.tap(find.text('Rent'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
  });

  testWidgets('Add Expense: a date-only change is dirty', (tester) async {
    usePhoneSurface(tester);
    await openAddExpense(tester);

    // Open the date picker and choose a day in the previous month.
    await tester.tap(find.byIcon(Icons.calendar_today_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
  });

  Future<void> openEditPalmOil(WidgetTester tester) async {
    await pumpWithStore(tester, const ProductsScreen(), store: fixtureStore());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert).first); // Palm Oil card
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Product'), findsOneWidget);
  }

  testWidgets('Edit Product: a whitespace-only no-op edit is not dirty', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await openEditPalmOil(tester);

    // Re-type the same name padded with whitespace — a no-op once trimmed.
    await tester.enterText(find.byType(TextField).first, '  Palm Oil (25L)  ');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // No confirm dialog — the sheet just closes.
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Edit Product'), findsNothing);
  });

  testWidgets('Edit Product: a real change still confirms', (tester) async {
    usePhoneSurface(tester);
    await openEditPalmOil(tester);

    await tester.enterText(find.byType(TextField).first, 'Palm Oil (20L)');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
  });
}
