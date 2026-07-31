import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/auth/auth_service.dart';
import 'package:prosperflow/src/data/app_scope.dart';
import 'package:prosperflow/src/data/memory_store.dart';
import 'package:prosperflow/src/screens/products/products_screen.dart';
import 'package:prosperflow/src/sync/sync_engine.dart';
import 'package:prosperflow/src/widgets/primary_button.dart';

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

      await tester.enterText(find.widgetWithText(TextField, '6,800'), '6800');
      await tester.enterText(find.widgetWithText(TextField, '9,200'), '6000');
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

      await tester.enterText(find.widgetWithText(TextField, '6,800'), '5000');
      await tester.enterText(find.widgetWithText(TextField, '9,200'), '5000');
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

      final buy = find.widgetWithText(TextField, '6,800');
      final sell = find.widgetWithText(TextField, '9,200');
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

  group('Add Product form reachability', () {
    testWidgets(
      'the Save button stays reachable with the warning showing at a large '
      'text scale and the keyboard open',
      (tester) async {
        // A large keyboard inset over the viewport, so a fixed (non-scrolling)
        // column would clip the lower controls once the warning adds height.
        // Width 600 keeps the scaffold chrome (header, tab bar) from
        // overflowing at 2x — the app's practical accessibility ceiling — so
        // the test isolates the form. Start empty so no product cards render
        // behind the sheet.
        tester.view.physicalSize = const Size(600, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final store = MemoryStore();
        await tester.pumpWidget(
          AppScope(
            store: store,
            auth: FakeAuthService(signedIn: true),
            sync: NoopSyncEngine(),
            child: MaterialApp(
              // Force a large accessibility text scale AND a keyboard inset
              // across the whole app — the modal sheet's overlay included. At
              // 2x the form is ~1000px tall inside a ~500px sheet area, so the
              // Save button only stays reachable because the column scrolls.
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2.0),
                  viewInsets: const EdgeInsets.only(bottom: 400),
                ),
                child: child!,
              ),
              home: const ProductsScreen(),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        // A valid but below-cost product, so the warning is on screen.
        await tester.enterText(
          find.widgetWithText(TextField, 'Palm Oil (25L)'),
          'Garri (paint)',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'bottles'),
          'paints',
        );
        await tester.enterText(find.widgetWithText(TextField, '6,800'), '6800');
        await tester.enterText(find.widgetWithText(TextField, '9,200'), '6000');
        await tester.enterText(find.widgetWithText(TextField, '42'), '5');
        await tester.pump();
        expect(find.textContaining('Below cost'), findsOneWidget);

        // The Save button sits below the fold at this scale but is reachable
        // by scrolling, and it still submits — proving nothing is clipped.
        final saveButton = find.widgetWithText(PrimaryButton, 'Add Product');
        await tester.ensureVisible(saveButton);
        await tester.pumpAndSettle();
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // The sheet closed and the product was written.
        expect(find.widgetWithText(PrimaryButton, 'Add Product'), findsNothing);
        final products = await store.watchProducts().first;
        expect(products.any((p) => p.name == 'Garri (paint)'), isTrue);
      },
    );
  });
}
