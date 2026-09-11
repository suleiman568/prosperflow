import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/auth/auth_service.dart';
import 'package:prosperflow/src/data/app_scope.dart';
import 'package:prosperflow/src/data/db/app_database.dart';
import 'package:prosperflow/src/data/drift_store.dart';
import 'package:prosperflow/src/data/memory_store.dart';
import 'package:prosperflow/src/data/data_store.dart';
import 'package:prosperflow/src/data/models.dart';
import 'package:prosperflow/src/startup.dart';
import 'package:prosperflow/src/sync/sync_backend.dart';
import 'package:prosperflow/src/sync/sync_engine.dart';

import 'seed_data.dart';
import 'telemetry_sites_test.dart' show FailingBackend;
import 'telemetry_test.dart' show RecordingErrorReporter;

/// These test the *wiring*, not the reporting.
///
/// `telemetry_sites_test.dart` proves that each site reports, but it does so by
/// handing the engine a reporter itself. That passes on an app where nothing
/// ever hands the engine one — which is exactly what shipped: `connectBackend`
/// built the engine without a reporter, the constructor's
/// `const NoopErrorReporter()` default filled the gap silently, and all three
/// sync-side sites discarded their reports on every real phone while the suite
/// stayed green.
///
/// So nothing below injects a reporter into an engine. Each test goes through
/// the real production function and stubs only what cannot run in a test: the
/// Supabase client and the connectivity stream.
void main() {
  group('the reporter reaches the sync engine through the real wiring', () {
    late AppDatabase db;
    late StreamController<bool> connectivity;
    late RecordingErrorReporter reporter;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      connectivity = StreamController<bool>.broadcast();
      reporter = RecordingErrorReporter();
      await seedDatabase(db);
      await DriftStore(db).bindToTrader('trader-a');
    });

    Future<void> queueASale(DataStore store) async {
      final product = (await store.watchProducts().first).first;
      await store.recordSale(
        productId: product.id,
        qty: 1,
        method: PaymentMethod.cash,
        fulfilment: Fulfilment.walkIn,
      );
    }

    tearDown(() async {
      await connectivity.close();
      await db.close();
    });

    /// Calls [connectBackend] itself — the function `main()` calls — with only
    /// the outside world replaced.
    Future<Startup> connect({required Object Function() failWith}) {
      return connectBackend(
        db: db,
        store: DriftStore(db),
        reporter: reporter,
        connect: () async => BackendConnection(
          auth: FakeAuthService(signedIn: true),
          backend: FailingBackend(onApply: failWith),
          connectivity: connectivity.stream,
          initiallyOnline: true,
        ),
      );
    }

    test('a sync failure from the wired-up engine is reported', () async {
      final startup = await connect(
        failWith: () => StateError('the server fell over'),
      );

      final ready = startup as StartupReady;
      await queueASale(ready.store);
      await ready.sync.syncNow();

      // The assertion that would have caught the shipped bug. Delete
      // `reporter: reporter` from the DriftSyncEngine call in
      // `connectBackend` and this is empty.
      expect(
        reporter.issues.map((i) => i.kind),
        contains('sync_failed'),
        reason:
            'the engine connectBackend builds must report through the '
            'reporter it was given, not through the discarding default',
      );
    });

    test('and so is a refused write', () async {
      final startup = await connect(
        failWith: () => WriteRefused('sales', 's-wiring'),
      );

      final ready = startup as StartupReady;
      await queueASale(ready.store);
      await ready.sync.syncNow();

      expect(reporter.issues.map((i) => i.kind), contains('write_refused'));
    });

    test('the web preview is still allowed its silent stand-ins', () async {
      // Not a regression of the above: no database means the design preview,
      // where there is no engine to report from and nothing to report to.
      final startup = await connectBackend(
        db: null,
        store: MemoryStore(),
        reporter: reporter,
      );

      expect((startup as StartupReady).sync, isA<NoopSyncEngine>());
      expect(reporter.issues, isEmpty);
    });
  });

  group('a failure to claim the database is a startup failure', () {
    late AppDatabase db;
    late StreamController<bool> connectivity;
    late RecordingErrorReporter reporter;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      connectivity = StreamController<bool>.broadcast();
      reporter = RecordingErrorReporter();
      await seedDatabase(db);
    });

    tearDown(() async {
      await connectivity.close();
      await db.close();
    });

    Future<Startup> startUpWith(DataStore store) async {
      // Signed in for real, not just flagged: `traderId` is what binding keys
      // off, and `FakeAuthService` only has one once `signIn` has run. Without
      // it the bind returns early and this group would test nothing.
      final auth = FakeAuthService();
      await auth.signIn(email: 'ada@market.ng', password: 'password');
      return startUp(
        db: db,
        store: store,
        reporter: reporter,
        connect: () async => BackendConnection(
          auth: auth,
          backend: FailingBackend(),
          connectivity: connectivity.stream,
          initiallyOnline: true,
        ),
      );
    }

    test('rather than an exception that escapes with nowhere to go', () async {
      final startup = await startUpWith(_UnclaimableStore());

      // Uncaught, this escaped before any state was assigned, and the trader
      // sat on the connecting spinner indefinitely — no message, no retry,
      // nothing to do but force-quit. There is no half-started state worth
      // showing: the app cannot know whose ledger it holds.
      expect(
        startup,
        isA<StartupFailed>(),
        reason:
            'the failure screen and its retry already exist — a bind failure '
            'must reach them rather than hang before the first frame',
      );
      expect(
        (startup as StartupFailed).error.toString(),
        contains('disk is full'),
      );
    });

    test('and it is reported, not only shown', () async {
      await startUpWith(_UnclaimableStore());

      expect(reporter.issues.map((i) => i.kind), contains('startup_failed'));
    });

    test('a startup that binds cleanly is still ready', () async {
      // The guard must not swallow the working case into a failure screen.
      final startup = await startUpWith(DriftStore(db));

      expect(startup, isA<StartupReady>());
      expect(reporter.issues, isEmpty);

      // Binding leaves a sync running on purpose — it is what fills a fresh
      // install. Let it finish and shut it down, or it outlives the test and
      // runs into the closed database in teardown.
      final ready = startup as StartupReady;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      ready.sync.dispose();
    });
  });

  group('reports are attributed to whoever is signed in', () {
    test('binding attaches the trader', () async {
      final reporter = RecordingErrorReporter();
      final auth = FakeAuthService();
      await auth.signIn(email: 'ada@market.ng', password: 'password');

      await bindLocalDataToTrader(MemoryStore(), auth, reporter: reporter);

      // Every path into the signed-in app goes through this one function, so
      // attaching here covers sign-in and sign-up, not only the restored
      // session that bootstrap handles.
      expect(reporter.trader, auth.traderId);
    });

    test(
      'a handover re-attributes rather than keeping the first trader',
      () async {
        final reporter = RecordingErrorReporter();
        final auth = FakeAuthService();
        final store = MemoryStore();

        await auth.signIn(email: 'ada@market.ng', password: 'password');
        await bindLocalDataToTrader(store, auth, reporter: reporter);
        final first = reporter.trader;

        await auth.signIn(email: 'chidi@market.ng', password: 'password');
        await bindLocalDataToTrader(store, auth, reporter: reporter);

        expect(reporter.trader, isNot(first));
        expect(reporter.trader, auth.traderId);
      },
    );

    test('signed out, nobody is attached', () async {
      final reporter = RecordingErrorReporter();

      await bindLocalDataToTrader(
        MemoryStore(),
        FakeAuthService(),
        reporter: reporter,
      );

      expect(reporter.trader, isNull);
      expect(
        reporter.traderWrites,
        isEmpty,
        reason: 'nothing to attach, so nothing should be written',
      );
    });
  });
}

/// A store that cannot be claimed. Stands in for the real reasons this throws
/// on a phone — a corrupt database file, a migration that will not apply, a
/// disk with nothing left on it.
class _UnclaimableStore extends MemoryStore {
  @override
  Future<void> bindToTrader(String traderId) async =>
      throw StateError('disk is full');
}
