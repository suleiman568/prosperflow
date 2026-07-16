import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'data_store.dart';
import 'db/app_database.dart';
import 'models.dart';

/// Drift/SQLite-backed [DataStore] — the production implementation.
/// Every mutation runs in a transaction and appends to the outbox so the
/// sync engine can push it later (Backend Plan §5).
class DriftStore implements DataStore {
  DriftStore(this.db);

  final AppDatabase db;
  final _uuid = const Uuid();

  // ---------------------------------------------------------------- mapping

  Product _product(ProductRow row) => Product(
        id: row.id,
        name: row.name,
        unit: row.unit,
        stock: row.stock,
        buyPrice: row.buyPrice,
        sellPrice: row.sellPrice,
        lowStockThreshold: row.lowStockThreshold,
      );

  Sale _sale(SaleRow row, Map<String, String> productNames) => Sale(
        id: row.id,
        productId: row.productId,
        productName: productNames[row.productId] ?? 'Unknown product',
        qty: row.qty,
        unitPrice: row.unitPrice,
        unitCost: row.unitCost,
        listPrice: row.listPrice,
        total: row.total,
        method: row.method,
        fulfilment: row.fulfilment,
        customerName: row.customerName,
        location: row.location,
        soldAt: row.soldAt,
      );

  Expense _expense(ExpenseRow row) => Expense(
        id: row.id,
        description: row.description,
        amount: row.amount,
        category: row.category,
        spentOn: row.spentOn,
      );

  Credit _credit(CreditRow row) => Credit(
        saleId: row.saleId,
        customerName: row.customerName,
        amount: row.amount,
        product: row.product,
        status: row.status,
        soldAt: row.soldAt,
        paidAt: row.paidAt,
      );

  Future<void> _appendOutbox(String entity, String entityId, String op,
      Map<String, Object?> payload) {
    return db.into(db.outbox).insert(OutboxCompanion.insert(
          entity: entity,
          entityId: entityId,
          op: op,
          payloadJson: jsonEncode(payload),
          createdAt: DateTime.now(),
        ));
  }

  // -------------------------------------------------------------- products

  @override
  Stream<List<Product>> watchProducts() {
    final query = db.select(db.products)
      ..where((p) => p.deleted.equals(false));
    return query.watch().map((rows) => rows.map(_product).toList());
  }

