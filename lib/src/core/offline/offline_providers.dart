import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_service.dart';
import 'local_database.dart';
import 'pending_sync_repository.dart';

final localDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

final pendingSyncRepositoryProvider = Provider<PendingSyncRepository>((ref) {
  return PendingSyncRepository(ref.watch(localDatabaseProvider));
});

final isOnlineProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onOnlineStatusChanged();
});
