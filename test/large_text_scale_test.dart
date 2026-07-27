import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/theme/tokens.dart';
import 'package:prosperflow/src/widgets/app_tab_bar.dart';
import 'package:prosperflow/src/widgets/header_back_button.dart';
import 'package:prosperflow/src/widgets/screen_title.dart';

/// Renders [child] at [scale] accessibility text scaling inside a [width]-wide
/// slot — the setup a low-vision user on a narrow phone hits.
Widget _scaled(double scale, double width, Widget child) => MaterialApp(
  builder: (context, inner) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: inner!,
  ),
  home: Scaffold(
    body: Center(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

void main() {
  testWidgets('the bottom tab bar does not overflow at a huge text scale', (
    tester,
  ) async {
    // A narrow phone so the four tabs are tight, at an extreme scale.
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(3.0)),
          child: child!,
        ),
        home: const Scaffold(
          backgroundColor: AppColors.appBg,
          bottomNavigationBar: AppTabBar(active: AppTab.home),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    // All four labels still render (clamped, not dropped).
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Credits'), findsOneWidget);
  });

  testWidgets('a back-button header ellipsizes a long title without overflow', (
    tester,
  ) async {
    // The shared screen-header composition (Products, Expenses, Record Sale,
    // Reports, Credits): a fixed back button beside an Expanded, ellipsizing
    // title. Squeezed into 300px at 3x it must clip, not overflow.
    await tester.pumpWidget(
      _scaled(
        3.0,
        300,
        Row(
          children: const [
            HeaderBackButton(),
            Expanded(
              child: ScreenTitle(
                'Outstanding Credits',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final title = tester.widget<Text>(find.text('Outstanding Credits'));
    expect(title.overflow, TextOverflow.ellipsis);
  });

  testWidgets('a space-between brand header keeps its trailing action', (
    tester,
  ) async {
    // The dashboard header: a Flexible, ellipsizing title beside a fixed
    // action cluster that must stay on screen.
    await tester.pumpWidget(
      _scaled(
        3.0,
        300,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Flexible(
              child: ScreenTitle(
                'ProsperFlow',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.sync_rounded),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.sync_rounded), findsOneWidget); // not pushed off
    final title = tester.widget<Text>(find.text('ProsperFlow'));
    expect(title.overflow, TextOverflow.ellipsis);
  });
}
