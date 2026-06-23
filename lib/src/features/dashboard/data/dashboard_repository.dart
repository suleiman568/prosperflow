import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';

import '../../../core/offline/local_database.dart';

class DashboardRepository {
  const DashboardRepository(this._database);

  final AppDatabase _database;

  Future<DashboardSummary> fetchLocalSummary() async {
    debugPrint('DASHBOARD_LOCAL_START');
    try {
      final summary = await _buildLocalSummary();
      debugPrint('DASHBOARD_LOCAL_DONE');
      return summary;
    } catch (error) {
      debugPrint('DASHBOARD_LOCAL_ERROR $error');
      return DashboardSummary.empty();
    }
  }

  Future<DashboardSummary> _buildLocalSummary() async {
    final now = DateTime.now();
    final totalCustomers = await _fetchInt('''
SELECT COUNT(*) AS value
FROM customers
WHERE is_deleted = 0
''');
    final totalProducts = await _fetchInt('''
SELECT COUNT(*) AS value
FROM products
WHERE is_deleted = 0
''');
    final lowStockProducts = await _fetchInt('''
SELECT COUNT(*) AS value
FROM products
WHERE is_deleted = 0
  AND stock_quantity <= reorder_level
''');
    final totalExpenses = await _fetchDouble('''
SELECT COALESCE(SUM(amount), 0) AS value
FROM expenses
WHERE is_deleted = 0
''');
    final todayExpenses = await _fetchDouble(
      '''
SELECT COALESCE(SUM(amount), 0) AS value
FROM expenses
WHERE is_deleted = 0
  AND date >= ?
  AND date < ?
''',
      [
        Variable.withString(_startOfDay(now).toIso8601String()),
        Variable.withString(
          _startOfDay(now).add(const Duration(days: 1)).toIso8601String(),
        ),
      ],
    );
    final monthlyExpenses = await _fetchDouble(
      '''
SELECT COALESCE(SUM(amount), 0) AS value
FROM expenses
WHERE is_deleted = 0
  AND date >= ?
  AND date < ?
''',
      [
        Variable.withString(_startOfMonth(now).toIso8601String()),
        Variable.withString(_nextMonth(now).toIso8601String()),
      ],
    );
    final openTasks = await _fetchInt('''
SELECT COUNT(*) AS value
FROM tasks
WHERE is_deleted = 0
  AND status NOT IN ('done', 'completed')
''');
    final sales = await _fetchSales();
    final productsById = await _fetchProductsById();

    final totalRevenue = sales.fold<double>(
      0,
      (total, sale) => total + sale.totalAmount,
    );
    final costOfGoods = sales.fold<double>(0, (total, sale) {
      final product = productsById[sale.productId];
      return total + (product == null ? 0 : product.costPrice * sale.quantity);
    });
    final saleProfits = [
      for (final sale in sales)
        (
          date: sale.saleDate,
          amount: productsById.containsKey(sale.productId)
              ? (sale.unitPrice - productsById[sale.productId]!.costPrice) *
                    sale.quantity
              : 0.0,
        ),
    ];
    final todayProfit = saleProfits
        .where((profit) => _isSameDay(profit.date, now))
        .fold<double>(0, (total, profit) => total + profit.amount);
    final monthlyProfit = saleProfits
        .where((profit) => _isSameMonth(profit.date, now))
        .fold<double>(0, (total, profit) => total + profit.amount);
    final months = [
      for (var offset = 5; offset >= 0; offset--)
        DateTime(now.year, now.month - offset),
    ];

    return DashboardSummary(
      totalRevenue: totalRevenue,
      totalCustomers: totalCustomers,
      totalProducts: totalProducts,
      totalSales: totalRevenue,
      totalExpenses: totalExpenses,
      costOfGoods: costOfGoods,
      lowStockProducts: lowStockProducts,
      openTasks: openTasks,
      todayProfit: todayProfit - todayExpenses,
      monthlyProfit: monthlyProfit - monthlyExpenses,
      totalProfit: totalRevenue - costOfGoods - totalExpenses,
      revenueChart: [
        for (final month in months)
          RevenueChartPoint(
            label: _monthLabel(month),
            amount: sales
                .where((sale) => _isSameMonth(sale.saleDate, month))
                .fold<double>(0, (total, sale) => total + sale.totalAmount),
          ),
      ],
    );
  }

