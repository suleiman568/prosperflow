import 'package:flutter/widgets.dart';

import '../auth/auth_service.dart';
import '../sync/sync_engine.dart';
import 'data_store.dart';

/// Claims the local database for whoever is signed in, before any screen
/// reads it.
///
/// Call on every path into the signed-in app: sign-in, sign-up, and startup
/// with a restored session. A no-op when signed out, and a no-op when the
/// database already belongs to this trader — it only does work when the phone
/// changes hands.
Future<void> bindLocalDataToTrader(DataStore store, AuthService auth) async {
  final traderId = auth.traderId;
  if (traderId != null) await store.bindToTrader(traderId);
}

/// Exposes the app's [DataStore], [AuthService], and [SyncEngine] to the
/// widget tree.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.store,
    required this.auth,
    required this.sync,
    required super.child,
  });

  final DataStore store;
  final AuthService auth;
  final SyncEngine sync;

  static AppScope _scope(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  static DataStore of(BuildContext context) => _scope(context).store;

  static AuthService authOf(BuildContext context) => _scope(context).auth;

  static SyncEngine syncOf(BuildContext context) => _scope(context).sync;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      store != oldWidget.store ||
      auth != oldWidget.auth ||
      sync != oldWidget.sync;
}
