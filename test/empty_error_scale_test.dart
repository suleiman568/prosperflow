import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/widgets/empty_state.dart';
import 'package:prosperflow/src/widgets/error_state.dart';

/// Renders [child] in a narrow, tall slot at [scale] accessibility text
/// scaling — a low-vision user on a slim phone.
Widget _scaled(double scale, Widget child) => MaterialApp(
  builder: (context, inner) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: inner!,
  ),
  home: Scaffold(
    body: Center(child: SizedBox(width: 300, height: 1400, child: child)),
  ),
);

void main() {
  testWidgets('the empty-state CTA wraps instead of overflowing at 3x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _scaled(
        3.0,
        EmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'No products yet',
          message: 'Everything you sell lives here.',
          actionLabel: 'Add product',
          onAction: () {},
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Add product'), findsOneWidget);
  });

  testWidgets('the error-state CTA wraps instead of overflowing at 3x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_scaled(3.0, ErrorState(onRetry: () {})));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('the CTAs render normally at 1x (no layout regression)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _scaled(
        1.0,
        EmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'No products yet',
          message: 'Everything you sell lives here.',
          actionLabel: 'Add product',
          onAction: () {},
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Add product'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });
}
