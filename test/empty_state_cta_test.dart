import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/data/memory_store.dart';
import 'package:prosperflow/src/screens/expenses/expenses_screen.dart';
import 'package:prosperflow/src/screens/products/products_screen.dart';
import 'package:prosperflow/src/widgets/empty_state.dart';

import 'helpers.dart';

void main() {
  group('EmptyState call-to-action', () {
    testWidgets('renders the action and fires onAction when tapped', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No products yet',
              message: 'Everything you sell lives here.',
              actionLabel: 'Add product',
              onAction: () => taps++,
            ),
          ),
        ),
      );

      expect(find.text('Add product'), findsOneWidget);
      await tester.tap(find.text('Add product'));
      expect(taps, 1);
    });

    testWidgets('shows no button when no action is given', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.check_circle_outline,
              title: 'All done',
              message: 'Nothing to see here.',
            ),
          ),
        ),
      );

      expect(find.byType(EmptyState), findsOneWidget);
      // No CTA row — only the title and message text are present.
      expect(find.byIcon(Icons.add_rounded), findsNothing);
    });
  });

  group('Screen empty-state CTAs open the add sheet', () {
    testWidgets('Products "Add product" opens the Add Product sheet', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await pumpWithStore(tester, const ProductsScreen(), store: MemoryStore());
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      await tester.tap(find.text('Add product'));
      await tester.pumpAndSettle();

      // The Add Product bottom sheet is now open (title + button both read it).
      expect(find.text('Add Product'), findsWidgets);
      expect(find.text('PRODUCT NAME'), findsOneWidget);
    });

    testWidgets('Expenses "Add expense" opens the Add Expense sheet', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await pumpWithStore(tester, const ExpensesScreen(), store: MemoryStore());
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      await tester.tap(find.text('Add expense'));
      await tester.pumpAndSettle();

      expect(find.text('Add Expense'), findsWidgets);
    });
  });
}
