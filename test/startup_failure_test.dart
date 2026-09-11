import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/auth/auth_service.dart';
import 'package:prosperflow/src/data/db/app_database.dart';
import 'package:prosperflow/src/data/drift_store.dart';
import 'package:prosperflow/src/data/memory_store.dart';
import 'package:prosperflow/src/screens/dashboard/dashboard_screen.dart';
import 'package:prosperflow/src/screens/startup_failure_screen.dart';
import 'package:prosperflow/src/startup.dart';
import 'package:prosperflow/src/sync/sync_engine.dart';
import 'package:prosperflow/src/widgets/sync_widgets.dart';
import 'package:prosperflow/src/telemetry/error_reporter.dart';

import 'helpers.dart';

void main() {
  group('what the preview stand-ins would have told a trader', () {
    // These two are not hypothetical failures — they are what the app did on
    // any device where wiring up the backend threw, because the failure was
    // swallowed and the preview fakes were left in place. They are kept as
    // tests so the reason those fakes must never reach a phone is written
    // down next to them.

    test('the fake auth signs in anybody who types six characters', () async {
      final auth = FakeAuthService();

      final error = await auth.signIn(
        email: 'not-a-real-account@example.com',
        password: 'aaaaaa',
      );

      expect(error, isNull);
      expect(auth.isSignedIn, isTrue);
    });

    testWidgets('the no-op engine reports the ledger as backed up', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final sync = NoopSyncEngine(lastSyncAt: DateTime.now());

      await pumpWithStore(
        tester,
        Scaffold(body: SyncStatusRow(state: sync.state)),
        sync: sync,
      );
      await tester.pumpAndSettle();

      // On a phone that was syncing nothing at all, to a trader whose sales
      // existed only on that phone.
      expect(find.textContaining('Backed up'), findsOneWidget);
    });
  });

  group('starting up without a backend', () {
    testWidgets('says so, and offers to try again', (tester) async {
      usePhoneSurface(tester);
      var retries = 0;

      await tester.pumpWidget(StartupFailureScreen(onRetry: () => retries++));
      await tester.pumpAndSettle();

      expect(find.text("ProsperFlow can't start"), findsOneWidget);
      // The ledger is on the phone and is not lost — a trader who thinks it
      // is gone may start writing it out on paper, or reinstall.
      expect(find.textContaining('safe on the phone'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });

    testWidgets('never offers a way through to the ledger', (tester) async {
      usePhoneSurface(tester);

      await tester.pumpWidget(StartupFailureScreen(onRetry: () {}));
      await tester.pumpAndSettle();

      // Without a backend the app cannot tell who is signed in, so it cannot
      // know whose ledger to show. Letting somebody past this screen is how
      // the previous behaviour leaked one trader's books to whoever held the
      // phone next.
      expect(find.byType(DashboardScreen), findsNothing);
      expect(find.text('Sign in'), findsNothing);
    });

    test('the failure carries its cause, so it can be reported', () {
      // The cause is kept rather than discarded because the next change
      // reports it. `catch (_)` threw away the one thing that would have
      // said why a trader's phone never synced.
      final error = StateError('no backend');
      final stack = StackTrace.current;

      final failed = StartupFailed(error, stack);

      expect(failed.error, same(error));
      expect(failed.stackTrace, same(stack));
    });
  });

  group('a device whose backend will not start', () {
    // A plain test, not testWidgets: Supabase leaves platform-channel timers
    // pending when its channels are absent, and the widget binding waits for
    // those forever.
    test(
      'reports the failure instead of substituting the fakes',
      () async {
        // The real thing, not a simulation: with a real database and the real
        // config, Supabase.initialize throws here because its platform channels
        // are not available under test. That is the same shape of failure a
        // phone hits when the platform refuses it, and it is the case that used
        // to be swallowed.
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        // Run it under a zone guard, because part of this failure does not
        // come back as a returned value: supabase_flutter builds its storage
        // in a constructor, and the platform channel's rejection escapes as an
        // unawaited error. On a phone today that error has nowhere to go —
        // which is the argument for the zone guard going in next.
        Startup? startup;
        final escaped = <Object>[];
        await runZonedGuarded(() async {
          startup = await connectBackend(
            db: db,
            store: DriftStore(db),
            reporter: const NoopErrorReporter(),
          );
        }, (error, _) => escaped.add(error));
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(
          startup,
          isA<StartupFailed>(),
          reason:
              'a failure must never resolve to the preview stand-ins — that '
              'is what signed anyone in and reported the ledger as backed up',
        );
        expect((startup! as StartupFailed).error, isNotNull);
        expect((startup! as StartupFailed).stackTrace, isNotNull);
        // Recorded, not asserted in detail: which errors escape is the
        // package's business. What matters is that the value returned already
        // tells the truth without depending on them.
        expect(escaped, isNotEmpty);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });

  group('the web preview keeps its stand-ins', () {
    test(
      'no database means the fakes, deliberately, not as a fallback',
      () async {
        final store = MemoryStore();

        final startup = await connectBackend(
          db: null,
          store: store,
          reporter: const NoopErrorReporter(),
        );

        // The preview has no backend by design. What must never happen is this
        // same pair being reached because something threw on a real phone.
        expect(startup, isA<StartupReady>());
        final ready = startup as StartupReady;
        expect(ready.auth, isA<FakeAuthService>());
        expect(ready.sync, isA<NoopSyncEngine>());
        expect(identical(ready.store, store), isTrue);
      },
    );
  });
}
