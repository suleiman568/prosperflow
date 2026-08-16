import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/data/db/app_database.dart';
import 'package:prosperflow/src/data/drift_store.dart';
import 'package:prosperflow/src/data/models.dart';
import 'package:prosperflow/src/sync/pull_ingest.dart';
import 'package:prosperflow/src/sync/sync_backend.dart';
import 'package:prosperflow/src/sync/sync_engine.dart';

/// A stand-in server that both devices share.
///
/// It keeps rows keyed by primary key and stamps each write with a watermark,
/// the way the trigger does, so pulls page in the same order the real one
/// serves. Deliberately paginates, because the bug a cursor has to survive
/// only appears at a page boundary.
class FakeServer {
  FakeServer({this.pageSize = 200});

  final int pageSize;
  final Map<String, Map<String, Map<String, dynamic>>> tables = {};
  var _tick = 0;

  static const _pk = {'credit': 'sale_id'};

  String _keyOf(String entity) => _pk[entity] ?? 'id';

  /// Writes a row as the server would, assigning the next watermark.
  void put(String entity, Map<String, dynamic> row, {DateTime? at}) {
    final stamped = {
      ...row,
      SupabaseSyncBackend.watermarkColumn: (at ?? _nextStamp())
          .toIso8601String(),
    };
    (tables[entity] ??= {})[row[_keyOf(entity)] as String] = stamped;
  }

  DateTime _nextStamp() =>
      DateTime.utc(2026, 1, 1).add(Duration(seconds: _tick++));

  List<Map<String, dynamic>> _ordered(String entity) {
    final key = _keyOf(entity);
    final rows = (tables[entity] ?? {}).values.toList();
    rows.sort((a, b) {
      final byTime = (a[SupabaseSyncBackend.watermarkColumn] as String)
          .compareTo(b[SupabaseSyncBackend.watermarkColumn] as String);
      return byTime != 0
          ? byTime
          : (a[key] as String).compareTo(b[key] as String);
    });
    return rows;
  }
}

class FakeBackend implements SyncBackend {
  FakeBackend(this.server);

  final FakeServer server;
  final pulls = <String>[];

  /// Runs when a page is fetched, before it is handed back. Lets a test drop
  /// something — a sign-in, a delay — into the middle of a sync, which is the
  /// only place the interesting races live.
  Future<void> Function()? onFetch;

  @override
  bool get canPush => true;

  @override
  Future<void> apply(
    String entity,
    String op,
    Map<String, dynamic> payload, {
    required String trader,
  }) async => server.put(entity, payload);

  @override
  Future<PullPage> fetchSince(
    String entity,
    PullCursor? cursor, {
    int limit = 200,
  }) async {
    pulls.add(entity);
    await onFetch?.call();
    final key = server._keyOf(entity);
    var rows = server._ordered(entity);

    if (cursor != null) {
      final at = cursor.watermark.toUtc().toIso8601String();
      rows = rows.where((r) {
        final stamp = r[SupabaseSyncBackend.watermarkColumn] as String;
        if (cursor.lastId == null) return stamp.compareTo(at) >= 0;
        final cmp = stamp.compareTo(at);
        return cmp > 0 ||
            (cmp == 0 && (r[key] as String).compareTo(cursor.lastId!) > 0);
      }).toList();
    }

    final page = rows.take(server.pageSize).toList();
    if (page.length < server.pageSize) {
      return PullPage(rows: page, cursor: null);
    }
    final last = page.last;
    return PullPage(
      rows: page,
      cursor: PullCursor(
        DateTime.parse(last[SupabaseSyncBackend.watermarkColumn] as String),
        last[key] as String,
      ),
    );
  }
}

