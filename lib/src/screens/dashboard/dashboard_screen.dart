import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Screen 2 — Dashboard. Placeholder until the Login screen is confirmed;
/// built next per the screen-by-screen plan.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const route = '/dashboard';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: Center(
        child: Text(
          'Dashboard — coming next',
          style: AppText.style(FontWeight.w700, 15, AppColors.textSecondary),
        ),
      ),
    );
  }
}
