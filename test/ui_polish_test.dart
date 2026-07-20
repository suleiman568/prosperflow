import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/auth/auth_service.dart';
import 'package:prosperflow/src/data/app_scope.dart';
import 'package:prosperflow/src/data/memory_store.dart';
import 'package:prosperflow/src/screens/expenses/expenses_screen.dart';
import 'package:prosperflow/src/screens/products/products_screen.dart';
import 'package:prosperflow/src/screens/record_sale/record_sale_screen.dart';
import 'package:prosperflow/src/screens/reports/reports_screen.dart';
import 'package:prosperflow/src/sync/sync_engine.dart';
import 'package:prosperflow/src/widgets/empty_state.dart';

import 'helpers.dart';

Future<void> pumpWithRoutes(WidgetTester tester, Widget home,
    {MemoryStore? store}) async {
  await tester.pumpWidget(
    AppScope(
      store: store ?? MemoryStore(),
      auth: FakeAuthService(signedIn: true),
      sync: NoopSyncEngine(),
      child: MaterialApp(
        home: home,
        routes: {'/products': (_) => const ProductsScreen()},
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('Record Sale with no products (batch item 1)', () {
    testWidgets('shows the add-a-product state, never an endless spinner',
        (tester) async {
      usePhoneSurface(tester);
      await pumpWithRoutes(tester, const RecordSaleScreen());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Add a product first'), findsOneWidget);
      expect(find.text('Go to Products'), findsOneWidget);
    });

    testWidgets('the button navigates to the Products screen', (tester) async {
      usePhoneSurface(tester);
      await pumpWithRoutes(tester, const RecordSaleScreen());
      await tester.pump();

      await tester.tap(find.text('Go to Products'));
      await tester.pumpAndSettle();

      expect(find.byType(ProductsScreen), findsOneWidget);
    });
  });

  group('First-run empty states (batch item 2)', () {
    testWidgets('Products shows guidance instead of a blank list',
        (tester) async {
      usePhoneSurface(tester);
      await pumpWithStore(tester, const ProductsScreen(),
          store: MemoryStore());
      await tester.pump();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No products yet'), findsOneWidget);
      expect(find.textContaining('add your first product'), findsOneWidget);
    });

    testWidgets('Expenses shows guidance instead of a bare ₦0 banner',
        (tester) async {
      usePhoneSurface(tester);
      await pumpWithStore(tester, const ExpensesScreen(),
          store: MemoryStore());
      await tester.pump();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No expenses yet'), findsOneWidget);
      expect(find.text("THIS WEEK'S TOTAL"), findsNothing); // banner hidden
    });

    testWidgets('empty states disappear once data exists', (tester) async {
      usePhoneSurface(tester);
      final store = MemoryStore();
      await pumpWithStore(tester, const ProductsScreen(), store: store);
      await tester.pump();
      expect(find.byType(EmptyState), findsOneWidget);

      await store.addProduct(
          name: 'Garri', unit: 'paints', stock: 5, buyPrice: 1, sellPrice: 2);
      await tester.pumpAndSettle();
      expect(find.byType(EmptyState), findsNothing);
      expect(find.text('Garri'), findsOneWidget);
    });
  });

  group('Touch targets (batch item 3)', () {
    testWidgets('qty steppers, three-dot menu, and back arrow are ≥ 44dp',
        (tester) async {
      usePhoneSurface(tester);
      await pumpWithStore(tester, const RecordSaleScreen());
      await tester.pump();

      // Stepper hit areas (the GestureDetector around each button).
      for (final icon in [Icons.remove, Icons.add]) {
        final size = tester.getSize(find.ancestor(
            of: find.byIcon(icon).first,
            matching: find.byType(GestureDetector)).first);
        expect(size.width, greaterThanOrEqualTo(44), reason: '$icon width');
        expect(size.height, greaterThanOrEqualTo(44), reason: '$icon height');
      }

      // Header back arrow.
      final back = tester.getSize(find.ancestor(
          of: find.byIcon(Icons.arrow_back),
          matching: find.byType(GestureDetector)).first);
      expect(back.width, greaterThanOrEqualTo(44));
      expect(back.height, greaterThanOrEqualTo(44));
    });

    testWidgets('three-dot overflow menu hit area is ≥ 44dp', (tester) async {
      usePhoneSurface(tester);
      await pumpWithStore(tester, const ProductsScreen());
      await tester.pump();

      // The SizedBox around the icon defines the tappable region.
      // (The visual icon itself stays 18px inside it.)
      final region = tester.getSize(find.ancestor(
          of: find.byIcon(Icons.more_vert).first,
          matching: find.byType(SizedBox)).first);
      expect(region.width, greaterThanOrEqualTo(44));
      expect(region.height, greaterThanOrEqualTo(44));
    });
  });

  group('Sales History animation (batch item 4)', () {
    testWidgets('expansion animates via AnimatedSize with a rotating chevron',
        (tester) async {
      usePhoneSurface(tester, height: 3200);
      await pumpWithStore(tester, const ReportsScreen());
      await tester.pump();
      await tester.pump();

      AnimatedRotation chevron() => tester.widget<AnimatedRotation>(
          find.byType(AnimatedRotation).first);
      expect(chevron().turns, 0);
      expect(find.byType(AnimatedSize), findsWidgets);

      await tester.tap(find.text('+₦4,800 profit'));
      await tester.pump();
      expect(chevron().turns, 0.5); // pointing up while open

      // Detail rows are present and settle in smoothly.
      await tester.pumpAndSettle();
      expect(find.text('2 × ₦9,200'), findsOneWidget);

      await tester.tap(find.text('+₦4,800 profit'));
      await tester.pumpAndSettle();
      expect(chevron().turns, 0);
      expect(find.text('2 × ₦9,200'), findsNothing);
    });
  });
}
