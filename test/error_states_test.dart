import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/data/memory_store.dart';
import 'package:prosperflow/src/data/models.dart';
import 'package:prosperflow/src/screens/credits/credits_screen.dart';
import 'package:prosperflow/src/screens/expenses/expenses_screen.dart';
import 'package:prosperflow/src/screens/products/products_screen.dart';
import 'package:prosperflow/src/widgets/error_state.dart';
import 'package:prosperflow/src/widgets/skeleton.dart';

import 'helpers.dart';

/// Every watch stream errors immediately — the failure case the screens now
/// have to render instead of spinning on the loading skeleton.
class _ErrorStore extends MemoryStore {
  @override
  Stream<List<Product>> watchProducts() =>
      Stream.error(Exception('load failed'));

  @override
  Stream<List<Expense>> watchExpenses() =>
      Stream.error(Exception('load failed'));

  @override
  Stream<List<Credit>> watchOwedCredits() =>
      Stream.error(Exception('load failed'));
}

/// Errors on the first subscription, then serves real data on the retry —
/// so we can prove "Try again" actually re-subscribes and recovers.
class _FlakyProductStore extends MemoryStore {
  _FlakyProductStore() : super(products: fixtureProducts);

  int _subscriptions = 0;

  @override
  Stream<List<Product>> watchProducts() {
    _subscriptions++;
    return _subscriptions == 1
        ? Stream<List<Product>>.error(Exception('load failed'))
        : super.watchProducts();
  }
}

void main() {
  group('ErrorState widget', () {
    testWidgets('shows a retry action that fires onRetry', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ErrorState(onRetry: () => taps++)),
        ),
      );

      expect(find.text("Couldn't load"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      expect(taps, 1);
    });
  });

  group('Screen error states', () {
    testWidgets(
      'Products shows the error state, not the skeleton, on failure',
      (tester) async {
        usePhoneSurface(tester);
        await pumpWithStore(
          tester,
          const ProductsScreen(),
          store: _ErrorStore(),
        );
        await tester.pump();

        expect(find.byType(ErrorState), findsOneWidget);
        expect(find.byType(Skeleton), findsNothing);
        expect(find.text('No products yet'), findsNothing);
      },
    );

    testWidgets('Expenses shows the error state on failure', (tester) async {
      usePhoneSurface(tester);
      await pumpWithStore(tester, const ExpensesScreen(), store: _ErrorStore());
      await tester.pump();

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.byType(Skeleton), findsNothing);
    });

    testWidgets('Credits shows the error state on failure', (tester) async {
      usePhoneSurface(tester);
      await pumpWithStore(tester, const CreditsScreen(), store: _ErrorStore());
      await tester.pump();

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.byType(Skeleton), findsNothing);
    });

    testWidgets('Try again re-subscribes and recovers into the real list', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await pumpWithStore(
        tester,
        const ProductsScreen(),
        store: _FlakyProductStore(),
      );
      await tester.pump();

      expect(find.byType(ErrorState), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsNothing);
      expect(find.text('Palm Oil (25L)'), findsOneWidget);
    });
  });
}
