import 'package:flutter/material.dart';

import 'screens/coming_soon_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/record_sale/record_sale_screen.dart';
import 'theme/tokens.dart';
import 'widgets/app_tab_bar.dart';

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
      initialRoute: LoginScreen.route,
      routes: {
        LoginScreen.route: (_) => const LoginScreen(),
        DashboardScreen.route: (_) => const DashboardScreen(),
        RecordSaleScreen.route: (_) => const RecordSaleScreen(),
        '/products': (_) => const ComingSoonScreen(
            title: 'Products', tab: AppTab.products),
        '/expenses': (_) => const ComingSoonScreen(title: 'Expenses'),
        '/reports': (_) =>
            const ComingSoonScreen(title: 'Reports', tab: AppTab.reports),
        '/credits': (_) => const ComingSoonScreen(
            title: 'Outstanding Credits', tab: AppTab.credits),
      },
    );
  }
}
