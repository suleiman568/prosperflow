import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../widgets/app_tab_bar.dart';

/// Temporary stand-in for screens not yet built in the screen-by-screen
/// plan. Replaced one by one as each screen is implemented and approved.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title, this.tab});

  final String title;

  /// When set, this screen is a tab destination and shows the tab bar.
  final AppTab? tab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.divider)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      final navigator = Navigator.of(context);
                      if (navigator.canPop()) {
                        navigator.pop();
                      } else {
                        navigator.pushReplacementNamed('/dashboard');
                      }
                    },
                    child: const Icon(Icons.arrow_back,
                        size: 20, color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 12),
                  Text(title, style: AppText.screenTitle),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '$title — coming next',
                  style: AppText.style(
                      FontWeight.w700, 15, AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: tab == null ? null : AppTabBar(active: tab!),
    );
  }
}
