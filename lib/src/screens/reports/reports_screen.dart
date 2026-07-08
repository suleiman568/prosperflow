import 'package:flutter/material.dart';

import '../../data/demo_data.dart';
import '../../theme/tokens.dart';
import '../../utils/naira.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_tab_bar.dart';

enum ReportPeriod { week, month, all }

/// Screen 6 — Reports.
///
/// Week/Month/All pill selector; hero profit card (green gradient +
/// encouraging message if ≥ 0, red gradient + warning if loss); Sales vs
/// Expenses cards; Top Products bars; Payment Breakdown bars.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  static const route = '/reports';

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.week;

  /// Scaling factors from the design prototype: a week of demo data
  /// extrapolated to the longer periods.
  static const _factors = {
    ReportPeriod.week: 1.0,
    ReportPeriod.month: 4.3,
    ReportPeriod.all: 13.0,
  };

  double get _factor => _factors[_period]!;

  String get _periodWord => switch (_period) {
        ReportPeriod.week => 'week',
        ReportPeriod.month => 'month',
        ReportPeriod.all => 'run',
      };

  @override
  Widget build(BuildContext context) {
    final weekExpenses = demoExpenses.fold(0, (sum, e) => sum + e.amount);
    final sales = (demoWeekSalesTotal * _factor).round();
    final expenses = (weekExpenses * _factor).round();
    final profit = sales - expenses;
    final salesCount = (demoWeekSalesCount * _factor).round();
    final expensesCount = (demoExpenses.length * 3 * _factor).round();

    const payTotal = demoPayCash + demoPayTransfer + demoPayPos + demoPayCredit;
    final payRows = [
      (Icons.payments_rounded, 'Cash', AppColors.primary, AppColors.mintTint,
          demoPayCash),
      (
        Icons.account_balance_rounded,
        'Transfer',
        AppColors.accentBlue,
        AppColors.blueTint,
        demoPayTransfer
      ),
      (
        Icons.credit_card_rounded,
        'POS',
        AppColors.accentPurple,
        AppColors.purpleTint,
        demoPayPos
      ),
      (
        Icons.schedule_rounded,
        'Credit',
        AppColors.accentOrange,
        AppColors.orangeTint,
        demoPayCredit
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                children: [
                  Row(
                    children: [
                      for (final period in ReportPeriod.values) ...[
                        _PeriodPill(
                          label: switch (period) {
                            ReportPeriod.week => 'Week',
                            ReportPeriod.month => 'Month',
                            ReportPeriod.all => 'All',
                          },
                          selected: _period == period,
                          onTap: () => setState(() => _period = period),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppShape.cardGap),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppShape.cardRadius),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: profit >= 0
                            ? const [AppColors.primary, AppColors.primaryDark]
                            : const [AppColors.accentRed, Color(0xFFB71C1C)],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profit >= 0 ? 'NET PROFIT' : 'NET LOSS',
                          style: AppText.style(FontWeight.w700, 11,
                              Colors.white.withValues(alpha: 0.9)),
                        ),
                        const SizedBox(height: 4),
                        Text(formatNaira(profit.abs()),
                            style: AppText.moneyHero),
                        const SizedBox(height: 6),
                        Text(
                          profit >= 0
                              ? "📈 You're on track! Great $_periodWord."
                              : '⚠ Spending more than you earn.',
                          style: AppText.style(FontWeight.w600, 12,
                              Colors.white.withValues(alpha: 0.85)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppShape.cardGap),
                  Row(
                    children: [
                      Expanded(
                        child: _TotalsCard(
                          label: 'SALES',
                          labelColor: AppColors.primary,
                          amount: sales,
                          caption: '$salesCount transactions',
                        ),
                      ),
                      const SizedBox(width: AppShape.gridGap),
                      Expanded(
                        child: _TotalsCard(
                          label: 'EXPENSES',
                          labelColor: AppColors.accentRed,
                          amount: expenses,
                          caption: '$expensesCount items',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppShape.cardGap),
                  Text(
                    'Top Products',
                    style: AppText.style(
                        FontWeight.w800, 13, AppColors.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  const _TopProductCard(
                      name: 'Palm Oil (25L)', fraction: 0.68),
                  const SizedBox(height: 8),
                  const _TopProductCard(
                      name: 'Yam (per tuber)', fraction: 0.22),
                  const SizedBox(height: AppShape.cardGap),
                  Text(
                    'Payment Breakdown',
                    style: AppText.style(
                        FontWeight.w800, 13, AppColors.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  for (final (icon, label, color, tint, amount) in payRows) ...[
                    _PaymentRowCard(
                      icon: icon,
                      label: label,
                      color: color,
                      tint: tint,
                      amount: (amount * _factor).round(),
                      fraction: amount / payTotal,
                    ),
                    if (label != 'Credit') const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppTabBar(active: AppTab.reports),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text('Reports', style: AppText.screenTitle),
        ],
      ),
    );
  }
}

class _PeriodPill extends StatelessWidget {
  const _PeriodPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.inputBg,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: AppText.style(
            FontWeight.w700,
            13,
            selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.label,
    required this.labelColor,
    required this.amount,
    required this.caption,
  });

  final String label;
  final Color labelColor;
  final int amount;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.style(FontWeight.w700, 11, labelColor)),
          const SizedBox(height: 4),
          Text(
            formatNaira(amount),
            style: AppText.style(FontWeight.w800, 20, AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: AppText.style(FontWeight.w600, 11, AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Progress bar per the component inventory: 8px tall, 4px radius,
/// tint track, solid colored fill.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.fraction,
    required this.color,
    required this.tint,
  });

  final double fraction;
  final Color color;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Stack(
          children: [
            Container(color: tint),
            FractionallySizedBox(
              widthFactor: fraction.clamp(0, 1),
              child: Container(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopProductCard extends StatelessWidget {
  const _TopProductCard({required this.name, required this.fraction});

  final String name;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: AppText.style(FontWeight.w700, 12, AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          _ProgressBar(
            fraction: fraction,
            color: AppColors.primary,
            tint: AppColors.mintTint,
          ),
          const SizedBox(height: 4),
          Text(
            '${(fraction * 100).round()}% of sales',
            style: AppText.style(FontWeight.w600, 10, AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _PaymentRowCard extends StatelessWidget {
  const _PaymentRowCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.tint,
    required this.amount,
    required this.fraction,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color tint;
  final int amount;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 5),
                  Text(label, style: AppText.style(FontWeight.w700, 12, color)),
                ],
              ),
              Text(
                formatNaira(amount),
                style:
                    AppText.style(FontWeight.w700, 12, AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _ProgressBar(fraction: fraction, color: color, tint: tint),
        ],
      ),
    );
  }
}
