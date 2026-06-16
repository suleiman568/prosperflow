import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/offline/offline_providers.dart';
import '../domain/customer.dart';
import 'customers_repository.dart';

final customersRepositoryProvider = Provider<CustomersRepository>((ref) {
  final repository = CustomersRepository(
    database: ref.watch(localDatabaseProvider),
    pendingSyncRepository: ref.watch(pendingSyncRepositoryProvider),
    connectivityService: ref.watch(connectivityServiceProvider),
  );

  return repository;
});

final customersLocalRefreshProvider = StateProvider<int>((ref) => 0);

final customersProvider = FutureProvider<List<Customer>>((ref) {
  final repository = ref.watch(customersRepositoryProvider);
  ref.watch(customersLocalRefreshProvider);

  ref.listen(isOnlineProvider, (previous, next) {
    final isOnline = next.maybeWhen(
      data: (value) => value,
      orElse: () => false,
    );
    if (isOnline) {
      unawaited(repository.syncPendingChanges());
      ref.read(customersLocalRefreshProvider.notifier).state++;
    }
  });

  return repository.fetchCustomers().catchError((_) {
    return repository.fetchLocalCustomers();
  });
});
