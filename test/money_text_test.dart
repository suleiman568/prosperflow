import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/auth/auth_service.dart';
import 'package:prosperflow/src/data/app_scope.dart';
import 'package:prosperflow/src/data/memory_store.dart';
import 'package:prosperflow/src/data/models.dart';
import 'package:prosperflow/src/screens/credits/credits_screen.dart';
import 'package:prosperflow/src/screens/dashboard/dashboard_screen.dart';
import 'package:prosperflow/src/screens/reports/reports_screen.dart';
import 'package:prosperflow/src/sync/sync_engine.dart';
import 'package:prosperflow/src/widgets/money_text.dart';
import 'package:prosperflow/src/telemetry/error_reporter.dart';

/// Loads the bundled Inter faces so glyph widths match the real app — the
/// test-default font renders every glyph as a square, which would make the
/// fits-vs-scales math meaningless.
Future<void> _loadInter() async {
  for (final f in [
    'Inter-Regular',
    'Inter-Medium',
    'Inter-SemiBold',
    'Inter-Bold',
    'Inter-ExtraBold',
    'Inter-Black',
  ]) {
    final loader = FontLoader('Inter')
      ..addFont(
        Future.value(
          ByteData.view(File('assets/fonts/$f.ttf').readAsBytesSync().buffer),
        ),
      );
    await loader.load();
  }
}

Sale _saleToday(int total) => Sale(
  id: 's-big',
  productId: 'p1',
  productName: 'Palm Oil (25L)',
  qty: 1,
  unitPrice: total,
  unitCost: 100,
  total: total,
  method: PaymentMethod.cash,
  fulfilment: Fulfilment.walkIn,
  soldAt: DateTime.now(),
);

const _palm = Product(
  id: 'p1',
  name: 'Palm Oil (25L)',
  unit: 'bottles',
  stock: 42,
  buyPrice: 6800,
  sellPrice: 9200,
);

Future<void> _pumpScreen(
  WidgetTester tester,
  Widget home,
  MemoryStore store,
) async {
  await tester.pumpWidget(
    AppScope(
      store: store,
      auth: FakeAuthService(signedIn: true),
      sync: NoopSyncEngine(),
      reporter: const NoopErrorReporter(),
      child: MaterialApp(home: home),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// A 360dp phone — the width where the wrap bug reproduced.
void _usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(_loadInter);

  testWidgets(
    'a 7-digit amount stays on one line in the dashboard stat cards',
    (tester) async {
      _usePhone(tester);
      final store = MemoryStore(
        products: const [_palm],
        sales: [_saleToday(1339000)],
      );
      await _pumpScreen(tester, const DashboardScreen(), store);

      expect(tester.takeException(), isNull);
      // Both stat cards show the amount, intact (never split across lines).
      expect(find.text('₦1,339,000'), findsNWidgets(2));
      // One line: the scaled figure's box is well under two 24px lines
      // (unscaled single line ≈ 34px; the pre-fix wrap measured 68px).
      final box = tester.getSize(find.byType(MoneyText).first);
      expect(box.height, lessThan(40));
    },
  );

  testWidgets('an amount that fits renders at its natural size (no scaling)', (
    tester,
  ) async {
    _usePhone(tester);
    final store = MemoryStore(
      products: const [_palm],
      sales: [_saleToday(18400)],
    );
    await _pumpScreen(tester, const DashboardScreen(), store);

    // When the figure fits, FittedBox(scaleDown) sizes exactly to the text,
    // so the MoneyText box equals the Text's natural box — nothing shrank.
    final outer = tester.getSize(find.byType(MoneyText).first);
    final text = tester.getSize(find.text('₦18,400').first);
    expect(outer, text);
  });

  testWidgets('the reports totals cards keep a huge figure on one line', (
    tester,
  ) async {
    _usePhone(tester);
    // A revenue big enough to breach the totals card's ~126px slot at 20px.
    final store = MemoryStore(
      products: const [_palm],
      sales: [_saleToday(123456789000)],
    );
    await _pumpScreen(tester, const ReportsScreen(), store);

    expect(tester.takeException(), isNull);
    expect(find.text('₦123,456,789,000'), findsWidgets);
    // The today-history banner's signed profit (total − ₦100 cost) stays a
    // single intact string too.
    expect(find.text('+₦123,456,788,900'), findsOneWidget);
    for (final money in find.byType(MoneyText).evaluate().map((e) => e.size!)) {
      // statValue is 20px (line ≈ 28px) and moneyHero 32px (line ≈ 45px);
      // anything two-line would be 56px+.
      expect(money.height, lessThan(50));
    }
  });

  testWidgets('the credits banner survives an extreme total without overflow', (
    tester,
  ) async {
    _usePhone(tester);
    final store = MemoryStore(
      credits: [
        Credit(
          saleId: 'c-huge',
          customerName: 'Ada Obi',
          amount: 999999999999,
          product: 'Palm Oil (25L) × 9999',
          status: CreditStatus.owed,
          soldAt: DateTime.now(),
        ),
      ],
    );
    await _pumpScreen(tester, const CreditsScreen(), store);

    // Pre-fix this row overflowed horizontally (yellow/black stripe
    // exception); now the figure scales down inside its Expanded slot.
    expect(tester.takeException(), isNull);
    // Matches the banner total and the (identical) single card amount.
    expect(find.text('₦999,999,999,999'), findsNWidgets(2));
  });
}
