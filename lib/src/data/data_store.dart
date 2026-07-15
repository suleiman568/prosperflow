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

  /// Edits a product's details. Historical sales are untouched — their
  /// unitPrice/unitCost snapshots were frozen at sale time — but product
  /// names resolve at read time, so a rename relabels history everywhere.
  ///
  /// Known behavior: edits sync as plain updates with no versioning, so if
  /// two devices edit the same product offline, whichever syncs last wins.
  Future<void> updateProduct({
    required String id,
    required String name,
    required String unit,
    required int buyPrice,
    required int sellPrice,
    required int lowStockThreshold,
  });

  /// Soft-deletes a product (Backend Plan §3: the `deleted` flag syncs like
  /// any other update). Past sales referencing it stay intact in reports.
  Future<void> deleteProduct(String id);

  Stream<SalesStats> watchTodayStats();

  /// Rolling last-7-days window.
  Stream<SalesStats> watchWeekStats();

  /// Records a sale: inserts the sale, decrements the product's stock, and
  /// opens a credit record when [method] is [PaymentMethod.credit].
  ///
  /// [unitPrice] overrides the product's normal sell price for this sale
  /// (a custom price or discount). When it differs from the normal price,
  /// the normal price is kept as the sale's listPrice so history can show
  /// the discount. Profit still uses the product's buyPrice snapshot.
  Future<void> recordSale({
    required String productId,
    required int qty,
    required PaymentMethod method,
    required Fulfilment fulfilment,
    int? unitPrice,
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

  /// Today's sales grouped per product for the Reports history section.
  /// Implemented reactively by both stores so device and web behave
  /// identically.
  Stream<TodayHistory> watchTodayHistory();
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
/// Shared "Sales History for Today" aggregation — one implementation so
/// DriftStore and MemoryStore can't drift apart.
///
/// [sales] may span any range; only rows on or after `startOfToday(now)`
/// count. Groups are keyed by product **id** (names aren't unique) and use
/// the sale's resolved product name (an unfiltered lookup, so soft-deleted
/// products still show correctly), ordered by revenue descending; entries
/// are newest first.
/// Profit sums skip sales without a recorded cost instead of dropping them.
TodayHistory buildTodayHistory({
  required List<Sale> sales,
  required Set<String> paidCreditSaleIds,
  required DateTime now,
}) {
  final since = startOfToday(now);
  final today = sales.where((s) => !s.soldAt.isBefore(since)).toList()
    ..sort((a, b) => b.soldAt.compareTo(a.soldAt));

  final byProduct = <String, List<Sale>>{};
  for (final sale in today) {
    byProduct.putIfAbsent(sale.productId, () => []).add(sale);
  }

  int? sumProfit(Iterable<Sale> group) {
    int? sum;
    for (final sale in group) {
      final profit = sale.profit;
      if (profit != null) sum = (sum ?? 0) + profit;
    }
    return sum;
  }

  final groups = [
    for (final MapEntry(key: productId, value: group) in byProduct.entries)
      ProductSalesGroup(
        productId: productId,
        productName: group.first.productName,
        qty: group.fold(0, (sum, s) => sum + s.qty),
        revenue: group.fold(0, (sum, s) => sum + s.total),
        profit: sumProfit(group),
        missingCostCount: group.where((s) => s.unitCost == null).length,
        entries: [
          for (final sale in group)
            SaleHistoryEntry(
              qty: sale.qty,
              unitPrice: sale.unitPrice,
              listPrice: sale.discounted ? sale.listPrice : null,
              profit: sale.profit,
              soldAt: sale.soldAt,
              method: sale.method,
              collected: sale.method == PaymentMethod.credit &&
                  paidCreditSaleIds.contains(sale.id),
            ),
        ],
      ),
  ]..sort((a, b) => b.revenue.compareTo(a.revenue));

  return TodayHistory(
    revenue: today.fold(0, (sum, s) => sum + s.total),
    profit: sumProfit(today),
    missingCostCount: today.where((s) => s.unitCost == null).length,
    groups: groups,
  );
}

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
