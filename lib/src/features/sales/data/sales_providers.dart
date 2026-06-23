import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../customers/data/customers_providers.dart';
import '../../customers/domain/customer.dart';
import '../../products/data/products_providers.dart';
import '../../products/domain/product.dart';
import '../../../core/offline/offline_providers.dart';
import '../domain/sale.dart';
import 'sales_repository.dart';

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository(
    database: ref.watch(localDatabaseProvider),
    pendingSyncRepository: ref.watch(pendingSyncRepositoryProvider),
    connectivityService: ref.watch(connectivityServiceProvider),
  );
});

final salesLocalRefreshProvider = StateProvider<int>((ref) => 0);

final salesProvider = FutureProvider<List<Sale>>((ref) {
  final repository = ref.watch(salesRepositoryProvider);
  ref.watch(salesLocalRefreshProvider);
  final localRefresh = ref.read(salesLocalRefreshProvider.notifier);
  var isDisposed = false;

  ref.onDispose(() {
    isDisposed = true;
    repository.resetStartupSync();
  });

  void refreshLocalSalesIfAlive() {
    if (isDisposed) {
      return;
    }
    localRefresh.state++;
  }

  ref.listen(isOnlineProvider, (previous, next) {
    final wasOnline =
        previous?.maybeWhen(data: (value) => value, orElse: () => false) ??
        false;
    final isOnline = next.maybeWhen(
      data: (value) => value,
      orElse: () => false,
    );
    if (!wasOnline && isOnline && previous != null) {
      repository.maybeSyncPendingChangesInBackground(
        force: true,
        onSynced: refreshLocalSalesIfAlive,
      );
    }
  });

  return repository.fetchSales().catchError((_) {
    return const <Sale>[];
  });
});

final salesLookupProvider = FutureProvider<SalesLookupData>((ref) async {
  ref.watch(salesLocalRefreshProvider);
  ref.watch(customersLocalRefreshProvider);
  ref.watch(productsLocalRefreshProvider);

  final customers = await ref
      .watch(customersRepositoryProvider)
      .fetchLocalCustomers()
      .catchError((_) => const <Customer>[]);
  final products = await ref
      .watch(productsRepositoryProvider)
      .fetchLocalProducts()
      .catchError((_) => const <Product>[]);

  return SalesLookupData(customers: customers, products: products);
});

class SalesLookupData {
  const SalesLookupData({required this.customers, required this.products});

  final List<Customer> customers;
  final List<Product> products;
}
