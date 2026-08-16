import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:prosperflow/src/auth/auth_service.dart';
import 'package:prosperflow/src/data/app_scope.dart';
import 'package:prosperflow/src/data/db/app_database.dart';
import 'package:prosperflow/src/data/drift_store.dart';
import 'package:prosperflow/src/data/memory_store.dart';

import 'helpers.dart';
import 'seed_data.dart';

/// A phone holds one trader's books. Isolation comes from owning the whole
/// database rather than filtering per row, so signing in as someone else has
/// to clear it — otherwise the new trader reads the previous one's ledger,
/// and any edit they make to it is refused by row-level security and then
/// dropped without a trace.
void main() {
  group('DriftStore.bindToTrader', () {
    late AppDatabase db;
    late DriftStore store;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      store = DriftStore(db);
      await seedDatabase(db);
    });

    tearDown(() => db.close());

    Future<int> productCount() async =>
        (await db.select(db.products).get()).length;
    Future<int> outboxCount() async =>
        (await db.select(db.outbox).get()).length;

    test('an unowned database is adopted, not wiped', () async {
      // A fresh install, or one upgrading from before ownership was tracked:
      // whatever is here already belongs to whoever is signing in.
      final before = await productCount();
      expect(before, greaterThan(0));

      await store.bindToTrader('trader-a');

      expect(await productCount(), before);
    });

    test('re-binding the same trader changes nothing', () async {
      await store.bindToTrader('trader-a');
      final before = await productCount();

      await store.bindToTrader('trader-a');

      expect(await productCount(), before);
    });

    test('a different trader gets an empty ledger', () async {
      await store.bindToTrader('trader-a');
      expect(await productCount(), greaterThan(0));

      await store.bindToTrader('trader-b');

      expect(await productCount(), 0);
      expect((await db.select(db.sales).get()), isEmpty);
      expect((await db.select(db.expenses).get()), isEmpty);
      expect((await db.select(db.credits).get()), isEmpty);
    });

    test('the previous trader queued work is dropped, not pushed', () async {
      await store.bindToTrader('trader-a');
      await store.addProduct(
        name: 'Palm Oil',
        unit: 'bottles',
        stock: 5,
        buyPrice: 6800,
        sellPrice: 9200,
      );
      expect(await outboxCount(), greaterThan(0));

      await store.bindToTrader('trader-b');

      // Pushing these under the new session would stamp them with the wrong
      // trader on insert, and be refused on update.
      expect(await outboxCount(), 0);
    });

    test('the previous trader stock events go too', () async {
      await store.bindToTrader('trader-a');
      await store.addProduct(
        name: 'Palm Oil',
        unit: 'bottles',
        stock: 5,
        buyPrice: 6800,
        sellPrice: 9200,
      );
      expect(await db.select(db.stockAdjustments).get(), isNotEmpty);

      await store.bindToTrader('trader-b');

      // Stock is derived from these, so leaving them behind would have the
      // new trader's products counting movements they never made.
      expect(await db.select(db.stockAdjustments).get(), isEmpty);
    });

    test('the pull cursors are cleared, but ownership is not', () async {
      await store.bindToTrader('trader-a');
      await db
          .into(db.meta)
          .insertOnConflictUpdate(
            MetaCompanion.insert(
              key: '${DriftStore.cursorKeyPrefix}product',
              value: '2026-03-01T00:00:00.000Z|p1',
            ),
          );

      await store.bindToTrader('trader-b');

      // A cursor means "this device has everything up to here", which was
      // true of the previous trader's ledger and says nothing about this
      // one's. Kept, the first pull resumes from a watermark it never
      // reached and silently skips everything the new trader wrote before it.
      final keys = (await db.select(db.meta).get()).map((m) => m.key);
      expect(keys, isNot(contains('${DriftStore.cursorKeyPrefix}product')));
      expect(keys, contains(DriftStore.traderKey));
    });

    test('ownership survives so the next sign-in is compared against it', () {
      return db.transaction(() async {
        await store.bindToTrader('trader-a');
        final owner = await (db.select(
          db.meta,
        )..where((m) => m.key.equals(DriftStore.traderKey))).getSingle();
        expect(owner.value, 'trader-a');
      });
    });
  });

  group('MemoryStore.bindToTrader', () {
    test(
      'matches DriftStore: adopt, then wipe on a different trader',
      () async {
        final store = MemoryStore(products: [palm, veg]);

        await store.bindToTrader('trader-a');
        expect(await store.watchProducts().first, hasLength(2));

        await store.bindToTrader('trader-a');
        expect(await store.watchProducts().first, hasLength(2));

        await store.bindToTrader('trader-b');
        expect(await store.watchProducts().first, isEmpty);
      },
    );
  });

  group('bindLocalDataToTrader', () {
    test('does nothing while signed out', () async {
      final store = MemoryStore(products: [palm]);
      final auth = FakeAuthService();

      await bindLocalDataToTrader(store, auth);

      expect(await store.watchProducts().first, hasLength(1));
    });

    test('claims the database for the signed-in trader', () async {
      final store = MemoryStore(products: [palm]);
      final auth = FakeAuthService();
      await auth.signIn(email: 'a@market.ng', password: 'password');

      await bindLocalDataToTrader(store, auth);
      expect(await store.watchProducts().first, hasLength(1));

      // Same phone, different trader.
      await auth.signIn(email: 'b@market.ng', password: 'password');
      await bindLocalDataToTrader(store, auth);

      expect(await store.watchProducts().first, isEmpty);
    });
  });

  test('v4 → v5 migration adds the meta table and keeps the ledger', () async {
    final dir = await Directory.systemTemp.createTemp('prosperflow_v5');
    final file = File('${dir.path}/app.db');
    addTearDown(() => dir.delete(recursive: true));

    // A v4 database: everything except the meta table, at user_version 4.
    final raw = sqlite.sqlite3.open(file.path);
    raw.execute(_v4Schema);
    final soldAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    raw.execute('''
      INSERT INTO products (id, name, unit, stock, buy_price, sell_price,
                            low_stock_threshold, updated_at, deleted, synced)
      VALUES ('p-legacy', 'Palm Oil', 'bottles', 12, 6800, 9200, 10,
              $soldAt, 0, 1);
    ''');
    raw.execute('PRAGMA user_version = 4;');
    raw.dispose();

    // Opening the app database runs onUpgrade 4 → 5.
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final store = DriftStore(db);

    // The ledger is untouched by the upgrade itself.
    expect((await db.select(db.products).get()).single.id, 'p-legacy');

    // And with no owner recorded, the first sign-in adopts rather than wipes.
    await store.bindToTrader('trader-a');
    expect((await db.select(db.products).get()).single.id, 'p-legacy');

    await store.bindToTrader('trader-b');
    expect(await db.select(db.products).get(), isEmpty);
  });
}

/// The v4 schema, matching drift's generated DDL (snake_case, dateTimes as
/// INTEGER) — everything before the meta table existed.
const _v4Schema = '''
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
''';
