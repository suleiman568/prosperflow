import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../domain/cashflow_entry.dart';

class CashflowRepository {
  CashflowRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<List<CashflowEntry>> fetchCashflow() async {
    final rows = await _client.from('cashflow').select();
    return rows.map(CashflowEntry.fromJson).toList();
  }

  Future<CashflowEntry> createCashflow(CashflowEntry entry) async {
    final row = await _client
        .from('cashflow')
        .insert({
          ...entry.toInsertJson(),
          'user_id': _client.auth.currentUser!.id,
        })
        .select()
        .single();
    return CashflowEntry.fromJson(row);
  }

  Future<CashflowEntry> updateCashflow(CashflowEntry entry) async {
    final row = await _client
        .from('cashflow')
        .update(entry.toInsertJson())
        .eq('id', entry.id)
        .select()
        .single();
    return CashflowEntry.fromJson(row);
  }

  Future<void> deleteCashflow(String id) async {
    await _client.from('cashflow').delete().eq('id', id);
  }
}
