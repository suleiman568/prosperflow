import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/connectivity_service.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/sale.dart';

class SalesRepository {
  SalesRepository({
    ConnectivityService? connectivityService,
    SupabaseClient? client,
  }) : _connectivityService = connectivityService ?? ConnectivityService(),
       _client = client ?? SupabaseService.client;

  final ConnectivityService _connectivityService;
  final SupabaseClient _client;

  Future<List<Sale>> fetchSales() async {
    final rows = await _client.from('sales').select().order('sale_date');
    return rows.map(Sale.fromJson).toList();
  }

  Future<Sale> createSale(Sale sale) async {
    await _adjustProductStock(sale.productId, -sale.quantity);
    try {
      final row = await _client
          .from('sales')
          .insert({
            ...sale.toInsertJson(),
            'user_id': Supabase.instance.client.auth.currentUser!.id,
          })
          .select()
          .single();
      return Sale.fromJson(row);
    } catch (_) {
      await _adjustProductStock(sale.productId, sale.quantity);
      rethrow;
    }
  }

  Future<Sale> updateSale(Sale sale) async {
    final existing = await _client
        .from('sales')
        .select()
        .eq('id', sale.id)
        .single()
        .then(Sale.fromJson);

    if (existing.productId == sale.productId) {
      await _adjustProductStock(
        sale.productId,
        existing.quantity - sale.quantity,
      );
    } else {
      await _adjustProductStock(existing.productId, existing.quantity);
      await _adjustProductStock(sale.productId, -sale.quantity);
    }

    try {
      final row = await _client
          .from('sales')
          .update(sale.toInsertJson())
          .eq('id', sale.id)
          .select()
          .single();
      return Sale.fromJson(row);
    } catch (_) {
      if (existing.productId == sale.productId) {
        await _adjustProductStock(
          sale.productId,
          sale.quantity - existing.quantity,
        );
      } else {
        await _adjustProductStock(existing.productId, -existing.quantity);
        await _adjustProductStock(sale.productId, sale.quantity);
      }
      rethrow;
    }
  }

  Future<void> deleteSale(Sale sale) async {
    await _adjustProductStock(sale.productId, sale.quantity);
    try {
      await _client.from('sales').delete().eq('id', sale.id);
    } catch (_) {
      await _adjustProductStock(sale.productId, -sale.quantity);
      rethrow;
    }
  }

  Future<void> _adjustProductStock(String productId, int delta) async {
    if (!await _connectivityService.isOnline()) {
      throw StateError('Product stock sync is unavailable while offline.');
    }

    debugPrint('PRODUCTS_SUPABASE_FETCH');
    final row = await _client
        .from('products')
        .select('stock_quantity')
        .eq('id', productId)
        .single();
    final current = _asInt(row['stock_quantity']);
    final next = current + delta;
    if (next < 0) {
      throw StateError('Not enough stock for this sale.');
    }
    await _client
        .from('products')
        .update({'stock_quantity': next})
        .eq('id', productId);
  }

  static int _asInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse((value ?? '0').toString()) ?? 0;
  }
}
