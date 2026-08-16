import 'dart:convert';

import 'package:drift/drift.dart';

import '../models.dart';

part 'app_database.g.dart';

/// Client-side mirror of the Backend Plan schema (§3). All row IDs are
/// client-generated UUIDs; `synced` drives the "waiting to sync" UI and the
/// outbox drives push sync (Stage 3).
@DataClassName('ProductRow')
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get unit => text()();
  IntColumn get stock => integer()();
  IntColumn get buyPrice => integer()();
  IntColumn get sellPrice => integer()();
  IntColumn get lowStockThreshold =>
      integer().withDefault(const Constant(10))();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SaleRow')
class Sales extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text()();
  IntColumn get qty => integer()();
  IntColumn get unitPrice => integer()();

  /// Buy price snapshot at sale time (v3). Null on pre-v3 sales, where
  /// profit is unknowable and shown as "—".
  IntColumn get unitCost => integer().nullable()();

  /// The product's normal sell price when this sale was discounted (v4).
  /// Null when the sale went for the normal price — only set when
  /// unitPrice differs, so history can show "₦X off ₦Y".
  IntColumn get listPrice => integer().nullable()();

  IntColumn get total => integer()();
  TextColumn get method => textEnum<PaymentMethod>()();
  TextColumn get fulfilment => textEnum<Fulfilment>()();
  TextColumn get customerName => text().nullable()();
  TextColumn get location => text().nullable()();
  DateTimeColumn get soldAt => dateTime()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ExpenseRow')
class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get description => text()();
  IntColumn get amount => integer()();
  TextColumn get category => textEnum<ExpenseCategory>()();
  DateTimeColumn get spentOn => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CreditRow')
class Credits extends Table {
  TextColumn get saleId => text()();
  TextColumn get customerName => text()();
  IntColumn get amount => integer()();
  TextColumn get product => text()();
  TextColumn get status => textEnum<CreditStatus>()();
  DateTimeColumn get soldAt => dateTime()();
  DateTimeColumn get paidAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {saleId};
}

/// Every deliberate change to a product's stock level, as an event.
///
/// Stock is derived — the sum of these deltas minus everything sold — rather
/// than stored as a running total. A running total cannot survive two devices:
/// each pushes the absolute value it arrived at, so whichever writes last wins
/// and the other device's sales silently vanish from the count. Deltas and
/// sales are both facts that merge by union, so any set of devices that has
/// seen the same events computes the same stock.
@DataClassName('StockAdjustmentRow')
class StockAdjustments extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text()();

  /// Signed: positive puts stock in, negative takes it out. Sales are not
  /// recorded here — they are already events in their own right.
  IntColumn get delta => integer()();

  /// Why the stock moved: 'opening' when the product was created, and room
  /// for restocks and corrections without another migration.
  TextColumn get reason => text()();

  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Small key/value side table for local bookkeeping that is not the
/// trader's data: which trader this database belongs to, and (once pulls
/// land) the per-entity sync cursors.
@DataClassName('MetaRow')
class Meta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Outbox per Backend Plan §5: every local write appends a mutation here;
/// a background task flushes it to the server in order (Stage 3).
@DataClassName('OutboxRow')
class Outbox extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get entity => text()();
  TextColumn get entityId => text()();
  TextColumn get op => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime()();
}

@DriftDatabase(
  tables: [Products, Sales, Expenses, Credits, Outbox, Meta, StockAdjustments],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // v2: expenses become soft-deletable, like products.
        await m.addColumn(expenses, expenses.deleted);
      }
      if (from < 3) {
        // v3: sales snapshot the buy price for profit reporting.
        await m.addColumn(sales, sales.unitCost);
      }
      if (from < 4) {
        // v4: discounted sales keep the normal price for display.
        await m.addColumn(sales, sales.listPrice);
      }
      if (from < 5) {
        // v5: local bookkeeping, starting with the owning trader. Existing
        // installs have no trader recorded, so the first sign-in after
        // upgrading adopts the database rather than wiping it — the data
        // already belongs to whoever is signed in on that device.
        await m.createTable(meta);
      }
      if (from < 6) {
        // v6: stock becomes derived. Every existing product needs the opening
        // event its current total implies — current stock already has its
        // sales subtracted, so the opening level is stock + everything sold.
        // Reconstructing it this way means the derived value comes out equal
        // to what the trader sees today rather than jumping.
        await m.createTable(stockAdjustments);
        final products = await select(this.products).get();
        for (final product in products) {
          final sold = await customSelect(
            'SELECT COALESCE(SUM(qty), 0) AS n FROM sales '
            'WHERE product_id = ?',
            variables: [Variable<String>(product.id)],
          ).getSingle().then((row) => row.read<int>('n'));
          final opening = product.stock + sold;
          await into(stockAdjustments).insert(
            StockAdjustmentsCompanion.insert(
              id: 'opening-${product.id}',
              productId: product.id,
              delta: opening,
              reason: 'opening',
              createdAt: product.updatedAt,
            ),
          );
          // Queued, not just written. The server has no adjustments for
          // products that predate this table, and only this device can work
          // out what they were — it is the one holding the total the
          // reconstruction is derived from. Left local, another device would
          // pull these products and their sales with no opening to offset
          // them, and derive every stock level as zero.
          await into(outbox).insert(
            OutboxCompanion.insert(
              entity: 'stock_adjustment',
              entityId: 'opening-${product.id}',
              op: 'create',
              payloadJson: jsonEncode({
                'id': 'opening-${product.id}',
                'product_id': product.id,
                'delta': opening,
                'reason': 'opening',
                'created_at': product.updatedAt.toIso8601String(),
              }),
              createdAt: product.updatedAt,
            ),
          );
        }
      }
    },
  );
}
