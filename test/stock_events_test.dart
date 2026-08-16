import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:prosperflow/src/data/db/app_database.dart';
import 'package:prosperflow/src/data/drift_store.dart';
import 'package:prosperflow/src/data/models.dart';

/// Stock is derived from events rather than stored as a running total.
///
/// The reason is convergence. A running total is a value each device computes
/// locally and then pushes as an absolute number, so two devices selling from
/// the same product overwrite each other and one device's sales disappear from
/// the count. Deltas and sales are facts that merge by union, so any device
/// holding the same set of events arrives at the same stock, whatever order it
/// learned them in.
void main() {
  late AppDatabase db;
  late DriftStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftStore(db);
  });

  tearDown(() => db.close());

  Future<Product> product(String id) async =>
      (await store.watchProducts().first).firstWhere((p) => p.id == id);

  Future<String> addPalmOil({int stock = 42}) async {
    await store.addProduct(
      name: 'Palm Oil',
      unit: 'bottles',
      stock: stock,
      buyPrice: 6800,
      sellPrice: 9200,
    );
    return (await store.watchProducts().first).single.id;
  }

  group('derivation', () {
    test('opening stock is recorded as an event, not just a number', () async {
      final id = await addPalmOil(stock: 42);

      final events = await db.select(db.stockAdjustments).get();
      expect(events.single.productId, id);
      expect(events.single.delta, 42);
      expect(events.single.reason, 'opening');
      expect((await product(id)).stock, 42);
    });

    test('selling moves stock without anyone storing a total', () async {
      final id = await addPalmOil(stock: 42);

      await store.recordSale(
        productId: id,
        qty: 5,
        method: PaymentMethod.cash,
        fulfilment: Fulfilment.walkIn,
      );

      expect((await product(id)).stock, 37);
      // Still exactly one adjustment: the sale is its own event.
      expect(await db.select(db.stockAdjustments).get(), hasLength(1));
    });

    test('overselling floors at zero rather than going negative', () async {
      final id = await addPalmOil(stock: 2);

      await store.recordSale(
        productId: id,
        qty: 9,
        method: PaymentMethod.cash,
        fulfilment: Fulfilment.walkIn,
      );

      expect((await product(id)).stock, 0);
    });
  });

  group('two devices', () {
    // The case a running total cannot survive: both phones sell from the same
    // product before either has synced.
    test('concurrent sales both count once the events meet', () async {
      final id = await addPalmOil(stock: 42);

      // This device sells 2 and sees 40.
      await store.recordSale(
        productId: id,
        qty: 2,
        method: PaymentMethod.cash,
        fulfilment: Fulfilment.walkIn,
      );
      expect((await product(id)).stock, 40);

      // The other device sold 3 from the same 42 and saw 39. Its sale arrives
      // as an event, which is all a pull ever delivers.
      await db
          .into(db.sales)
          .insert(
            SalesCompanion.insert(
              id: 'sale-from-other-device',
              productId: id,
              qty: 3,
              unitPrice: 9200,
              total: 27600,
              method: PaymentMethod.cash,
              fulfilment: Fulfilment.walkIn,
              soldAt: DateTime.now(),
              synced: const Value(true),
            ),
          );
      await store.recomputeStock(id);

      // 42 - 2 - 3. Last-write-wins on an absolute total would have landed on
      // 40 or 39 here, losing one of the two sales.
      expect((await product(id)).stock, 37);
    });

    test('order of arrival does not matter', () async {
      final id = await addPalmOil(stock: 20);

      for (final (saleId, qty) in [('a', 4), ('b', 1), ('c', 6)]) {
        await db
            .into(db.sales)
            .insert(
              SalesCompanion.insert(
                id: saleId,
                productId: id,
                qty: qty,
                unitPrice: 9200,
                total: 9200 * qty,
                method: PaymentMethod.cash,
                fulfilment: Fulfilment.walkIn,
                soldAt: DateTime.now(),
                synced: const Value(true),
              ),
            );
      }
      await store.recomputeStock(id);
      final forwards = (await product(id)).stock;

      // Re-derive after deleting and re-inserting in the opposite order: the
      // result is a function of the set, not the sequence.
      await (db.delete(db.sales)..where((s) => s.productId.equals(id))).go();
      for (final (saleId, qty) in [('c', 6), ('b', 1), ('a', 4)]) {
        await db
            .into(db.sales)
            .insert(
              SalesCompanion.insert(
                id: saleId,
                productId: id,
                qty: qty,
                unitPrice: 9200,
                total: 9200 * qty,
                method: PaymentMethod.cash,
                fulfilment: Fulfilment.walkIn,
                soldAt: DateTime.now(),
                synced: const Value(true),
              ),
            );
      }
      await store.recomputeStock(id);

      expect(forwards, 9);
      expect((await product(id)).stock, forwards);
    });
  });

  group('what goes over the wire', () {
    test('a sale queues no product update', () async {
      final id = await addPalmOil();
      await (db.delete(db.outbox)).go(); // ignore the create traffic

      await store.recordSale(
        productId: id,
        qty: 2,
        method: PaymentMethod.cash,
        fulfilment: Fulfilment.walkIn,
      );

      final queued = (await db.select(db.outbox).get())
          .map((r) => '${r.entity}.${r.op}')
          .toList();
      expect(queued, ['sale.create']);
    });

    test('creating a product queues the opening event, and no stock', () async {
      await addPalmOil(stock: 42);

      final queued = await db.select(db.outbox).get();
      final kinds = queued.map((r) => '${r.entity}.${r.op}').toList();
      expect(kinds, containsAll(['stock_adjustment.create', 'product.create']));

      // The product payload carries no absolute total for anyone to overwrite.
      final productPush = queued.firstWhere((r) => r.entity == 'product');
      expect(productPush.payloadJson, isNot(contains('"stock"')));

      final openingPush = queued.firstWhere(
        (r) => r.entity == 'stock_adjustment',
      );
      expect(openingPush.payloadJson, contains('"delta":42'));
    });
  });

  test('v5 → v6 migration backfills openings so totals do not jump', () async {
    final dir = await Directory.systemTemp.createTemp('prosperflow_v6');
    final file = File('${dir.path}/app.db');
    addTearDown(() => dir.delete(recursive: true));

    // A v5 database holding a product that has already sold some stock: 12
    // left after selling 5, so it opened at 17.
    final raw = sqlite.sqlite3.open(file.path);
    raw.execute(_v5Schema);
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    raw.execute('''
      INSERT INTO products (id, name, unit, stock, buy_price, sell_price,
                            low_stock_threshold, updated_at, deleted, synced)
      VALUES ('p1', 'Palm Oil', 'bottles', 12, 6800, 9200, 10, $ts, 0, 1);
      INSERT INTO sales (id, product_id, qty, unit_price, total, method,
                         fulfilment, sold_at, synced)
      VALUES ('s1', 'p1', 5, 9200, 46000, 'cash', 'walkIn', $ts, 1);
    ''');
    raw.execute('PRAGMA user_version = 5;');
    raw.dispose();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    final upgradedStore = DriftStore(upgraded);

    final opening = await upgraded.select(upgraded.stockAdjustments).get();
    expect(opening.single.delta, 17, reason: '12 left + 5 sold');

    // The derived value has to equal what the trader already sees, or the
    // upgrade silently rewrites their books.
    await upgradedStore.recomputeStock('p1');
    final row = await (upgraded.select(
      upgraded.products,
    )..where((p) => p.id.equals('p1'))).getSingle();
    expect(row.stock, 12);
  });
}

