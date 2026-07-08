import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/screens/record_sale/record_sale_screen.dart';
import 'package:prosperflow/src/widgets/primary_button.dart';

Widget _app() => const MaterialApp(home: RecordSaleScreen());

/// Use a tall phone-like surface so the whole form is on screen.
void _usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('total recomputes live from the qty stepper', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app());

    // Palm Oil (25L) at ₦9,200, qty 1.
    expect(find.text('₦9,200'), findsNWidgets(2)); // price/unit + total

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('₦18,400'), findsOneWidget);

    // Min quantity is 1.
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('credit payment shows the customer-name warning and blocks save',
      (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app());

    expect(
        find.text('⚠ Customer name is required for credit sales'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Credit'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Credit'));
    await tester.pump();
    expect(find.text('⚠ Customer name is required for credit sales'),
        findsOneWidget);

    // Submitting without a customer name shows the warning toast instead of
    // navigating away.
    await tester.scrollUntilVisible(
      find.byType(PrimaryButton),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();
    expect(find.byType(RecordSaleScreen), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('delivery toggle reveals the location field', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app());

    expect(find.text('DELIVERY LOCATION'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Delivery'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Delivery'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('DELIVERY LOCATION'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('DELIVERY LOCATION'), findsOneWidget);
  });

  testWidgets('product picker changes product and stock label', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_app());

    await tester.tap(find.text('Palm Oil (25L)'));
    await tester.pumpAndSettle();
    expect(find.text('Choose product'), findsOneWidget);

    await tester.tap(find.text('Yam (per tuber)'));
    await tester.pumpAndSettle();
    expect(find.text('Yam (per tuber)'), findsOneWidget);
    expect(find.text('28 in stock'), findsOneWidget);
    expect(find.text('₦2,500'), findsNWidgets(2));
  });
}
