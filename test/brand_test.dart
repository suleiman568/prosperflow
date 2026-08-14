import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/brand/brand_colors.dart';
import 'package:prosperflow/src/brand/brand_lockup.dart';
import 'package:prosperflow/src/brand/brand_mark.dart';
import 'package:prosperflow/src/brand/brand_wordmark.dart';

/// Loads the bundled brand face. Without it every glyph renders as a square,
/// which would make the crossbar measurements meaningless.
Future<void> loadBrandFont() async {
  final loader = FontLoader(BrandWordmark.fontFamily)
    ..addFont(
      Future.value(
        ByteData.view(
          File(
            'assets/fonts/FamiljenGrotesk-SemiBold.ttf',
          ).readAsBytesSync().buffer,
        ),
      ),
    );
  await loader.load();
}

Widget _swatch(Widget child, {Color background = BrandColors.bone}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: background,
        body: Center(child: RepaintBoundary(child: child)),
      ),
    );

void main() {
  setUpAll(loadBrandFont);

  group('BrandMark', () {
    testWidgets('renders at 16 / 40 / 88 on light', (tester) async {
      for (final size in [16.0, 40.0, 88.0]) {
        await tester.pumpWidget(_swatch(BrandMark(size: size)));
        await expectLater(
          find.byType(BrandMark),
          matchesGoldenFile('goldens/brand_mark_${size.toInt()}.png'),
        );
      }
    });

    testWidgets('marigold on ink — the app-icon pairing', (tester) async {
      await tester.pumpWidget(
        _swatch(
          const BrandMark(size: 88, color: BrandColors.marigold),
          background: BrandColors.ink,
        ),
      );
      await expectLater(
        find.byType(BrandMark),
        matchesGoldenFile('goldens/brand_mark_88_on_ink.png'),
      );
    });

    test('the box is the grid, so the stem sits 19 units in', () {
      // The stroke's outer edge: 27 - 16/2 = 19 of 100 units. The stacked
      // lockup subtracts exactly this to find the stem axis.
      expect(BrandMark.stemInset, 0.19);
      expect(BrandMark.inkHeightRatio, 0.88); // 6..94
    });
  });

  group('BrandWordmark', () {
    testWidgets('renders at 11 / 26 / 40', (tester) async {
      for (final size in [11.0, 26.0, 40.0]) {
        await tester.pumpWidget(_swatch(BrandWordmark(fontSize: size)));
        await expectLater(
          find.byType(BrandWordmark),
          matchesGoldenFile('goldens/brand_wordmark_${size.toInt()}.png'),
        );
      }
    });

    testWidgets('single-material variant drops the bar', (tester) async {
      await tester.pumpWidget(
        _swatch(const BrandWordmark(fontSize: 40, showCrossbar: false)),
      );
      await expectLater(
        find.byType(BrandWordmark),
        matchesGoldenFile('goldens/brand_wordmark_single_material.png'),
      );
    });

    // The riskiest number in the system: the bar is positioned from a real
    // measurement of the laid-out text, not a constant, so it has to hold at
    // every size and would break loudly if the face were swapped.
    test('the bar lands on the glyph crossbar at every size', () {
      for (final fontSize in [11.0, 16.0, 23.0, 26.0, 40.0, 88.0, 200.0]) {
        final painter = BrandWordmark.layOut(fontSize, BrandColors.ink);
        final baseline = painter.computeDistanceToActualBaseline(
          TextBaseline.alphabetic,
        );
        final bar = BrandWordmark.crossbarRectFor(painter, fontSize);

        // Spec: the glyph's crossbar sits 0.31-0.39em above the baseline.
        // Verified against the rendered glyph: its ink runs 0.300-0.390em.
        expect(
          (baseline - bar.top) / fontSize,
          closeTo(0.39, 0.001),
          reason: 'bar top at fontSize $fontSize',
        );
        expect(
          (baseline - bar.bottom) / fontSize,
          closeTo(0.31, 0.001),
          reason: 'bar bottom at fontSize $fontSize',
        );
      }
    });

    test('the bar is measured from the F, not assumed', () {
      // Same geometry at every size means the offset tracks the real prefix
      // width rather than a constant that happens to look right at one size.
      final ratios = <double>[];
      for (final fontSize in [11.0, 26.0, 40.0, 200.0]) {
        final painter = BrandWordmark.layOut(fontSize, BrandColors.ink);
        ratios.add(BrandWordmark.crossbarOriginFor(painter) / fontSize);
      }
      for (final ratio in ratios) {
        expect(ratio, closeTo(ratios.first, 0.002));
      }
      // The F starts after "Prosper" — well into the wordmark, not at zero.
      expect(ratios.first, greaterThan(3));
    });

    test('line box is exactly one em, per line-height 1', () {
      for (final fontSize in [11.0, 26.0, 40.0]) {
        final painter = BrandWordmark.layOut(fontSize, BrandColors.ink);
        expect(painter.height, closeTo(fontSize, 0.01));
      }
    });

    test('tracking is -0.035em at all sizes', () {
      for (final fontSize in [11.0, 26.0, 40.0]) {
        final style = BrandWordmark.styleFor(fontSize, BrandColors.ink);
        expect(style.letterSpacing, closeTo(-0.035 * fontSize, 0.0001));
        expect(style.fontWeight, FontWeight.w600);
        expect(style.height, 1);
      }
    });
  });

  group('BrandLockup', () {
    testWidgets('stacked', (tester) async {
      await tester.pumpWidget(_swatch(const BrandLockup.stacked(fontSize: 26)));
      await expectLater(
        find.byType(BrandLockup),
        matchesGoldenFile('goldens/brand_lockup_stacked.png'),
      );
    });

    testWidgets('horizontal', (tester) async {
      await tester.pumpWidget(
        _swatch(const BrandLockup.horizontal(fontSize: 23)),
      );
      await expectLater(
        find.byType(BrandLockup),
        matchesGoldenFile('goldens/brand_lockup_horizontal.png'),
      );
    });

    testWidgets('stacked on ink, marigold mark', (tester) async {
      await tester.pumpWidget(
        _swatch(
          const BrandLockup.stacked(
            fontSize: 26,
            color: BrandColors.bone,
            markColor: BrandColors.marigold,
          ),
          background: BrandColors.ink,
        ),
      );
      await expectLater(
        find.byType(BrandLockup),
        matchesGoldenFile('goldens/brand_lockup_stacked_on_ink.png'),
      );
    });

    test('mark sizes follow the spec ratios', () {
      expect(
        BrandLockup.iconSizeFor(BrandLockupVariant.stacked, 26),
        closeTo(54.08, 0.01), // the spec sheet renders 54 at 26
      );
      expect(
        BrandLockup.iconSizeFor(BrandLockupVariant.horizontal, 23),
        closeTo(42.32, 0.01), // and 42 at 23
      );
    });

    test('gaps are the counter, measured off the mark', () {
      final stacked = BrandLockup.iconSizeFor(BrandLockupVariant.stacked, 26);
      expect(BrandLockup.stackedGapRatio * stacked, closeTo(12.98, 0.01));

      final horizontal = BrandLockup.iconSizeFor(
        BrandLockupVariant.horizontal,
        23,
      );
      expect(BrandLockup.horizontalGapRatio * horizontal, closeTo(12.70, 0.01));
      expect(BrandLockup.clearSpaceFor(stacked), closeTo(16.22, 0.01));
    });

    testWidgets('stacked box is tight to the stem axis', (tester) async {
      const fontSize = 26.0;
      await tester.pumpWidget(
        _swatch(const BrandLockup.stacked(fontSize: fontSize)),
      );

      final iconSize = BrandLockup.iconSizeFor(
        BrandLockupVariant.stacked,
        fontSize,
      );
      final lockup = tester.getRect(find.byType(BrandLockup));
      final mark = tester.getRect(find.byType(BrandMark));
      final wordmark = tester.getRect(find.byType(BrandWordmark));

      // The mark hangs left of the box by its stem inset, which puts the
      // stem's outer edge exactly on the box's left edge — the same rule the
      // P sits on. Rebuilding this by bounding box is an explicit don't.
      expect(
        mark.left,
        closeTo(lockup.left - BrandMark.stemInset * iconSize, 0.01),
      );
      expect(wordmark.left, closeTo(lockup.left, 0.01));
      expect(
        mark.left + BrandMark.stemInset * iconSize,
        closeTo(wordmark.left, 0.01),
      );

      // Gap is measured box-to-box, as the spec sheet lays it out.
      expect(
        wordmark.top - mark.bottom,
        closeTo(BrandLockup.stackedGapRatio * iconSize, 0.01),
      );
    });

    testWidgets('horizontal centres the mark and gaps by the counter', (
      tester,
    ) async {
      const fontSize = 23.0;
      await tester.pumpWidget(
        _swatch(const BrandLockup.horizontal(fontSize: fontSize)),
      );

      final iconSize = BrandLockup.iconSizeFor(
        BrandLockupVariant.horizontal,
        fontSize,
      );
      final mark = tester.getRect(find.byType(BrandMark));
      final wordmark = tester.getRect(find.byType(BrandWordmark));

      expect(
        wordmark.left - mark.right,
        closeTo(BrandLockup.horizontalGapRatio * iconSize, 0.01),
      );
      expect(mark.center.dy, closeTo(wordmark.center.dy, 0.01));
    });

    testWidgets('drops to the mark alone below the minimum width', (
      tester,
    ) async {
      // At this size the lockup would come out under 120px, where the spec
      // says to show the icon only rather than shrink the type further.
      await tester.pumpWidget(
        _swatch(const BrandLockup.horizontal(fontSize: 9)),
      );
      expect(find.byType(BrandMark), findsOneWidget);
      expect(find.byType(BrandWordmark), findsNothing);

      await tester.pumpWidget(
        _swatch(const BrandLockup.horizontal(fontSize: 23)),
      );
      expect(find.byType(BrandWordmark), findsOneWidget);
    });
  });
}
