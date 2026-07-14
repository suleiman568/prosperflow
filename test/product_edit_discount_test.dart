import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/auth/auth_service.dart';
import 'package:prosperflow/src/data/app_scope.dart';
import 'package:prosperflow/src/data/db/app_database.dart';
import 'package:prosperflow/src/data/drift_store.dart';
import 'package:prosperflow/src/data/memory_store.dart';
import 'package:prosperflow/src/data/models.dart';
import 'package:prosperflow/src/screens/dashboard/dashboard_screen.dart';
import 'package:prosperflow/src/screens/products/products_screen.dart';
import 'package:prosperflow/src/screens/record_sale/record_sale_screen.dart';
import 'package:prosperflow/src/screens/reports/reports_screen.dart';
import 'package:prosperflow/src/sync/sync_backend.dart';
import 'package:prosperflow/src/sync/sync_engine.dart';
import 'package:prosperflow/src/theme/tokens.dart';
import 'package:prosperflow/src/widgets/primary_button.dart';

import 'helpers.dart';
import 'seed_data.dart';

/// TextFields inside the currently open bottom sheet, in layout order.
Finder sheetField(int index) => find
    .descendant(of: find.byType(BottomSheet), matching: find.byType(TextField))
    .at(index);

/// Record Sale navigates to /dashboard after saving, so it needs a route.
Future<void> pumpRecordSale(WidgetTester tester, MemoryStore store) async {
  await tester.pumpWidget(
    AppScope(
      store: store,
      auth: FakeAuthService(signedIn: true),
      sync: NoopSyncEngine(),
      child: MaterialApp(
        home: const RecordSaleScreen(),
        routes: {'/dashboard': (_) => const DashboardScreen()},
      ),
    ),
  );
  await tester.pump();
}

class _RecordingBackend implements SyncBackend {
  final applied = <(String entity, String op, Map<String, dynamic> payload)>[];

  @override
  bool get canPush => true;

  @override
  Future<void> apply(
      String entity, String op, Map<String, dynamic> payload) async {
    applied.add((entity, op, payload));
  }
}

