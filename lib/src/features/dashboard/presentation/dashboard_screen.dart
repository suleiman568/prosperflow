import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dashboard_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(dashboardSummaryProvider.future),
        child: summary.when(
          data: (data) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Business overview', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              _MetricGrid(
                metrics: [
                  _Metric(label: 'Total Revenue', value: _money(data.totalRevenue)),
                  _Metric(
                    label: 'Total Customers',
                    value: data.totalCustomers.toString(),
                  ),
                  _Metric(
                    label: 'Total Products',
                    value: data.totalProducts.toString(),
                  ),
                  _Metric(label: 'Total Sales', value: _money(data.totalSales)),
                  _Metric(
                    label: 'Cost of Goods',
                    value: _money(data.costOfGoods),
                  ),
                  _Metric(
                    label: 'Total Expenses',
                    value: _money(data.totalExpenses),
                  ),
                  _Metric(
                    label: 'Low Stock Products',
                    value: data.lowStockProducts.toString(),
                  ),
                  _Metric(label: 'Tasks', value: '${data.openTasks} open'),
                  _Metric(
                    label: 'Today\'s Net Profit',
                    value: _money(data.todayProfit),
                  ),
                  _Metric(
                    label: 'Monthly Net Profit',
                    value: _money(data.monthlyProfit),
                  ),
                  _Metric(label: 'Net Profit', value: _money(data.totalProfit)),
                ],
              ),
              const SizedBox(height: 24),
              _RevenueChart(points: data.revenueChart),
            ],
          ),
          error: (error, stackTrace) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Unable to load dashboard data.', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(error.toString(), style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: () => ref.invalidate(dashboardSummaryProvider),
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.points});

  final List<RevenueChartPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Revenue Chart', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: CustomPaint(
                painter: _RevenueChartPainter(
                  points: points,
                  barColor: theme.colorScheme.primary,
                  gridColor: theme.colorScheme.outlineVariant,
                  labelColor: theme.colorScheme.onSurfaceVariant,
                ),
                size: Size.infinite,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueChartPainter extends CustomPainter {
  const _RevenueChartPainter({
    required this.points,
    required this.barColor,
    required this.gridColor,
    required this.labelColor,
  });

  final List<RevenueChartPoint> points;
  final Color barColor;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 8.0;
    const bottomPadding = 28.0;
    const topPadding = 8.0;
    final chartHeight = size.height - bottomPadding - topPadding;
    final chartWidth = size.width - leftPadding;
    final maxAmount = points.fold<double>(
      0,
      (max, point) => point.amount > max ? point.amount : max,
    );

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index < 4; index++) {
      final y = topPadding + chartHeight * index / 3;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    if (points.isEmpty) {
      return;
    }

    final slotWidth = chartWidth / points.length;
    final barWidth = slotWidth * 0.54;
    final barPaint = Paint()..color = barColor;
    final textStyle = TextStyle(color: labelColor, fontSize: 12);

    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final normalized = maxAmount == 0 ? 0.0 : point.amount / maxAmount;
      final barHeight = chartHeight * normalized;
      final x = leftPadding + slotWidth * index + (slotWidth - barWidth) / 2;
      final y = topPadding + chartHeight - barHeight;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, barPaint);

      final label = TextPainter(
        text: TextSpan(text: point.label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: slotWidth);
      label.paint(
        canvas,
        Offset(
          leftPadding + slotWidth * index + (slotWidth - label.width) / 2,
          size.height - bottomPadding + 8,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RevenueChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.barColor != barColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor;
  }
}

class _Metric {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 4 : 2;

        return GridView.count(
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: columns == 4 ? 1.7 : 1.25,
          children: [
            for (final metric in metrics)
              _MetricCard(label: metric.label, value: metric.value),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            Text(value, style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

String _money(double value) {
  final sign = value < 0 ? '-' : '';
  return '$sign\u20A6${value.abs().toStringAsFixed(2)}';
}
