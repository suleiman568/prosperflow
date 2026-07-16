import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/data/data_store.dart';
import 'package:prosperflow/src/data/db/app_database.dart';
import 'package:prosperflow/src/data/drift_store.dart';
import 'package:prosperflow/src/data/memory_store.dart';
import 'package:prosperflow/src/data/models.dart';
import 'package:prosperflow/src/export/csv_export.dart';
import 'package:prosperflow/src/export/pdf_export.dart';
import 'package:prosperflow/src/export/share_export.dart';
import 'package:prosperflow/src/screens/reports/reports_screen.dart';

import 'helpers.dart';
import 'seed_data.dart';

void main() {
  group('exportBundle', () {
    late AppDatabase db;
    late DriftStore store;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      store = DriftStore(db);
      await seedDatabase(db);
    });

    tearDown(() => db.close());

    test('respects the period window and matches the screen aggregates',
        () async {
      // An old sale outside the week window, so week < all is meaningful.
      await db.into(db.sales).insert(SalesCompanion.insert(
            id: '00000000-0000-4000-8000-000000006666',
            productId: '00000000-0000-4000-8000-000000000001',
            qty: 1,
            unitPrice: 9200,
            total: 9200,
            method: PaymentMethod.cash,
            fulfilment: Fulfilment.walkIn,
            soldAt: DateTime.now().subtract(const Duration(days: 60)),
            synced: const Value(true),
          ));

      final week = await store.exportBundle(ReportPeriod.week);
      final all = await store.exportBundle(ReportPeriod.all);
      final weekReport = await store.watchReport(ReportPeriod.week).first;

      expect(week.report.salesTotal, weekReport.salesTotal);
      expect(week.report.expensesCount, weekReport.expensesCount);
      expect(all.sales.length, greaterThan(week.sales.length));
      expect(all.expenses.length, greaterThan(week.expenses.length));

      // Rows are newest first.
      for (var i = 1; i < week.sales.length; i++) {
        expect(
            week.sales[i - 1].soldAt.isBefore(week.sales[i].soldAt), isFalse);
      }
    });

    test('DriftStore and MemoryStore build identical bundles (parity)',
        () async {
      final seed = SeedData.build(DateTime.now());
      final memory = MemoryStore(
        products: seed.products,
        sales: seed.sales,
        expenses: seed.expenses,
        credits: seed.credits,
      );

      for (final period in ReportPeriod.values) {
        final fromDrift = await store.exportBundle(period);
        final fromMemory = await memory.exportBundle(period);
        expect(fromMemory.sales.length, fromDrift.sales.length);
        expect(fromMemory.expenses.length, fromDrift.expenses.length);
        expect(fromMemory.report.salesTotal, fromDrift.report.salesTotal);
        expect(fromMemory.report.expensesTotal, fromDrift.report.expensesTotal);
        expect(fromMemory.marginProfit, fromDrift.marginProfit);
        expect(fromMemory.missingCostCount, fromDrift.missingCostCount);
        expect(fromMemory.sales.map((s) => s.id).toSet(),
            fromDrift.sales.map((s) => s.id).toSet());
      }
    });
  });

  group('CSV export', () {
    late AppDatabase db;
    late DriftStore store;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      store = DriftStore(db);
      await seedDatabase(db);
    });

    tearDown(() => db.close());

    test('discounted, legacy, and normal sales export faithfully', () async {
      final palm = (await store.watchProducts().first)
          .firstWhere((p) => p.name.startsWith('Palm Oil'));

      // A discounted sale and a legacy pre-cost-tracking sale.
      await store.recordSale(
        productId: palm.id,
        qty: 2,
        method: PaymentMethod.cash,
        fulfilment: Fulfilment.walkIn,
        unitPrice: 8700,
      );
      final now = DateTime.now();
      await db.into(db.sales).insert(SalesCompanion.insert(
            id: '00000000-0000-4000-8000-000000007777',
            productId: palm.id,
            qty: 1,
            unitPrice: 9200,
            total: 9200,
            method: PaymentMethod.cash,
            fulfilment: Fulfilment.walkIn,
            soldAt: DateTime(now.year, now.month, now.day, 6),
            synced: const Value(true),
            // no unitCost, no listPrice — a pre-v3 row
          ));

      final csv = buildReportCsv(await store.exportBundle(ReportPeriod.week));
      final rows = const CsvToListConverter(eol: '\n').convert(csv);

      final header = rows.firstWhere((r) => r.isNotEmpty && r[0] == 'date');
      int col(String name) => header.indexOf(name);

      // The discounted sale carries list_price + discount + profit.
      final discounted = rows.firstWhere(
          (r) => r.length == header.length && r[col('unit_price')] == 8700);
      expect(discounted[col('list_price')], 9200);
      expect(discounted[col('discount')], 500);
      expect(discounted[col('profit')], (8700 - palm.buyPrice) * 2);

      // The legacy sale has BLANK (not zero) cost and profit cells.
      final legacy = rows.firstWhere((r) =>
          r.length == header.length &&
          r[col('qty')] == 1 &&
          r[col('unit_cost')] == '');
      expect(legacy[col('profit')], '');
      expect(legacy[col('list_price')], '');

      // Margin footnote mirrors the UI.
      expect(csv, contains('before cost tracking'));

      // Summary values match the bundle's report.
      final bundle = await store.exportBundle(ReportPeriod.week);
      expect(csv, contains('Sales total (₦)'));
      final salesTotalRow =
          rows.firstWhere((r) => r.isNotEmpty && r[0] == 'Sales total (₦)');
      expect(salesTotalRow[1], bundle.report.salesTotal);
    });

    test('collected credit sales are marked in the credit_collected column',
        () async {
      final memory = fixtureStore();
      await memory.recordSale(
        productId: veg.id,
        qty: 1,
        method: PaymentMethod.credit,
        fulfilment: Fulfilment.walkIn,
        customerName: 'Ngozi',
      );
      final credit = (await memory.watchOwedCredits().first)
          .firstWhere((c) => c.customerName == 'Ngozi');
      await memory.markCreditPaid(credit.saleId);

      final csv = buildReportCsv(await memory.exportBundle(ReportPeriod.week));
      final rows = const CsvToListConverter(eol: '\n').convert(csv);
      final header = rows.firstWhere((r) => r.isNotEmpty && r[0] == 'date');
      int col(String name) => header.indexOf(name);

      final collected = rows.firstWhere((r) =>
          r.length == header.length && r[col('customer')] == 'Ngozi');
      expect(collected[col('method')], 'credit');
      expect(collected[col('credit_collected')], 'yes');
      // Cash rows leave the column blank.
      final cash = rows.firstWhere(
          (r) => r.length == header.length && r[col('method')] == 'cash');
      expect(cash[col('credit_collected')], '');
    });
  });

  group('PDF export', () {
    test('builds a real PDF with the bundled Inter fonts', () async {
      final memory = fixtureStore();
      final bundle = await memory.exportBundle(ReportPeriod.week);

      ByteData ttf(String file) => ByteData.view(
          File('assets/fonts/$file').readAsBytesSync().buffer);

      final bytes = await buildReportPdf(
        bundle,
        regularFont: ttf('Inter-Regular.ttf'),
        boldFont: ttf('Inter-Bold.ttf'),
      );

      expect(bytes.length, greaterThan(10 * 1024)); // embedded fonts
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });

  group('Reports export UI', () {
    tearDown(() => debugExportHandler = null);

    testWidgets('export sheet offers PDF and CSV; CSV export flows through',
        (tester) async {
      usePhoneSurface(tester);
      final captured = <(String, String, int)>[];
      debugExportHandler = (bytes, filename, mimeType) async {
        captured.add((filename, mimeType, bytes.length));
      };

      await pumpWithStore(tester, const ReportsScreen());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.ios_share_rounded));
      await tester.pumpAndSettle();
      expect(find.text('PDF report'), findsOneWidget);
      expect(find.text('CSV spreadsheet'), findsOneWidget);

      await tester.tap(find.text('CSV spreadsheet'));
      await tester.pumpAndSettle();

      expect(captured, hasLength(1));
      expect(captured.single.$1, startsWith('prosperflow-week-'));
      expect(captured.single.$1, endsWith('.csv'));
      expect(captured.single.$2, 'text/csv');
      expect(captured.single.$3, greaterThan(100));
      expect(find.textContaining('report exported'), findsOneWidget);
    });

    testWidgets('PDF export produces %PDF bytes named after the period',
        (tester) async {
      usePhoneSurface(tester);
      String? filename;
      List<int>? head;
      debugExportHandler = (bytes, name, mime) async {
        filename = name;
        head = bytes.take(5).toList();
      };

      await pumpWithStore(tester, const ReportsScreen());
      await tester.pump();

      // Switch to Month so the filename reflects the selected period.
      await tester.tap(find.text('Month'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.ios_share_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PDF report'));
      await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 300))); // real async font load
      await tester.pumpAndSettle();

      expect(filename, isNotNull);
      expect(filename, startsWith('prosperflow-month-'));
      expect(filename, endsWith('.pdf'));
      expect(String.fromCharCodes(head!), '%PDF-');
    });
  });
}
