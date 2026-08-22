import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/data/db/app_database.dart';
import 'package:prosperflow/src/data/drift_store.dart';
import 'package:prosperflow/src/data/models.dart';
import 'package:prosperflow/src/sync/sync_backend.dart';
import 'package:prosperflow/src/sync/sync_engine.dart';

import 'seed_data.dart';
import 'telemetry_test.dart' show RecordingErrorReporter;

/// Fails whichever way the test asks it to.
class FailingBackend implements SyncBackend {
  FailingBackend({this.onApply, this.onFetch});

  final Object Function()? onApply;
  final Object Function()? onFetch;

  @override
  bool get canPush => true;

  @override
  Future<void> apply(
    String entity,
    String op,
    Map<String, dynamic> payload, {
    required String trader,
  }) async {
    final failure = onApply;
    if (failure != null) throw failure();
  }

  @override
  Future<PullPage> fetchSince(
    String entity,
    PullCursor? cursor, {
    int limit = 200,
  }) async {
    final failure = onFetch;
    if (failure != null) throw failure();
    return const PullPage(rows: [], cursor: null);
  }
}

void main() {
  late AppDatabase db;
  late DriftStore store;
  late StreamController<bool> connectivity;
  late RecordingErrorReporter reporter;
  DriftSyncEngine? engine;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftStore(db);
    connectivity = StreamController<bool>.broadcast();
    reporter = RecordingErrorReporter();
    await seedDatabase(db);
    await store.bindToTrader('trader-a');
  });

  tearDown(() async {
    engine?.dispose();
    await connectivity.close();
    await db.close();
  });

  DriftSyncEngine engineWith(SyncBackend backend) => engine = DriftSyncEngine(
    db,
    backend,
    connectivity: connectivity.stream,
    writeDebounce: const Duration(milliseconds: 10),
    reporter: reporter,
  );

  Future<void> queueASale() async {
    final product = (await store.watchProducts().first).first;
    await store.recordSale(
      productId: product.id,
      qty: 1,
      method: PaymentMethod.cash,
      fulfilment: Fulfilment.walkIn,
    );
  }

  group('a sync that fails', () {
    test('is reported with its cause instead of being discarded', () async {
      // `catch (_)` threw away the type, the message and the stack of every
      // sync failure the app ever had.
      final sync = engineWith(
        FailingBackend(onApply: () => Exception('connection reset')),
      );
      await queueASale();

      await sync.syncNow();

      expect(reporter.issues.map((i) => i.kind), contains('sync_failed'));
      final reported = reporter.issues.firstWhere(
        (i) => i.kind == 'sync_failed',
      );
      expect(reported.error.toString(), contains('connection reset'));
    });

    test(
      'says whether the trader was still waiting for their ledger',
      () async {
        final sync = engineWith(
          FailingBackend(onFetch: () => Exception('connection reset')),
        );
        await sync.refreshRestoreState();

        await sync.syncNow();

        final reported = reporter.issues.firstWhere(
          (i) => i.kind == 'sync_failed',
        );
        // The difference between an inconvenience and a trader staring at a
        // restore that never finishes.
        expect(reported.tags['restoring'], 'true');
      },
    );
  });

  group('a write the server refuses', () {
    test('is reported apart from the noise of dropped connections', () async {
      // The server is up and is refusing this write, so the retry will not
      // fix it: it means a permission problem, and the trader's edit sits in
      // the outbox until somebody notices.
      final sync = engineWith(
        FailingBackend(onApply: () => WriteRefused('products', 'p1')),
      );
      await queueASale();

      await sync.syncNow();

      final kinds = reporter.issues.map((i) => i.kind);
      expect(kinds, contains('write_refused'));
      expect(kinds, isNot(contains('sync_failed')));
      expect(
        reporter.issues.firstWhere((i) => i.kind == 'write_refused').tags,
        containsPair('table', 'products'),
      );
    });
  });

  group('a restore that will not finish', () {
    test('is reported once, after a few attempts, not on the first', () async {
      // One failure is a signal that came and went at the market. A phone
      // that cannot reach the server would otherwise report forever.
      final sync = engineWith(
        FailingBackend(onFetch: () => Exception('connection reset')),
      );
      await sync.refreshRestoreState();

      await sync.syncNow();
      expect(
        reporter.issues.map((i) => i.kind),
        isNot(contains('restore_stuck')),
        reason: 'one failed attempt is not a stuck restore',
      );

      await sync.syncNow();
      await sync.syncNow();
      await sync.syncNow();

      final stuck = reporter.issues.where((i) => i.kind == 'restore_stuck');
      expect(stuck, hasLength(1), reason: 'reported once per episode');
      expect(stuck.single.tags['attempts'], '3');
    });

    test('is not reported when the trader is not restoring', () async {
      final sync = engineWith(
        FailingBackend(onFetch: () => Exception('connection reset')),
      );
      await sync.refreshRestoreState(nothingToRestore: true);

      await sync.syncNow();
      await sync.syncNow();
      await sync.syncNow();
      await sync.syncNow();

      expect(
        reporter.issues.map((i) => i.kind),
        isNot(contains('restore_stuck')),
      );
    });
  });
}
