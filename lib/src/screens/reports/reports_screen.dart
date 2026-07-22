import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../data/app_scope.dart';
import '../../data/data_store.dart';
import '../../data/models.dart';
import '../../export/csv_export.dart';
import '../../export/pdf_export.dart';
import '../../export/share_export.dart';
import '../../theme/tokens.dart';
import '../../utils/dates.dart';
import '../../utils/naira.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_tab_bar.dart';
import '../../widgets/header_back_button.dart';
import '../../widgets/app_toast.dart';

/// Screen 6 — Reports.
///
/// Week/Month/All pill selector; hero profit card (green gradient +
/// encouraging message if ≥ 0, red gradient + warning if loss); Sales vs
/// Expenses cards; Top Products bars; Payment Breakdown bars. Aggregates
/// are computed live from the local store for the selected period.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  static const route = '/reports';

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.week;

  String get _periodWord => switch (_period) {
    ReportPeriod.week => 'week',
    ReportPeriod.month => 'month',
    ReportPeriod.all => 'run',
  };

  static const _paymentSpecs = {
    PaymentMethod.cash: (
      Icons.payments_rounded,
      'Cash',
      AppColors.primary,
      AppColors.mintTint,
    ),
    PaymentMethod.transfer: (
      Icons.account_balance_rounded,
      'Transfer',
      AppColors.accentBlue,
      AppColors.blueTint,
    ),
    PaymentMethod.pos: (
      Icons.credit_card_rounded,
      'POS',
      AppColors.accentPurple,
      AppColors.purpleTint,
    ),
    PaymentMethod.credit: (
      Icons.schedule_rounded,
      'Credit',
      AppColors.accentOrange,
      AppColors.orangeTint,
    ),
  };

  void _openExportSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text('Export report', style: AppText.screenTitle),
            ),
            ListTile(
              leading: const Icon(
                Icons.picture_as_pdf_rounded,
                color: AppColors.accentRed,
              ),
              title: Text(
                'PDF report',
                style: AppText.style(
                  FontWeight.w700,
                  14,
                  AppColors.textPrimary,
                ),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _export(pdf: true);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.table_chart_rounded,
                color: AppColors.primary,
              ),
              title: Text(
                'CSV spreadsheet',
                style: AppText.style(
                  FontWeight.w700,
                  14,
                  AppColors.textPrimary,
                ),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _export(pdf: false);
              },
            ),
            const SizedBox(height: AppShape.gapSm),
          ],
        ),
      ),
    );
  }

  Future<void> _export({required bool pdf}) async {
    final store = AppScope.of(context);
    try {
      final bundle = await store.exportBundle(_period);
      final d = bundle.generatedAt;
      final stamp =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      final name = 'prosperflow-${_period.name}-$stamp';

      if (pdf) {
        final bytes = await buildReportPdf(
          bundle,
          regularFont: await rootBundle.load('assets/fonts/Inter-Regular.ttf'),
          boldFont: await rootBundle.load('assets/fonts/Inter-Bold.ttf'),
        );
        await shareExportFile(bytes, '$name.pdf', 'application/pdf');
      } else {
        // UTF-8 BOM so Excel renders the ₦ signs correctly.
        final bytes = Uint8List.fromList([
          0xEF,
          0xBB,
          0xBF,
          ...utf8.encode(buildReportCsv(bundle)),
        ]);
        await shareExportFile(bytes, '$name.csv', 'text/csv');
      }
      if (!mounted) return;
      showAppToast(context, '✅ ${bundle.periodLabel} report exported');
    } catch (error, stack) {
      // Surface the failure instead of swallowing it (same pattern as the
      // product edit sheet): log for diagnosis, toast for the user.
      debugPrint('Report export failed: $error\n$stack');
      if (!mounted) return;
      showAppToast(context, '⚠ Export failed — please try again');
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onExport: _openExportSheet),
            Expanded(
              child: StreamBuilder<ReportData>(
                stream: store.watchReport(_period),
                builder: (context, snapshot) {
                  final report = snapshot.data;
                  if (report == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return _buildReport(report);
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppTabBar(active: AppTab.reports),
    );
  }

  Widget _buildReport(ReportData report) {
    final profit = report.profit;
    final paymentTotal = report.paymentBuckets.fold(
      0,
      (sum, bucket) => sum + bucket.amount,
    );

    return ListView(
      padding: AppShape.screenBody,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppShape.cardRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: profit >= 0
                  ? const [AppColors.primary, AppColors.primaryDark]
                  : const [AppColors.accentRed, AppColors.lossRed],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profit >= 0 ? 'NET PROFIT' : 'NET LOSS',
                style: AppText.style(
                  FontWeight.w700,
                  11,
                  Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: AppShape.gapXs),
              Text(formatNaira(profit.abs()), style: AppText.moneyHero),
              const SizedBox(height: 6),
              Text(
                profit >= 0
                    ? "📈 You're on track! Great $_periodWord."
                    : '⚠ Spending more than you earn.',
                style: AppText.style(
                  FontWeight.w600,
                  12,
                  Colors.white.withValues(alpha: 0.85),
                ),
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
                amount: report.salesTotal,
                caption: '${report.salesCount} transactions',
              ),
            ),
            const SizedBox(width: AppShape.gridGap),
            Expanded(
              child: _TotalsCard(
                label: 'EXPENSES',
                labelColor: AppColors.accentRed,
                amount: report.expensesTotal,
                caption: '${report.expensesCount} items',
              ),
            ),
          ],
        ),
        if (report.topProducts.isNotEmpty) ...[
          const SizedBox(height: AppShape.cardGap),
          Text('Top Products', style: AppText.sectionHeading),
          const SizedBox(height: 10),
          for (final (index, top) in report.topProducts.indexed) ...[
            if (index > 0) const SizedBox(height: AppShape.gapSm),
            _TopProductCard(name: top.name, fraction: top.share),
          ],
        ],
        const SizedBox(height: AppShape.cardGap),
        Text('Payment Breakdown', style: AppText.sectionHeading),
        const SizedBox(height: 10),
        for (final (index, bucket) in report.paymentBuckets.indexed) ...[
          if (index > 0) const SizedBox(height: AppShape.gapSm),
          Builder(
            builder: (context) {
              final (icon, label, color, tint) = _paymentSpecs[bucket.method]!;
              return _PaymentRowCard(
                icon: icon,
                label: label,
                color: color,
                tint: tint,
                amount: bucket.amount,
                fraction: paymentTotal == 0 ? 0 : bucket.amount / paymentTotal,
              );
            },
          ),
        ],
        const SizedBox(height: AppShape.cardGap),
        Text('Sales History for Today', style: AppText.sectionHeading),
        const SizedBox(height: 10),
        const _SalesHistorySection(),
      ],
    );
  }
}

