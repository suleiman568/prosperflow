import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/screens/credits/credits_screen.dart';

Widget _app() => const MaterialApp(home: CreditsScreen());

void _usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('credits list shows total banner and per-customer cards',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app());

    expect(find.text('TOTAL OUTSTANDING'), findsOneWidget);
    // 18,400 + 30,000 + 20,100.
    expect(find.text('₦68,500'), findsOneWidget);

    expect(find.text('Chioma Ojo'), findsOneWidget);
    expect(find.text('Palm Oil (25L) × 2'), findsOneWidget);
    expect(find.text('Sold: 1 July 2026'), findsOneWidget);
    expect(find.text('₦18,400'), findsOneWidget);
    expect(find.text('Mark as Paid'), findsNWidgets(3));
  });

  testWidgets('mark as paid removes the card and updates the total',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app());

    await tester.tap(find.text('Mark as Paid').first);
    await tester.pump();

    expect(find.text('Chioma Ojo'), findsNothing);
    // 68,500 − 18,400.
    expect(find.text('₦50,100'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('collecting every credit shows the empty state', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app());

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Mark as Paid').first);
      await tester.pump();
    }

    expect(find.text('All credits collected!'), findsOneWidget);
    expect(find.text('No customers owe you money.'), findsOneWidget);
    expect(find.text('TOTAL OUTSTANDING'), findsNothing);
  });
}
