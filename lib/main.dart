import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/auth/auth_service.dart';
import 'src/auth/supabase_auth_service.dart';
import 'src/config/supabase_config.dart';
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

  // Auth: Supabase on device (sessions persist locally, so a trader who
  // signed in once stays signed in offline). The web preview uses the fake.
  AuthService auth;
  if (!kIsWeb && SupabaseConfig.enabled) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
      );
      auth = SupabaseAuthService(Supabase.instance.client);
    } catch (_) {
      // Never block the ledger on auth infrastructure.
      auth = FakeAuthService();
    }
  } else {
    auth = FakeAuthService();
  }

  runApp(AppScope(store: store, auth: auth, child: const ProsperFlowApp()));
}
