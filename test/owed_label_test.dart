import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/utils/dates.dart';

void main() {
  final now = DateTime(2026, 7, 28, 15);
  DateTime daysAgo(int d) =>
      DateTime(2026, 7, 28, 9).subtract(Duration(days: d));

  group('owedLabel', () {
    test('the sale day reads "Owed today"', () {
      expect(owedLabel(daysAgo(0), now: now), 'Owed today');
    });

    test('days are singular then plural', () {
      expect(owedLabel(daysAgo(1), now: now), 'Owed for 1 day');
      expect(owedLabel(daysAgo(5), now: now), 'Owed for 5 days');
    });

    test('a week or more coarsens to weeks', () {
      expect(owedLabel(daysAgo(7), now: now), 'Owed for 1 week');
      expect(owedLabel(daysAgo(20), now: now), 'Owed for 2 weeks');
    });

    test('a month or more coarsens to months', () {
      expect(owedLabel(daysAgo(30), now: now), 'Owed for 1 month');
      expect(owedLabel(daysAgo(75), now: now), 'Owed for 2 months');
    });

    test('a year or more coarsens to years', () {
      expect(owedLabel(daysAgo(365), now: now), 'Owed for 1 year');
      expect(owedLabel(daysAgo(800), now: now), 'Owed for 2 years');
    });

    test('counts calendar days, not 24-hour periods', () {
      // Sold late last night, checked early this morning: 1 day, not 0.
      final soldLateYesterday = DateTime(2026, 7, 27, 23, 30);
      final earlyToday = DateTime(2026, 7, 28, 6);
      expect(owedLabel(soldLateYesterday, now: earlyToday), 'Owed for 1 day');
    });
  });

  group('creditIsStale', () {
    test('flips to stale at 30 calendar days', () {
      expect(creditIsStale(daysAgo(29), now: now), isFalse);
      expect(creditIsStale(daysAgo(30), now: now), isTrue);
      expect(creditIsStale(daysAgo(45), now: now), isTrue);
    });
  });
}
