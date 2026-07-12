import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/data/db/app_database.dart';
import 'package:prosperflow/src/data/drift_store.dart';
import 'package:prosperflow/src/data/memory_store.dart';
import 'package:prosperflow/src/data/models.dart';
import 'package:prosperflow/src/screens/dashboard/dashboard_screen.dart';
import 'package:prosperflow/src/sync/sync_backend.dart';
import 'package:prosperflow/src/sync/sync_engine.dart';

import 'helpers.dart';
import 'seed_data.dart';

class _RecordingBackend implements SyncBackend {
  final applied = <(String entity, String op, Map<String, dynamic> payload)>[];

  @override
  bool get canPush => true;

  @override
  Future<void> apply(
      String entity, String op, Map<String, dynamic> payload) async {
    applied.add((entity, op, payload));
  }
}

/// Data-integrity regressions: product deletion vs pending sales, sync
/// single-writer discipline, the negative-stock guard, and dashboard
/// freshness after mutations.
void main() {
  group('DriftStore', () {
    late AppDatabase db;
    late DriftStore store;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      store = DriftStore(db);
      await seedDatabase(db);
    });

    tearDown(() => db.close());

    test('overselling clamps stock at zero instead of going negative',
        () async {
      final water = (await store.watchProducts().first)
          .firstWhere((p) => p.name == 'Bottled Water (500ml)');
      expect(water.stock, 8);

      await store.recordSale(
        productId: water.id,
        qty: 50, // far more than in stock
        method: PaymentMethod.cash,
        fulfilment: Fulfilment.walkIn,
      );

      final after = (await store.watchProducts().first)
          .firstWhere((p) => p.id == water.id);
      expect(after.stock, 0);
      expect(after.stock, isNonNegative);
    });

    test(
        'deleting a product with a pending offline sale syncs safely: '
        'the sale flushes first and the product row survives (soft delete)',
        () async {
      final backend = _RecordingBackend();
      final connectivity = StreamController<bool>.broadcast();
      final engine = DriftSyncEngine(
        db,
        backend,
        connectivity: connectivity.stream,
        initiallyOnline: false, // queue everything while offline
        writeDebounce: const Duration(milliseconds: 1),
      );

      final palm = (await store.watchProducts().first)
          .firstWhere((p) => p.name == 'Palm Oil (25L)');

      await store.recordSale(
        productId: palm.id,
        qty: 2,
        method: PaymentMethod.cash,
        fulfilment: Fulfilment.walkIn,
      );
      await store.deleteProduct(palm.id);

      // Still offline: nothing must be pushed yet.
      await engine.syncNow();
      expect(backend.applied, isEmpty);

      connectivity.add(true);
      await pumpEventQueue(times: 50);

      // Everything flushed, strictly in write order: the sale reaches the
      // server before the soft-delete update, so it never references a
      // product the server hasn't seen the final state of.
      final ops = backend.applied.map((r) => '${r.$1}.${r.$2}').toList();
      expect(ops.indexOf('sale.create'),
          lessThan(ops.lastIndexOf('product.update')));
      final deletePayload = backend.applied
          .lastWhere((r) => r.$1 == 'product' && r.$2 == 'update')
          .$3;
      expect(deletePayload['deleted'], isTrue);
      expect(deletePayload['id'], palm.id);

      // No orphaned sale: deletion is soft, the product row still exists
      // locally (and the server only ever receives an update, not a delete).
      final row = await (db.select(db.products)
            ..where((p) => p.id.equals(palm.id)))
          .getSingle();
      expect(row.deleted, isTrue);

      final outbox = await db.select(db.outbox).get();
      expect(outbox, isEmpty);

      engine.dispose();
      await connectivity.close();
    });

    test('concurrent syncNow calls apply each outbox row exactly once',
        () async {
      final backend = _RecordingBackend();
      final connectivity = StreamController<bool>.broadcast();
      final engine = DriftSyncEngine(
        db,
        backend,
        connectivity: connectivity.stream,
        initiallyOnline: true,
        writeDebounce: const Duration(seconds: 30), // keep auto-sync out
      );

      final yam = (await store.watchProducts().first)
          .firstWhere((p) => p.name == 'Yam (per tuber)');
      await store.recordSale(
        productId: yam.id,
        qty: 1,
        method: PaymentMethod.cash,
        fulfilment: Fulfilment.walkIn,
      );

      // Two overlapping manual syncs: the _flushing guard must make the
      // second a no-op rather than a competing writer.
      await Future.wait([engine.syncNow(), engine.syncNow()]);
      await pumpEventQueue(times: 20);

      final saleCreates =
          backend.applied.where((r) => r.$1 == 'sale' && r.$2 == 'create');
      expect(saleCreates, hasLength(1));

      // Nothing left behind, nothing duplicated.
      expect(await db.select(db.outbox).get(), isEmpty);
      final pushedIds = backend.applied.map((r) => '${r.$1}:${r.$3['id']}');
      expect(pushedIds.toSet().length, pushedIds.length);

      engine.dispose();
      await connectivity.close();
    });
  });

  group('MemoryStore', () {
    test('overselling clamps stock at zero instead of going negative',
        () async {
      final store = MemoryStore(products: fixtureProducts);
      await store.recordSale(
        productId: veg.id, // stock 3
        qty: 99,
        method: PaymentMethod.cash,
        fulfilment: Fulfilment.walkIn,
      );

      final after =
          (await store.watchProducts().first).firstWhere((p) => p.id == veg.id);
      expect(after.stock, 0);
    });
  });

  testWidgets('dashboard stats update live after a sale is recorded',
      (tester) async {
    usePhoneSurface(tester);
    final store = fixtureStore();
    await pumpWithStore(tester, const DashboardScreen(), store: store);
    await tester.pump();

    expect(find.text('₦28,400'), findsOneWidget); // today, from fixtures
    expect(find.text('2 sales today'), findsOneWidget);

    await store.recordSale(
      productId: palm.id, // ₦9,200 each
      qty: 1,
      method: PaymentMethod.cash,
      fulfilment: Fulfilment.walkIn,
    );
    await tester.pumpAndSettle();

    // No manual refresh: the streams push the new totals to the dashboard.
    expect(find.text('₦37,600'), findsOneWidget);
    expect(find.text('3 sales today'), findsOneWidget);
  });
}
