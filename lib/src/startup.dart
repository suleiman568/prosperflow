import 'package:drift/drift.dart' show QueryExecutor;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'auth/auth_service.dart';
import 'auth/supabase_auth_service.dart';
import 'config/supabase_config.dart';
import 'data/data_store.dart';
import 'data/db/app_database.dart';
import 'sync/sync_backend.dart';
import 'sync/sync_engine.dart';

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
}) async {
  if (db == null || !SupabaseConfig.enabled) {
    return StartupReady(
      store: store,
      auth: FakeAuthService(),
      sync: NoopSyncEngine(lastSyncAt: DateTime.now()),
    );
  }

  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
    final client = Supabase.instance.client;

    final connectivity = Connectivity();
    final initial = await connectivity.checkConnectivity();

    return StartupReady(
      store: store,
      auth: SupabaseAuthService(client),
      sync: DriftSyncEngine(
        db,
        SupabaseSyncBackend(client),
        connectivity: connectivity.onConnectivityChanged.map(
          (results) => !results.contains(ConnectivityResult.none),
        ),
        initiallyOnline: !initial.contains(ConnectivityResult.none),
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
