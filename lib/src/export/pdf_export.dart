import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/data_store.dart';
import '../data/models.dart';
import '../utils/naira.dart';

/// Builds the PDF report for one period, mirroring the Reports screen:
/// summary (both profit figures, explicitly labeled), payment breakdown,
/// then sales and expense tables.
///
/// Fonts are passed in as raw TTF bytes (the app hands over its bundled
/// Inter, which includes the ₦ glyph) so this stays a pure, testable
/// function with no asset-bundle dependency.
Future<Uint8List> buildReportPdf(
  ExportBundle bundle, {
  required ByteData regularFont,
  required ByteData boldFont,
}) async {
  final base = pw.Font.ttf(regularFont);
  final bold = pw.Font.ttf(boldFont);
  final theme = pw.ThemeData.withFont(base: base, bold: bold);

  const green = PdfColor.fromInt(0xFF0B8F4E);
  const red = PdfColor.fromInt(0xFFC62828);
  const grey = PdfColor.fromInt(0xFF666666);

  String date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  String time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  pw.Widget stat(String label, String value, {PdfColor color = green}) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(label,
            style: pw.TextStyle(
                fontSize: 8, color: grey, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 14, color: color, fontWeight: pw.FontWeight.bold)),
      ]);

  String profitText(int? profit) {
    if (profit == null) return '—';
    return '${profit < 0 ? '-' : '+'}${formatNaira(profit.abs())}';
  }

  final marginNote = bundle.missingCostCount > 0
      ? '* margin excludes ${bundle.missingCostCount} sale(s) recorded '
          'before cost tracking'
      : null;

  final doc = pw.Document(theme: theme);
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    footer: (context) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        'ProsperFlow · page ${context.pageNumber}/${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 8, color: grey),
      ),
    ),
    build: (context) => [
      pw.Text('ProsperFlow — ${bundle.periodLabel} Report',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.Text(
        'Generated ${date(bundle.generatedAt)} ${time(bundle.generatedAt)}',
        style: const pw.TextStyle(fontSize: 9, color: grey),
      ),
      pw.SizedBox(height: 16),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          stat('SALES (${bundle.report.salesCount})',
              formatNaira(bundle.report.salesTotal)),
          stat('EXPENSES (${bundle.report.expensesCount})',
              formatNaira(bundle.report.expensesTotal),
              color: red),
          stat(
            'NET CASH PROFIT',
            profitText(bundle.report.profit),
            color: bundle.report.profit < 0 ? red : green,
          ),
          stat(
            'MARGIN ON COSTED SALES${marginNote != null ? '*' : ''}',
            profitText(bundle.marginProfit),
            color: (bundle.marginProfit ?? 0) < 0 ? red : green,
          ),
        ],
      ),
      if (marginNote != null) ...[
        pw.SizedBox(height: 4),
        pw.Text(marginNote, style: const pw.TextStyle(fontSize: 8, color: grey)),
      ],
      pw.SizedBox(height: 14),
      pw.Text('Payment breakdown',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.TableHelper.fromTextArray(
        headers: ['Method', 'Amount'],
        data: [
          for (final bucket in bundle.report.paymentBuckets)
            [bucket.method.name, formatNaira(bucket.amount)],
        ],
        headerStyle:
            pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 9),
        cellAlignments: {1: pw.Alignment.centerRight},
      ),
      pw.SizedBox(height: 14),
      pw.Text('Sales (${bundle.sales.length})',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      if (bundle.sales.isEmpty)
        pw.Text('No sales in this period.',
            style: const pw.TextStyle(fontSize: 9, color: grey))
      else
        pw.TableHelper.fromTextArray(
          headers: [
            'Date',
            'Product',
            'Qty',
            'Price',
            'Total',
            'Profit',
            'Method',
          ],
          data: [
            for (final sale in bundle.sales)
              [
                date(sale.soldAt),
                sale.productName,
                '${sale.qty}',
                sale.discounted
                    ? '${formatNaira(sale.unitPrice)} '
                        '(was ${formatNaira(sale.listPrice!)})'
                    : formatNaira(sale.unitPrice),
                formatNaira(sale.total),
                profitText(sale.profit),
                sale.method == PaymentMethod.credit
                    ? (bundle.paidCreditSaleIds.contains(sale.id)
                        ? 'credit (collected)'
                        : 'credit')
                    : sale.method.name,
              ],
          ],
          headerStyle:
              pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignments: {
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
          },
        ),
      pw.SizedBox(height: 14),
      pw.Text('Expenses (${bundle.expenses.length})',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      if (bundle.expenses.isEmpty)
        pw.Text('No expenses in this period.',
            style: const pw.TextStyle(fontSize: 9, color: grey))
      else
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Description', 'Category', 'Amount'],
          data: [
            for (final expense in bundle.expenses)
              [
                date(expense.spentOn),
                expense.description,
                expense.category.name,
                formatNaira(expense.amount),
              ],
          ],
          headerStyle:
              pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignments: {3: pw.Alignment.centerRight},
        ),
    ],
  ));

  return doc.save();
}
