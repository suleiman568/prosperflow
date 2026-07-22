import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/screens/products/products_screen.dart';
import 'package:prosperflow/src/screens/record_sale/record_sale_screen.dart';
import 'package:prosperflow/src/widgets/pressable.dart';

import 'helpers.dart';

AnimatedScale _scaleOf(WidgetTester tester, Finder pressable) =>
    tester.widget<AnimatedScale>(find.descendant(
        of: pressable, matching: find.byType(AnimatedScale)));

void main() {
  testWidgets('Pressable shrinks while held and fires onTap on release',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Pressable(
            onTap: () => taps++,
            child: const SizedBox(width: 80, height: 40),
          ),
        ),
      ),
    ));

    expect(_scaleOf(tester, find.byType(Pressable)).scale, 1.0);

    // Press and hold: the target scale drops.
    final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Pressable)));
    await tester.pump();
    expect(_scaleOf(tester, find.byType(Pressable)).scale, lessThan(1.0));

    // Release: fires onTap and returns to full size.
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(_scaleOf(tester, find.byType(Pressable)).scale, 1.0);
  });

  testWidgets('a null onTap leaves the child inert (no shrink)',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Pressable(child: SizedBox(width: 80, height: 40)),
        ),
      ),
    ));
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(Pressable)));
    await tester.pump();
    expect(_scaleOf(tester, find.byType(Pressable)).scale, 1.0);
    await gesture.up();
  });

  testWidgets('key controls are wrapped in Pressable', (tester) async {
    usePhoneSurface(tester);

    // Products FAB.
    await pumpWithStore(tester, const ProductsScreen(), store: fixtureStore());
    await tester.pump();
    expect(
        find.ancestor(
            of: find.byIcon(Icons.add), matching: find.byType(Pressable)),
        findsOneWidget);

    // Record Sale steppers + tap-to-change + price field.
    await pumpWithStore(tester, const RecordSaleScreen(),
        store: fixtureStore());
    await tester.pump();
    expect(find.byType(Pressable), findsWidgets);
    expect(
        find.ancestor(
            of: find.byIcon(Icons.remove), matching: find.byType(Pressable)),
        findsOneWidget);
  });
}