  Future<int> _fetchInt(
    String sql, [
    List<Variable> variables = const [],
  ]) async {
    try {
      final row = await _database
          .customSelect(sql, variables: variables)
          .getSingle();
      return row.read<num>('value').toInt();
    } catch (error) {
      debugPrint('DASHBOARD_LOCAL_ERROR $error');
      return 0;
    }
  }

  Future<double> _fetchDouble(
    String sql, [
    List<Variable> variables = const [],
  ]) async {
    try {
      final row = await _database
          .customSelect(sql, variables: variables)
          .getSingle();
      return row.read<num>('value').toDouble();
    } catch (error) {
      debugPrint('DASHBOARD_LOCAL_ERROR $error');
      return 0;
    }
  }

  Future<List<_DashboardSale>> _fetchSales() async {
    try {
      final rows = await _database.customSelect('''
SELECT id,
       product_id,
       quantity,
       unit_price,
       total_amount,
       sale_date,
       created_at
FROM sales
WHERE is_deleted = 0
ORDER BY COALESCE(sale_date, created_at, updated_at, id) DESC
''').get();

      return rows.map((row) {
        return _DashboardSale(
          productId: row.read<String>('product_id'),
          quantity: row.read<int>('quantity'),
          unitPrice: row.read<num>('unit_price').toDouble(),
          totalAmount: row.read<num>('total_amount').toDouble(),
          saleDate: DateTime.tryParse(
            row.readNullable<String>('sale_date') ?? '',
          ),
        );
      }).toList();
    } catch (error) {
      debugPrint('DASHBOARD_LOCAL_ERROR $error');
      return const [];
    }
  }

  Future<Map<String, _DashboardProduct>> _fetchProductsById() async {
    try {
      final rows = await _database.customSelect('''
SELECT id,
       cost_price
FROM products
WHERE is_deleted = 0
''').get();

      return {
        for (final row in rows)
          row.read<String>('id'): _DashboardProduct(
            costPrice: row.read<num>('cost_price').toDouble(),
          ),
      };
    } catch (error) {
      debugPrint('DASHBOARD_LOCAL_ERROR $error');
      return const {};
    }
  }
}

class DashboardSummary {
  const DashboardSummary({
    required this.totalRevenue,
    required this.totalCustomers,
    required this.totalProducts,
    required this.totalSales,
    required this.totalExpenses,
    required this.costOfGoods,
    required this.lowStockProducts,
    required this.openTasks,
    required this.todayProfit,
    required this.monthlyProfit,
    required this.totalProfit,
    required this.revenueChart,
  });

  factory DashboardSummary.empty() {
    final now = DateTime.now();
    return DashboardSummary(
      totalRevenue: 0,
      totalCustomers: 0,
      totalProducts: 0,
      totalSales: 0,
      totalExpenses: 0,
      costOfGoods: 0,
      lowStockProducts: 0,
      openTasks: 0,
      todayProfit: 0,
      monthlyProfit: 0,
      totalProfit: 0,
      revenueChart: [
        for (var offset = 5; offset >= 0; offset--)
          RevenueChartPoint(
            label: _monthLabel(DateTime(now.year, now.month - offset)),
            amount: 0,
          ),
      ],
    );
  }

  final double totalRevenue;
  final int totalCustomers;
  final int totalProducts;
  final double totalSales;
  final double totalExpenses;
  final double costOfGoods;
  final int lowStockProducts;
  final int openTasks;
  final double todayProfit;
  final double monthlyProfit;
  final double totalProfit;
  final List<RevenueChartPoint> revenueChart;
}

class RevenueChartPoint {
  const RevenueChartPoint({required this.label, required this.amount});

  final String label;
  final double amount;
}

class _DashboardSale {
  const _DashboardSale({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.saleDate,
  });

  final String productId;
  final int quantity;
  final double unitPrice;
  final double totalAmount;
  final DateTime? saleDate;
}

class _DashboardProduct {
  const _DashboardProduct({required this.costPrice});

  final double costPrice;
}

DateTime _startOfDay(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

DateTime _startOfMonth(DateTime date) {
  return DateTime(date.year, date.month);
}

DateTime _nextMonth(DateTime date) {
  return DateTime(date.year, date.month + 1);
}

bool _isSameDay(DateTime? date, DateTime other) {
  return date != null &&
      date.year == other.year &&
      date.month == other.month &&
      date.day == other.day;
}

bool _isSameMonth(DateTime? date, DateTime other) {
  return date != null && date.year == other.year && date.month == other.month;
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
  return months[date.month - 1];
}
