import 'models.dart';

/// Deterministic, valid UUID-format id for seed rows — the server's uuid
/// columns reject arbitrary strings, so seed ids must parse as UUIDs.
String _seedUuid(int n) =>
    '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

/// Demo dataset installed on first launch so a new install is explorable.
/// Deterministic apart from being anchored to the install date.
class SeedData {
  SeedData._({
    required this.products,
    required this.sales,
    required this.credits,
    required this.expenses,
  });

  final List<Product> products;
  final List<Sale> sales;
  final List<Credit> credits;
  final List<Expense> expenses;

  factory SeedData.build(DateTime now) {
    const palm = Product(
      id: '00000000-0000-4000-8000-000000000001',
      name: 'Palm Oil (25L)',
      unit: 'bottles',
      stock: 42,
      buyPrice: 6800,
      sellPrice: 9200,
    );
    const veg = Product(
      id: '00000000-0000-4000-8000-000000000002',
      name: 'Vegetable Oil (20L)',
      unit: 'bottles',
      stock: 3,
      buyPrice: 5200,
      sellPrice: 7000,
    );
    const yam = Product(
      id: '00000000-0000-4000-8000-000000000003',
      name: 'Yam (per tuber)',
      unit: 'tubers',
      stock: 28,
      buyPrice: 1200,
      sellPrice: 2500,
    );
    const water = Product(
      id: '00000000-0000-4000-8000-000000000004',
      name: 'Bottled Water (500ml)',
      unit: 'packs',
      stock: 8,
      buyPrice: 800,
      sellPrice: 1200,
    );
    final products = [palm, veg, yam, water];

    // ~10 sales/day over the past week, rotating products and methods.
    const perDay = [12, 9, 11, 8, 10, 9, 8];
    const rotation = [palm, yam, water, palm, veg, yam, palm, water];
    const methods = [
      PaymentMethod.cash,
      PaymentMethod.transfer,
      PaymentMethod.cash,
      PaymentMethod.pos,
      PaymentMethod.cash,
      PaymentMethod.transfer,
    ];

    final sales = <Sale>[];
    var n = 0;
    for (var day = 0; day < perDay.length; day++) {
      for (var i = 0; i < perDay[day]; i++) {
        final product = rotation[n % rotation.length];
        final qty = n % 3 + 1;
        final soldAt = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: day))
            .add(Duration(hours: 8 + (n * 37) % 10, minutes: (n * 17) % 60));
        sales.add(
          Sale(
            id: _seedUuid(1000 + n),
            productId: product.id,
            productName: product.name,
            qty: qty,
            unitPrice: product.sellPrice,
            total: qty * product.sellPrice,
            method: methods[n % methods.length],
            fulfilment: n % 5 == 0 ? Fulfilment.delivery : Fulfilment.walkIn,
            location: n % 5 == 0 ? 'Lekki Phase 1' : null,
            soldAt: soldAt,
          ),
        );
        n++;
      }
    }

    // Three open credit sales (the design's demo customers).
    Sale creditSale(
      String id,
      Product product,
      int qty,
      String customer,
      int daysAgo,
      int hour,
    ) {
      final soldAt = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: daysAgo)).add(Duration(hours: hour));
      return Sale(
        id: id,
        productId: product.id,
        productName: product.name,
        qty: qty,
        unitPrice: product.sellPrice,
        total: qty * product.sellPrice,
        method: PaymentMethod.credit,
        fulfilment: Fulfilment.walkIn,
        customerName: customer,
        soldAt: soldAt,
      );
    }

    final creditSales = [
      creditSale(_seedUuid(2001), palm, 2, 'Chioma Ojo', 3, 11), // ₦18,400
      creditSale(_seedUuid(2002), yam, 12, 'Abike Adeyemi', 5, 14), // ₦30,000
      creditSale(_seedUuid(2003), veg, 3, 'Okoro Emeka', 6, 10), // ₦21,000
    ];
    sales.addAll(creditSales);

    final credits = [
      for (final sale in creditSales)
        Credit(
          saleId: sale.id,
          customerName: sale.customerName!,
          amount: sale.total,
          product: '${sale.productName} × ${sale.qty}',
          status: CreditStatus.owed,
          soldAt: sale.soldAt,
        ),
    ];

    Expense expense(
      String id,
      String description,
      int amount,
      ExpenseCategory category,
      int daysAgo,
    ) => Expense(
      id: id,
      description: description,
      amount: amount,
      category: category,
      spentOn: DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: daysAgo)),
    );

    final expenses = [
      expense(
        _seedUuid(3001),
        'Delivery Cost',
        8500,
        ExpenseCategory.delivery,
        2,
      ),
      expense(
        _seedUuid(3002),
        'Stock Purchase',
        18000,
        ExpenseCategory.stock,
        3,
      ),
      expense(_seedUuid(3003), 'Stall Rent', 10000, ExpenseCategory.rent, 4),
      expense(
        _seedUuid(3004),
        'Fuel/Transport',
        5800,
        ExpenseCategory.transport,
        5,
      ),
      // Older history so Month/All reports differ from Week.
      expense(
        _seedUuid(3005),
        'Stock Purchase',
        22000,
        ExpenseCategory.stock,
        15,
      ),
      expense(_seedUuid(3006), 'Stall Rent', 10000, ExpenseCategory.rent, 25),
      expense(
        _seedUuid(3007),
        'Delivery Cost',
        6400,
        ExpenseCategory.delivery,
        40,
      ),
    ];

    return SeedData._(
      products: products,
      sales: sales,
      credits: credits,
      expenses: expenses,
    );
  }
}
