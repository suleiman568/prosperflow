/// Domain models per the handoff's data model (§5) and Backend Plan schema.
/// All money is integer Naira; all IDs are client-generated UUIDs so offline
/// writes sync safely (Backend Plan §3/§5).
library;

enum PaymentMethod { cash, transfer, pos, credit }

enum Fulfilment { walkIn, delivery }

enum ExpenseCategory { delivery, stock, rent, transport, other }

enum CreditStatus { owed, paid }

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.unit,
    required this.stock,
    required this.buyPrice,
    required this.sellPrice,
    this.lowStockThreshold = 10,
  });

  final String id;
  final String name;
  final String unit;
  final int stock;
  final int buyPrice;
  final int sellPrice;
  final int lowStockThreshold;

  bool get isLow => stock <= lowStockThreshold;

  /// "Vegetable Oil — 3 bottles left" (parenthetical size stripped).
  String get lowStockLine =>
      '${name.replaceAll(RegExp(r'\s*\(.*\)'), '')} — $stock $unit left';
}

class Sale {
  const Sale({
    required this.id,
    required this.productId,
    required this.productName,
    required this.qty,
    required this.unitPrice,
    required this.total,
    required this.method,
    required this.fulfilment,
    this.customerName,
    this.location,
    required this.soldAt,
  });

  final String id;
  final String productId;
  final String productName;
  final int qty;
  final int unitPrice;
  final int total;
  final PaymentMethod method;
  final Fulfilment fulfilment;
  final String? customerName;
  final String? location;
  final DateTime soldAt;
}

class Expense {
  const Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.spentOn,
  });

  final String id;
  final String description;
  final int amount;
  final ExpenseCategory category;
  final DateTime spentOn;
}

class Credit {
  const Credit({
    required this.saleId,
    required this.customerName,
    required this.amount,
    required this.product,
    required this.status,
    required this.soldAt,
    this.paidAt,
  });

  final String saleId;
  final String customerName;
  final int amount;

  /// Display line, e.g. "Palm Oil (25L) × 2".
  final String product;

  final CreditStatus status;
  final DateTime soldAt;
  final DateTime? paidAt;
}

/// Aggregates for the Dashboard stat cards.
class SalesStats {
  const SalesStats({required this.total, required this.count});

  final int total;
  final int count;
}

/// One row of the Reports payment breakdown.
class PaymentBucket {
  const PaymentBucket({required this.method, required this.amount});

  final PaymentMethod method;
  final int amount;
}

/// One row of the Reports top-products section.
class TopProduct {
  const TopProduct({required this.name, required this.share});

  final String name;

  /// Fraction of period sales revenue, 0..1.
  final double share;
}
