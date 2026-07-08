import 'package:flutter/material.dart';

import '../theme/tokens.dart';

enum AppTab { home, products, reports, credits }

/// Tab bar per the component inventory: 64px, white, 1px top border #ECECEC;
/// 4 tabs (Home, Products, Reports, Credits); active = primary, inactive #999.
///
/// [active] is null on non-tab screens (e.g. Record Sale) where the bar is
/// visible but no destination is highlighted.
class AppTabBar extends StatelessWidget {
  const AppTabBar({super.key, this.active});

  final AppTab? active;

  static const _tabs = [
    (AppTab.home, Icons.home_rounded, 'Home', '/dashboard'),
    (AppTab.products, Icons.inventory_2_rounded, 'Products', '/products'),
    (AppTab.reports, Icons.bar_chart_rounded, 'Reports', '/reports'),
    (AppTab.credits, Icons.receipt_long_rounded, 'Credits', '/credits'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final (tab, icon, label, route) in _tabs)
                  InkWell(
                    onTap: tab == active
                        ? null
                        : () =>
                            Navigator.of(context).pushReplacementNamed(route),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon,
                            size: 22,
                            color: tab == active
                                ? AppColors.primary
                                : AppColors.placeholder),
                        const SizedBox(height: 3),
                        Text(
                          label,
                          style: AppText.style(
                            FontWeight.w600,
                            10,
                            tab == active
                                ? AppColors.primary
                                : AppColors.placeholder,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
