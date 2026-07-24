import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/app.dart';
import 'package:prosperflow/src/auth/auth_service.dart';
import 'package:prosperflow/src/data/app_scope.dart';
import 'package:prosperflow/src/screens/credits/credits_screen.dart';
import 'package:prosperflow/src/screens/dashboard/dashboard_screen.dart';
import 'package:prosperflow/src/screens/expenses/expenses_screen.dart';
import 'package:prosperflow/src/screens/login/login_screen.dart';
import 'package:prosperflow/src/screens/products/products_screen.dart';
import 'package:prosperflow/src/screens/record_sale/record_sale_screen.dart';
import 'package:prosperflow/src/screens/reports/reports_screen.dart';
import 'package:prosperflow/src/sync/sync_engine.dart';

import 'helpers.dart';

/// Re-scales everything below it to [factor], simulating the OS "larger text"
/// setting. Sits below MaterialApp's own MediaQuery so the override sticks.
Widget _scaled(Widget child, double factor) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(factor)),
    child: child,
  ),
);

void main() {
  group('OS text scaling (item 2)', () {
    testWidgets('the app clamps an oversized OS text scale to 1.3×', (
      tester,
    ) async {
      // Simulate a user who cranked system font size to 3×.
      tester.platformDispatcher.textScaleFactorTestValue = 3.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        AppScope(
          store: fixtureStore(),
          auth: FakeAuthService(signedIn: false),
          sync: NoopSyncEngine(),
          child: const ProsperFlowApp(),
        ),
      );
      await tester.pump();

      // Below the app's builder the effective scale is capped, not 3×.
      final scaler = MediaQuery.of(
        tester.element(find.byType(LoginScreen)),
      ).textScaler;
      expect(scaler.scale(10), 13.0);
    });

    testWidgets('a below-normal OS text scale is left untouched', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 0.8;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        AppScope(
          store: fixtureStore(),
          auth: FakeAuthService(signedIn: false),
          sync: NoopSyncEngine(),
          child: const ProsperFlowApp(),
        ),
      );
      await tester.pump();

      final scaler = MediaQuery.of(
        tester.element(find.byType(LoginScreen)),
      ).textScaler;
      expect(scaler.scale(10), 8.0);
    });

    // At the 1.3× cap every screen must still lay out without a RenderFlex
    // overflow — the test framework fails automatically if one is thrown.
    final screens = <String, Widget>{
      'Dashboard': const DashboardScreen(),
      'Products': const ProductsScreen(),
      'Record Sale': const RecordSaleScreen(),
      'Expenses': const ExpensesScreen(),
      'Reports': const ReportsScreen(),
      'Credits': const CreditsScreen(),
    };

    screens.forEach((name, screen) {
      testWidgets('$name has no overflow at the 1.3× cap', (tester) async {
        usePhoneSurface(tester, height: 1800);
        await pumpWithStore(
          tester,
          _scaled(screen, 1.3),
          store: fixtureStore(),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      });
    });
  });
}
