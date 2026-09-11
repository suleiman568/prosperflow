import 'dart:async';

import 'package:flutter/widgets.dart';

import '../auth/auth_service.dart';
import '../sync/sync_engine.dart';
import '../telemetry/error_reporter.dart';
import 'data_store.dart';

/// Claims the local database for whoever is signed in and starts their first
/// sync, before any screen reads it.
///
/// Call on every path into the signed-in app: sign-in, sign-up, and startup
/// with a restored session. Binding is a no-op when signed out, and when the
/// database already belongs to this trader — it only does work when the phone
/// changes hands.
///
/// The sync is what fills a fresh install. Nothing else would start one: the
/// engine syncs on a connectivity change or after a local write, and a trader
/// signing in on a new phone has neither. It is left running rather than
/// awaited, because the screens stream from the database and fill in as rows
/// land.
///
/// Whether that sync is a *restore* is settled first, and awaited, because the
/// screens render as soon as this returns and an empty one has to know which
/// of two opposite things to say. Pass [newAccount] on the sign-up path: an
/// account created seconds ago has nothing on the server to wait for, and
/// saying otherwise would leave a new trader watching for data that does not
/// exist.
/// Reports are attributed here too, because this is the one function every
/// path into the signed-in app already goes through. Attaching the trader at
/// the bootstrap call site only — which is what it used to do — left a phone
/// that launched signed out reporting anonymously for the whole session, and
/// left a handover attributing the new trader's failures to the old one.
Future<void> bindLocalDataToTrader(
  DataStore store,
  AuthService auth, {
  required ErrorReporter reporter,
  SyncEngine? sync,
  bool newAccount = false,
}) async {
  final traderId = auth.traderId;
  if (traderId == null) return;
  await store.bindToTrader(traderId);
  // The opaque account uuid and nothing else, so a report can be tied to a
  // ledger without naming anybody.
  await reporter.setTrader(traderId);
  if (sync == null) return;
  await sync.refreshRestoreState(nothingToRestore: newAccount);
  unawaited(sync.syncNow());
}

/// Exposes the app's [DataStore], [AuthService], [SyncEngine] and
/// [ErrorReporter] to the widget tree.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.store,
    required this.auth,
    required this.sync,
    // Required rather than defaulted, for the same reason as on
    // [DriftSyncEngine]: sign-in and sign-out attribute reports through this,
    // and a default would let the app quietly go back to reporting
    // anonymously. A test that wants silence can say `NoopErrorReporter()`.
    required this.reporter,
    required super.child,
  });

  final DataStore store;
  final AuthService auth;
  final SyncEngine sync;
  final ErrorReporter reporter;

  static AppScope _scope(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  static DataStore of(BuildContext context) => _scope(context).store;

  static AuthService authOf(BuildContext context) => _scope(context).auth;

  static SyncEngine syncOf(BuildContext context) => _scope(context).sync;

  static ErrorReporter reporterOf(BuildContext context) =>
      _scope(context).reporter;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      store != oldWidget.store ||
      auth != oldWidget.auth ||
      sync != oldWidget.sync ||
      reporter != oldWidget.reporter;
}
