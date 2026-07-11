import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/data/data_store.dart';
import 'package:prosperflow/src/data/db/app_database.dart';
import 'package:prosperflow/src/data/drift_store.dart';
import 'package:prosperflow/src/data/models.dart';

void main() {
  late AppDatabase db;
  late DriftStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftStore(db);
  });

  tearDown(() => db.close());

  test('seedIfEmpty populates demo data exactly once', () async {
    await store.seedIfEmpty();
    await store.seedIfEmpty();

    final products = await store.watchProducts().first;
    expect(products, hasLength(4));

    final credits = await store.watchOwedCredits().first;
    expect(credits, hasLength(3));

    // Seeded rows are baseline data — they must not flood the outbox.
    final outbox = await db.select(db.outbox).get();
    expect(outbox, isEmpty);
  });

  test('deleteProduct soft-deletes, hides the product, and fills the outbox',
      () async {
    await store.seedIfEmpty();
    final palm = (await store.watchProducts().first)
        .firstWhere((p) => p.name == 'Palm Oil (25L)');

    await store.deleteProduct(palm.id);

    // Hidden from the app...
    final products = await store.watchProducts().first;
    expect(products.any((p) => p.id == palm.id), isFalse);

    // ...but soft-deleted in the database, so reports keep the name.
    final row = await (db.select(db.products)
          ..where((p) => p.id.equals(palm.id)))
        .getSingle();
    expect(row.deleted, isTrue);
    expect(row.synced, isFalse);

    final outbox = await db.select(db.outbox).get();
    expect(outbox.single.entity, 'product');
    expect(outbox.single.op, 'update');
    expect(outbox.single.payloadJson, contains('"deleted":true'));
  });

  test('deleteExpense soft-deletes, updates reports, and fills the outbox',
      () async {
    await store.seedIfEmpty();
    final rent = (await store.watchExpenses().first)
        .firstWhere((e) => e.description == 'Stall Rent');
    final before = await store.watchReport(ReportPeriod.week).first;

    await store.deleteExpense(rent.id);

    final expenses = await store.watchExpenses().first;
    expect(expenses.any((e) => e.id == rent.id), isFalse);

    final after = await store.watchReport(ReportPeriod.week).first;
    expect(after.expensesTotal, before.expensesTotal - rent.amount);
    expect(after.expensesCount, before.expensesCount - 1);

    final outbox = await db.select(db.outbox).get();
    expect(outbox.single.entity, 'expense');
    expect(outbox.single.op, 'update');
    expect(outbox.single.payloadJson, contains('"deleted":true'));
  });

  test('recordSale inserts the sale, decrements stock, and fills the outbox',
      () async {
    await store.seedIfEmpty();
    final palm = (await store.watchProducts().first)
        .firstWhere((p) => p.name == 'Palm Oil (25L)');

    final before = await store.watchTodayStats().first;
    await store.recordSale(
      productId: palm.id,
      qty: 3,
      method: PaymentMethod.cash,
      fulfilment: Fulfilment.walkIn,
    );

    final products = await store.watchProducts().first;
    expect(products.firstWhere((p) => p.id == palm.id).stock, palm.stock - 3);

    final after = await store.watchTodayStats().first;
    expect(after.total, before.total + 3 * palm.sellPrice);
    expect(after.count, before.count + 1);

    final outbox = await db.select(db.outbox).get();
    expect(outbox.map((r) => '${r.entity}.${r.op}'),
        containsAll(['sale.create', 'product.update']));
  });

  test('credit sale opens a credit; marking paid moves it to cash', () async {
    await store.seedIfEmpty();
    final yam = (await store.watchProducts().first)
        .firstWhere((p) => p.name == 'Yam (per tuber)');

    await store.recordSale(
      productId: yam.id,
      qty: 4,
      method: PaymentMethod.credit,
      fulfilment: Fulfilment.walkIn,
      customerName: 'Test Customer',
    );

    final credits = await store.watchOwedCredits().first;
    final credit = credits.firstWhere(
        (c) => c.customerName == 'Test Customer');
    expect(credit.amount, 4 * yam.sellPrice);

    ReportData report = await store.watchReport(ReportPeriod.week).first;
    int bucket(PaymentMethod m) =>
        report.paymentBuckets.firstWhere((b) => b.method == m).amount;
    final creditBefore = bucket(PaymentMethod.credit);
    final cashBefore = bucket(PaymentMethod.cash);

    await store.markCreditPaid(credit.saleId);

    expect(await store.watchOwedCredits().first,
        isNot(contains(predicate<Credit>(
            (c) => c.customerName == 'Test Customer'))));

    report = await store.watchReport(ReportPeriod.week).first;
    expect(bucket(PaymentMethod.credit), creditBefore - credit.amount);
    expect(bucket(PaymentMethod.cash), cashBefore + credit.amount);
  });

  test('report periods filter by date window', () async {
    await store.seedIfEmpty();

    // Insert a sale far outside the week/month windows.
    await db.into(db.sales).insert(SalesCompanion.insert(
          id: '00000000-0000-4000-8000-000000009999',
          productId: '00000000-0000-4000-8000-000000000001',
          qty: 1,
          unitPrice: 9200,
          total: 9200,
          method: PaymentMethod.cash,
          fulfilment: Fulfilment.walkIn,
          soldAt: DateTime.now().subtract(const Duration(days: 60)),
          synced: const Value(true),
        ));

    final week = await store.watchReport(ReportPeriod.week).first;
    final all = await store.watchReport(ReportPeriod.all).first;
    expect(all.salesTotal, week.salesTotal + 9200);
    expect(all.salesCount, week.salesCount + 1);
    expect(all.expensesCount, greaterThan(week.expensesCount));
  });
}
