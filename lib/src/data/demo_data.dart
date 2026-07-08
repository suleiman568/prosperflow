/// Demo data for the UI-only build phase, mirroring the design prototype's
/// state. Replaced by the local database + sync layer once all 7 screens
/// are approved.
library;

class DemoProduct {
  const DemoProduct({
    required this.name,
    required this.unit,
    required this.stock,
    required this.buyPrice,
    required this.sellPrice,
  });

  final String name;
  final String unit;
  final int stock;
  final int buyPrice;
  final int sellPrice;

  static const lowStockThreshold = 10;

  bool get isLow => stock <= lowStockThreshold;

  /// "Vegetable Oil — 3 bottles left" (parenthetical size stripped).
  String get lowStockLine =>
      '${name.replaceAll(RegExp(r'\s*\(.*\)'), '')} — $stock $unit left';
}

enum ExpenseCategory { delivery, stock, rent, transport, other }

class DemoExpense {
  const DemoExpense({
    required this.name,
    required this.amount,
    required this.date,
    required this.category,
  });

  final String name;
  final int amount;
  final String date;
  final ExpenseCategory category;
}

class DemoCredit {
  const DemoCredit({
    required this.customerName,
    required this.amount,
    required this.product,
    required this.soldOn,
  });

  final String customerName;
  final int amount;
  final String product;
  final String soldOn;
}

const demoProducts = [
  DemoProduct(
      name: 'Palm Oil (25L)',
      unit: 'bottles',
      stock: 42,
      buyPrice: 6800,
      sellPrice: 9200),
  DemoProduct(
      name: 'Vegetable Oil (20L)',
      unit: 'bottles',
      stock: 3,
      buyPrice: 5200,
      sellPrice: 7000),
  DemoProduct(
      name: 'Yam (per tuber)',
      unit: 'tubers',
      stock: 28,
      buyPrice: 1200,
      sellPrice: 2500),
  DemoProduct(
      name: 'Bottled Water (500ml)',
      unit: 'packs',
      stock: 8,
      buyPrice: 800,
      sellPrice: 1200),
];

const demoTodaySalesTotal = 48500;
const demoTodaySalesCount = 12;
const demoWeekSalesTotal = 312000;
const demoWeekSalesCount = 67;

/// Payment breakdown for the week (cash, transfer, POS, credit).
const demoPayCash = 140400;
const demoPayTransfer = 118560;
const demoPayPos = 37440;
const demoPayCredit = 15600;

const demoExpenses = [
  DemoExpense(
      name: 'Delivery Cost',
      amount: 8500,
      date: 'Friday, 3 July',
      category: ExpenseCategory.delivery),
  DemoExpense(
      name: 'Stock Purchase',
      amount: 18000,
      date: 'Thursday, 2 July',
      category: ExpenseCategory.stock),
  DemoExpense(
      name: 'Stall Rent',
      amount: 10000,
      date: 'Wednesday, 1 July',
      category: ExpenseCategory.rent),
  DemoExpense(
      name: 'Fuel/Transport',
      amount: 5800,
      date: 'Tuesday, 30 June',
      category: ExpenseCategory.transport),
];

const demoCredits = [
  DemoCredit(
      customerName: 'Chioma Ojo',
      amount: 18400,
      product: 'Palm Oil (25L) × 2',
      soldOn: '1 July 2026'),
  DemoCredit(
      customerName: 'Abike Adeyemi',
      amount: 30000,
      product: 'Yam (tuber) × 12',
      soldOn: '30 June 2026'),
  DemoCredit(
      customerName: 'Okoro Emeka',
      amount: 20100,
      product: 'Vegetable Oil (20L) × 1',
      soldOn: '28 June 2026'),
];
