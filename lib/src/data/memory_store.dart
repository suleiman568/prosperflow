import 'dart:async';

import 'package:uuid/uuid.dart';

import '../utils/streams.dart';
import 'data_store.dart';
import 'models.dart';

/// In-memory [DataStore] used on the web (where SQLite isn't bundled) and
/// as a fixture-friendly double in widget tests. Behavior matches
/// [DriftStore]; persistence and the sync outbox are Drift-only concerns.
class MemoryStore implements DataStore {
  MemoryStore({
    List<Product>? products,
    List<Sale>? sales,
    List<Expense>? expenses,
    List<Credit>? credits,
  })  : _products = List.of(products ?? const []),
        _sales = List.of(sales ?? const []),
        _expenses = List.of(expenses ?? const []),
        _credits = List.of(credits ?? const []);

  final List<Product> _products;
  final List<Sale> _sales;
  final List<Expense> _expenses;
  final List<Credit> _credits;

  /// Soft-deleted product ids: hidden from [watchProducts] but kept in
  /// [_products] so historical sales still resolve their names — matching
  /// DriftStore's soft-delete behavior.
  final _deletedIds = <String>{};

  final _changes = StreamController<void>.broadcast();
  final _uuid = const Uuid();

  void _notify() => _changes.add(null);

  /// Sales resolve product names at read time (like DriftStore), so a
  /// product rename relabels history identically on device and web.
  Sale _withCurrentName(Sale sale) {
    final product =
        _products.where((p) => p.id == sale.productId).firstOrNull;
    if (product == null || product.name == sale.productName) return sale;
    return Sale(
      id: sale.id,
      productId: sale.productId,
      productName: product.name,
      qty: sale.qty,
      unitPrice: sale.unitPrice,
      unitCost: sale.unitCost,
      listPrice: sale.listPrice,
      total: sale.total,
      method: sale.method,
      fulfilment: sale.fulfilment,
      customerName: sale.customerName,
      location: sale.location,
      soldAt: sale.soldAt,
    );
  }

  List<Sale> get _salesWithCurrentNames =>
      [for (final sale in _sales) _withCurrentName(sale)];

  /// Emits the current value immediately, then again on every change.
  /// Multi-listen safe: each listener runs its own generator, so re-listening
  /// never throws "Stream has already been listened to".
  Stream<T> _watch<T>(T Function() compute) {
    Stream<T> snapshotThenUpdates() async* {
      yield compute();
      yield* _changes.stream.map((_) => compute());
    }

    return MultiListenStream(snapshotThenUpdates);
  }

  @override
  Stream<List<Product>> watchProducts() => _watch(
      () => [for (final p in _products) if (!_deletedIds.contains(p.id)) p]);

  @override
  Future<void> addProduct({
    required String name,
    required String unit,
    required int stock,
    required int buyPrice,
    required int sellPrice,
  }) async {
    _products.add(Product(
      id: _uuid.v4(),
      name: name,
      unit: unit,
      stock: stock,
      buyPrice: buyPrice,
      sellPrice: sellPrice,
    ));
    _notify();
  }

  @override
  Future<void> updateProduct({
    required String id,
    required String name,
    required String unit,
    required int buyPrice,
    required int sellPrice,
    required int lowStockThreshold,
  }) async {
    final index = _products.indexWhere((p) => p.id == id);
    final current = _products[index];
    _products[index] = Product(
      id: id,
      name: name,
      unit: unit,
      stock: current.stock,
      buyPrice: buyPrice,
      sellPrice: sellPrice,
      lowStockThreshold: lowStockThreshold,
    );
    _notify();
  }

  @override
  Future<void> deleteProduct(String id) async {
    _deletedIds.add(id);
    _notify();
  }

  SalesStats _statsSince(DateTime since) {
    var total = 0;
    var count = 0;
    for (final sale in _sales) {
      if (!sale.soldAt.isBefore(since)) {
        total += sale.total;
        count++;
      }
    }
    return SalesStats(total: total, count: count);
  }

  @override
  Stream<SalesStats> watchTodayStats() =>
      _watch(() => _statsSince(startOfToday(DateTime.now())));

