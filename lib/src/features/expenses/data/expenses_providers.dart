import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/expense.dart';
import 'expenses_repository.dart';

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  return ExpensesRepository();
});

final expensesProvider = FutureProvider<List<Expense>>((ref) {
  return ref.watch(expensesRepositoryProvider).fetchExpenses();
});
