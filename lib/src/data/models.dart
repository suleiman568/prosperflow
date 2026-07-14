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
    this.unitCost,
    this.listPrice,
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

  /// The product's buy price at the moment of sale. Null on sales recorded
  /// before costs were snapshotted — profit is unknowable for those.
  final int? unitCost;

  /// The product's normal sell price when this sale was discounted;
  /// null when the sale went for the normal price.
  final int? listPrice;

  final int total;
  final PaymentMethod method;
  final Fulfilment fulfilment;
  final String? customerName;
  final String? location;
  final DateTime soldAt;

  /// (sell − cost) × qty, or null when the cost wasn't recorded.
  int? get profit {
    final cost = unitCost;
    return cost == null ? null : (unitPrice - cost) * qty;
  }

  /// True when this sale went for less than the product's normal price.
  bool get discounted => listPrice != null && listPrice != unitPrice;
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

/// One sale inside the Sales History detail expansion.
class SaleHistoryEntry {
  const SaleHistoryEntry({
    required this.qty,
    required this.unitPrice,
    this.listPrice,
    required this.profit,
    required this.soldAt,
    required this.method,
    required this.collected,
  });

  final int qty;
  final int unitPrice;

  /// Normal price when the sale was discounted; null otherwise.
  final int? listPrice;

  /// True when [listPrice] is set and differs from [unitPrice].
  bool get discounted => listPrice != null && listPrice != unitPrice;

  /// Null when the sale predates cost snapshotting — rendered as "—".
  final int? profit;

  final DateTime soldAt;
  final PaymentMethod method;

  /// True when this was a credit sale whose credit has been collected
  /// ("Credit → Collected"); always false for non-credit sales.
  final bool collected;
}

/// One product's sales for the day, expandable into [entries].
class ProductSalesGroup {
  const ProductSalesGroup({
    required this.productId,
    required this.productName,
    required this.qty,
    required this.revenue,
    required this.profit,
    required this.missingCostCount,
    required this.entries,
  });

  final String productId;
  final String productName;
  final int qty;
  final int revenue;

  /// Sum of profits over sales that have a cost; null when none do.
  final int? profit;

  /// Sales in this group with no recorded cost (legacy rows). When
  /// 0 < missingCostCount < entries.length the profit shown is partial.
  final int missingCostCount;

  /// Newest first.
  final List<SaleHistoryEntry> entries;

  bool get profitIsPartial =>
      profit != null && missingCostCount > 0;
}

/// The "Sales History for Today" payload: day totals + per-product groups.
class TodayHistory {
  const TodayHistory({
    required this.revenue,
    required this.profit,
    required this.missingCostCount,
    required this.groups,
  });

  final int revenue;

  /// Sum of profits over today's costed sales; null when no sale has one.
  final int? profit;

  /// Today's sales with no recorded cost (excluded from [profit]).
  final int missingCostCount;

  /// Ordered by revenue, highest first.
  final List<ProductSalesGroup> groups;

  bool get isEmpty => groups.isEmpty;
}

/// One row of the Reports top-products section.
class TopProduct {
  const TopProduct({required this.name, required this.share});

  final String name;

  /// Fraction of period sales revenue, 0..1.
  final double share;
}
