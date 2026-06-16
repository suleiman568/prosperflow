import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/offline/offline_providers.dart';
import '../domain/product.dart';
import 'products_repository.dart';

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return ProductsRepository(
    database: ref.watch(localDatabaseProvider),
    pendingSyncRepository: ref.watch(pendingSyncRepositoryProvider),
    connectivityService: ref.watch(connectivityServiceProvider),
  );
});

final productsLocalRefreshProvider = StateProvider<int>((ref) => 0);

final productsProvider = FutureProvider<List<Product>>((ref) {
  final repository = ref.watch(productsRepositoryProvider);
  ref.watch(productsLocalRefreshProvider);

  ref.listen(isOnlineProvider, (previous, next) {
    final isOnline = next.maybeWhen(
      data: (value) => value,
      orElse: () => false,
    );
    if (isOnline) {
      unawaited(repository.syncPendingChanges());
      ref.read(productsLocalRefreshProvider.notifier).state++;
    }
  });

  return repository.fetchProducts().catchError((_) {
    return repository.fetchLocalProducts();
  });
});
