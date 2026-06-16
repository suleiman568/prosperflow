import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../domain/expense.dart';

class ExpensesRepository {
  ExpensesRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<List<Expense>> fetchExpenses() async {
    final rows = await _client.from('expenses').select().order('date');
    return rows.map(Expense.fromJson).toList();
  }

  Future<Expense> createExpense(Expense expense) async {
    final row = await _client
        .from('expenses')
        .insert({
          ...expense.toInsertJson(),
          'user_id': _client.auth.currentUser!.id,
        })
        .select()
        .single();
    return Expense.fromJson(row);
  }

  Future<Expense> updateExpense(Expense expense) async {
    final row = await _client
        .from('expenses')
        .update(expense.toInsertJson())
        .eq('id', expense.id)
        .select()
        .single();
    return Expense.fromJson(row);
  }

  Future<void> deleteExpense(String id) async {
    await _client.from('expenses').delete().eq('id', id);
  }
}
