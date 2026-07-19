import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/data/memory_store.dart';
import 'package:prosperflow/src/data/models.dart';
import 'package:prosperflow/src/screens/expenses/expenses_screen.dart';

import 'helpers.dart';

List<Expense> _manyExpenses(int n) => [
      for (var i = 0; i < n; i++)
        Expense(
          id: 'e$i',
          // A long description so cards wrap to variable heights — the case
          // the full-height stripe must cover.
          description: 'Expense $i — a deliberately long description that '
              'wraps onto a second line to vary the card height',
          amount: 1000 + i,
          category: ExpenseCategory.values[i % ExpenseCategory.values.length],
          spentOn: DateTime.now().subtract(Duration(days: i)),
        ),
    ];

void main() {
  testWidgets('100 expense cards render with no overflow and no IntrinsicHeight',
      (tester) async {
    usePhoneSurface(tester, height: 4000);
    final store =
        MemoryStore(products: fixtureProducts, expenses: _manyExpenses(100));

    final sw = Stopwatch()..start();
    await pumpWithStore(tester, const ExpensesScreen(), store: store);
    await tester.pump();
    sw.stop();

    // Zero overflow at scale.
    expect(tester.takeException(), isNull);
    // The stripe no longer costs an IntrinsicHeight pass per row.
    expect(find.byType(IntrinsicHeight), findsNothing);
    // The red edge stripe is present (one per laid-out card).
    expect(find.byType(ColoredBox), findsWidgets);

    // ignore: avoid_print
    print('Expenses (100 rows) build+layout: ${sw.elapsedMilliseconds}ms');
  });
}
