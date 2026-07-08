import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/data/app_scope.dart';
import 'src/data/data_store.dart';
import 'src/data/db/app_database.dart';
import 'src/data/drift_store.dart';
import 'src/data/memory_store.dart';

import 'src/data/db/connection.dart'
    if (dart.library.js_interop) 'src/data/db/connection_stub.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local-first storage (Backend Plan §6): SQLite on device. The web build
  // (used for design previews) keeps data in memory only.
  final DataStore store =
      kIsWeb ? MemoryStore() : DriftStore(AppDatabase(openConnection()));
  await store.seedIfEmpty();

  runApp(AppScope(store: store, child: const ProsperFlowApp()));
}
