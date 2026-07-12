import 'models.dart';

enum ReportPeriod { week, month, all }

class ReportData {
  const ReportData({
    required this.salesTotal,
    required this.salesCount,
    required this.expensesTotal,
    required this.expensesCount,
    required this.topProducts,
    required this.paymentBuckets,
  });

  final int salesTotal;
  final int salesCount;
  final int expensesTotal;
  final int expensesCount;
  final List<TopProduct> topProducts;
  final List<PaymentBucket> paymentBuckets;

  int get profit => salesTotal - expensesTotal;
}

/// The app's single data access surface. Screens only talk to this.
///
/// Per the Backend Plan, the local store is the source of truth: every
/// method works offline instantly. The Drift implementation also appends
/// each mutation to the outbox, which the sync engine (Stage 3) flushes
/// to Supabase when connectivity allows.
abstract class DataStore {
  Stream<List<Product>> watchProducts();

  Future<void> addProduct({
    required String name,
    required String unit,
    required int stock,
    required int buyPrice,
    required int sellPrice,
  });

  /// Soft-deletes a product (Backend Plan §3: the `deleted` flag syncs like
  /// any other update). Past sales referencing it stay intact in reports.
  Future<void> deleteProduct(String id);

  Stream<SalesStats> watchTodayStats();

  /// Rolling last-7-days window.
  Stream<SalesStats> watchWeekStats();

  /// Records a sale: inserts the sale, decrements the product's stock, and
  /// opens a credit record when [method] is [PaymentMethod.credit].
  Future<void> recordSale({
    required String productId,
    required int qty,
    required PaymentMethod method,
    required Fulfilment fulfilment,
    String? customerName,
    String? location,
  });

  /// Newest first.
  Stream<List<Expense>> watchExpenses();

  Future<void> addExpense({
    required String description,
    required int amount,
    required ExpenseCategory category,
    required DateTime spentOn,
  });

  /// Soft-deletes an expense; the deletion syncs like any other update
  /// and the amount leaves every total and report.
  Future<void> deleteExpense(String id);

  /// Open credits, newest sale first.
  Stream<List<Credit>> watchOwedCredits();

  /// Collects a credit. The owed amount then counts as cash in reports.
  Future<void> markCreditPaid(String saleId);

  Stream<ReportData> watchReport(ReportPeriod period);
}

DateTime startOfToday(DateTime now) => DateTime(now.year, now.month, now.day);

DateTime? periodStart(ReportPeriod period, DateTime now) => switch (period) {
      ReportPeriod.week => now.subtract(const Duration(days: 7)),
      ReportPeriod.month => now.subtract(const Duration(days: 30)),
      ReportPeriod.all => null,
    };

/// Shared aggregation used by both store implementations, so reports behave
/// identically on every platform.
///
/// Credit sales whose credit has been collected count as cash — collecting
/// a credit "moves the amount from credit to cash" (handoff §4).
ReportData buildReport({
  required List<Sale> sales,
  required List<Expense> expenses,
  required Set<String> paidCreditSaleIds,
}) {
  final salesTotal = sales.fold(0, (sum, s) => sum + s.total);

  final byMethod = {for (final m in PaymentMethod.values) m: 0};
  for (final sale in sales) {
    final bucket =
        sale.method == PaymentMethod.credit && paidCreditSaleIds.contains(sale.id)
            ? PaymentMethod.cash
            : sale.method;
    byMethod[bucket] = byMethod[bucket]! + sale.total;
  }

  final revenueByProduct = <String, int>{};
  for (final sale in sales) {
    revenueByProduct[sale.productName] =
        (revenueByProduct[sale.productName] ?? 0) + sale.total;
  }
  final ranked = revenueByProduct.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final topProducts = [
    for (final entry in ranked.take(2))
      TopProduct(
        name: entry.key,
        share: salesTotal == 0 ? 0 : entry.value / salesTotal,
      ),
  ];

  return ReportData(
    salesTotal: salesTotal,
    salesCount: sales.length,
    expensesTotal: expenses.fold(0, (sum, e) => sum + e.amount),
    expensesCount: expenses.length,
    topProducts: topProducts,
    paymentBuckets: [
      for (final method in PaymentMethod.values)
        PaymentBucket(method: method, amount: byMethod[method]!),
    ],
  );
}
