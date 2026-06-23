import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/offline_providers.dart';
import 'dashboard_repository.dart';

export 'dashboard_repository.dart' show DashboardSummary, RevenueChartPoint;

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(localDatabaseProvider));
});

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  try {
    return await ref.watch(dashboardRepositoryProvider).fetchLocalSummary();
  } catch (_) {
    return DashboardSummary.empty();
  }
});
