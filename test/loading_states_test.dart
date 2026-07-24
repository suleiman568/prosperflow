import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/data/memory_store.dart';
import 'package:prosperflow/src/data/models.dart';
import 'package:prosperflow/src/screens/credits/credits_screen.dart';
import 'package:prosperflow/src/screens/dashboard/dashboard_screen.dart';
import 'package:prosperflow/src/screens/expenses/expenses_screen.dart';
import 'package:prosperflow/src/screens/products/products_screen.dart';
import 'package:prosperflow/src/widgets/skeleton.dart';

import 'helpers.dart';

/// A store whose watch streams stay open but never emit, so screens sit in
/// their first-frame loading state for as long as the test needs. Writes are
/// inherited from [MemoryStore] and go unused here.
class _PendingStore extends MemoryStore {
  Stream<T> _pending<T>() => StreamController<T>().stream;

  @override
  Stream<List<Product>> watchProducts() => _pending();

  @override
  Stream<List<Expense>> watchExpenses() => _pending();

  @override
  Stream<List<Credit>> watchOwedCredits() => _pending();

  @override
  Stream<SalesStats> watchTodayStats() => _pending();

  @override
  Stream<SalesStats> watchWeekStats() => _pending();
}

void main() {
  group('Skeleton primitive (item 1)', () {
    testWidgets('renders and its shimmer band advances over time', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: Skeleton(width: 100))),
        ),
      );

      expect(find.byType(Skeleton), findsOneWidget);

      List<double> stops() {
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(Skeleton),
            matching: find.byType(Container),
          ),
        );
        final gradient =
            (container.decoration as BoxDecoration).gradient as LinearGradient;
        return gradient.stops!;
      }

      final before = stops();
      await tester.pump(const Duration(milliseconds: 300));
      expect(stops(), isNot(before), reason: 'shimmer should animate');
    });

    testWidgets('circle variant is laid out square', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: Skeleton.circle(size: 42))),
        ),
      );

      final size = tester.getSize(find.byType(Skeleton));
      expect(size, const Size(42, 42));
    });
  });

  group('Screen loading skeletons (items 2 & 3)', () {
    testWidgets(
      'Products shows skeletons, not the empty state, while loading',
      (tester) async {
        usePhoneSurface(tester);
        await pumpWithStore(
          tester,
          const ProductsScreen(),
          store: _PendingStore(),
        );
        await tester.pump();

        expect(find.byType(Skeleton), findsWidgets);
        expect(find.text('No products yet'), findsNothing);
      },
    );

    testWidgets(
      'Expenses shows skeletons, not the empty state, while loading',
      (tester) async {
        usePhoneSurface(tester);
        await pumpWithStore(
          tester,
          const ExpensesScreen(),
          store: _PendingStore(),
        );
        await tester.pump();

        expect(find.byType(Skeleton), findsWidgets);
        expect(find.text('No expenses yet'), findsNothing);
      },
    );

    testWidgets('Credits shows skeletons instead of a blank while loading', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await pumpWithStore(
        tester,
        const CreditsScreen(),
        store: _PendingStore(),
      );
      await tester.pump();

      expect(find.byType(Skeleton), findsWidgets);
      expect(find.text('TOTAL OUTSTANDING'), findsNothing);
    });

    testWidgets('Dashboard stat cards skeleton the figures, not a stale ₦0', (
      tester,
    ) async {
      usePhoneSurface(tester, height: 1600);
      await pumpWithStore(
        tester,
        const DashboardScreen(),
        store: _PendingStore(),
      );
      await tester.pump();

      // Cards are present (labels show) but the numbers are skeletons, not 0.
      expect(find.text("Today's Sales"), findsOneWidget);
      expect(find.byType(Skeleton), findsWidgets);
      expect(find.text('0 sales today'), findsNothing);
    });

    testWidgets('skeletons clear once data arrives', (tester) async {
      usePhoneSurface(tester);
      // A normal fixture store emits immediately; after settling, the real
      // list has replaced the placeholders.
      await pumpWithStore(
        tester,
        const ProductsScreen(),
        store: fixtureStore(),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Skeleton), findsNothing);
      expect(find.text('Palm Oil (25L)'), findsOneWidget);
    });
  });
}
