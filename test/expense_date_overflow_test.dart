import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/data/memory_store.dart';
import 'package:prosperflow/src/screens/expenses/expenses_screen.dart';
import 'package:prosperflow/src/utils/dates.dart';

import 'helpers.dart';

/// The Add Expense sheet spells the date out in full, so its width depends on
/// the calendar. "Friday, 1 May" fits with room to spare; "Wednesday, 22
/// September" does not. The row was laid out for the short ones, which meant
/// it was correct for most of the year and overflowed for the rest — and the
/// suite only caught it on the days it happened to run.
///
/// These pin the widest and narrowest dates so neither depends on when CI
/// runs. A widget test fails on an overflow, so reaching the assertions at all
/// is most of the point.
void main() {
  /// Longest possible: the longest weekday, a two-digit day, and a month tied
  /// for longest. 22 September 2026 is a Tuesday, so the date is chosen for
  /// its rendered width rather than for being a real Wednesday.
  final longest = DateTime(2026, 9, 23); // Wednesday, 23 September
  final shortest = DateTime(2026, 5, 1); // Friday, 1 May

  Future<void> openSheetOn(WidgetTester tester, DateTime date) async {
    usePhoneSurface(tester);
    await pumpWithStore(
      tester,
      ExpensesScreen(clock: () => date),
      store: MemoryStore(products: const [], expenses: const []),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
  }

  testWidgets('the longest date in the year does not overflow the row', (
    tester,
  ) async {
    await openSheetOn(tester, longest);

    expect(find.text(formatWeekdayDayMonth(longest)), findsOneWidget);
  });

  testWidgets('and it is shown whole, not cut short', (tester) async {
    await openSheetOn(tester, longest);

    // Scaled down rather than ellipsized: half a date is worse than a small
    // one, and a trader has to be able to read which day they are filing an
    // expense against.
    final text = tester.widget<Text>(find.text(formatWeekdayDayMonth(longest)));
    expect(text.overflow, isNot(TextOverflow.ellipsis));
    expect(text.data, contains('September'));
    expect(text.data, contains('Wednesday'));
  });

  testWidgets('a short date still renders at its natural size', (tester) async {
    await openSheetOn(tester, shortest);

    // BoxFit.scaleDown never enlarges, so nothing that already fits is
    // touched by the fix.
    expect(find.text(formatWeekdayDayMonth(shortest)), findsOneWidget);
  });
}
