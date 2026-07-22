import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/screens/credits/credits_screen.dart';
import 'package:prosperflow/src/screens/dashboard/dashboard_screen.dart';
import 'package:prosperflow/src/screens/expenses/expenses_screen.dart';
import 'package:prosperflow/src/screens/products/products_screen.dart';
import 'package:prosperflow/src/screens/record_sale/record_sale_screen.dart';

import 'helpers.dart';

void main() {
  group('Semantic labels on custom controls (item 1)', () {
    testWidgets('Products FAB is a labelled button', (tester) async {
      final handle = tester.ensureSemantics();
      usePhoneSurface(tester);
      await pumpWithStore(
        tester,
        const ProductsScreen(),
        store: fixtureStore(),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Add product'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Expenses FAB is a labelled button', (tester) async {
      final handle = tester.ensureSemantics();
      usePhoneSurface(tester);
      await pumpWithStore(
        tester,
        const ExpensesScreen(),
        store: fixtureStore(),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Add expense'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Record Sale steppers and pickers are labelled', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      usePhoneSurface(tester);
      await pumpWithStore(
        tester,
        const RecordSaleScreen(),
        store: fixtureStore(),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Decrease quantity'), findsOneWidget);
      expect(find.bySemanticsLabel('Increase quantity'), findsOneWidget);
      expect(find.bySemanticsLabel('Adjust price'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Change product')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('dashboard quick actions expose their labels as buttons', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      usePhoneSurface(tester, height: 1600);
      await pumpWithStore(
        tester,
        const DashboardScreen(),
        store: fixtureStore(),
      );
      await tester.pump();

      for (final label in ['Record Sale', 'Products', 'Expenses', 'Reports']) {
        expect(find.bySemanticsLabel(label), findsWidgets, reason: label);
      }
      handle.dispose();
    });

    testWidgets('Mark as Paid is a labelled button', (tester) async {
      final handle = tester.ensureSemantics();
      usePhoneSurface(tester);
      await pumpWithStore(tester, const CreditsScreen(), store: fixtureStore());
      await tester.pump();

      expect(find.bySemanticsLabel('Mark as paid'), findsWidgets);
      handle.dispose();
    });

    testWidgets('steppers carry button role and enabled state', (tester) async {
      final handle = tester.ensureSemantics();
      usePhoneSurface(tester);
      await pumpWithStore(
        tester,
        const RecordSaleScreen(),
        store: fixtureStore(),
      );
      await tester.pump();

      // qty starts at 1: "Increase" is enabled, "Decrease" is disabled — and
      // both still expose a button role to the screen reader.
      Semantics labelled(String label) => tester
          .widgetList<Semantics>(find.byType(Semantics))
          .firstWhere((s) => s.properties.label == label);

      final increase = labelled('Increase quantity');
      expect(increase.properties.button, isTrue);
      expect(increase.properties.enabled, isTrue);
      final decrease = labelled('Decrease quantity');
      expect(decrease.properties.button, isTrue);
      expect(decrease.properties.enabled, isFalse);
      handle.dispose();
    });
  });

  group('Screen-title header semantics (item 3)', () {
    bool titleIsHeader(WidgetTester tester, String title) => tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((s) => s.properties.header == true)
        .any(
          (s) => find
              .descendant(of: find.byWidget(s), matching: find.text(title))
              .evaluate()
              .isNotEmpty,
        );

    testWidgets('each screen exposes its title as a heading', (tester) async {
      final handle = tester.ensureSemantics();
      usePhoneSurface(tester, height: 1600);

      Future<void> check(Widget screen, String title) async {
        await pumpWithStore(tester, screen, store: fixtureStore());
        await tester.pump();
        expect(titleIsHeader(tester, title), isTrue, reason: title);
      }

      await check(const DashboardScreen(), 'ProsperFlow');
      await check(const ProductsScreen(), 'Products');
      await check(const ExpensesScreen(), 'Expenses');
      await check(const RecordSaleScreen(), 'Record Sale');
      await check(const CreditsScreen(), 'Outstanding Credits');
      handle.dispose();
    });
  });
}
