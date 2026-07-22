import 'package:flutter/material.dart';

import 'data/app_scope.dart';
import 'screens/credits/credits_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/expenses/expenses_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/products/products_screen.dart';
import 'screens/record_sale/record_sale_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'theme/tokens.dart';

class ProsperFlowApp extends StatelessWidget {
  const ProsperFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ProsperFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: AppColors.appBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
        ),
        splashFactory: InkSparkle.splashFactory,
      ),
      builder: (context, child) {
        // Honour the OS "larger text" accessibility setting, but clamp the
        // upper bound: our compact stat cards and 2×2 grids overflow past
        // ~1.3×, so we cap there rather than let labels clip. Below 1.0 we
        // leave the user's choice untouched.
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: child ?? const SizedBox.shrink(),
        );
      },
      initialRoute: AppScope.authOf(context).isSignedIn
          ? DashboardScreen.route
          : LoginScreen.route,
      routes: {
        LoginScreen.route: (_) => const LoginScreen(),
        DashboardScreen.route: (_) => const DashboardScreen(),
        RecordSaleScreen.route: (_) => const RecordSaleScreen(),
        ProductsScreen.route: (_) => const ProductsScreen(),
        ExpensesScreen.route: (_) => const ExpensesScreen(),
        ReportsScreen.route: (_) => const ReportsScreen(),
        CreditsScreen.route: (_) => const CreditsScreen(),
      },
    );
  }
}
