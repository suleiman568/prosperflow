import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'brand_colors.dart';
import 'brand_mark.dart';
import 'brand_wordmark.dart';

/// Which arrangement of mark and wordmark a [BrandLockup] draws.
enum BrandLockupVariant {
  /// The primary lockup: mark above wordmark, aligned on the stem axis.
  stacked,

  /// The secondary lockup: mark beside wordmark. For nav bars, receipt
  /// headers, email signatures — anywhere vertical space is capped. Not for
  /// primary brand moments.
  horizontal,
}

/// Mark and wordmark locked up per Identity Spec §04.
///
/// Both variants are driven by font size, because the spec expresses every
/// ratio against it: the stacked mark is 3.2 × cap height, which is 2.08 ×
/// font size at the wordmark's 0.65 cap-height ratio.
class BrandLockup extends StatelessWidget {
  const BrandLockup._({
    super.key,
    required this.variant,
    required this.fontSize,
    required this.color,
    required this.markColor,
    required this.crossbarColor,
    required this.showCrossbar,
    required this.isHeader,
  });

  /// Mark above wordmark, left-aligned on the mark's stem axis.
  const BrandLockup.stacked({
    Key? key,
    required double fontSize,
    Color color = BrandColors.ink,
    Color? markColor,
    Color crossbarColor = BrandColors.marigold,
    bool showCrossbar = true,
    bool isHeader = false,
  }) : this._(
         key: key,
         isHeader: isHeader,
         variant: BrandLockupVariant.stacked,
         fontSize: fontSize,
         color: color,
         markColor: markColor,
         crossbarColor: crossbarColor,
         showCrossbar: showCrossbar,
       );

  /// Mark beside wordmark, vertically centred.
  const BrandLockup.horizontal({
    Key? key,
    required double fontSize,
    Color color = BrandColors.ink,
    Color? markColor,
    Color crossbarColor = BrandColors.marigold,
    bool showCrossbar = true,
    bool isHeader = false,
  }) : this._(
         key: key,
         isHeader: isHeader,
         variant: BrandLockupVariant.horizontal,
         fontSize: fontSize,
         color: color,
         markColor: markColor,
         crossbarColor: crossbarColor,
         showCrossbar: showCrossbar,
       );

  final BrandLockupVariant variant;
  final double fontSize;
  final Color color;

  /// Defaults to [color] — the mark and the type are one colour unless a
  /// caller deliberately splits them (ink type with a marigold mark on a dark
  /// ground, say).
  final Color? markColor;

  final Color crossbarColor;
  final bool showCrossbar;

  /// True where the lockup stands in for a screen heading, as it does in the
  /// dashboard's app bar. Keeps the heading in the semantics tree even though
  /// the title is now drawn rather than set as text.
  final bool isHeader;

  /// The lockup is a picture of the app's name, so it carries that name as its
  /// label — a screen reader should hear "ProsperFlow", not silence.
  static const String semanticLabel = 'ProsperFlow';

  /// Stacked mark: 3.2 × cap height.
  static const double stackedIconRatio = 2.08;

  /// Horizontal mark: 2.8 × cap height.
  static const double horizontalIconRatio = 1.84;

  /// Stacked vertical gap, as a fraction of mark height — the counter height.
  static const double stackedGapRatio = 0.24;

  /// Horizontal gap, as a fraction of mark height — the counter width.
  static const double horizontalGapRatio = 0.30;

  /// Clear space on all four sides, as a fraction of mark height. Nothing
  /// enters it, including page edges.
  static const double clearSpaceRatio = 0.30;

  /// Below this the horizontal lockup drops to the mark alone.
  static const double horizontalMinWidth = 120;

  static double iconSizeFor(BrandLockupVariant variant, double fontSize) =>
      fontSize *
      (variant == BrandLockupVariant.stacked
          ? stackedIconRatio
          : horizontalIconRatio);

  static double clearSpaceFor(double iconSize) => clearSpaceRatio * iconSize;

  @override
  Widget build(BuildContext context) {
    final iconSize = iconSizeFor(variant, fontSize);
    final mark = BrandMark(size: iconSize, color: markColor ?? color);
    final wordmark = BrandWordmark(
      fontSize: fontSize,
      color: color,
      crossbarColor: crossbarColor,
      showCrossbar: showCrossbar,
    );
    final wordmarkSize = BrandWordmark.layOut(fontSize, color).size;

    return Semantics(
      label: semanticLabel,
      image: true,
      header: isHeader,
      child: switch (variant) {
        BrandLockupVariant.stacked => _stacked(
          mark,
          wordmark,
          iconSize,
          wordmarkSize,
        ),
        BrandLockupVariant.horizontal => _horizontal(
          mark,
          wordmark,
          iconSize,
          wordmarkSize,
        ),
      },
    );
  }

  /// The mark hangs [BrandMark.stemInset] to the left of the box so the box's
  /// own left edge lands on the stem's outer edge — the same invisible rule
  /// the P of "Prosper" sits on. Rebuilding this by bounding box instead would
  /// throw away the whole idea of the lockup, so the offset is not optional.
  ///
  /// Only the mark's transparent left margin falls outside the box; its ink
  /// starts exactly at x = 0.
  Widget _stacked(
    Widget mark,
    Widget wordmark,
    double iconSize,
    Size wordmarkSize,
  ) {
    final overhang = BrandMark.stemInset * iconSize;
    final gap = stackedGapRatio * iconSize;

    return SizedBox(
      width: math.max(iconSize - overhang, wordmarkSize.width),
      height: iconSize + gap + wordmarkSize.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: -overhang, top: 0, child: mark),
          Positioned(left: 0, top: iconSize + gap, child: wordmark),
        ],
      ),
    );
  }

  Widget _horizontal(
    Widget mark,
    Widget wordmark,
    double iconSize,
    Size wordmarkSize,
  ) {
    final gap = horizontalGapRatio * iconSize;

    // Below the minimum the wordmark stops being legible, so the spec drops
    // to the mark alone rather than shrinking the type past 11px.
    if (iconSize + gap + wordmarkSize.width < horizontalMinWidth) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        mark,
        SizedBox(width: gap),
        wordmark,
      ],
    );
  }
}
