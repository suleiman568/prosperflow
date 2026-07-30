import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/data/models.dart';
import 'package:prosperflow/src/utils/plural.dart';

void main() {
  group('lowStockLine', () {
    Product stocked(int stock, {String unit = 'bottles'}) => Product(
      id: 'p',
      name: 'Vegetable Oil (20L)',
      unit: unit,
      stock: stock,
      buyPrice: 5200,
      sellPrice: 7000,
    );

    test('many units keep the unit noun', () {
      expect(stocked(3).lowStockLine, 'Vegetable Oil — 3 bottles left');
      expect(stocked(0).lowStockLine, 'Vegetable Oil — 0 bottles left');
    });

    test('a single unit drops the unit instead of reading "1 bottles"', () {
      expect(stocked(1).lowStockLine, 'Vegetable Oil — 1 left');
      // Also right for units no naive singularizer could handle.
      expect(stocked(1, unit: 'glass').lowStockLine, 'Vegetable Oil — 1 left');
      expect(stocked(1, unit: 'boxes').lowStockLine, 'Vegetable Oil — 1 left');
    });
  });

  group('countNoun', () {
    test('one is singular', () {
      expect(countNoun(1, 'sale'), '1 sale');
      expect(countNoun(1, 'customer'), '1 customer');
      expect(countNoun(1, 'transaction'), '1 transaction');
      expect(countNoun(1, 'item'), '1 item');
    });

    test('zero and many are plural', () {
      expect(countNoun(0, 'sale'), '0 sales');
      expect(countNoun(2, 'sale'), '2 sales');
      expect(countNoun(42, 'customer'), '42 customers');
    });

    test('an explicit plural overrides the default "s"', () {
      expect(countNoun(1, 'entry', plural: 'entries'), '1 entry');
      expect(countNoun(3, 'entry', plural: 'entries'), '3 entries');
    });

    test('a negative count reads as plural, not singular', () {
      // Defensive: no caller passes one today, but -1 must not read "-1 sale".
      expect(countNoun(-1, 'sale'), '-1 sales');
    });
  });
}
