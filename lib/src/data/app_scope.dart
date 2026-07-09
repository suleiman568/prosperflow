import 'package:flutter/widgets.dart';

import '../auth/auth_service.dart';
import '../sync/sync_engine.dart';
import 'data_store.dart';

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
