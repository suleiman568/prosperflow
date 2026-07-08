import 'package:flutter/material.dart';

import '../../data/demo_data.dart';
import '../../theme/tokens.dart';
import '../../utils/naira.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_tab_bar.dart';
import '../login/login_screen.dart';

/// Screen 2 — Dashboard.
///
/// Greeting + date; Today's Sales (green) and This Week (blue) stat cards;
/// Low Stock alert (only when any product ≤ 10 units); sync status row;
/// 2×2 Quick Actions; Outstanding Credits banner (only when credits exist,
/// taps through to Credits).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const route = '/dashboard';

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
    'Sunday', //
  ];
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
    'September', 'October', 'November', 'December', //
  ];

  /// "Tuesday, 7 July 2026" — the handoff's date format.
  static String _formatDate(DateTime d) =>
      '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final lowStock = demoProducts.where((p) => p.isLow).toList();
    final creditTotal =
        demoCredits.fold(0, (sum, credit) => sum + credit.amount);

    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: SafeArea(
        child: Column(
          children: [
            _AppBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                children: [
                  Text(
                    'Welcome back, Prosper 👋',
                    style: AppText.style(
                        FontWeight.w800, 19, AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(DateTime.now()),
                    style: AppText.style(
                        FontWeight.w500, 13, AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppShape.cardGap),
                  const Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.trending_up_rounded,
                          label: "Today's Sales",
                          color: AppColors.primary,
                          tint: AppColors.mintTint,
                          amount: demoTodaySalesTotal,
                          caption: '$demoTodaySalesCount sales today',
                        ),
                      ),
                      SizedBox(width: AppShape.gridGap),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.calendar_today_rounded,
                          label: 'This Week',
                          color: AppColors.accentBlue,
                          tint: AppColors.blueTint,
                          amount: demoWeekSalesTotal,
                          caption: '$demoWeekSalesCount sales',
                        ),
                      ),
                    ],
                  ),
                  if (lowStock.isNotEmpty) ...[
                    const SizedBox(height: AppShape.cardGap),
                    AppCard.tinted(
                      color: AppColors.orangeTint,
                      borderColor: AppColors.orangeBorder,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  size: 16, color: AppColors.accentOrange),
                              const SizedBox(width: 8),
                              Text(
                                'Low Stock Alert',
                                style: AppText.style(FontWeight.w800, 13,
                                    AppColors.accentOrange),
                              ),
                            ],
                          ),
                          for (final product in lowStock) ...[
                            const SizedBox(height: 8),
                            Text(
                              product.lowStockLine,
                              style: AppText.style(
                                  FontWeight.w600, 13, AppColors.textPrimary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppShape.cardGap),
                  AppCard.tinted(
                    color: AppColors.mintTint,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    onTap: () {},
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '✅ Backed up 2 min ago',
                          style: AppText.style(
                              FontWeight.w700, 12, AppColors.primary),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.sync_rounded,
                                size: 13, color: AppColors.primary),
                            const SizedBox(width: 3),
                            Text(
                              'sync',
                              style: AppText.style(
                                  FontWeight.w600, 11, AppColors.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppShape.cardGap),
                  Text(
                    'Quick Actions',
                    style: AppText.style(
                        FontWeight.w800, 15, AppColors.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: AppShape.gridGap,
                    crossAxisSpacing: AppShape.gridGap,
                    childAspectRatio: 169 / 105,
                    children: [
                      _QuickAction(
                        icon: Icons.shopping_cart_rounded,
                        tint: AppColors.mintTint,
                        iconColor: AppColors.primary,
                        label: 'Record Sale',
                        route: '/record-sale',
                      ),
                      _QuickAction(
                        icon: Icons.inventory_2_rounded,
                        tint: AppColors.blueTint,
                        iconColor: AppColors.accentBlue,
                        label: 'Products',
                        route: '/products',
                      ),
                      _QuickAction(
                        icon: Icons.payments_rounded,
                        tint: AppColors.redTint,
                        iconColor: AppColors.accentRed,
                        label: 'Expenses',
                        route: '/expenses',
                      ),
                      _QuickAction(
                        icon: Icons.bar_chart_rounded,
                        tint: AppColors.purpleTint,
                        iconColor: AppColors.accentPurple,
                        label: 'Reports',
                        route: '/reports',
                      ),
                    ],
                  ),
                  if (demoCredits.isNotEmpty) ...[
                    const SizedBox(height: AppShape.cardGap),
                    AppCard.tinted(
                      color: AppColors.orangeTint,
                      borderColor: AppColors.orangeBorder,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      onTap: () => Navigator.of(context).pushNamed('/credits'),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'OUTSTANDING CREDITS',
                                style: AppText.style(FontWeight.w700, 12,
                                    AppColors.accentOrange),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatNaira(creditTotal),
                                style: AppText.style(FontWeight.w800, 18,
                                    AppColors.accentOrange),
                              ),
                            ],
                          ),
                          Text(
                            '${demoCredits.length} customers →',
                            style: AppText.style(
                                FontWeight.w600, 12, AppColors.accentOrange),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppTabBar(active: AppTab.home),
    );
  }
}

class _AppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'ProsperFlow',
            style: AppText.style(FontWeight.w800, 18, AppColors.textPrimary),
          ),
          Row(
            children: [
              _CircleIconButton(icon: Icons.sync_rounded, onTap: () {}),
              const SizedBox(width: 14),
              _CircleIconButton(
                icon: Icons.power_settings_new_rounded,
                onTap: () => Navigator.of(context)
                    .pushReplacementNamed(LoginScreen.route),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.inputBg,
        ),
        child: Icon(icon, size: 16, color: AppColors.textPrimary),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.tint,
    required this.amount,
    required this.caption,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color tint;
  final int amount;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(shape: BoxShape.circle, color: tint),
                child: Icon(icon, size: 12, color: color),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: AppText.style(FontWeight.w700, 12, color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            formatNaira(amount),
            style: AppText.style(FontWeight.w900, 24, AppColors.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(caption, style: AppText.style(FontWeight.w600, 11, color)),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final Color tint;
  final Color iconColor;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      onTap: () => Navigator.of(context).pushNamed(route),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(shape: BoxShape.circle, color: tint),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          Text(
            label,
            style: AppText.style(FontWeight.w700, 13, AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