/// The v5 schema, matching drift's generated DDL — everything before the
/// stock_adjustments table existed.
const _v5Schema = '''
CREATE TABLE products (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  unit TEXT NOT NULL,
  stock INTEGER NOT NULL,
  buy_price INTEGER NOT NULL,
  sell_price INTEGER NOT NULL,
  low_stock_threshold INTEGER NOT NULL DEFAULT 10,
  updated_at INTEGER NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0,
  synced INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE sales (
  id TEXT NOT NULL PRIMARY KEY,
  product_id TEXT NOT NULL,
  qty INTEGER NOT NULL,
  unit_price INTEGER NOT NULL,
  unit_cost INTEGER,
  list_price INTEGER,
  total INTEGER NOT NULL,
  method TEXT NOT NULL,
  fulfilment TEXT NOT NULL,
  customer_name TEXT,
  location TEXT,
  sold_at INTEGER NOT NULL,
  synced INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE expenses (
  id TEXT NOT NULL PRIMARY KEY,
  description TEXT NOT NULL,
  amount INTEGER NOT NULL,
  category TEXT NOT NULL,
  spent_on INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0,
  synced INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE credits (
  sale_id TEXT NOT NULL PRIMARY KEY,
  customer_name TEXT NOT NULL,
  amount INTEGER NOT NULL,
  product TEXT NOT NULL,
  status TEXT NOT NULL,
  sold_at INTEGER NOT NULL,
  paid_at INTEGER,
  updated_at INTEGER NOT NULL,
  synced INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE outbox (
  seq INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  entity TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  op TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE TABLE meta (
  key TEXT NOT NULL PRIMARY KEY,
  value TEXT NOT NULL
);
''';
