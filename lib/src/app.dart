import 'package:flutter/material.dart';

import 'screens/dashboard/dashboard_screen.dart';
import 'screens/login/login_screen.dart';
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
      initialRoute: LoginScreen.route,
      routes: {
        LoginScreen.route: (_) => const LoginScreen(),
        DashboardScreen.route: (_) => const DashboardScreen(),
      },
    );
  }
}