String _methodLabel(SaleHistoryEntry entry) {
  if (entry.method == PaymentMethod.credit) {
    return entry.collected ? 'Credit → Collected' : 'Credit';
  }
  return switch (entry.method) {
    PaymentMethod.cash => 'Cash',
    PaymentMethod.transfer => 'Transfer',
    PaymentMethod.pos => 'POS',
    PaymentMethod.credit => 'Credit',
  };
}

/// "+₦4,800" / "-₦300" / "—" (no recorded cost).
String _profitText(int? profit) {
  if (profit == null) return '—';
  final sign = profit < 0 ? '-' : '+';
  return '$sign${formatNaira(profit.abs())}';
}

/// Green for profit, red for a loss, muted for unknown ("—").
Color _profitColor(int? profit) {
  if (profit == null) return AppColors.textSecondary;
  return profit < 0 ? AppColors.accentRed : AppColors.primary;
}

/// Today's sales grouped per product, expandable into individual sales.
/// Fed by its own stream so it updates live and independently of the
/// Week/Month/All period selector — "today" is always today.
class _SalesHistorySection extends StatefulWidget {
  const _SalesHistorySection();

  @override
  State<_SalesHistorySection> createState() => _SalesHistorySectionState();
}

class _SalesHistorySectionState extends State<_SalesHistorySection> {
  final _expanded = <String>{};

