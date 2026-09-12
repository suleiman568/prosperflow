import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/auth/auth_service.dart';
import 'package:prosperflow/src/data/app_scope.dart';
import 'package:prosperflow/src/data/memory_store.dart';
import 'package:prosperflow/src/data/models.dart';
import 'package:prosperflow/src/screens/dashboard/dashboard_screen.dart';
import 'package:prosperflow/src/screens/products/products_screen.dart';
import 'package:prosperflow/src/screens/record_sale/record_sale_screen.dart';
import 'package:prosperflow/src/sync/sync_engine.dart';
import 'package:prosperflow/src/widgets/primary_button.dart';
import 'package:prosperflow/src/telemetry/error_reporter.dart';

import 'helpers.dart';

/// A store whose writes can be held open (via [gate]) so a test can observe
/// the in-flight busy state, and that counts how many times each write was
/// actually reached — to prove a double-tap fires the save only once.
class _GatedStore extends MemoryStore {
  _GatedStore()
    : super(
        products: fixtureProducts,
        sales: fixtureSales,
        expenses: fixtureExpenses,
        credits: fixtureCredits,
      );

  Completer<void>? gate;
  int recordSaleCalls = 0;
  int updateProductCalls = 0;

  @override
  Future<void> recordSale({
    required String productId,
    required int qty,
    required PaymentMethod method,
    required Fulfilment fulfilment,
    int? unitPrice,
    String? customerName,
    String? location,
  }) async {
    recordSaleCalls++;
    if (gate != null) await gate!.future;
    return super.recordSale(
      productId: productId,
      qty: qty,
      method: method,
      fulfilment: fulfilment,
      unitPrice: unitPrice,
      customerName: customerName,
      location: location,
    );
  }

  @override
  Future<void> updateProduct({
    required String id,
    required String name,
    required String unit,
    required int buyPrice,
    required int sellPrice,
    required int lowStockThreshold,
  }) async {
    updateProductCalls++;
    if (gate != null) await gate!.future;
    return super.updateProduct(
      id: id,
      name: name,
      unit: unit,
      buyPrice: buyPrice,
      sellPrice: sellPrice,
      lowStockThreshold: lowStockThreshold,
    );
  }
}

/// A store whose recordSale always fails, for the error-reset test.
class _FailingRecordStore extends MemoryStore {
  _FailingRecordStore() : super(products: fixtureProducts);

  int recordSaleCalls = 0;

  @override
  Future<void> recordSale({
    required String productId,
    required int qty,
    required PaymentMethod method,
    required Fulfilment fulfilment,
    int? unitPrice,
    String? customerName,
    String? location,
  }) async {
    recordSaleCalls++;
    throw StateError('simulated storage failure');
  }
}

Future<void> _pumpRecordSale(WidgetTester tester, MemoryStore store) async {
  await tester.pumpWidget(
    AppScope(
      store: store,
      auth: FakeAuthService(signedIn: true),
      sync: NoopSyncEngine(),
      reporter: const NoopErrorReporter(),
      child: MaterialApp(
        home: const RecordSaleScreen(),
        routes: {'/dashboard': (_) => const DashboardScreen()},
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'Record Sale shows a spinner and a double-tap records the sale only once',
    (tester) async {
      usePhoneSurface(tester);
      final store = _GatedStore();
      store.gate = Completer<void>();
      await _pumpRecordSale(tester, store);

      await tester.tap(find.byIcon(Icons.add)); // qty 2
      await tester.pump();

      // Kick off the save; it hangs at the gated store write.
      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();

      // In progress: spinner shown, save reached exactly once.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(store.recordSaleCalls, 1);

      // A second tap while busy can't fire the save again.
      await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
      await tester.pump();
      expect(store.recordSaleCalls, 1);

      // Finishing the write navigates to the dashboard and decrements stock.
      store.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Welcome back, Prosper 👋'), findsOneWidget);
      expect(store.recordSaleCalls, 1);
      final products = await store.watchProducts().first;
      expect(products.firstWhere((p) => p.id == 'p1').stock, 40); // 42 − 2
    },
  );

  testWidgets('a failed sale clears the busy state so the trader can retry', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final store = _FailingRecordStore();
    await _pumpRecordSale(tester, store);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    // The failure surfaces, the button is released (no stuck spinner), and
    // we're still on the sale screen.
    expect(store.recordSaleCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining("Couldn't save the sale"), findsOneWidget);
    expect(find.byType(RecordSaleScreen), findsOneWidget);

    // Retrying fires the save again — the button wasn't left disabled.
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();
    expect(store.recordSaleCalls, 2);
  });

  testWidgets(
    'Edit Product shows a spinner and a double-tap saves the edit only once',
    (tester) async {
      usePhoneSurface(tester);
      final store = _GatedStore();
      store.gate = Completer<void>();
      await pumpWithStore(tester, const ProductsScreen(), store: store);
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Red Oil (25L)');

      // Kick off the save; it hangs at the gated store write.
      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(store.updateProductCalls, 1);

      // A second tap while busy can't fire the save again.
      await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
      await tester.pump();
      expect(store.updateProductCalls, 1);

      // Finishing the write closes the sheet and persists the single edit.
      store.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Edit Product'), findsNothing);
      expect(store.updateProductCalls, 1);
      final products = await store.watchProducts().first;
      expect(products.firstWhere((p) => p.id == palm.id).name, 'Red Oil (25L)');
    },
  );
}
