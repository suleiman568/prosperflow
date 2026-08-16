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

@DriftDatabase(tables: [Products, Sales, Expenses, Credits, Outbox, Meta])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 5;

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
    },
  );
}
