import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:prosperflow/src/data/db/app_database.dart';
import 'package:prosperflow/src/data/drift_store.dart';
import 'package:prosperflow/src/data/models.dart';

/// Hand-written copy of the v2 schema (before sales.unit_cost existed),
/// matching drift's generated DDL: snake_case columns, dateTimes as INTEGER.
const _v2Schema = '''
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
  seq INTEGER PRIMARY KEY AUTOINCREMENT,
  entity TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  op TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
''';

void main() {
  test('v2 → v3 migration adds sales.unit_cost and keeps old rows readable',
      () async {
    final dir = await Directory.systemTemp.createTemp('prosperflow_migration');
    final file = File('${dir.path}/app.db');
    addTearDown(() => dir.delete(recursive: true));

    // Build a real v2 database with one pre-migration sale in it.
    final raw = sqlite.sqlite3.open(file.path);
    raw.execute(_v2Schema);
    final soldAt =
        DateTime.now().millisecondsSinceEpoch ~/ 1000; // drift stores seconds
    raw.execute('''
      INSERT INTO products
        (id, name, unit, stock, buy_price, sell_price, updated_at, synced)
      VALUES ('p-legacy', 'Palm Oil (25L)', 'bottles', 10, 6800, 9200,
              $soldAt, 1);
    ''');
    raw.execute('''
      INSERT INTO sales
        (id, product_id, qty, unit_price, total, method, fulfilment,
         sold_at, synced)
      VALUES ('s-legacy', 'p-legacy', 2, 9200, 18400, 'cash', 'walkIn',
              $soldAt, 1);
    ''');
    raw.execute('PRAGMA user_version = 2;');
    raw.dispose();

    // Opening the app database runs onUpgrade 2 → 3.
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final columns = await db
        .customSelect('PRAGMA table_info(sales)')
        .get()
        .then((rows) => rows.map((r) => r.data['name']).toList());
    expect(columns, contains('unit_cost'));

    // The pre-migration sale survives, with no cost (profit unknowable).
    final legacy = await (db.select(db.sales)
          ..where((s) => s.id.equals('s-legacy')))
        .getSingle();
    expect(legacy.unitCost, isNull);
    expect(legacy.total, 18400);

    // New sales written after the upgrade snapshot the cost.
    final store = DriftStore(db);
    await store.recordSale(
      productId: 'p-legacy',
      qty: 1,
      method: PaymentMethod.cash,
      fulfilment: Fulfilment.walkIn,
    );
    final rows = await (db.select(db.sales)
          ..where((s) => s.id.equals('s-legacy').not()))
        .get();
    expect(rows.single.unitCost, 6800);
  });

  test('v3 → v4 migration adds sales.list_price and keeps old rows readable',
      () async {
    final dir = await Directory.systemTemp.createTemp('prosperflow_v4');
    final file = File('${dir.path}/app.db');
    addTearDown(() => dir.delete(recursive: true));

    // A v3 database: the v2 schema plus unit_cost, at user_version 3.
    final v3Schema = _v2Schema.replaceFirst(
        'unit_price INTEGER NOT NULL,',
        'unit_price INTEGER NOT NULL,\n  unit_cost INTEGER,');
    final raw = sqlite.sqlite3.open(file.path);
    raw.execute(v3Schema);
    final soldAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    raw.execute('''
      INSERT INTO products
        (id, name, unit, stock, buy_price, sell_price, updated_at, synced)
      VALUES ('p-v3', 'Palm Oil (25L)', 'bottles', 10, 6800, 9200,
              $soldAt, 1);
    ''');
    raw.execute('''
      INSERT INTO sales
        (id, product_id, qty, unit_price, unit_cost, total, method,
         fulfilment, sold_at, synced)
      VALUES ('s-v3', 'p-v3', 1, 9200, 6800, 9200, 'cash', 'walkIn',
              $soldAt, 1);
    ''');
    raw.execute('PRAGMA user_version = 3;');
    raw.dispose();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final columns = await db
        .customSelect('PRAGMA table_info(sales)')
        .get()
        .then((rows) => rows.map((r) => r.data['name']).toList());
    expect(columns, contains('list_price'));

    // Pre-v4 sales read back with no list price (sold at normal price).
    final legacy = await (db.select(db.sales)
          ..where((s) => s.id.equals('s-v3')))
        .getSingle();
    expect(legacy.listPrice, isNull);
    expect(legacy.unitCost, 6800);

    // Discounted sales recorded after the upgrade keep the normal price.
    final store = DriftStore(db);
    await store.recordSale(
      productId: 'p-v3',
      qty: 1,
      method: PaymentMethod.cash,
      fulfilment: Fulfilment.walkIn,
      unitPrice: 8700,
    );
    final discounted = await (db.select(db.sales)
          ..where((s) => s.id.equals('s-v3').not()))
        .get();
    expect(discounted.single.listPrice, 9200);
    expect(discounted.single.unitPrice, 8700);
  });
}
