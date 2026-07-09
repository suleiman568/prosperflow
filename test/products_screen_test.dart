import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/screens/products/products_screen.dart';
import 'package:prosperflow/src/widgets/primary_button.dart';

import 'helpers.dart';

void main() {
  testWidgets('products list shows cards with prices and stock badges',
      (tester) async {
    usePhoneSurface(tester);
    await pumpWithStore(tester, const ProductsScreen());
    await tester.pump();

    expect(find.text('Palm Oil (25L)'), findsOneWidget);
    expect(find.text('42 bottles'), findsOneWidget);
    expect(find.text('₦6,800 → ₦9,200'), findsOneWidget);
    expect(find.text('42'), findsOneWidget); // healthy stock badge

    // Two products at/below the threshold show LOW badges.
    expect(find.text('LOW'), findsNWidgets(2));
  });

  testWidgets('FAB opens Add Product sheet and adds a product',
      (tester) async {
    usePhoneSurface(tester);
    await pumpWithStore(tester, const ProductsScreen());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Add Product'), findsNWidgets(2)); // title + button

    await tester.enterText(
        find.widgetWithText(TextField, 'Palm Oil (25L)'), 'Garri (paint)');
    await tester.enterText(find.widgetWithText(TextField, 'bottles'), 'paints');
    await tester.enterText(find.widgetWithText(TextField, '6800'), '1500');
    await tester.enterText(find.widgetWithText(TextField, '9200'), '2200');
    await tester.enterText(find.widgetWithText(TextField, '42'), '30');
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(find.text('Garri (paint)'), findsOneWidget);
    expect(find.text('30 paints'), findsOneWidget);
    expect(find.text('₦1,500 → ₦2,200'), findsOneWidget);
  });

  testWidgets('incomplete Add Product form is rejected with a toast',
      (tester) async {
    usePhoneSurface(tester);
    await pumpWithStore(tester, const ProductsScreen());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('PRODUCT NAME'), findsOneWidget); // sheet stays open
  });

  testWidgets('swipe-to-delete confirms and removes the product',
      (tester) async {
    usePhoneSurface(tester);
    final store = fixtureStore();
    await pumpWithStore(tester, const ProductsScreen(), store: store);
    await tester.pump();

    await tester.drag(find.text('Palm Oil (25L)'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('Delete Palm Oil (25L)?'), findsOneWidget);

    // Cancel keeps the product.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Palm Oil (25L)'), findsOneWidget);

    // Delete removes it from the store and the list.
    await tester.drag(find.text('Palm Oil (25L)'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Palm Oil (25L)'), findsNothing);
    final products = await store.watchProducts().first;
    expect(products.any((p) => p.name == 'Palm Oil (25L)'), isFalse);
  });

  testWidgets('long-press also offers delete (mouse-friendly fallback)',
      (tester) async {
    usePhoneSurface(tester);
    final store = fixtureStore();
    await pumpWithStore(tester, const ProductsScreen(), store: store);
    await tester.pump();

    await tester.longPress(find.text('Yam (per tuber)'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Yam (per tuber)?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Yam (per tuber)'), findsNothing);
    final products = await store.watchProducts().first;
    expect(products.any((p) => p.name == 'Yam (per tuber)'), isFalse);
  });
}
