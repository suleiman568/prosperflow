import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../domain/revenue_entry.dart';

class RevenueRepository {
  RevenueRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<List<RevenueEntry>> fetchRevenue() async {
    final rows = await _client.from('revenue').select().order('date');
    return rows.map(RevenueEntry.fromJson).toList();
  }

  Future<RevenueEntry> createRevenue(RevenueEntry entry) async {
    final row = await _client
        .from('revenue')
        .insert({
          ...entry.toInsertJson(),
          'user_id': _client.auth.currentUser!.id,
        })
        .select()
        .single();
    return RevenueEntry.fromJson(row);
  }

  Future<RevenueEntry> updateRevenue(RevenueEntry entry) async {
    final row = await _client
        .from('revenue')
        .update(entry.toInsertJson())
        .eq('id', entry.id)
        .select()
        .single();
    return RevenueEntry.fromJson(row);
  }

  Future<void> deleteRevenue(String id) async {
    await _client.from('revenue').delete().eq('id', id);
  }
}
