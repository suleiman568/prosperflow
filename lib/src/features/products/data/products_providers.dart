import 'package:flutter/foundation.dart';
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
  final localRefresh = ref.read(productsLocalRefreshProvider.notifier);
  var isDisposed = false;

  ref.onDispose(() {
    isDisposed = true;
    repository.resetStartupHydration();
  });

  void refreshLocalProductsIfAlive() {
    if (isDisposed) {
      return;
    }
    localRefresh.state++;
  }

  repository.maybeHydrateFromRemoteInBackground(
    startup: true,
    onHydrated: refreshLocalProductsIfAlive,
  );

  ref.listen(isOnlineProvider, (previous, next) {
    final wasOnline =
        previous?.maybeWhen(data: (value) => value, orElse: () => false) ??
        false;
    final isOnline = next.maybeWhen(
      data: (value) => value,
      orElse: () => false,
    );
    if (!wasOnline && isOnline && previous != null) {
      repository.maybeHydrateFromRemoteInBackground(
        force: true,
        onHydrated: refreshLocalProductsIfAlive,
      );
    }
  });

  return repository
      .fetchProducts()
      .then((products) {
        debugPrint('productsProvider count: ${products.length}');
        return products;
      })
      .catchError((_) async {
        final products = await repository.fetchLocalProducts();
        debugPrint('productsProvider count: ${products.length}');
        return products;
      });
});
