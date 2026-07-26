import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/screens/reports/reports_screen.dart';
import 'package:prosperflow/src/utils/motion.dart';
import 'package:prosperflow/src/widgets/pressable.dart';

import 'helpers.dart';

/// Wraps [child] in a MediaQuery that reports reduce-motion is on.
Widget _rm(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child,
  ),
);

void main() {
  testWidgets('reducedMotion collapses the duration only under reduce-motion', (
    tester,
  ) async {
    late Duration normal;
    late Duration reduced;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            normal = reducedMotion(context, const Duration(milliseconds: 90));
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: Builder(
                builder: (context) {
                  reduced = reducedMotion(
                    context,
                    const Duration(milliseconds: 90),
                  );
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      ),
    );

    expect(normal, const Duration(milliseconds: 90));
    expect(reduced, Duration.zero);
  });

  testWidgets('Pressable press-scale is instant under reduce-motion', (
    tester,
  ) async {
    Duration scaleDuration() =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Pressable(
            onTap: () {},
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    );
    expect(scaleDuration(), const Duration(milliseconds: 90));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _rm(
            Pressable(
              onTap: () {},
              child: const SizedBox(width: 40, height: 40),
            ),
          ),
        ),
      ),
    );
    expect(scaleDuration(), Duration.zero);
  });

  testWidgets('Reports expand animations are instant under reduce-motion', (
    tester,
  ) async {
    usePhoneSurface(tester, height: 3200);

    // Control: normal motion keeps the 200ms durations.
    await pumpWithStore(tester, const ReportsScreen());
    await tester.pump();
    await tester.pump();
    expect(
      tester
          .widget<AnimatedRotation>(find.byType(AnimatedRotation).first)
          .duration,
      const Duration(milliseconds: 200),
    );
    expect(
      tester.widget<AnimatedSize>(find.byType(AnimatedSize).first).duration,
      const Duration(milliseconds: 200),
    );

    // Reduce-motion collapses them to instant.
    await pumpWithStore(tester, _rm(const ReportsScreen()));
    await tester.pump();
    await tester.pump();
    expect(
      tester
          .widget<AnimatedRotation>(find.byType(AnimatedRotation).first)
          .duration,
      Duration.zero,
    );
    expect(
      tester.widget<AnimatedSize>(find.byType(AnimatedSize).first).duration,
      Duration.zero,
    );
  });
}
