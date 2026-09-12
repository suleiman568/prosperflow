import 'dart:async';

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'auth/auth_service.dart';
import 'auth/supabase_auth_service.dart';
import 'config/supabase_config.dart';
import 'data/app_scope.dart';
import 'data/data_store.dart';
import 'data/db/app_database.dart';
import 'sync/sync_backend.dart';
import 'sync/sync_engine.dart';
import 'telemetry/error_reporter.dart';

/// What starting up produced: either the services the app runs on, or the
/// reason it cannot have them.
///
/// This exists because the failure used to be unrepresentable. Wiring up the
/// backend was wrapped in `catch (_)`, and a failure left the app holding
/// [FakeAuthService] and [NoopSyncEngine] — the web preview's stand-ins — on a
/// real phone, with nothing anywhere recording that it had happened.
sealed class Startup {
  const Startup();
}

/// The app has everything it needs.
class StartupReady extends Startup {
  const StartupReady({
    required this.store,
    required this.auth,
    required this.sync,
  });

  final DataStore store;
  final AuthService auth;
  final SyncEngine sync;
}

/// The backend could not be wired up, and the app must say so rather than
/// carry on with something that resembles it.
///
/// Carries the cause so it can be reported rather than only shown.
class StartupFailed extends Startup {
  const StartupFailed(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}

/// Opens the local database. Called once, because opening it twice would give
/// the retry path a second connection to the same file.
AppDatabase? openLocalDatabase(DatabaseOpener opener) =>
    kIsWeb ? null : AppDatabase(opener());

typedef DatabaseOpener = QueryExecutor Function();

/// Everything [connectBackend] needs from outside the process, gathered into
/// one value.
///
/// This exists so the wiring below can be tested. The part worth testing is
/// which services get built and what they are handed — not `Supabase.initialize`
/// — and that part was untestable while the two were the same function. It is
/// how the reporter came to be missing from the sync engine in the first
/// place: nothing could reach the line that builds it.
class BackendConnection {
  const BackendConnection({
    required this.auth,
    required this.backend,
    required this.connectivity,
    required this.initiallyOnline,
  });

  final AuthService auth;
  final SyncBackend backend;
  final Stream<bool> connectivity;
  final bool initiallyOnline;
}

/// Reaches the outside world. Substituted in tests; never in the app.
typedef BackendConnector = Future<BackendConnection> Function();

Future<BackendConnection> connectToSupabase() async {
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  final client = Supabase.instance.client;

  final connectivity = Connectivity();
  final initial = await connectivity.checkConnectivity();

  return BackendConnection(
    auth: SupabaseAuthService(client),
    backend: SupabaseSyncBackend(client),
    connectivity: connectivity.onConnectivityChanged.map(
      (results) => !results.contains(ConnectivityResult.none),
    ),
    initiallyOnline: !initial.contains(ConnectivityResult.none),
  );
}

/// The whole of starting up: connect, claim the database for whoever is
/// signed in, and report it if either half fails.
///
/// This is a plain function rather than part of the bootstrap widget so that
/// all of it can be tested — including the binding, whose failure used to
/// escape the widget's `_connect` before any state was assigned and leave the
/// trader on the spinner for good.
Future<Startup> startUp({
  required AppDatabase? db,
  required DataStore store,
  required ErrorReporter reporter,
  BackendConnector connect = connectToSupabase,
}) async {
  var startup = await connectBackend(
    db: db,
    store: store,
    reporter: reporter,
    connect: connect,
  );

  if (startup is StartupReady) {
    final ready = startup;
    try {
      // A restored session skips the login screen entirely, so the database
      // has to be claimed here too — otherwise the Dashboard renders the
      // previous trader's ledger before anything else runs. Binding also
      // attaches the trader to any report made from here on.
      await bindLocalDataToTrader(
        ready.store,
        ready.auth,
        sync: ready.sync,
        reporter: reporter,
      );
    } catch (error, stackTrace) {
      // The engine is already running by this point — it opens its
      // connectivity and outbox subscriptions in its constructor — and
      // demoting the result to a failure makes it unreachable without making
      // it stop. Left alone it keeps watching the outbox of a database
      // nothing managed to claim, and every press of Try again adds another
      // one beside it, each debouncing on the same writes and syncing
      // independently.
      //
      // Guarded because `startUp` must not throw: a failure escaping here
      // would strand the trader on the connecting spinner, which is the exact
      // fault this function exists to prevent.
      try {
        ready.sync.dispose();
      } catch (_) {
        // Nothing useful to do, and the binding failure below is the more
        // important of the two.
      }
      // Claiming the database is as much a part of starting up as reaching the
      // server, and it fails the same way: a corrupt file, a migration that
      // will not apply, a disk with nothing left on it. Demoting it to the
      // same failure the rest of startup produces gives it the screen and the
      // retry that already exist, instead of a spinner with no way out.
      startup = StartupFailed(error, stackTrace);
    }
  }

  // After the bind, so a failure there is reported too rather than only the
  // ones from connecting.
  if (startup is StartupFailed) {
    // The failure this whole change exists for. Without this it is invisible
    // from outside: the trader sees a screen, and nobody else sees anything.
    unawaited(
      reporter.reportIssue(
        'startup_failed',
        error: startup.error,
        stackTrace: startup.stackTrace,
      ),
    );
  }

  return startup;
}

/// Wires up storage, auth and sync.
///
/// The web build has no backend by design — it is a design preview, and the
/// fakes are the point there rather than a fallback. On a device the fakes are
/// never substituted: [FakeAuthService.signIn] accepts any email with a
/// six-character password and reports success, and [NoopSyncEngine] reports
/// itself online with nothing pending and a recent backup. Together they gave
/// a trader whose backend never started a working-looking ledger that told
/// them, on the dashboard, that their sales were backed up. They were on the
/// phone and nowhere else.
Future<Startup> connectBackend({
  required AppDatabase? db,
  required DataStore store,
  required ErrorReporter reporter,
  BackendConnector connect = connectToSupabase,
}) async {
  if (db == null || !SupabaseConfig.enabled) {
    return StartupReady(
      store: store,
      auth: FakeAuthService(),
      sync: NoopSyncEngine(lastSyncAt: DateTime.now()),
    );
  }

  try {
    final connection = await connect();

    return StartupReady(
      store: store,
      auth: connection.auth,
      sync: DriftSyncEngine(
        db,
        connection.backend,
        connectivity: connection.connectivity,
        initiallyOnline: connection.initiallyOnline,
        // The engine holds three of the four places this app reports from.
        // Left off, they all resolve to a reporter that discards them, and
        // every sync failure on every phone goes back to being invisible —
        // which is the exact thing this change exists to end.
        reporter: reporter,
      ),
    );
  } catch (error, stackTrace) {
    // Deliberately not a fallback. Being offline does not reach here:
    // supabase_flutter recovers its session inside its own try/catch and only
    // logs a warning, so a throw means the app is misconfigured or the
    // platform refused it — a defect, not a bad signal at the market.
    return StartupFailed(error, stackTrace);
  }
}
