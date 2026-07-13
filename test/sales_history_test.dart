import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/data/data_store.dart';
import 'package:prosperflow/src/data/db/app_database.dart';
import 'package:prosperflow/src/data/drift_store.dart';
import 'package:prosperflow/src/data/memory_store.dart';
import 'package:prosperflow/src/data/models.dart';
import 'package:prosperflow/src/screens/reports/reports_screen.dart';

import 'helpers.dart';
import 'seed_data.dart';

Sale _todaySale(
  String id,
  Product product,
  int qty, {
  int? unitCost,
  PaymentMethod method = PaymentMethod.cash,
  int hour = 9,
  String? customer,
}) {
  final now = DateTime.now();
  return Sale(
    id: id,
    productId: product.id,
    productName: product.name,
    qty: qty,
    unitPrice: product.sellPrice,
    unitCost: unitCost,
    total: qty * product.sellPrice,
    method: method,
    fulfilment: Fulfilment.walkIn,
    customerName: customer,
    soldAt: DateTime(now.year, now.month, now.day, hour),
  );
}

void main() {
  group('buildTodayHistory', () {
    test('profit math: (sell − cost) × qty per sale, summed per group',
        () async {
      final history = buildTodayHistory(
        sales: [
          _todaySale('a', palm, 2, unitCost: 6800), // (9200−6800)×2 = 4800
          _todaySale('b', palm, 1, unitCost: 6800), // 2400
          _todaySale('c', yam, 4, unitCost: 1200), // (2500−1200)×4 = 5200
        ],
        paidCreditSaleIds: {},
        now: DateTime.now(),
      );

      expect(history.revenue, 3 * 9200 + 4 * 2500);
      expect(history.profit, 4800 + 2400 + 5200);
      expect(history.missingCostCount, 0);

      final palmGroup =
          history.groups.firstWhere((g) => g.productId == palm.id);
      expect(palmGroup.qty, 3);
      expect(palmGroup.revenue, 3 * 9200);
      expect(palmGroup.profit, 7200);
      expect(palmGroup.profitIsPartial, isFalse);
    });

    test('NULL-cost sales stay in revenue but leave the profit sum', () {
      final history = buildTodayHistory(
        sales: [
          _todaySale('a', palm, 2, unitCost: 6800), // 4800 profit
          _todaySale('b', palm, 1), // legacy: no cost
          _todaySale('c', yam, 1), // legacy: no cost
        ],
        paidCreditSaleIds: {},
        now: DateTime.now(),
      );

      // Revenue counts every sale; profit only the costed one.
      expect(history.revenue, 3 * 9200 + 2500);
      expect(history.profit, 4800);
      expect(history.missingCostCount, 2);

      final palmGroup =
          history.groups.firstWhere((g) => g.productId == palm.id);
      expect(palmGroup.profit, 4800);
      expect(palmGroup.profitIsPartial, isTrue); // mixed group → flagged

      // A group where NO sale has a cost has null profit → rendered "—".
      final yamGroup = history.groups.firstWhere((g) => g.productId == yam.id);
      expect(yamGroup.profit, isNull);
      expect(yamGroup.missingCostCount, 1);
    });

    test('groups key on productId, so shared names stay separate', () {
      const otherPalm = Product(
        id: 'palm-2',
        name: 'Palm Oil (25L)', // same display name, different product
        unit: 'bottles',
        stock: 5,
        buyPrice: 7000,
        sellPrice: 9500,
      );
      final history = buildTodayHistory(
        sales: [
          _todaySale('a', palm, 1, unitCost: 6800),
          _todaySale('b', otherPalm, 1, unitCost: 7000),
        ],
        paidCreditSaleIds: {},
        now: DateTime.now(),
      );

      expect(history.groups, hasLength(2));
      expect(history.groups.map((g) => g.productId).toSet(),
          {palm.id, otherPalm.id});
      expect(history.groups.map((g) => g.productName).toSet(),
          {'Palm Oil (25L)'});
    });

    test('collected credit sales are flagged; open ones are not', () {
      final history = buildTodayHistory(
        sales: [
          _todaySale('paid-sale', palm, 1,
              unitCost: 6800, method: PaymentMethod.credit, customer: 'A'),
          _todaySale('open-sale', palm, 1,
              unitCost: 6800, method: PaymentMethod.credit, customer: 'B'),
          _todaySale('cash-sale', palm, 1, unitCost: 6800),
        ],
        paidCreditSaleIds: {'paid-sale'},
        now: DateTime.now(),
      );

      final entries = history.groups.single.entries;
      expect(
          entries.where((e) => e.method == PaymentMethod.credit && e.collected),
          hasLength(1));
      expect(
          entries
              .where((e) => e.method == PaymentMethod.credit && !e.collected),
          hasLength(1));
      expect(
          entries
              .where((e) => e.method == PaymentMethod.cash)
              .single
              .collected,
          isFalse);
    });

    test('yesterday’s sales are excluded (startOfToday boundary)', () {
      final now = DateTime.now();
      final yesterday = Sale(
        id: 'y',
        productId: palm.id,
        productName: palm.name,
        qty: 1,
        unitPrice: palm.sellPrice,
        unitCost: palm.buyPrice,
        total: palm.sellPrice,
        method: PaymentMethod.cash,
        fulfilment: Fulfilment.walkIn,
        soldAt: DateTime(now.year, now.month, now.day)
            .subtract(const Duration(minutes: 1)),
      );
      final history = buildTodayHistory(
        sales: [yesterday, _todaySale('t', palm, 1, unitCost: 6800)],
        paidCreditSaleIds: {},
        now: now,
      );
      expect(history.groups.single.entries, hasLength(1));
      expect(history.revenue, palm.sellPrice);
    });
  });

  group('DriftStore', () {
    late AppDatabase db;
    late DriftStore store;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      store = DriftStore(db);
      await seedDatabase(db);
    });

    tearDown(() => db.close());

    test('recordSale stores unitCost and the outbox payload includes it',
        () async {
      final palmRow = (await store.watchProducts().first)
          .firstWhere((p) => p.name == 'Palm Oil (25L)');

      await store.recordSale(
        productId: palmRow.id,
        qty: 2,
        method: PaymentMethod.cash,
        fulfilment: Fulfilment.walkIn,
      );

      // The freshly recorded sale is the only unsynced one.
      final row = await (db.select(db.sales)
            ..where((s) => s.synced.equals(false)))
          .getSingle();
      expect(row.unitCost, palmRow.buyPrice);

      final outbox = await db.select(db.outbox).get();
      final salePush = outbox.firstWhere((o) => o.entity == 'sale');
      expect(salePush.payloadJson, contains('"unit_cost":6800'));
    });

    test('a deleted product still resolves its name in today’s history',
        () async {
      final palmRow = (await store.watchProducts().first)
          .firstWhere((p) => p.name == 'Palm Oil (25L)');

      await store.recordSale(
        productId: palmRow.id,
        qty: 1,
        method: PaymentMethod.cash,
        fulfilment: Fulfilment.walkIn,
      );
      await store.deleteProduct(palmRow.id);

      final history = await store.watchTodayHistory().first;
      final group =
          history.groups.firstWhere((g) => g.productId == palmRow.id);
      expect(group.productName, 'Palm Oil (25L)');
    });

    test('legacy NULL-cost rows show in revenue, not profit', () async {
      final now = DateTime.now();
      await db.into(db.sales).insert(SalesCompanion.insert(
            id: '00000000-0000-4000-8000-000000008888',
            productId: '00000000-0000-4000-8000-000000000001',
            qty: 1,
            unitPrice: 9200,
            total: 9200,
            method: PaymentMethod.cash,
            fulfilment: Fulfilment.walkIn,
            soldAt: DateTime(now.year, now.month, now.day, 7),
            synced: const Value(true),
            // unitCost deliberately absent — a pre-v3 row.
          ));

      final history = await store.watchTodayHistory().first;
      final palmGroup = history.groups
          .firstWhere((g) => g.productId.endsWith('000000000001'));
      expect(palmGroup.missingCostCount, greaterThan(0));
      expect(history.revenue, greaterThanOrEqualTo(9200));
    });

    test('DriftStore and MemoryStore build identical histories', () async {
      // Mirror the drift seed into a MemoryStore and compare outputs.
      final seed = SeedData.build(DateTime.now());
      final memory = MemoryStore(
        products: seed.products,
        sales: seed.sales,
        expenses: seed.expenses,
        credits: seed.credits,
      );

      final fromDrift = await store.watchTodayHistory().first;
      final fromMemory = await memory.watchTodayHistory().first;

      expect(fromMemory.revenue, fromDrift.revenue);
      expect(fromMemory.profit, fromDrift.profit);
      expect(fromMemory.missingCostCount, fromDrift.missingCostCount);
      List<(String, int, int, int?)> shape(TodayHistory h) => [
            for (final g in h.groups)
              (g.productId, g.qty, g.revenue, g.profit),
          ];
      expect(shape(fromMemory), shape(fromDrift));
    });
  });

  group('Reports UI', () {
    testWidgets('shows day summary, groups, and expandable detail',
        (tester) async {
      usePhoneSurface(tester, height: 3200);
      await pumpWithStore(tester, const ReportsScreen());
      await tester.pump();
      await tester.pump(); // history stream's first emission

      expect(find.text('Sales History for Today'), findsOneWidget);
      expect(find.text("TODAY'S REVENUE"), findsOneWidget);
      expect(find.text('₦28,400'), findsOneWidget); // s1 18,400 + s2 10,000
      expect(find.text('+₦10,000'), findsOneWidget); // 4,800 + 5,200

      // Grouped rows, collapsed by default.
      expect(find.text('+₦4,800 profit'), findsOneWidget); // palm group
      expect(find.text('2 × ₦9,200'), findsNothing);

      // Expanding palm reveals its sale with time and method.
      await tester.tap(find.text('+₦4,800 profit'));
      await tester.pump();
      expect(find.text('2 × ₦9,200'), findsOneWidget);
      expect(find.textContaining('9:00 AM · Cash'), findsOneWidget);

      // Collapse again.
      await tester.tap(find.text('+₦4,800 profit'));
      await tester.pump();
      expect(find.text('2 × ₦9,200'), findsNothing);
    });

    testWidgets(
        'expand/collapse reuses the same stream — no resubscribe, no blank '
        'frame', (tester) async {
      usePhoneSurface(tester, height: 3200);
      await pumpWithStore(tester, const ReportsScreen());
      await tester.pump();
      await tester.pump();

      Stream<TodayHistory> currentStream() => tester
          .widget<StreamBuilder<TodayHistory>>(
              find.byWidgetPredicate((w) => w is StreamBuilder<TodayHistory>))
          .stream!;
      final before = currentStream();

      // Expand: pump exactly one frame. With a recreated stream the
      // builder's snapshot would reset and the section would blank out.
      await tester.tap(find.text('+₦4,800 profit'));
      await tester.pump();

      expect(identical(currentStream(), before), isTrue,
          reason: 'watchTodayHistory() must not be re-called on setState');
      expect(find.text("TODAY'S REVENUE"), findsOneWidget);
      expect(find.text('₦28,400'), findsOneWidget);
      expect(find.text('2 × ₦9,200'), findsOneWidget); // expansion applied
    });

    testWidgets('collected credit sales read "Credit → Collected"',
        (tester) async {
      usePhoneSurface(tester, height: 3200);
      final store = fixtureStore();
      await store.recordSale(
        productId: veg.id,
        qty: 1,
        method: PaymentMethod.credit,
        fulfilment: Fulfilment.walkIn,
        customerName: 'Ngozi',
      );
      final credit = (await store.watchOwedCredits().first)
          .firstWhere((c) => c.customerName == 'Ngozi');
      await store.markCreditPaid(credit.saleId);

      await pumpWithStore(tester, const ReportsScreen(), store: store);
      await tester.pump();
      await tester.pump(); // history stream's first emission

      await tester.tap(find.textContaining('+₦1,800 profit')); // veg group
      await tester.pump();
      expect(find.textContaining('Credit → Collected'), findsOneWidget);
    });

    testWidgets('empty state when nothing has been sold today',
        (tester) async {
      usePhoneSurface(tester, height: 2400);
      await pumpWithStore(tester, const ReportsScreen(),
          store: MemoryStore(products: fixtureProducts));
      await tester.pump();
      await tester.pump(); // history stream's first emission

      expect(find.text('🌅 No sales recorded yet today'), findsOneWidget);
    });
  });
}
