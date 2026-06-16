import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/offline_providers.dart';
import '../domain/sale.dart';
import 'sales_repository.dart';

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository(
    connectivityService: ref.watch(connectivityServiceProvider),
  );
});

final salesProvider = FutureProvider<List<Sale>>((ref) {
  return ref.watch(salesRepositoryProvider).fetchSales();
});
