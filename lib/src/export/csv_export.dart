import 'package:csv/csv.dart';

import '../data/data_store.dart';
import '../data/models.dart';

/// Builds the CSV export for one period: a metadata header, a summary
/// section, the sales table, and the expenses table.
///
/// Money is exported as plain integer naira so spreadsheets can sum the
/// columns. Sales recorded before cost tracking export *blank* cost and
/// profit cells — never 0, which would misstate margins in a SUM — and the
/// summary carries the same footnote the Reports screen shows. Discounted
/// sales carry `list_price` and `discount`; both are blank for sales at the
/// normal price.
String buildReportCsv(ExportBundle bundle) {
  String date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  String time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  final rows = <List<Object?>>[
    ['ProsperFlow report'],
    ['Period', bundle.periodLabel],
    ['Generated', '${date(bundle.generatedAt)} ${time(bundle.generatedAt)}'],
    [],
    ['SUMMARY'],
    ['Sales total (₦)', bundle.report.salesTotal],
    ['Sales count', bundle.report.salesCount],
    ['Expenses total (₦)', bundle.report.expensesTotal],
    ['Expenses count', bundle.report.expensesCount],
    ['Net cash profit (₦, sales − expenses)', bundle.report.profit],
    [
      'Margin on costed sales (₦, (sell − cost) × qty)',
      bundle.marginProfit ?? '',
    ],
    if (bundle.missingCostCount > 0)
      [
        'Note',
        'margin excludes ${bundle.missingCostCount} sale(s) recorded '
            'before cost tracking',
      ],
    [],
    ['SALES'],
    [
      'date',
      'time',
      'product',
      'qty',
      'unit_price',
      'list_price',
      'discount',
      'unit_cost',
      'total',
      'profit',
      'method',
      'credit_collected',
      'customer',
      'fulfilment',
      'location',
    ],
    for (final sale in bundle.sales)
      [
        date(sale.soldAt),
        time(sale.soldAt),
        sale.productName,
        sale.qty,
        sale.unitPrice,
        if (sale.discounted) sale.listPrice else '',
        if (sale.discounted) sale.listPrice! - sale.unitPrice else '',
        sale.unitCost ?? '',
        sale.total,
        sale.profit ?? '',
        sale.method.name,
        if (sale.method == PaymentMethod.credit)
          bundle.paidCreditSaleIds.contains(sale.id) ? 'yes' : 'no'
        else
          '',
        sale.customerName ?? '',
        sale.fulfilment.name,
        sale.location ?? '',
      ],
    [],
    ['EXPENSES'],
    ['date', 'description', 'category', 'amount'],
    for (final expense in bundle.expenses)
      [
        date(expense.spentOn),
        expense.description,
        expense.category.name,
        expense.amount,
      ],
  ];

  return const ListToCsvConverter(eol: '\n').convert(rows);
}
