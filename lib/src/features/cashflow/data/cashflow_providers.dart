import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/cashflow_entry.dart';
import 'cashflow_repository.dart';

final cashflowRepositoryProvider = Provider<CashflowRepository>((ref) {
  return CashflowRepository();
});

final cashflowProvider = FutureProvider<List<CashflowEntry>>((ref) {
  return ref.watch(cashflowRepositoryProvider).fetchCashflow();
});
