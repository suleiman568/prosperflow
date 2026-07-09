import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/data/db/app_database.dart';
import 'package:prosperflow/src/data/drift_store.dart';
import 'package:prosperflow/src/data/models.dart';
import 'package:prosperflow/src/sync/sync_backend.dart';
import 'package:prosperflow/src/sync/sync_engine.dart';

class RecordingBackend implements SyncBackend {
  final applied = <(String, String, Map<String, dynamic>)>[];
  bool failNext = false;

  @override
  bool get canPush => true;

  @override
  Future<void> apply(
      String entity, String op, Map<String, dynamic> payload) async {
    if (failNext) {
      failNext = false;
      throw Exception('network down');
    }
    applied.add((entity, op, payload));
  }
}

void main() {
  late AppDatabase db;
  late DriftStore store;
  late RecordingBackend backend;
  late StreamController<bool> connectivity;
  late DriftSyncEngine engine;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftStore(db);
    backend = RecordingBackend();
    connectivity = StreamController<bool>.broadcast();
    await store.seedIfEmpty();
  });

  tearDown(() async {
    engine.dispose();
    await connectivity.close();
    await db.close();
  });

  DriftSyncEngine makeEngine({bool online = true}) => DriftSyncEngine(
        db,
        backend,
        connectivity: connectivity.stream,
        initiallyOnline: online,
        writeDebounce: const Duration(milliseconds: 10),
      );

  Future<String> firstProductId() async =>
      (await store.watchProducts().first).first.id;

  test('offline writes queue up; reconnect flushes them in order', () async {
    engine = makeEngine(online: false);
    final productId = await firstProductId();

    await store.recordSale(
      productId: productId,
      qty: 2,
      method: PaymentMethod.cash,
      fulfilment: Fulfilment.walkIn,
    );
    await store.recordSale(
      productId: productId,
      qty: 1,
      method: PaymentMethod.credit,
      fulfilment: Fulfilment.walkIn,
      customerName: 'Test Customer',
    );

    // Nothing pushed while offline; pending counts visible to the UI.
    var result = await engine.syncNow();
    expect(result.pushedSales, 0);
    expect(backend.applied, isEmpty);
    expect(engine.state.pendingSales, 2);
    expect(engine.state.pendingTotal, 5); // 2 sales + 2 stock + 1 credit

    // Reconnect → auto-flush.
    connectivity.add(true);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(engine.state.pendingTotal, 0);
    expect(engine.state.lastSyncAt, isNotNull);

    // Seq order: sale, product update, sale, product update, credit.
    expect(backend.applied.map((a) => '${a.$1}.${a.$2}').toList(), [
      'sale.create',
      'product.update',
      'sale.create',
      'product.update',
      'credit.create',
    ]);

    // The outbox is empty and rows are marked synced.
    expect(await db.select(db.outbox).get(), isEmpty);
    final sales = await db.select(db.sales).get();
    expect(sales.where((s) => !s.synced), isEmpty);
  });

  test('a failed push keeps the outbox and reports failure', () async {
    engine = makeEngine();
    final productId = await firstProductId();

    await store.recordSale(
      productId: productId,
      qty: 1,
      method: PaymentMethod.cash,
      fulfilment: Fulfilment.walkIn,
    );
    backend.failNext = true;

    final result = await engine.syncNow();
    expect(result.failed, isTrue);
    expect(await db.select(db.outbox).get(), isNotEmpty);

    // A later sync retries the same mutations successfully.
    final retry = await engine.syncNow();
    expect(retry.failed, isFalse);
    expect(retry.pushedSales, 1);
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test('marking a credit paid syncs the status update', () async {
    engine = makeEngine();
    final credit = (await store.watchOwedCredits().first).first;

    await store.markCreditPaid(credit.saleId);
    final result = await engine.syncNow();

    expect(result.failed, isFalse);
    final (entity, op, payload) = backend.applied.single;
    expect(entity, 'credit');
    expect(op, 'update');
    expect(payload['sale_id'], credit.saleId);
    expect(payload['status'], 'paid');
  });
}