void main() {
  group('DriftStore', () {
    late AppDatabase db;
    late DriftStore store;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      store = DriftStore(db);
      await seedDatabase(db);
    });

    tearDown(() => db.close());

    Future<Product> palmRow() async => (await store.watchProducts().first)
        .firstWhere((p) => p.name.startsWith('Palm Oil'));

    test('updateProduct edits fields, keeps stock, and fills the outbox',
        () async {
      final before = await palmRow();

      await store.updateProduct(
        id: before.id,
        name: 'Palm Oil (30L)',
        unit: 'kegs',
        buyPrice: 7000,
        sellPrice: 9500,
        lowStockThreshold: 5,
      );

      final after = (await store.watchProducts().first)
          .firstWhere((p) => p.id == before.id);
      expect(after.name, 'Palm Oil (30L)');
      expect(after.unit, 'kegs');
      expect(after.buyPrice, 7000);
      expect(after.sellPrice, 9500);
      expect(after.lowStockThreshold, 5);
      expect(after.stock, before.stock); // stock untouched by edits

      final outbox = await db.select(db.outbox).get();
      expect(outbox.single.entity, 'product');
      expect(outbox.single.op, 'update');
      expect(outbox.single.payloadJson, contains('"sell_price":9500'));
      expect(outbox.single.payloadJson, contains('"low_stock_threshold":5'));
    });

    test('a rename relabels past sales in history (read-time names)',
        () async {
      final palmBefore = await palmRow();
      await store.recordSale(
        productId: palmBefore.id,
        qty: 1,
        method: PaymentMethod.cash,
        fulfilment: Fulfilment.walkIn,
      );

      await store.updateProduct(
        id: palmBefore.id,
        name: 'Red Oil',
        unit: palmBefore.unit,
        buyPrice: palmBefore.buyPrice,
        sellPrice: palmBefore.sellPrice,
        lowStockThreshold: palmBefore.lowStockThreshold,
      );

      final history = await store.watchTodayHistory().first;
      final group =
          history.groups.firstWhere((g) => g.productId == palmBefore.id);
      expect(group.productName, 'Red Oil');
    });

    test('editing a product with pending offline sales stays consistent',
        () async {
      final backend = _RecordingBackend();
      final connectivity = StreamController<bool>.broadcast();
      final engine = DriftSyncEngine(
        db,
        backend,
        connectivity: connectivity.stream,
        initiallyOnline: false,
        writeDebounce: const Duration(milliseconds: 1),
      );

      final palm = await palmRow();
      await store.recordSale(
        productId: palm.id,
        qty: 2,
        method: PaymentMethod.cash,
        fulfilment: Fulfilment.walkIn,
      );
      // Edit the price while the sale is still queued offline.
      await store.updateProduct(
        id: palm.id,
        name: palm.name,
        unit: palm.unit,
        buyPrice: palm.buyPrice,
        sellPrice: 9900,
        lowStockThreshold: palm.lowStockThreshold,
      );

      connectivity.add(true);
      await pumpEventQueue(times: 50);

      // The queued sale pushes with the price it was SOLD at, and the
      // product edit follows it in write order.
      final salePush =
          backend.applied.firstWhere((r) => r.$1 == 'sale' && r.$2 == 'create');
      expect(salePush.$3['unit_price'], palm.sellPrice);
      final productEdits = backend.applied
          .where((r) => r.$1 == 'product' && r.$3['sell_price'] == 9900);
      expect(productEdits, hasLength(1));
      expect(backend.applied.indexOf(salePush),
          lessThan(backend.applied.toList().indexOf(productEdits.single)));
      expect(await db.select(db.outbox).get(), isEmpty);

      engine.dispose();
      await connectivity.close();
    });

    test('recordSale with a custom price stores unitPrice + listPrice',
        () async {
      final palm = await palmRow();
      await store.recordSale(
        productId: palm.id,
        qty: 2,
        method: PaymentMethod.cash,
        fulfilment: Fulfilment.walkIn,
        unitPrice: 8700, // ₦500 off 9,200
      );

      final row = await (db.select(db.sales)
            ..where((s) => s.synced.equals(false)))
          .getSingle();
      expect(row.unitPrice, 8700);
      expect(row.listPrice, palm.sellPrice);
      expect(row.total, 2 * 8700);

      final salePush = (await db.select(db.outbox).get())
          .firstWhere((o) => o.entity == 'sale');
      expect(salePush.payloadJson, contains('"unit_price":8700'));
      expect(salePush.payloadJson, contains('"list_price":9200'));

      // Profit uses the discounted price against the cost snapshot.
      final history = await store.watchTodayHistory().first;
      final entry = history.groups
          .firstWhere((g) => g.productId == palm.id)
          .entries
          .firstWhere((e) => e.unitPrice == 8700);
      expect(entry.profit, (8700 - palm.buyPrice) * 2);
      expect(entry.listPrice, palm.sellPrice);
      expect(entry.discounted, isTrue);
    });

    test('recordSale without an override leaves listPrice NULL', () async {
      final palm = await palmRow();
      await store.recordSale(
        productId: palm.id,
        qty: 1,
        method: PaymentMethod.cash,
        fulfilment: Fulfilment.walkIn,
      );
      final row = await (db.select(db.sales)
            ..where((s) => s.synced.equals(false)))
          .getSingle();
      expect(row.listPrice, isNull);
    });

    test('a below-cost price produces a negative profit (loss)', () async {
      final palm = await palmRow(); // buy 6,800
      await store.recordSale(
        productId: palm.id,
        qty: 3,
        method: PaymentMethod.cash,
        fulfilment: Fulfilment.walkIn,
        unitPrice: 6000,
      );
      final history = await store.watchTodayHistory().first;
      final entry = history.groups
          .firstWhere((g) => g.productId == palm.id)
          .entries
          .firstWhere((e) => e.unitPrice == 6000);
      expect(entry.profit, (6000 - 6800) * 3); // −2,400
      expect(entry.profit, isNegative);
    });

    test('DriftStore and MemoryStore agree after the same edit + discount',
        () async {
      final seed = SeedData.build(DateTime.now());
      final memory = MemoryStore(
        products: seed.products,
        sales: seed.sales,
        expenses: seed.expenses,
        credits: seed.credits,
      );

      final palmId = seed.products.first.id;
      Future<void> apply(dynamic s) async {
        await s.updateProduct(
          id: palmId,
          name: 'Red Oil',
          unit: 'kegs',
          buyPrice: 7000,
          sellPrice: 9500,
          lowStockThreshold: 5,
        );
        await s.recordSale(
          productId: palmId,
          qty: 2,
          method: PaymentMethod.cash,
          fulfilment: Fulfilment.walkIn,
          unitPrice: 9000,
        );
      }

      await apply(store);
      await apply(memory);

      (String, String, int, int, int, int) shape(Product p) =>
          (p.name, p.unit, p.buyPrice, p.sellPrice, p.lowStockThreshold,
              p.stock);
      final driftPalm = (await store.watchProducts().first)
          .firstWhere((p) => p.id == palmId);
      final memoryPalm = (await memory.watchProducts().first)
          .firstWhere((p) => p.id == palmId);
      expect(shape(memoryPalm), shape(driftPalm));

      final driftHistory = await store.watchTodayHistory().first;
      final memoryHistory = await memory.watchTodayHistory().first;
      final driftGroup =
          driftHistory.groups.firstWhere((g) => g.productId == palmId);
      final memoryGroup =
          memoryHistory.groups.firstWhere((g) => g.productId == palmId);
      expect(memoryGroup.productName, driftGroup.productName); // 'Red Oil'
      expect(memoryGroup.revenue, driftGroup.revenue);
      expect(memoryGroup.profit, driftGroup.profit);
      final driftEntry =
          driftGroup.entries.firstWhere((e) => e.unitPrice == 9000);
      final memoryEntry =
          memoryGroup.entries.firstWhere((e) => e.unitPrice == 9000);
      expect(memoryEntry.listPrice, driftEntry.listPrice); // 9,500
      expect(memoryEntry.profit, driftEntry.profit); // (9,000−7,000)×2
    });
  });

  group('Products UI', () {
    testWidgets('three-dot Edit opens a prefilled sheet and saves changes',
        (tester) async {
      usePhoneSurface(tester);
      final store = fixtureStore();
      await pumpWithStore(tester, const ProductsScreen(), store: store);
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Product'), findsOneWidget);
      // Prefilled with the product's current values (fields in order:
      // name, unit, buy, sell, threshold).
      final fields = find.byType(TextField);
      expect(tester.widget<TextField>(fields.at(0)).controller!.text,
          'Palm Oil (25L)');
      expect(tester.widget<TextField>(fields.at(3)).controller!.text, '9200');

      await tester.enterText(fields.at(0), 'Red Oil (25L)');
      await tester.enterText(fields.at(3), '9500');
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(find.text('Red Oil (25L)'), findsOneWidget);
      expect(find.text('₦6,800 → ₦9,500'), findsOneWidget);
      final products = await store.watchProducts().first;
      final edited = products.firstWhere((p) => p.id == palm.id);
      expect(edited.name, 'Red Oil (25L)');
      expect(edited.sellPrice, 9500);
    });
  });

  group('Record Sale UI', () {
    testWidgets(
        'custom below-cost price: sheet + inline warnings, confirm dialog, '
        'sale recorded discounted', (tester) async {
      usePhoneSurface(tester);
      final store = fixtureStore();
      await pumpRecordSale(tester, store);

      // Open the adjust-price sheet and type a below-cost price.
      await tester.tap(find.text('₦9,200').first);
      await tester.pumpAndSettle();
      expect(find.text('Adjust price'), findsOneWidget);

      await tester.enterText(sheetField(0), '6000');
      await tester.pump();
      expect(find.textContaining('Below cost'), findsOneWidget);

      await tester.tap(find.text('Apply price'));
      await tester.pumpAndSettle();

      // Main screen shows the discounted price, strikethrough, and warning.
      expect(find.text('₦6,000'), findsWidgets);
      expect(find.textContaining('Below cost — this sale loses'),
          findsOneWidget);

      // Saving asks for confirmation, and "Sell anyway" records the sale.
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(find.text('Sell below cost?'), findsOneWidget);
      await tester.tap(find.text('Sell anyway'));
      await tester.pumpAndSettle();

      final history = await store.watchTodayHistory().first;
      final entry = history.groups
          .firstWhere((g) => g.productId == palm.id)
          .entries
          .firstWhere((e) => e.unitPrice == 6000);
      expect(entry.listPrice, 9200);
      expect(entry.profit, (6000 - 6800) * 1);
    });

    testWidgets('percent discount computes the price in the sheet',
        (tester) async {
      usePhoneSurface(tester);
      await pumpWithStore(tester, const RecordSaleScreen());
      await tester.pump();

      await tester.tap(find.text('₦9,200').first);
      await tester.pumpAndSettle();
      await tester.enterText(sheetField(1), '10');
      await tester.pump();
      expect(find.text('Final price: ₦8,280 (10% off)'), findsOneWidget);
    });

    testWidgets('cancelling the below-cost dialog does not record a sale',
        (tester) async {
      usePhoneSurface(tester);
      final store = fixtureStore();
      await pumpRecordSale(tester, store);

      await tester.tap(find.text('₦9,200').first);
      await tester.pumpAndSettle();
      await tester.enterText(sheetField(0), '5000');
      await tester.tap(find.text('Apply price'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final history = await store.watchTodayHistory().first;
      final palmGroup =
          history.groups.firstWhere((g) => g.productId == palm.id);
      expect(palmGroup.entries.any((e) => e.unitPrice == 5000), isFalse);
    });
  });

  group('Reports UI', () {
    testWidgets(
        'discounted sale shows strikethrough list price; loss is red, '
        'profit is green', (tester) async {
      usePhoneSurface(tester, height: 3200);
      final store = fixtureStore();
      // A below-cost discounted sale (loss) alongside the fixtures' normal
      // profitable sales.
      await store.recordSale(
        productId: veg.id, // buy 5,200 / sell 7,000
        qty: 1,
        method: PaymentMethod.cash,
        fulfilment: Fulfilment.walkIn,
        unitPrice: 5000,
      );

      await pumpWithStore(tester, const ReportsScreen(), store: store);
      await tester.pump();
      await tester.pump();

      // Expand the veg group (its revenue line).
      await tester.tap(find.textContaining('-₦200 profit'));
      await tester.pump();

      // Strikethrough list price + discounted marker on the entry.
      final struck = tester.widget<Text>(find.text('₦7,000').last);
      expect(struck.style?.decoration, TextDecoration.lineThrough);
      expect(find.textContaining('· discounted'), findsOneWidget);

      // Loss text is red; a profitable group's text is green.
      final lossText = tester.widget<Text>(find.text('-₦200').last);
      expect(lossText.style?.color, AppColors.accentRed);
      final gainText =
          tester.widget<Text>(find.text('+₦4,800 profit').first);
      expect(gainText.style?.color, AppColors.primary);
    });
  });
}