  @override
  Stream<SalesStats> watchWeekStats() => _watch(
      () => _statsSince(DateTime.now().subtract(const Duration(days: 7))));

  @override
  Future<void> recordSale({
    required String productId,
    required int qty,
    required PaymentMethod method,
    required Fulfilment fulfilment,
    int? unitPrice,
    String? customerName,
    String? location,
  }) async {
    final index = _products.indexWhere((p) => p.id == productId);
    final product = _products[index];
    final now = DateTime.now();
    final price = unitPrice ?? product.sellPrice;
    final listPrice = price == product.sellPrice ? null : product.sellPrice;
    final total = qty * price;
    final saleId = _uuid.v4();

    _sales.add(Sale(
      id: saleId,
      productId: productId,
      productName: product.name,
      qty: qty,
      unitPrice: price,
      unitCost: product.buyPrice,
      listPrice: listPrice,
      total: total,
      method: method,
      fulfilment: fulfilment,
      customerName: customerName,
      location: location,
      soldAt: now,
    ));
    _products[index] = Product(
      id: product.id,
      name: product.name,
      unit: product.unit,
      stock: (product.stock - qty).clamp(0, 1 << 31),
      buyPrice: product.buyPrice,
      sellPrice: product.sellPrice,
      lowStockThreshold: product.lowStockThreshold,
    );
    if (method == PaymentMethod.credit) {
      _credits.add(Credit(
        saleId: saleId,
        customerName: customerName ?? '',
        amount: total,
        product: '${product.name} × $qty',
        status: CreditStatus.owed,
        soldAt: now,
      ));
    }
    _notify();
  }

  @override
  Stream<List<Expense>> watchExpenses() => _watch(() {
        final sorted = List.of(_expenses)
          ..sort((a, b) => b.spentOn.compareTo(a.spentOn));
        return sorted;
      });

  @override
  Future<void> addExpense({
    required String description,
    required int amount,
    required ExpenseCategory category,
    required DateTime spentOn,
  }) async {
    _expenses.add(Expense(
      id: _uuid.v4(),
      description: description,
      amount: amount,
      category: category,
      spentOn: spentOn,
    ));
    _notify();
  }

  @override
  Future<void> deleteExpense(String id) async {
    _expenses.removeWhere((e) => e.id == id);
    _notify();
  }

  @override
  Stream<List<Credit>> watchOwedCredits() => _watch(() {
        final owed = _credits
            .where((c) => c.status == CreditStatus.owed)
            .toList()
          ..sort((a, b) => b.soldAt.compareTo(a.soldAt));
        return owed;
      });

  @override
  Future<void> markCreditPaid(String saleId) async {
    final index = _credits.indexWhere((c) => c.saleId == saleId);
    final credit = _credits[index];
    final now = DateTime.now();
    _credits[index] = Credit(
      saleId: credit.saleId,
      customerName: credit.customerName,
      amount: credit.amount,
      product: credit.product,
      status: CreditStatus.paid,
      soldAt: credit.soldAt,
      paidAt: now,
    );
    _notify();
  }

  @override
  Stream<TodayHistory> watchTodayHistory() => _watch(() => buildTodayHistory(
        sales: _salesWithCurrentNames,
        paidCreditSaleIds: {
          for (final c in _credits)
            if (c.status == CreditStatus.paid) c.saleId,
        },
        now: DateTime.now(),
      ));

  @override
  Stream<ReportData> watchReport(ReportPeriod period) => _watch(() {
        final since = periodStart(period, DateTime.now());
        final all = _salesWithCurrentNames;
        final sales = since == null
            ? all
            : all.where((s) => s.soldAt.isAfter(since)).toList();
        final expenses = since == null
            ? _expenses
            : _expenses.where((e) => e.spentOn.isAfter(since)).toList();
        return buildReport(
          sales: sales,
          expenses: expenses,
          paidCreditSaleIds: {
            for (final c in _credits)
              if (c.status == CreditStatus.paid) c.saleId,
          },
        );
      });
}
