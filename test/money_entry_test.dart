import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/data/memory_store.dart';
import 'package:prosperflow/src/screens/expenses/expenses_screen.dart';
import 'package:prosperflow/src/screens/products/products_screen.dart';
import 'package:prosperflow/src/utils/naira.dart';
import 'package:prosperflow/src/widgets/digit_group_formatter.dart';
import 'package:prosperflow/src/widgets/primary_button.dart';

import 'helpers.dart';

/// Runs the formatter the way the framework does: old value → new value.
TextEditingValue _type(String text, {int? caret}) =>
    const DigitGroupFormatter().formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: caret ?? text.length),
      ),
    );

void main() {
  group('groupDigits / parseAmount', () {
    test('groups in threes from the right', () {
      expect(groupDigits('0'), '0');
      expect(groupDigits('999'), '999');
      expect(groupDigits('1000'), '1,000');
      expect(groupDigits('1339000'), '1,339,000');
      expect(groupDigits('123456789000'), '123,456,789,000');
    });

    test('drops any non-digits it is handed', () {
      expect(groupDigits('1,339,000'), '1,339,000');
      expect(groupDigits(''), '');
    });

    test('parseAmount reads grouped and bare text alike', () {
      expect(parseAmount('1,339,000'), 1339000);
      expect(parseAmount('1339000'), 1339000);
      expect(parseAmount(' 8,500 '), 8500);
      expect(parseAmount('0'), 0);
    });

    test('parseAmount returns null when there is no number', () {
      expect(parseAmount(''), isNull);
      expect(parseAmount('   '), isNull);
      expect(parseAmount('abc'), isNull);
    });

    test('formatNaira still renders the same as before', () {
      expect(formatNaira(0), '₦0');
      expect(formatNaira(9200), '₦9,200');
      expect(formatNaira(1339000), '₦1,339,000');
      expect(formatNaira(-500), '-₦500');
    });
  });

  group('DigitGroupFormatter', () {
    test('inserts separators as digits are typed', () {
      expect(_type('1').text, '1');
      expect(_type('1000').text, '1,000');
      expect(_type('1339000').text, '1,339,000');
    });

    test('strips characters the number pad cannot produce', () {
      expect(_type('12a3').text, '123');
    });

    test('caret stays after the digit just typed', () {
      // Typing the 4th digit of "1000": caret sits at the end.
      final v = _type('1000');
      expect(v.text, '1,000');
      expect(v.selection.baseOffset, 5);
    });

    test('caret tracks a digit edited mid-number, not a raw offset', () {
      // Caret after the "2" in "1234567" (3 digits in) → "1,234,567" keeps the
      // caret after that same digit, which is now at offset 5 ("1,23|4,567").
      final v = _type('1234567', caret: 3);
      expect(v.text, '1,234,567');
      final digitsBefore = v.text
          .substring(0, v.selection.baseOffset)
          .replaceAll(',', '')
          .length;
      expect(digitsBefore, 3);
    });

    test('deleting back to empty leaves an empty field', () {
      expect(_type('').text, '');
    });
  });

  group('money entry round-trips through the forms', () {
    testWidgets('a grouped price saves the underlying amount', (tester) async {
      usePhoneSurface(tester);
      final store = MemoryStore();
      await pumpWithStore(tester, const ProductsScreen(), store: store);
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Palm Oil (25L)'),
        'Generator',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'bottles'),
        'units',
      );
      await tester.enterText(find.widgetWithText(TextField, '6,800'), '850000');
      await tester.enterText(
        find.widgetWithText(TextField, '9,200'),
        '1339000',
      );
      await tester.enterText(find.widgetWithText(TextField, '42'), '3');
      await tester.pump();

      // Shown grouped while typing...
      expect(find.text('1,339,000'), findsOneWidget);
      expect(find.text('850,000'), findsOneWidget);

      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      // ...and stored as the plain integer.
      final products = await store.watchProducts().first;
      final added = products.firstWhere((p) => p.name == 'Generator');
      expect(added.buyPrice, 850000);
      expect(added.sellPrice, 1339000);
    });

    testWidgets('the edit sheet opens already grouped and is not dirty', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await pumpWithStore(tester, const ProductsScreen());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      // Seeded values are grouped without the trader touching the field.
      // (Asserted on the controllers: the hints read the same, so a text
      // finder would be ambiguous.)
      final fields = find.byType(TextField);
      String valueAt(int i) =>
          tester.widget<TextField>(fields.at(i)).controller!.text;
      expect(valueAt(2), '6,800'); // BUY PRICE
      expect(valueAt(3), '9,200'); // SELL PRICE

      // Closing an untouched sheet must not raise the discard prompt — the
      // dirty check compares amounts, so "6,800" == 6800.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
    });

    testWidgets('a grouped expense amount saves correctly', (tester) async {
      usePhoneSurface(tester);
      final store = MemoryStore();
      await pumpWithStore(tester, const ExpensesScreen(), store: store);
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Delivery Cost'),
        'Stall rent',
      );
      await tester.enterText(find.widgetWithText(TextField, '8,500'), '250000');
      await tester.pump();
      expect(find.text('250,000'), findsOneWidget);

      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      final expenses = await store.watchExpenses().first;
      expect(expenses.single.amount, 250000);
    });
  });
}