  DataStore? _store;
  Stream<TodayHistory>? _history;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache the stream: recreating it on every setState (expand/collapse)
    // would make the StreamBuilder resubscribe and blank the section for a
    // frame while it waits for the first emission.
    final store = AppScope.of(context);
    if (!identical(store, _store)) {
      _store = store;
      _history = store.watchTodayHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TodayHistory>(
      stream: _history,
      builder: (context, snapshot) {
        final history = snapshot.data;
        if (history == null) return const SizedBox.shrink();
        if (history.isEmpty) {
          return AppCard(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text(
                '🌅 No sales recorded yet today',
                style: AppText.style(
                  FontWeight.w600,
                  13,
                  AppColors.textSecondary,
                ),
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DaySummaryCard(history: history),
            for (final group in history.groups) ...[
              const SizedBox(height: AppShape.gapSm),
              _ProductGroupCard(
                group: group,
                expanded: _expanded.contains(group.productId),
                onTap: () => setState(() {
                  _expanded.contains(group.productId)
                      ? _expanded.remove(group.productId)
                      : _expanded.add(group.productId);
                }),
              ),
            ],
            if (history.missingCostCount > 0) ...[
              const SizedBox(height: 6),
              Text(
                '* profit excludes ${history.missingCostCount} '
                'sale${history.missingCostCount == 1 ? '' : 's'} recorded '
                'before cost tracking',
                style: AppText.style(
                  FontWeight.w600,
                  10,
                  AppColors.textSecondary,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _DaySummaryCard extends StatelessWidget {
  const _DaySummaryCard({required this.history});

  final TodayHistory history;

  @override
  Widget build(BuildContext context) {
    return AppCard.tinted(
      color: AppColors.mintTint,
      borderColor: AppColors.primary,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "TODAY'S REVENUE",
                  style: AppText.style(FontWeight.w700, 11, AppColors.primary),
                ),
                const SizedBox(height: AppShape.gapXs),
                Text(
                  formatNaira(history.revenue),
                  style: AppText.style(
                    FontWeight.w900,
                    20,
                    AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PROFIT',
                  style: AppText.style(FontWeight.w700, 11, AppColors.primary),
                ),
                const SizedBox(height: AppShape.gapXs),
                Text(
                  history.profit == null
                      ? '—'
                      : '${_profitText(history.profit)}'
                            '${history.missingCostCount > 0 ? '*' : ''}',
                  style: AppText.style(
                    FontWeight.w900,
                    20,
                    _profitColor(history.profit),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductGroupCard extends StatelessWidget {
  const _ProductGroupCard({
    required this.group,
    required this.expanded,
    required this.onTap,
  });

  final ProductSalesGroup group;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.productName,
                          style: AppText.listTitle,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${group.qty} sold · '
                          '${group.entries.length} '
                          'sale${group.entries.length == 1 ? '' : 's'}',
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatNaira(group.revenue),
                        style: AppText.sectionHeading,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        group.profit == null
                            ? '— profit'
                            : '${_profitText(group.profit)}'
                                  '${group.profitIsPartial ? '*' : ''} profit',
                        style: AppText.style(
                          FontWeight.w700,
                          11,
                          _profitColor(group.profit),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Smoothly grows/shrinks instead of snapping open (batch item 4).
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: !expanded
                ? const SizedBox(width: double.infinity)
                : Column(
                    children: [
                      const Divider(height: 1, color: AppColors.divider),
                      for (final entry in group.entries)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            '${entry.qty} × '
                                            '${formatNaira(entry.unitPrice)}',
                                            overflow: TextOverflow.ellipsis,
                                            style: AppText.style(
                                              FontWeight.w700,
                                              12,
                                              AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        if (entry.discounted) ...[
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              formatNaira(entry.listPrice!),
                                              overflow: TextOverflow.ellipsis,
                                              style: AppText.caption.copyWith(
                                                decoration:
                                                    TextDecoration.lineThrough,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${formatTime(entry.soldAt)} · '
                                      '${_methodLabel(entry)}'
                                      '${entry.discounted ? ' · discounted' : ''}',
                                      style: AppText.caption,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _profitText(entry.profit),
                                style: AppText.style(
                                  FontWeight.w700,
                                  12,
                                  _profitColor(entry.profit),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onExport});

  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 4, 20, 4),
      child: Row(
        children: [
          const HeaderBackButton(),
          Text('Reports', style: AppText.screenTitle),
          const Spacer(),
          IconButton(
            tooltip: 'Export report',
            onPressed: onExport,
            icon: const Icon(
              Icons.ios_share_rounded,
              size: 20,
              color: AppColors.textPrimary,
            ),
          ),
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
          const SizedBox(height: AppShape.gapXs),
          Text(formatNaira(amount), style: AppText.statValue),
          const SizedBox(height: AppShape.gapXs),
          Text(caption, style: AppText.caption),
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
          const SizedBox(height: AppShape.gapXs),
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
                style: AppText.style(
                  FontWeight.w700,
                  12,
                  AppColors.textPrimary,
                ),
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
