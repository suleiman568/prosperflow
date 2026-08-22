import 'dart:async';

import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/data/app_scope.dart';
import 'src/data/data_store.dart';
import 'src/data/db/app_database.dart';
import 'src/data/drift_store.dart';
import 'src/data/memory_store.dart';
import 'src/screens/startup_failure_screen.dart';
import 'src/startup.dart';
import 'src/telemetry/error_reporter.dart';
import 'src/telemetry/telemetry.dart';

import 'src/data/db/connection.dart'
    if (dart.library.js_interop) 'src/data/db/connection_stub.dart';

Future<void> main() async {
  // Started before the binding, so that anything the binding itself throws is
  // already being watched.
  final reporter = await startReporting();
  await runGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(ProsperFlowBootstrap(reporter: reporter));
  }, reporter: reporter);
}

/// Wires up the app's services before showing it, and shows the failure
/// plainly if they cannot be wired up.
///
/// The work moved out of `main` so that a failure has somewhere to be
/// displayed and something to retry it. Previously it happened before
/// `runApp`, which left nowhere to put the news.
class ProsperFlowBootstrap extends StatefulWidget {
  const ProsperFlowBootstrap({super.key, required this.reporter});

  final ErrorReporter reporter;

  @override
  State<ProsperFlowBootstrap> createState() => _ProsperFlowBootstrapState();
}

class _ProsperFlowBootstrapState extends State<ProsperFlowBootstrap> {
  // Opened once and kept across retries: a retry re-attempts the backend, not
  // the database, and opening the file twice would give the app two
  // connections to it.
  //
  // Local-first storage (Backend Plan §6): SQLite on device. The web build
  // (used for design previews) keeps data in memory only. Fresh installs
  // start empty — no demo data is seeded.
  late final AppDatabase? _db = openLocalDatabase(openConnection);
  late final DataStore _store = _db == null ? MemoryStore() : DriftStore(_db);

  Startup? _startup;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    final startup = await connectBackend(db: _db, store: _store);
    if (startup is StartupFailed) {
      // The failure this whole change exists for. Without this it is invisible
      // from here: the trader sees a screen, and nobody else sees anything.
      unawaited(
        widget.reporter.reportIssue(
          'startup_failed',
          error: startup.error,
          stackTrace: startup.stackTrace,
        ),
      );
    }
    if (startup is StartupReady) {
      // A restored session skips the login screen entirely, so the database
      // has to be claimed here too — otherwise the Dashboard renders the
      // previous trader's ledger before anything else runs.
      await bindLocalDataToTrader(
        startup.store,
        startup.auth,
        sync: startup.sync,
      );
      // The opaque account uuid and nothing else, so a report can be tied to
      // a ledger without naming anybody.
      unawaited(widget.reporter.setTrader(startup.auth.traderId));
    }
    if (mounted) setState(() => _startup = startup);
  }

  void _retry() {
    setState(() => _startup = null);
    _connect();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_startup) {
      // Brief on a phone, and deliberately bare: the branding lockup belongs
      // to the login screen, and flashing it here would read as a screen that
      // failed to finish loading.
      null => const _Connecting(),
      StartupFailed() => StartupFailureScreen(onRetry: _retry),
      StartupReady(:final store, :final auth, :final sync) => AppScope(
        store: store,
        auth: auth,
        sync: sync,
        child: const ProsperFlowApp(),
      ),
    };
  }
}

class _Connecting extends StatelessWidget {
  const _Connecting();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFFAF7F0), // AppColors.appBg, before the theme exists
      child: Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}
