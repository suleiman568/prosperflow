import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/screens/products/products_screen.dart';

import 'helpers.dart';

/// Opens the three-dot Edit sheet for the first product (Palm Oil).
Future<void> openEditSheet(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_vert).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Edit'));
  await tester.pumpAndSettle();
}

void main() {
  group('Add Product margin warning', () {
    testWidgets('a below-cost sell price warns with the per-unit loss', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await pumpWithStore(tester, const ProductsScreen());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // No warning before any prices are entered.
      expect(find.textContaining('Below cost'), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, '6800'), '6800');
      await tester.enterText(find.widgetWithText(TextField, '9200'), '6000');
      await tester.pump();

      expect(find.textContaining('Below cost'), findsOneWidget);
      expect(find.textContaining('lose ₦800'), findsOneWidget);
    });

    testWidgets('an equal buy/sell price warns there is no profit', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await pumpWithStore(tester, const ProductsScreen());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, '6800'), '5000');
      await tester.enterText(find.widgetWithText(TextField, '9200'), '5000');
      await tester.pump();

      expect(find.textContaining('No profit'), findsOneWidget);
      expect(find.textContaining('Below cost'), findsNothing);
    });

    testWidgets('raising the sell price above cost clears the warning', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await pumpWithStore(tester, const ProductsScreen());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      final buy = find.widgetWithText(TextField, '6800');
      final sell = find.widgetWithText(TextField, '9200');
      await tester.enterText(buy, '6800');
      await tester.enterText(sell, '6000');
      await tester.pump();
      expect(find.textContaining('Below cost'), findsOneWidget);

      await tester.enterText(sell, '9500');
      await tester.pump();
      expect(find.textContaining('Below cost'), findsNothing);
      expect(find.textContaining('No profit'), findsNothing);
    });
  });

  group('Edit Product margin warning', () {
    testWidgets('a healthy product opens without a warning', (tester) async {
      usePhoneSurface(tester);
      await pumpWithStore(tester, const ProductsScreen());
      await tester.pump();

      await openEditSheet(tester); // Palm Oil: buy 6,800 / sell 9,200

      expect(find.text('Edit Product'), findsOneWidget);
      expect(find.textContaining('Below cost'), findsNothing);
      expect(find.textContaining('No profit'), findsNothing);
    });

    testWidgets('lowering the sell price below cost warns live', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await pumpWithStore(tester, const ProductsScreen());
      await tester.pump();

      await openEditSheet(tester);

      // Fields in order: name, unit, buy, sell, threshold.
      await tester.enterText(find.byType(TextField).at(3), '6000');
      await tester.pump();

      expect(find.textContaining('Below cost'), findsOneWidget);
      expect(find.textContaining('lose ₦800'), findsOneWidget);
    });
  });
}
