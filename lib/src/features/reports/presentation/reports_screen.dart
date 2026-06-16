import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../customers/data/customers_providers.dart';
import '../../customers/domain/customer.dart';
import '../../expenses/data/expenses_providers.dart';
import '../../expenses/domain/expense.dart';
import '../../products/data/products_providers.dart';
import '../../products/domain/product.dart';
import '../../sales/data/sales_providers.dart';
import '../../sales/domain/sale.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _ReportFilter _filter = _ReportFilter.thisMonth;
  DateTimeRange? _customRange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sales = ref.watch(salesProvider);
    final products = ref.watch(productsProvider);
    final customers = ref.watch(customersProvider);
    final expenses = ref.watch(expensesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(salesProvider);
          ref.invalidate(productsProvider);
          ref.invalidate(customersProvider);
          ref.invalidate(expensesProvider);
          await Future.wait([
            ref.read(salesProvider.future),
            ref.read(productsProvider.future),
            ref.read(customersProvider.future),
            ref.read(expensesProvider.future),
          ]);
        },
        child: sales.when(
          data: (saleItems) {
            return products.when(
              data: (productItems) {
                return customers.when(
                  data: (customerItems) {
                    return expenses.when(
                      data: (expenseItems) {
                        final range = _activeRange();
                        final summary = _buildReportSummary(
                          sales: saleItems,
                          products: productItems,
                          customers: customerItems,
                          expenses: expenseItems,
                          range: range,
                        );

                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Business reports',
                                    style: theme.textTheme.titleLarge,
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: () => _exportCsv(summary),
                                  icon: const Icon(Icons.download),
                                  label: const Text('Export CSV'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _ReportFilters(
                              selectedFilter: _filter,
                              customRange: _customRange,
                              onSelected: _selectFilter,
                            ),
                            const SizedBox(height: 16),
                            _SummaryGrid(
                              metrics: [
                                _SummaryMetric(
                                  label: 'Total Revenue',
                                  value: _money(summary.totalRevenue),
                                ),
                                _SummaryMetric(
                                  label: 'Gross Profit',
                                  value: _money(summary.totalProfit),
                                ),
                                _SummaryMetric(
                                  label: 'Total Expenses',
                                  value: _money(summary.totalExpenses),
                                ),
                                _SummaryMetric(
                                  label: 'Net Profit',
                                  value: _money(summary.netProfit),
                                ),
                                _SummaryMetric(
                                  label: 'Sales Count',
                                  value: summary.totalSalesCount.toString(),
                                ),
                                _SummaryMetric(
                                  label: 'Products Sold',
                                  value: summary.totalProductsSold.toString(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _ReportSectionGrid(
                              children: [
                                _MetricTrendCard(
                                  title: 'Revenue by Day',
                                  points: summary.revenueByDay,
                                  valueLabel: _money,
                                ),
                                _MetricTrendCard(
                                  title: 'Revenue by Week',
                                  points: summary.revenueByWeek,
                                  valueLabel: _money,
                                ),
                                _MetricTrendCard(
                                  title: 'Revenue by Month',
                                  points: summary.revenueByMonth,
                                  valueLabel: _money,
                                ),
                                _MetricTrendCard(
                                  title: 'Profit by Day',
                                  points: summary.profitByDay,
                                  valueLabel: _money,
                                ),
                                _MetricTrendCard(
                                  title: 'Profit by Month',
                                  points: summary.profitByMonth,
                                  valueLabel: _money,
                                ),
                                _MetricTrendCard(
                                  title: 'Expense by Day',
                                  points: summary.expenseByDay,
                                  valueLabel: _money,
                                  emptyText: 'No expenses in this period.',
                                ),
                                _MetricTrendCard(
                                  title: 'Expense by Month',
                                  points: summary.expenseByMonth,
                                  valueLabel: _money,
                                  emptyText: 'No expenses in this period.',
                                ),
                                _MetricTrendCard(
                                  title: 'Expense by Category',
                                  points: summary.expenseByCategory,
                                  valueLabel: _money,
                                  emptyText: 'No expenses in this period.',
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _ReportSectionGrid(
                              children: [
                                _RankedListCard(
                                  title: 'Top Products',
                                  emptyText: 'No product sales in this period.',
                                  rows: [
                                    for (final product in summary.topProducts)
                                      _RankedRowData(
                                        title: product.name,
                                        subtitle:
                                            '${product.quantity} sold - ${_money(product.profit)} profit',
                                        trailing: _money(product.revenue),
                                      ),
                                  ],
                                ),
                                _RankedListCard(
                                  title: 'Top Customers',
                                  emptyText:
                                      'No customer sales in this period.',
                                  rows: [
                                    for (final customer
                                        in summary.topCustomers)
                                      _RankedRowData(
                                        title: customer.name,
                                        subtitle:
                                            '${customer.salesCount} sales - ${customer.quantity} items',
                                        trailing: _money(customer.revenue),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                      error: (error, stackTrace) => _ErrorState(
                        title: 'Unable to load expenses.',
                        message: error.toString(),
                        onRetry: () => ref.invalidate(expensesProvider),
                      ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                    );
                  },
                  error: (error, stackTrace) => _ErrorState(
                    title: 'Unable to load customers.',
                    message: error.toString(),
                    onRetry: () => ref.invalidate(customersProvider),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                );
              },
              error: (error, stackTrace) => _ErrorState(
                title: 'Unable to load products.',
                message: error.toString(),
                onRetry: () => ref.invalidate(productsProvider),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
            );
          },
          error: (error, stackTrace) => _ErrorState(
            title: 'Unable to load sales.',
            message: error.toString(),
            onRetry: () => ref.invalidate(salesProvider),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  DateTimeRange _activeRange() {
    final now = DateTime.now();
    final today = _startOfDay(now);

    switch (_filter) {
      case _ReportFilter.today:
        return DateTimeRange(start: today, end: _endOfDay(today));
      case _ReportFilter.thisWeek:
        final start = today.subtract(Duration(days: today.weekday - 1));
        return DateTimeRange(start: start, end: _endOfDay(now));
      case _ReportFilter.thisMonth:
        final start = DateTime(now.year, now.month);
        return DateTimeRange(start: start, end: _endOfDay(now));
      case _ReportFilter.custom:
        return _customRange ??
            DateTimeRange(start: today, end: _endOfDay(today));
    }
  }

  Future<void> _selectFilter(_ReportFilter filter) async {
    if (filter == _ReportFilter.custom) {
      final now = DateTime.now();
      final selected = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 5),
        lastDate: DateTime(now.year + 1),
        initialDateRange:
            _customRange ??
            DateTimeRange(
              start: DateTime(now.year, now.month),
              end: _endOfDay(now),
            ),
      );
      if (selected == null || !mounted) {
        return;
      }
      setState(() {
        _filter = filter;
        _customRange = DateTimeRange(
          start: _startOfDay(selected.start),
          end: _endOfDay(selected.end),
        );
      });
      return;
    }

    setState(() => _filter = filter);
  }

  Future<void> _exportCsv(_ReportSummary summary) async {
    await Clipboard.setData(ClipboardData(text: _buildCsv(summary)));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV report copied to clipboard.')),
    );
  }
}

class _ReportSummary {
  const _ReportSummary({
    required this.range,
    required this.totalRevenue,
    required this.totalProfit,
    required this.totalExpenses,
    required this.netProfit,
    required this.totalSalesCount,
    required this.totalProductsSold,
    required this.revenueByDay,
    required this.revenueByWeek,
    required this.revenueByMonth,
    required this.profitByDay,
    required this.profitByMonth,
    required this.expenseByDay,
    required this.expenseByMonth,
    required this.expenseByCategory,
    required this.topProducts,
    required this.topCustomers,
  });

  final DateTimeRange range;
  final double totalRevenue;
  final double totalProfit;
  final double totalExpenses;
  final double netProfit;
  final int totalSalesCount;
  final int totalProductsSold;
  final List<_MetricPoint> revenueByDay;
  final List<_MetricPoint> revenueByWeek;
  final List<_MetricPoint> revenueByMonth;
  final List<_MetricPoint> profitByDay;
  final List<_MetricPoint> profitByMonth;
  final List<_MetricPoint> expenseByDay;
  final List<_MetricPoint> expenseByMonth;
  final List<_MetricPoint> expenseByCategory;
  final List<_ProductRank> topProducts;
  final List<_CustomerRank> topCustomers;
}

class _MetricPoint {
  const _MetricPoint({
    required this.label,
    required this.sortDate,
    required this.amount,
  });

  final String label;
  final DateTime sortDate;
  final double amount;
}

class _ProductRank {
  const _ProductRank({
    required this.name,
    required this.quantity,
    required this.revenue,
    required this.profit,
  });

  final String name;
  final int quantity;
  final double revenue;
  final double profit;
}

class _CustomerRank {
  const _CustomerRank({
    required this.name,
    required this.quantity,
    required this.salesCount,
    required this.revenue,
  });

  final String name;
  final int quantity;
  final int salesCount;
  final double revenue;
}

class _MutableRank {
  int quantity = 0;
  int salesCount = 0;
  double revenue = 0;
  double profit = 0;
}

class _SummaryMetric {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;
}

class _RankedRowData {
  const _RankedRowData({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final String trailing;
}

enum _ReportFilter {
  today('Today'),
  thisWeek('This Week'),
  thisMonth('This Month'),
  custom('Custom Date Range');

  const _ReportFilter(this.label);

  final String label;
}

_ReportSummary _buildReportSummary({
  required List<Sale> sales,
  required List<Product> products,
  required List<Customer> customers,
  required List<Expense> expenses,
  required DateTimeRange range,
}) {
  final productsById = {for (final product in products) product.id: product};
  final customersById = {
    for (final customer in customers) customer.id: customer,
  };
  final filteredSales = sales.where((sale) {
    final date = sale.saleDate;
    return date != null &&
        !date.isBefore(range.start) &&
        !date.isAfter(range.end);
  }).toList();
  final filteredExpenses = expenses.where((expense) {
    final date = expense.date;
    return date != null &&
        !date.isBefore(range.start) &&
        !date.isAfter(range.end);
  }).toList();

  final revenueByDay = <DateTime, double>{};
  final revenueByWeek = <DateTime, double>{};
  final revenueByMonth = <DateTime, double>{};
  final profitByDay = <DateTime, double>{};
  final profitByMonth = <DateTime, double>{};
  final expenseByDay = <DateTime, double>{};
  final expenseByMonth = <DateTime, double>{};
  final expenseByCategory = <String, double>{};
  final productRanks = <String, _MutableRank>{};
  final customerRanks = <String, _MutableRank>{};
  var totalRevenue = 0.0;
  var totalProfit = 0.0;
  var totalExpenses = 0.0;
  var totalProductsSold = 0;

  for (final sale in filteredSales) {
    final product = productsById[sale.productId];
    final profit = product == null
        ? 0.0
        : (sale.unitPrice - product.costPrice) * sale.quantity;
    final saleDate = sale.saleDate!;
    final day = _startOfDay(saleDate);
    final week = _startOfWeek(saleDate);
    final month = DateTime(saleDate.year, saleDate.month);

    totalRevenue += sale.totalAmount;
    totalProfit += profit;
    totalProductsSold += sale.quantity;

    _addAmount(revenueByDay, day, sale.totalAmount);
    _addAmount(revenueByWeek, week, sale.totalAmount);
    _addAmount(revenueByMonth, month, sale.totalAmount);
    _addAmount(profitByDay, day, profit);
    _addAmount(profitByMonth, month, profit);

    final productRank = productRanks.putIfAbsent(
      sale.productId,
      _MutableRank.new,
    );
    productRank.quantity += sale.quantity;
    productRank.revenue += sale.totalAmount;
    productRank.profit += profit;

    final customerRank =
        customerRanks.putIfAbsent(sale.customerId, _MutableRank.new);
    customerRank.quantity += sale.quantity;
    customerRank.salesCount += 1;
    customerRank.revenue += sale.totalAmount;
  }

  for (final expense in filteredExpenses) {
    final expenseDate = expense.date!;
    final day = _startOfDay(expenseDate);
    final month = DateTime(expenseDate.year, expenseDate.month);

    totalExpenses += expense.amount;
    _addAmount(expenseByDay, day, expense.amount);
    _addAmount(expenseByMonth, month, expense.amount);
    expenseByCategory.update(
      expense.category,
      (amount) => amount + expense.amount,
      ifAbsent: () => expense.amount,
    );
  }

  final topProducts = productRanks.entries.map((entry) {
    final product = productsById[entry.key];
    final name = product?.name.isNotEmpty == true
        ? product!.name
        : 'Unknown product';
    return _ProductRank(
      name: name,
      quantity: entry.value.quantity,
      revenue: entry.value.revenue,
      profit: entry.value.profit,
    );
  }).toList()
    ..sort((a, b) => b.revenue.compareTo(a.revenue));

  final topCustomers = customerRanks.entries.map((entry) {
    final customer = customersById[entry.key];
    final name = customer?.name.isNotEmpty == true
        ? customer!.name
        : 'Unknown customer';
    return _CustomerRank(
      name: name,
      quantity: entry.value.quantity,
      salesCount: entry.value.salesCount,
      revenue: entry.value.revenue,
    );
  }).toList()
    ..sort((a, b) => b.revenue.compareTo(a.revenue));

  return _ReportSummary(
    range: range,
    totalRevenue: totalRevenue,
    totalProfit: totalProfit,
    totalExpenses: totalExpenses,
    netProfit: totalProfit - totalExpenses,
    totalSalesCount: filteredSales.length,
    totalProductsSold: totalProductsSold,
    revenueByDay: _points(revenueByDay, _shortDate),
    revenueByWeek: _points(revenueByWeek, _weekLabel),
    revenueByMonth: _points(revenueByMonth, _monthLabel),
    profitByDay: _points(profitByDay, _shortDate),
    profitByMonth: _points(profitByMonth, _monthLabel),
    expenseByDay: _points(expenseByDay, _shortDate),
    expenseByMonth: _points(expenseByMonth, _monthLabel),
    expenseByCategory: _categoryPoints(expenseByCategory),
    topProducts: topProducts.take(10).toList(),
    topCustomers: topCustomers.take(10).toList(),
  );
}

void _addAmount(Map<DateTime, double> amounts, DateTime date, double amount) {
  amounts.update(date, (value) => value + amount, ifAbsent: () => amount);
}

List<_MetricPoint> _points(
  Map<DateTime, double> amounts,
  String Function(DateTime date) label,
) {
  final points = amounts.entries
      .map(
        (entry) => _MetricPoint(
          label: label(entry.key),
          sortDate: entry.key,
          amount: entry.value,
        ),
      )
      .toList()
    ..sort((a, b) => a.sortDate.compareTo(b.sortDate));
  return points;
}

List<_MetricPoint> _categoryPoints(Map<String, double> amounts) {
  final points = amounts.entries
      .map(
        (entry) => _MetricPoint(
          label: entry.key,
          sortDate: DateTime(0),
          amount: entry.value,
        ),
      )
      .toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
  return points;
}

class _ReportFilters extends StatelessWidget {
  const _ReportFilters({
    required this.selectedFilter,
    required this.customRange,
    required this.onSelected,
  });

  final _ReportFilter selectedFilter;
  final DateTimeRange? customRange;
  final ValueChanged<_ReportFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final label = customRange == null
        ? _ReportFilter.custom.label
        : '${_shortDate(customRange!.start)} - ${_shortDate(customRange!.end)}';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final filter in _ReportFilter.values)
          ChoiceChip(
            label: Text(filter == _ReportFilter.custom ? label : filter.label),
            selected: selectedFilter == filter,
            onSelected: (_) => onSelected(filter),
          ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.metrics});

  final List<_SummaryMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 640
            ? 3
            : 2;

        return GridView.count(
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: columns >= 3 ? 1.7 : 1.25,
          children: [
            for (final metric in metrics)
              _SummaryCard(label: metric.label, value: metric.value),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value});

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
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportSectionGrid extends StatelessWidget {
  const _ReportSectionGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            children: [
              for (final child in children) ...[
                SizedBox(height: 360, child: child),
                if (child != children.last) const SizedBox(height: 16),
              ],
            ],
          );
        }

        return GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.45,
          children: children,
        );
      },
    );
  }
}

class _MetricTrendCard extends StatelessWidget {
  const _MetricTrendCard({
    required this.title,
    required this.points,
    required this.valueLabel,
    this.emptyText = 'No sales in this period.',
  });

  final String title;
  final List<_MetricPoint> points;
  final String Function(double value) valueLabel;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxAmount = points.fold<double>(
      0,
      (max, point) => point.amount.abs() > max ? point.amount.abs() : max,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            if (points.isEmpty)
              Text(emptyText)
            else
              Expanded(
                child: ListView.separated(
                  itemCount: points.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _MetricTrendRow(
                      point: points[index],
                      maxAmount: maxAmount,
                      valueLabel: valueLabel,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricTrendRow extends StatelessWidget {
  const _MetricTrendRow({
    required this.point,
    required this.maxAmount,
    required this.valueLabel,
  });

  final _MetricPoint point;
  final double maxAmount;
  final String Function(double value) valueLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalized = maxAmount == 0 ? 0.0 : point.amount.abs() / maxAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(point.label)),
            Text(valueLabel(point.amount), style: theme.textTheme.bodyMedium),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: normalized,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: point.amount < 0
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _RankedListCard extends StatelessWidget {
  const _RankedListCard({
    required this.title,
    required this.emptyText,
    required this.rows,
  });

  final String title;
  final String emptyText;
  final List<_RankedRowData> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              Text(emptyText)
            else
              Expanded(
                child: ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 20),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${index + 1}',
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                row.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(row.trailing, style: theme.textTheme.bodyMedium),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(message),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
    );
  }
}

String _buildCsv(_ReportSummary summary) {
  final rows = <List<String>>[
    [
      'Report Range',
      _shortDate(summary.range.start),
      _shortDate(summary.range.end),
    ],
    ['Total Revenue', summary.totalRevenue.toStringAsFixed(2)],
    ['Gross Profit', summary.totalProfit.toStringAsFixed(2)],
    ['Total Expenses', summary.totalExpenses.toStringAsFixed(2)],
    ['Net Profit', summary.netProfit.toStringAsFixed(2)],
    ['Sales Count', summary.totalSalesCount.toString()],
    ['Products Sold', summary.totalProductsSold.toString()],
    [],
    ['Revenue by Day'],
    ['Date', 'Revenue'],
    for (final point in summary.revenueByDay)
      [point.label, point.amount.toStringAsFixed(2)],
    [],
    ['Revenue by Week'],
    ['Week', 'Revenue'],
    for (final point in summary.revenueByWeek)
      [point.label, point.amount.toStringAsFixed(2)],
    [],
    ['Revenue by Month'],
    ['Month', 'Revenue'],
    for (final point in summary.revenueByMonth)
      [point.label, point.amount.toStringAsFixed(2)],
    [],
    ['Profit by Day'],
    ['Date', 'Profit'],
    for (final point in summary.profitByDay)
      [point.label, point.amount.toStringAsFixed(2)],
    [],
    ['Profit by Month'],
    ['Month', 'Profit'],
    for (final point in summary.profitByMonth)
      [point.label, point.amount.toStringAsFixed(2)],
    [],
    ['Expense by Day'],
    ['Date', 'Expense'],
    for (final point in summary.expenseByDay)
      [point.label, point.amount.toStringAsFixed(2)],
    [],
    ['Expense by Month'],
    ['Month', 'Expense'],
    for (final point in summary.expenseByMonth)
      [point.label, point.amount.toStringAsFixed(2)],
    [],
    ['Expense by Category'],
    ['Category', 'Expense'],
    for (final point in summary.expenseByCategory)
      [point.label, point.amount.toStringAsFixed(2)],
    [],
    ['Top Products'],
    ['Product', 'Quantity', 'Revenue', 'Profit'],
    for (final product in summary.topProducts)
      [
        product.name,
        product.quantity.toString(),
        product.revenue.toStringAsFixed(2),
        product.profit.toStringAsFixed(2),
      ],
    [],
    ['Top Customers'],
    ['Customer', 'Sales Count', 'Quantity', 'Revenue'],
    for (final customer in summary.topCustomers)
      [
        customer.name,
        customer.salesCount.toString(),
        customer.quantity.toString(),
        customer.revenue.toStringAsFixed(2),
      ],
  ];

  return rows.map(_csvRow).join('\n');
}

String _csvRow(List<String> values) {
  return values.map((value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }).join(',');
}

DateTime _startOfDay(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

DateTime _endOfDay(DateTime date) {
  return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
}

DateTime _startOfWeek(DateTime date) {
  final day = _startOfDay(date);
  return day.subtract(Duration(days: day.weekday - 1));
}

String _shortDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}

String _weekLabel(DateTime date) {
  final end = date.add(const Duration(days: 6));
  return '${_shortDate(date)} - ${_shortDate(end)}';
}

String _monthLabel(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

String _money(double value) {
  final sign = value < 0 ? '-' : '';
  final amount = value.abs().toStringAsFixed(2);
  final parts = amount.split('.');
  final naira = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
  return '$sign\u20A6$naira.${parts.last}';
}
