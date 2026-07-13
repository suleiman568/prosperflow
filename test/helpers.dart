import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/auth/auth_service.dart';
import 'package:prosperflow/src/data/app_scope.dart';
import 'package:prosperflow/src/data/data_store.dart';
import 'package:prosperflow/src/data/memory_store.dart';
import 'package:prosperflow/src/data/models.dart';
import 'package:prosperflow/src/sync/sync_engine.dart';

const palm = Product(
    id: 'p1',
    name: 'Palm Oil (25L)',
    unit: 'bottles',
    stock: 42,
    buyPrice: 6800,
    sellPrice: 9200);
const veg = Product(
    id: 'p2',
    name: 'Vegetable Oil (20L)',
    unit: 'bottles',
    stock: 3,
    buyPrice: 5200,
    sellPrice: 7000);
const yam = Product(
    id: 'p3',
    name: 'Yam (per tuber)',
    unit: 'tubers',
    stock: 28,
    buyPrice: 1200,
    sellPrice: 2500);
const water = Product(
    id: 'p4',
    name: 'Bottled Water (500ml)',
    unit: 'packs',
    stock: 8,
    buyPrice: 800,
    sellPrice: 1200);

final fixtureProducts = [palm, veg, yam, water];

DateTime _daysAgo(int days, {int hour = 10}) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: days))
      .add(Duration(hours: hour));
}

Sale _sale(String id, Product product, int qty, PaymentMethod method,
        DateTime soldAt, {String? customer}) =>
    Sale(
      id: id,
      productId: product.id,
      productName: product.name,
      qty: qty,
      unitPrice: product.sellPrice,
      unitCost: product.buyPrice,
      total: qty * product.sellPrice,
      method: method,
      fulfilment: Fulfilment.walkIn,
      customerName: customer,
      soldAt: soldAt,
    );

/// Today: ₦18,400 + ₦10,000 = ₦28,400 (2 sales).
/// Week adds ₦6,000 (POS) and three credit sales ₦18,400 + ₦30,000 +
/// ₦21,000 = ₦69,400 → week total ₦103,800 (6 sales).
final fixtureSales = [
  _sale('s1', palm, 2, PaymentMethod.cash, _daysAgo(0, hour: 9)),
  _sale('s2', yam, 4, PaymentMethod.transfer, _daysAgo(0, hour: 11)),
  _sale('s3', water, 5, PaymentMethod.pos, _daysAgo(3)),
  _sale('c1', palm, 2, PaymentMethod.credit, _daysAgo(3, hour: 12),
      customer: 'Chioma Ojo'),
  _sale('c2', yam, 12, PaymentMethod.credit, _daysAgo(5),
      customer: 'Abike Adeyemi'),
  _sale('c3', veg, 3, PaymentMethod.credit, _daysAgo(6),
      customer: 'Okoro Emeka'),
];

final fixtureCredits = [
  Credit(
      saleId: 'c1',
      customerName: 'Chioma Ojo',
      amount: 18400,
      product: 'Palm Oil (25L) × 2',
      status: CreditStatus.owed,
      soldAt: _daysAgo(3, hour: 12)),
  Credit(
      saleId: 'c2',
      customerName: 'Abike Adeyemi',
      amount: 30000,
      product: 'Yam (per tuber) × 12',
      status: CreditStatus.owed,
      soldAt: _daysAgo(5)),
  Credit(
      saleId: 'c3',
      customerName: 'Okoro Emeka',
      amount: 21000,
      product: 'Vegetable Oil (20L) × 3',
      status: CreditStatus.owed,
      soldAt: _daysAgo(6)),
];

/// Week total ₦42,300; one older expense brings the all-time total
/// to ₦48,700.
final fixtureExpenses = [
  Expense(
      id: 'e1',
      description: 'Delivery Cost',
      amount: 8500,
      category: ExpenseCategory.delivery,
      spentOn: _daysAgo(2)),
  Expense(
      id: 'e2',
      description: 'Stock Purchase',
      amount: 18000,
      category: ExpenseCategory.stock,
      spentOn: _daysAgo(3)),
  Expense(
      id: 'e3',
      description: 'Stall Rent',
      amount: 10000,
      category: ExpenseCategory.rent,
      spentOn: _daysAgo(4)),
  Expense(
      id: 'e4',
      description: 'Fuel/Transport',
      amount: 5800,
      category: ExpenseCategory.transport,
      spentOn: _daysAgo(5)),
  Expense(
      id: 'e5',
      description: 'Delivery Cost',
      amount: 6400,
      category: ExpenseCategory.delivery,
      spentOn: _daysAgo(40)),
];

MemoryStore fixtureStore() => MemoryStore(
      products: fixtureProducts,
      sales: fixtureSales,
      expenses: fixtureExpenses,
      credits: fixtureCredits,
    );

/// Pumps [home] under an [AppScope] with basic routes for navigation.
/// The fake auth starts signed in as "Prosper" to mirror the design.
Future<DataStore> pumpWithStore(
  WidgetTester tester,
  Widget home, {
  MemoryStore? store,
  AuthService? auth,
  SyncEngine? sync,
}) async {
  final dataStore = store ?? fixtureStore();
  await tester.pumpWidget(
    AppScope(
      store: dataStore,
      auth: auth ?? FakeAuthService(signedIn: true),
      sync: sync ?? NoopSyncEngine(),
      child: MaterialApp(home: home),
    ),
  );
  return dataStore;
}

/// Use a tall phone-like surface so whole screens fit without scrolling.
void usePhoneSurface(WidgetTester tester, {double height = 1400}) {
  tester.view.physicalSize = Size(390, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}