  @override
  Future<void> addProduct({
    required String name,
    required String unit,
    required int stock,
    required int buyPrice,
    required int sellPrice,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await db.transaction(() async {
      await db.into(db.products).insert(ProductsCompanion.insert(
            id: id,
            name: name,
            unit: unit,
            stock: stock,
            buyPrice: buyPrice,
            sellPrice: sellPrice,
            updatedAt: now,
          ));
      await _appendOutbox('product', id, 'create', {
        'id': id,
        'name': name,
        'unit': unit,
        'stock': stock,
        'buy_price': buyPrice,
        'sell_price': sellPrice,
        'updated_at': now.toIso8601String(),
      });
    });
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
    final now = DateTime.now();
    await db.transaction(() async {
      await (db.update(db.products)..where((p) => p.id.equals(id)))
          .write(ProductsCompanion(
        name: Value(name),
        unit: Value(unit),
        buyPrice: Value(buyPrice),
        sellPrice: Value(sellPrice),
        lowStockThreshold: Value(lowStockThreshold),
        updatedAt: Value(now),
        synced: const Value(false),
      ));
      await _appendOutbox('product', id, 'update', {
        'id': id,
        'name': name,
        'unit': unit,
        'buy_price': buyPrice,
        'sell_price': sellPrice,
        'low_stock_threshold': lowStockThreshold,
        'updated_at': now.toIso8601String(),
      });
    });
  }

  @override
  Future<void> deleteProduct(String id) async {
    final now = DateTime.now();
    await db.transaction(() async {
      await (db.update(db.products)..where((p) => p.id.equals(id)))
          .write(ProductsCompanion(
        deleted: const Value(true),
        updatedAt: Value(now),
        synced: const Value(false),
      ));
      await _appendOutbox('product', id, 'update', {
        'id': id,
        'deleted': true,
        'updated_at': now.toIso8601String(),
      });
    });
  }

  // ----------------------------------------------------------------- sales

  Stream<SalesStats> _watchStatsSince(DateTime Function() start) {
    final query = db.select(db.sales);
    return query.watch().map((rows) {
      final since = start();
      var total = 0;
      var count = 0;
      for (final row in rows) {
        if (!row.soldAt.isBefore(since)) {
          total += row.total;
          count++;
        }
      }
      return SalesStats(total: total, count: count);
    });
  }

  @override
  Stream<SalesStats> watchTodayStats() =>
      _watchStatsSince(() => startOfToday(DateTime.now()));

  @override
  Stream<SalesStats> watchWeekStats() =>
      _watchStatsSince(() => DateTime.now().subtract(const Duration(days: 7)));

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
    await db.transaction(() async {
      final product = await (db.select(db.products)
            ..where((p) => p.id.equals(productId)))
          .getSingle();
      final saleId = _uuid.v4();
      final now = DateTime.now();
      final price = unitPrice ?? product.sellPrice;
      // Keep the normal price only when this sale deviates from it.
      final listPrice = price == product.sellPrice ? null : product.sellPrice;
      final total = qty * price;

      await db.into(db.sales).insert(SalesCompanion.insert(
            id: saleId,
            productId: productId,
            qty: qty,
            unitPrice: price,
            unitCost: Value(product.buyPrice),
            listPrice: Value(listPrice),
            total: total,
            method: method,
            fulfilment: fulfilment,
            customerName: Value(customerName),
            location: Value(location),
            soldAt: now,
          ));
      await _appendOutbox('sale', saleId, 'create', {
        'id': saleId,
        'product_id': productId,
        'qty': qty,
        'unit_price': price,
        'unit_cost': product.buyPrice,
        'list_price': listPrice,
        'total': total,
        'method': method.name,
        'fulfilment': fulfilment.name,
        'customer_name': customerName,
        'location': location,
        'sold_at': now.toIso8601String(),
      });

      final newStock = (product.stock - qty).clamp(0, 1 << 31);
      await (db.update(db.products)..where((p) => p.id.equals(productId)))
          .write(ProductsCompanion(
        stock: Value(newStock),
        updatedAt: Value(now),
        synced: const Value(false),
      ));
      await _appendOutbox('product', productId, 'update', {
        'id': productId,
        'stock': newStock,
        'updated_at': now.toIso8601String(),
      });

      if (method == PaymentMethod.credit) {
        await db.into(db.credits).insert(CreditsCompanion.insert(
              saleId: saleId,
              customerName: customerName ?? '',
              amount: total,
              product: '${product.name} × $qty',
              status: CreditStatus.owed,
              soldAt: now,
              updatedAt: now,
            ));
        await _appendOutbox('credit', saleId, 'create', {
          'sale_id': saleId,
          'customer_name': customerName,
          'amount': total,
          'product': '${product.name} × $qty',
          'status': 'owed',
          'sold_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
      }
    });
  }

  // -------------------------------------------------------------- expenses

  @override
  Stream<List<Expense>> watchExpenses() {
    final query = db.select(db.expenses)
      ..where((e) => e.deleted.equals(false))
      ..orderBy([(e) => OrderingTerm.desc(e.spentOn)]);
    return query.watch().map((rows) => rows.map(_expense).toList());
  }

  @override
  Future<void> addExpense({
    required String description,
    required int amount,
    required ExpenseCategory category,
    required DateTime spentOn,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await db.transaction(() async {
      await db.into(db.expenses).insert(ExpensesCompanion.insert(
            id: id,
            description: description,
            amount: amount,
            category: category,
            spentOn: spentOn,
            updatedAt: now,
          ));
      await _appendOutbox('expense', id, 'create', {
        'id': id,
        'description': description,
        'amount': amount,
        'category': category.name,
        'spent_on': spentOn.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
    });
  }

  @override
  Future<void> deleteExpense(String id) async {
    final now = DateTime.now();
    await db.transaction(() async {
      await (db.update(db.expenses)..where((e) => e.id.equals(id)))
          .write(ExpensesCompanion(
        deleted: const Value(true),
        updatedAt: Value(now),
        synced: const Value(false),
      ));
      await _appendOutbox('expense', id, 'update', {
        'id': id,
        'deleted': true,
        'updated_at': now.toIso8601String(),
      });
    });
  }

  // --------------------------------------------------------------- credits

  @override
  Stream<List<Credit>> watchOwedCredits() {
    final query = db.select(db.credits)
      ..where((c) => c.status.equalsValue(CreditStatus.owed))
      ..orderBy([(c) => OrderingTerm.desc(c.soldAt)]);
    return query.watch().map((rows) => rows.map(_credit).toList());
  }

  @override
  Future<void> markCreditPaid(String saleId) async {
    final now = DateTime.now();
    await db.transaction(() async {
      await (db.update(db.credits)..where((c) => c.saleId.equals(saleId)))
          .write(CreditsCompanion(
        status: const Value(CreditStatus.paid),
        paidAt: Value(now),
        updatedAt: Value(now),
        synced: const Value(false),
      ));
      await _appendOutbox('credit', saleId, 'update', {
        'sale_id': saleId,
        'status': 'paid',
        'paid_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
    });
  }

  // --------------------------------------------------------------- reports

  @override
  Stream<ReportData> watchReport(ReportPeriod period) {
    // A trivial query watching every table the report reads from; each
    // change re-runs the aggregation below.
    final tick = db.customSelect(
      'SELECT 1',
      readsFrom: {db.sales, db.expenses, db.credits, db.products},
    );
    return tick.watch().asyncMap((_) => _computeReport(period));
  }

  @override
  Stream<TodayHistory> watchTodayHistory() {
    final tick = db.customSelect(
      'SELECT 1',
      readsFrom: {db.sales, db.products, db.credits},
    );
    return tick.watch().asyncMap((_) => _computeTodayHistory());
  }

  Future<TodayHistory> _computeTodayHistory() async {
    // One clock read for both the query window and the aggregation, so a
    // midnight rollover mid-computation can't split "today" in two.
    final now = DateTime.now();

    // Unfiltered product read (like _computeReport): sales of soft-deleted
    // products must still resolve their names.
    final productRows = await db.select(db.products).get();
    final names = {for (final p in productRows) p.id: p.name};

    final saleRows = await (db.select(db.sales)
          ..where((s) => s.soldAt.isBiggerOrEqualValue(startOfToday(now))))
        .get();

    final paidRows = await (db.select(db.credits)
          ..where((c) => c.status.equalsValue(CreditStatus.paid)))
        .get();

    return buildTodayHistory(
      sales: saleRows.map((row) => _sale(row, names)).toList(),
      paidCreditSaleIds: {for (final c in paidRows) c.saleId},
      now: now,
    );
  }

  @override
  Future<ExportBundle> exportBundle(ReportPeriod period) async {
    final now = DateTime.now();
    final since = periodStart(period, now);

    // Unfiltered product read: exported sales of soft-deleted products
    // must still resolve their names.
    final productRows = await db.select(db.products).get();
    final names = {for (final p in productRows) p.id: p.name};

    // Filter in SQL (like _computeReport) so a long sales history isn't
    // loaded into memory just to be discarded; buildExportBundle applies
    // the same strict window again, harmlessly, for store parity.
    var salesQuery = db.select(db.sales);
    if (since != null) {
      salesQuery = salesQuery..where((s) => s.soldAt.isBiggerThanValue(since));
    }
    final saleRows = await salesQuery.get();

    var expensesQuery = db.select(db.expenses)
      ..where((e) => e.deleted.equals(false));
    if (since != null) {
      expensesQuery = expensesQuery
        ..where((e) => e.spentOn.isBiggerThanValue(since));
    }
    final expenseRows = await expensesQuery.get();

    final paidRows = await (db.select(db.credits)
          ..where((c) => c.status.equalsValue(CreditStatus.paid)))
        .get();

    return buildExportBundle(
      period: period,
      sales: saleRows.map((row) => _sale(row, names)).toList(),
      expenses: expenseRows.map(_expense).toList(),
      paidCreditSaleIds: {for (final c in paidRows) c.saleId},
      now: now,
    );
  }

  Future<ReportData> _computeReport(ReportPeriod period) async {
    final since = periodStart(period, DateTime.now());

    final productRows = await db.select(db.products).get();
    final names = {for (final p in productRows) p.id: p.name};

    var salesQuery = db.select(db.sales);
    if (since != null) {
      salesQuery = salesQuery..where((s) => s.soldAt.isBiggerThanValue(since));
    }
    final sales =
        (await salesQuery.get()).map((row) => _sale(row, names)).toList();

    var expensesQuery = db.select(db.expenses)
      ..where((e) => e.deleted.equals(false));
    if (since != null) {
      expensesQuery = expensesQuery
        ..where((e) => e.spentOn.isBiggerThanValue(since));
    }
    final expenses = (await expensesQuery.get()).map(_expense).toList();

    final paidRows = await (db.select(db.credits)
          ..where((c) => c.status.equalsValue(CreditStatus.paid)))
        .get();

    return buildReport(
      sales: sales,
      expenses: expenses,
      paidCreditSaleIds: {for (final c in paidRows) c.saleId},
    );
  }
}
