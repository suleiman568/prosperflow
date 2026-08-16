import 'package:drift/drift.dart';

import '../data/db/app_database.dart';
import '../data/drift_store.dart';
import '../data/models.dart';
import 'sync_backend.dart';

/// Writes pulled rows into the local database.
///
/// Deliberately not part of [DataStore]. Every method there appends to the
/// outbox, because every method there represents something the trader did — so
/// putting pulled rows through it would queue them straight back to the server
/// they came from, and each pull would re-push everything it had just fetched.
/// This writes the tables directly and marks rows synced, because they are.
///
/// Rows carry client-generated primary keys and are upserted, so ingesting the
/// same row twice is a no-op. That is what lets a pull deliberately re-cover a
/// window of time without needing to know exactly what it already has.
class PullIngest {
  PullIngest(this.db, this.store);

  final AppDatabase db;
  final DriftStore store;

  /// Applies one page of [entity] rows. Returns the product ids whose stock
  /// needs re-deriving, since a pulled sale or adjustment changes it.
  ///
  /// [trader] is who the page was fetched as. It is re-checked inside the
  /// write transaction, so a sign-in that lands mid-pull cannot leave the
  /// outgoing trader's rows in the incoming one's ledger: either this
  /// transaction commits first and the wipe clears it, or the wipe commits
  /// first and this sees the new owner and abandons. Checking before opening
  /// the transaction would leave exactly the gap that makes the race possible.
  Future<Set<String>> apply(
    String entity,
    List<Map<String, dynamic>> rows, {
    required String trader,
  }) async {
    final touchedProducts = <String>{};
    if (rows.isEmpty) return touchedProducts;

    await db.transaction(() async {
      if (await DriftStore.ownerOf(db) != trader) throw TraderChanged();
      for (final row in rows) {
        switch (entity) {
          case 'product':
            await _product(row);
            // The upsert cannot carry a stock value — it is derived, and the
            // wire has none — so the row lands with a placeholder. Without
            // settling it here, pulling an unrelated edit like a rename would
            // leave the cache reading zero until some later sale happened to
            // recompute it.
            touchedProducts.add(row['id'] as String);
          case 'sale':
            await _sale(row);
            touchedProducts.add(row['product_id'] as String);
          case 'expense':
            await _expense(row);
          case 'credit':
            await _credit(row);
          case 'stock_adjustment':
            await _stockAdjustment(row);
            touchedProducts.add(row['product_id'] as String);
        }
      }
    });
    return touchedProducts;
  }

  /// Re-derives stock for everything a pull touched.
  Future<void> settleStock(Set<String> productIds) async {
    for (final id in productIds) {
      await store.recomputeStock(id);
    }
  }

  /// A local row still waiting to be pushed is the trader's most recent
  /// intent, so a pulled copy must not overwrite it — the push will settle it
  /// shortly. Only rows already agreed with the server are safe to replace.
  Future<bool> _hasUnpushed(String table, String column, String id) async {
    final rows = await db
        .customSelect(
          'SELECT 1 FROM $table WHERE $column = ? AND synced = 0 LIMIT 1',
          variables: [Variable<String>(id)],
        )
        .get();
    return rows.isNotEmpty;
  }

  Future<void> _product(Map<String, dynamic> row) async {
    final id = row['id'] as String;
    if (await _hasUnpushed('products', 'id', id)) return;
    await db
        .into(db.products)
        .insertOnConflictUpdate(
          ProductsCompanion.insert(
            id: id,
            name: row['name'] as String,
            unit: row['unit'] as String,
            // Derived locally and absent from the wire; settleStock replaces
            // this placeholder before anything reads it.
            stock: 0,
            buyPrice: row['buy_price'] as int,
            sellPrice: row['sell_price'] as int,
            lowStockThreshold: Value(
              (row['low_stock_threshold'] as int?) ?? 10,
            ),
            updatedAt: DateTime.parse(row['updated_at'] as String),
            deleted: Value((row['deleted'] as bool?) ?? false),
            synced: const Value(true),
          ),
        );
  }

  Future<void> _sale(Map<String, dynamic> row) async {
    final id = row['id'] as String;
    if (await _hasUnpushed('sales', 'id', id)) return;
    await db
        .into(db.sales)
        .insertOnConflictUpdate(
          SalesCompanion.insert(
            id: id,
            productId: row['product_id'] as String,
            qty: row['qty'] as int,
            unitPrice: row['unit_price'] as int,
            unitCost: Value(row['unit_cost'] as int?),
            listPrice: Value(row['list_price'] as int?),
            total: row['total'] as int,
            method: PaymentMethod.values.byName(row['method'] as String),
            fulfilment: Fulfilment.values.byName(row['fulfilment'] as String),
            customerName: Value(row['customer_name'] as String?),
            location: Value(row['location'] as String?),
            soldAt: DateTime.parse(row['sold_at'] as String),
            synced: const Value(true),
          ),
        );
  }

  Future<void> _expense(Map<String, dynamic> row) async {
    final id = row['id'] as String;
    if (await _hasUnpushed('expenses', 'id', id)) return;
    await db
        .into(db.expenses)
        .insertOnConflictUpdate(
          ExpensesCompanion.insert(
            id: id,
            description: row['description'] as String,
            amount: row['amount'] as int,
            category: ExpenseCategory.values.byName(row['category'] as String),
            spentOn: DateTime.parse(row['spent_on'] as String),
            updatedAt: DateTime.parse(row['updated_at'] as String),
            deleted: Value((row['deleted'] as bool?) ?? false),
            synced: const Value(true),
          ),
        );
  }

  Future<void> _credit(Map<String, dynamic> row) async {
    final saleId = row['sale_id'] as String;
    if (await _hasUnpushed('credits', 'sale_id', saleId)) return;
    final paidAt = row['paid_at'] as String?;
    await db
        .into(db.credits)
        .insertOnConflictUpdate(
          CreditsCompanion.insert(
            saleId: saleId,
            customerName: row['customer_name'] as String,
            amount: row['amount'] as int,
            product: (row['product'] as String?) ?? '',
            status: CreditStatus.values.byName(
              (row['status'] as String?) ?? 'owed',
            ),
            soldAt: DateTime.parse(
              (row['sold_at'] as String?) ?? row['updated_at'] as String,
            ),
            paidAt: Value(paidAt == null ? null : DateTime.parse(paidAt)),
            updatedAt: DateTime.parse(row['updated_at'] as String),
            synced: const Value(true),
          ),
        );
  }

  Future<void> _stockAdjustment(Map<String, dynamic> row) async {
    final id = row['id'] as String;
    if (await _hasUnpushed('stock_adjustments', 'id', id)) return;
    await db
        .into(db.stockAdjustments)
        .insertOnConflictUpdate(
          StockAdjustmentsCompanion.insert(
            id: id,
            productId: row['product_id'] as String,
            delta: row['delta'] as int,
            reason: (row['reason'] as String?) ?? 'opening',
            createdAt: DateTime.parse(row['created_at'] as String),
            synced: const Value(true),
          ),
        );
  }
}