/// One trader's phone.
///
/// The database is claimed on construction, as it is on every path into the
/// signed-in app. The engine attributes its writes to whoever owns the
/// database, so an unclaimed one syncs nothing.
class Device {
  Device(this.server, {int pageSize = 200, this.trader = 'trader-a'}) {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftStore(db);
    claimed = store.bindToTrader(trader);
    backend = FakeBackend(server);
    connectivity = StreamController<bool>.broadcast();
    engine = DriftSyncEngine(
      db,
      backend,
      connectivity: connectivity.stream,
      ingest: PullIngest(db, store),
    );
  }

  final FakeServer server;
  final String trader;
  late final AppDatabase db;
  late final DriftStore store;
  late final FakeBackend backend;
  late final StreamController<bool> connectivity;
  late final DriftSyncEngine engine;

  /// Completes once the database has been claimed. Awaited by [sync] so the
  /// tests need not think about it.
  late final Future<void> claimed;

  Future<List<Product>> products() => store.watchProducts().first;

  /// Claims the database if that has not finished, then syncs.
  Future<SyncResult> sync() async {
    await claimed;
    return engine.syncNow();
  }

  Future<void> dispose() async {
    engine.dispose();
    await connectivity.close();
    await db.close();
  }
}

void main() {
  late FakeServer server;

  setUp(() => server = FakeServer());

  group('a new phone for an existing trader', () {
    test('pulls the whole ledger it had no idea about', () async {
      // The trader's first phone builds a ledger and pushes it.
      final first = Device(server);
      addTearDown(first.dispose);
      await first.store.addProduct(
        name: 'Palm Oil',
        unit: 'bottles',
        stock: 42,
        buyPrice: 6800,
        sellPrice: 9200,
      );
      final productId = (await first.products()).single.id;
      await first.store.recordSale(
        productId: productId,
        qty: 5,
        method: PaymentMethod.cash,
        fulfilment: Fulfilment.walkIn,
      );
      await first.sync();

      // A replacement phone: empty database, same account. This is the case
      // that used to show an empty ledger forever.
      final replacement = Device(server);
      addTearDown(replacement.dispose);
      expect(await replacement.products(), isEmpty);

      final result = await replacement.sync();

      expect(result.pulledRows, greaterThan(0));
      final restored = await replacement.products();
      expect(restored.single.name, 'Palm Oil');
      // Stock came back derived from the events, not copied as a total.
      expect(restored.single.stock, 37);
      expect(
        await replacement.db.select(replacement.db.sales).get(),
        hasLength(1),
      );
    });

    test('a second pull brings down nothing new', () async {
      final first = Device(server);
      addTearDown(first.dispose);
      await first.store.addProduct(
        name: 'Palm Oil',
        unit: 'bottles',
        stock: 10,
        buyPrice: 6800,
        sellPrice: 9200,
      );
      await first.sync();

      final second = Device(server);
      addTearDown(second.dispose);
      await second.sync();
      final afterFirst = await second.products();

      final again = await second.sync();

      // The overlap window re-covers a few rows on purpose; what matters is
      // that ingesting them again changes nothing.
      expect(await second.products(), hasLength(afterFirst.length));
      expect(again.failed, isFalse);
    });
  });

  group('two phones on one stall', () {
    test('concurrent sales both survive the round trip', () async {
      final a = Device(server);
      final b = Device(server);
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      await a.store.addProduct(
        name: 'Palm Oil',
        unit: 'bottles',
        stock: 42,
        buyPrice: 6800,
        sellPrice: 9200,
      );
      await a.sync();
      await b.sync();
      final productId = (await b.products()).single.id;
      expect((await b.products()).single.stock, 42);

      // Neither has synced since; each sells from what it believes is 42.
      await a.store.recordSale(
        productId: productId,
        qty: 2,
        method: PaymentMethod.cash,
        fulfilment: Fulfilment.walkIn,
      );
      await b.store.recordSale(
        productId: productId,
        qty: 3,
        method: PaymentMethod.cash,
        fulfilment: Fulfilment.walkIn,
      );
      expect((await a.products()).single.stock, 40);
      expect((await b.products()).single.stock, 39);

      // Both sync, then both sync again so each sees the other's sale.
      await a.sync();
      await b.sync();
      await a.sync();

      // 42 - 2 - 3. A pushed absolute total would have left 40 or 39 here,
      // depending on who wrote last, and one sale would be gone from the count.
      expect((await a.products()).single.stock, 37);
      expect((await b.products()).single.stock, 37);
    });
  });

  group('paging', () {
    test('a cursor does not skip rows that share a watermark', () async {
      // Every row written in one transaction shares a stamp. Three of them
      // straddling a page boundary is exactly where a timestamp-only cursor
      // loses rows.
      final sameInstant = DateTime.utc(2026, 3, 1);
      for (final id in ['e1', 'e2', 'e3', 'e4']) {
        server.put('expense', {
          'id': id,
          'description': 'Transport $id',
          'amount': 500,
          'category': 'transport',
          'spent_on': sameInstant.toIso8601String(),
          'updated_at': sameInstant.toIso8601String(),
          'deleted': false,
        }, at: sameInstant);
      }

      final device = Device(
        FakeServer(pageSize: 2)..tables.addAll(server.tables),
      );
      addTearDown(device.dispose);

      await device.sync();

      final expenses = await device.db.select(device.db.expenses).get();
      expect(expenses, hasLength(4), reason: 'no row lost at the boundary');
    });
  });

  group('a pulled product keeps its stock', () {
    test('ingesting a product leaves the cache settled', () async {
      final device = Device(server);
      addTearDown(device.dispose);
      final ingest = PullIngest(device.db, device.store);
      await device.claimed;

      // The upsert cannot carry a stock value — it is derived, and the wire
      // has none — so the row lands at a placeholder zero.
      await ingest.apply('product', [
        {
          'id': 'p1',
          'name': 'Palm Oil',
          'unit': 'bottles',
          'buy_price': 6800,
          'sell_price': 9200,
          'low_stock_threshold': 10,
          'updated_at': DateTime.utc(2026).toIso8601String(),
          'deleted': false,
        },
      ], trader: device.trader);
      await ingest.apply('stock_adjustment', [
        {
          'id': 'a1',
          'product_id': 'p1',
          'delta': 42,
          'reason': 'opening',
          'created_at': DateTime.utc(2026).toIso8601String(),
        },
      ], trader: device.trader);

      // Settlement is told nothing about what changed and works it out from
      // the events, which is what lets it run after a pull that died.
      await ingest.settleStock();

      expect((await device.products()).single.stock, 42);
    });

    test('a pull that dies part-way still settles what landed', () async {
      // The case a per-pull settlement list cannot survive, and it needs
      // setting up precisely: the rewind re-covers the newest rows every
      // time, so a product only stays broken when the cursor has moved well
      // past it. Watermarks are stamped an hour apart for that reason —
      // seconds apart, the two-minute rewind would rescue everything by luck
      // and this test would pass with the bug in place.
      final t0 = DateTime.utc(2026, 3, 1);
      final t1 = t0.add(const Duration(hours: 1));
      final t2 = t0.add(const Duration(hours: 2));
      final t3 = t0.add(const Duration(hours: 3));

      void putProduct(String id, String name, DateTime at) =>
          server.put('product', {
            'id': id,
            'name': name,
            'unit': 'bottles',
            'buy_price': 6800,
            'sell_price': 9200,
            'low_stock_threshold': 10,
            'updated_at': at.toIso8601String(),
            'deleted': false,
          }, at: at);

      void putOpening(String id, String productId, int delta, DateTime at) =>
          server.put('stock_adjustment', {
            'id': id,
            'product_id': productId,
            'delta': delta,
            'reason': 'opening',
            'created_at': at.toIso8601String(),
          }, at: at);

      putProduct('p1', 'Palm Oil', t0);
      putOpening('a1', 'p1', 42, t0);
      putProduct('p2', 'Rice', t1);
      putOpening('a2', 'p2', 7, t1);

      final device = Device(server);
      addTearDown(device.dispose);
      await device.sync();
      expect(
        {for (final p in await device.products()) p.name: p.stock},
        {'Palm Oil': 42, 'Rice': 7},
      );

      // Both are renamed elsewhere. Neither edit carries stock — the wire
      // never does — so each upsert drops its row back to the placeholder.
      putProduct('p1', 'Palm Oil (25L)', t2);
      putProduct('p2', 'Rice (50kg)', t3);

      // The pull dies after the products land, before it finishes.
      device.backend.onFetch = () async {
        if (device.backend.pulls.last != 'product') {
          throw Exception('connection dropped');
        }
      };
      expect((await device.sync()).failed, isTrue, reason: 'the pull must die');

      // The next pull cannot repair p1 by re-fetching it: the product cursor
      // now sits at t3 and rewinds two minutes, which reaches p2 and nothing
      // else, and p1's only stock event is three hours behind the adjustment
      // cursor. Nothing will ever fetch either of them again.
      device.backend.onFetch = null;
      await device.sync();

      // Stock is derived from events this device already holds. A pull that
      // died is no reason to show the trader an empty shelf.
      expect(
        {for (final p in await device.products()) p.name: p.stock},
        {'Palm Oil (25L)': 42, 'Rice (50kg)': 7},
      );
    });

    test('an edit with no stock event still settles the cache', () async {
      final first = Device(server);
      addTearDown(first.dispose);
      await first.store.addProduct(
        name: 'Palm Oil',
        unit: 'bottles',
        stock: 42,
        buyPrice: 6800,
        sellPrice: 9200,
      );
      await first.sync();

      final second = Device(server);
      addTearDown(second.dispose);
      await second.sync();
      expect((await second.products()).single.stock, 42);

      // Another device renames it. Nothing about stock changed, so the pull
      // carries no sale and no adjustment — and the wire has never carried a
      // stock value for the upsert to restore.
      final productId = (await second.products()).single.id;
      server.put('product', {
        'id': productId,
        'name': 'Palm Oil (25L)',
        'unit': 'bottles',
        'buy_price': 6800,
        'sell_price': 9200,
        'low_stock_threshold': 10,
        'updated_at': DateTime.utc(2027).toIso8601String(),
        'deleted': false,
      });

      await second.sync();

      final after = (await second.products()).single;
      expect(after.name, 'Palm Oil (25L)');
      expect(after.stock, 42, reason: 'the rename must not zero the cache');
    });
  });

  group('local work is protected', () {
    test('a pull does not overwrite something not yet pushed', () async {
      final device = Device(server);
      addTearDown(device.dispose);

      await device.store.addProduct(
        name: 'Palm Oil',
        unit: 'bottles',
        stock: 10,
        buyPrice: 6800,
        sellPrice: 9200,
      );
      final productId = (await device.products()).single.id;
      await device.sync();

      // An older copy is waiting on the server while the trader renames it
      // locally and has not pushed yet.
      server.put('product', {
        'id': productId,
        'name': 'Stale Name',
        'unit': 'bottles',
        'buy_price': 6800,
        'sell_price': 9200,
        'low_stock_threshold': 10,
        'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
        'deleted': false,
      });
      await (device.db.update(
        device.db.products,
      )..where((p) => p.id.equals(productId))).write(
        const ProductsCompanion(
          name: Value('Renamed Locally'),
          synced: Value(false),
        ),
      );

      await device.sync();

      // The rename is the trader's most recent intent; the push settles it.
      expect((await device.products()).single.name, 'Renamed Locally');
    });
  });

  /// The phone is shared, and the sync engine is built once at startup rather
  /// than per session — so a sign-in can land in the middle of a sync that is
  /// still writing. Everything the engine writes is attributed to the trader
  /// it started as, and stops the moment the database belongs to someone else.
  group('the phone changes hands mid-sync', () {
    test('the outgoing trader rows do not land in the new ledger', () async {
      // trader-a's ledger, already on the server.
      final a = Device(server);
      addTearDown(a.dispose);
      await a.store.addProduct(
        name: 'Palm Oil',
        unit: 'bottles',
        stock: 42,
        buyPrice: 6800,
        sellPrice: 9200,
      );
      await a.sync();

      // The same phone starts a pull as trader-a, and trader-b signs in while
      // the page is in flight — after it was fetched, before it is written.
      final phone = Device(server);
      addTearDown(phone.dispose);
      await phone.claimed;
      phone.backend.onFetch = () async {
        phone.backend.onFetch = null;
        await phone.store.bindToTrader('trader-b');
      };

      await phone.sync();

      // trader-b is looking at this screen. None of trader-a's ledger may be
      // on it, whatever was already in flight when they signed in.
      expect(await phone.products(), isEmpty);
      expect(await phone.db.select(phone.db.sales).get(), isEmpty);
      expect(await phone.db.select(phone.db.stockAdjustments).get(), isEmpty);
    });

    test('the new trader sync is not swallowed by the running one', () async {
      final device = Device(server);
      addTearDown(device.dispose);
      await device.claimed;

      // Hold the first sync open, so the second is asked for while it runs.
      final held = Completer<void>();
      var first = true;
      device.backend.onFetch = () async {
        if (!first) return;
        first = false;
        await held.future;
      };

      final running = device.engine.syncNow();
      await pumpEventQueue();

      // This is the sign-in kick. Dropped, the trader taking the phone over
      // sits on an empty ledger until some unrelated trigger fires.
      await device.engine.syncNow();
      held.complete();
      await running;
      await pumpEventQueue();

      expect(
        device.backend.pulls.where((e) => e == 'product'),
        hasLength(greaterThan(1)),
        reason: 'the deferred request should run once the first lets go',
      );
    });

    test('cursors are keyed per trader, so one cannot become another', () async {
      final device = Device(server);
      addTearDown(device.dispose);
      await device.store.addProduct(
        name: 'Palm Oil',
        unit: 'bottles',
        stock: 5,
        buyPrice: 6800,
        sellPrice: 9200,
      );
      await device.sync();

      // A cursor claims "this device holds everything up to here" about one
      // ledger, so it is nonsense applied to another. Naming the trader in the
      // key means a straggling write from a sync that is still unwinding lands
      // somewhere the next trader never reads, rather than silently becoming
      // their starting position and skipping their history.
      final keys = (await device.db.select(device.db.meta).get())
          .map((m) => m.key)
          .where((k) => k.startsWith(DriftStore.cursorKeyPrefix));
      expect(keys, isNotEmpty);
      expect(keys.every((k) => k.contains(device.trader)), isTrue);
    });
  });

  test('pulled rows are not pushed straight back', () async {
    final first = Device(server);
    addTearDown(first.dispose);
    await first.store.addProduct(
      name: 'Palm Oil',
      unit: 'bottles',
      stock: 10,
      buyPrice: 6800,
      sellPrice: 9200,
    );
    await first.sync();

    final second = Device(server);
    addTearDown(second.dispose);
    await second.sync();

    // Ingest writes the tables directly rather than through DataStore, which
    // would queue every pulled row straight back to the server it came from.
    expect(await second.db.select(second.db.outbox).get(), isEmpty);
    expect(second.backend.server.tables['product'], hasLength(1));

    // And it marks them synced, because they are. Left unsynced they would be
    // mistaken for the trader's own unpushed work on the next pull, and then
    // never updated again.
    final pulledProducts = await second.db.select(second.db.products).get();
    expect(pulledProducts, isNotEmpty);
    expect(pulledProducts.every((p) => p.synced), isTrue);
    final pulledAdjustments = await second.db
        .select(second.db.stockAdjustments)
        .get();
    expect(pulledAdjustments, isNotEmpty);
    expect(pulledAdjustments.every((a) => a.synced), isTrue);
  });
}
