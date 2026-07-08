import 'package:flutter/widgets.dart';

import 'data_store.dart';

/// Exposes the app's [DataStore] to the widget tree.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.store, required super.child});

  final DataStore store;

  static DataStore of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AppScope>()!
      .store;

  @override
  bool updateShouldNotify(AppScope oldWidget) => store != oldWidget.store;
}
