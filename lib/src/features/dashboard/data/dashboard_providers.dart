import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../customers/data/customers_providers.dart';
import '../../expenses/data/expenses_providers.dart';
import '../../products/data/products_providers.dart';
import '../../sales/data/sales_providers.dart';
import '../../tasks/data/tasks_providers.dart';

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
  const RevenueChartPoint({
    required this.label,
    required this.amount,
  });

  final String label;
  final double amount;
}

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  final customers = await ref.watch(customersProvider.future);
  final products = await ref.watch(productsProvider.future);
  final sales = await ref.watch(salesProvider.future);
  final expenses = await ref.watch(expensesProvider.future);
  final tasks = await ref.watch(tasksProvider.future);

  final now = DateTime.now();
  final productsById = {
    for (final product in products) product.id: product,
  };
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
  final totalRevenue = sales.fold<double>(
    0,
    (total, sale) => total + sale.totalAmount,
  );
  final costOfGoods = sales.fold<double>(
    0,
    (total, sale) {
      final product = productsById[sale.productId];
      return total + (product == null ? 0 : product.costPrice * sale.quantity);
    },
  );
  final totalExpenses = expenses.fold<double>(
    0,
    (total, expense) => total + expense.amount,
  );
  final todayExpenses = expenses
      .where((expense) {
        final date = expense.date;
        return date != null &&
            date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      })
      .fold<double>(0, (total, expense) => total + expense.amount);
  final monthlyExpenses = expenses
      .where((expense) {
        final date = expense.date;
        return date != null && date.year == now.year && date.month == now.month;
      })
      .fold<double>(0, (total, expense) => total + expense.amount);
  final todayProfit = saleProfits
      .where((profit) {
        final date = profit.date;
        return date != null &&
            date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      })
      .fold<double>(0, (total, profit) => total + profit.amount);
  final todayNetProfit = todayProfit - todayExpenses;
  final monthlyProfit = saleProfits
      .where((profit) {
        final date = profit.date;
        return date != null && date.year == now.year && date.month == now.month;
      })
      .fold<double>(0, (total, profit) => total + profit.amount);
  final monthlyNetProfit = monthlyProfit - monthlyExpenses;
  final netProfit = totalRevenue - costOfGoods - totalExpenses;
  final months = [
    for (var offset = 5; offset >= 0; offset--)
      DateTime(now.year, now.month - offset),
  ];
  final revenueChart = [
    for (final month in months)
      RevenueChartPoint(
        label: _monthLabel(month),
        amount: sales
            .where((sale) {
              final date = sale.saleDate;
              return date != null &&
                  date.year == month.year &&
                  date.month == month.month;
            })
            .fold<double>(0, (total, sale) => total + sale.totalAmount),
      ),
  ];

  return DashboardSummary(
    totalRevenue: totalRevenue,
    totalCustomers: customers.length,
    totalProducts: products.length,
    totalSales: totalRevenue,
    totalExpenses: totalExpenses,
    costOfGoods: costOfGoods,
    lowStockProducts: products.where((product) => product.isLowStock).length,
    openTasks: tasks.where((task) => !task.isComplete).length,
    todayProfit: todayNetProfit,
    monthlyProfit: monthlyNetProfit,
    totalProfit: netProfit,
    revenueChart: revenueChart,
  );
});

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
