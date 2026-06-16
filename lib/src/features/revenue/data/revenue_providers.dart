import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/revenue_entry.dart';
import 'revenue_repository.dart';

final revenueRepositoryProvider = Provider<RevenueRepository>((ref) {
  return RevenueRepository();
});

final revenueProvider = FutureProvider<List<RevenueEntry>>((ref) {
  return ref.watch(revenueRepositoryProvider).fetchRevenue();
});
