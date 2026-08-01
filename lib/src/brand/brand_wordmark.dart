import 'package:flutter/widgets.dart';

import 'brand_colors.dart';

/// The ProsperFlow wordmark: "ProsperFlow" in Familjen Grotesk 600 with an
/// accent bar laid over the F's crossbar (Identity Spec §03).
///
/// One weight throughout — the spec calls splitting "Prosper" and "Flow" into
/// two weights or two colours an explicit don't, so the accent bar is the only
/// thing distinguishing the two halves.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    super.key,
    required this.fontSize,
    this.color = BrandColors.ink,
    this.crossbarColor = BrandColors.marigold,
    this.showCrossbar = true,
  });

  final double fontSize;

  /// The type colour: ink on light, bone on dark.
  final Color color;

  /// The crossbar bar. Marigold in full colour.
  final Color crossbarColor;

  /// False for the single-material variant — deboss, foil, laser, moulded
  /// plastic — where the wordmark reverts to plain "ProsperFlow" because the
  /// crossbar detail cannot survive a single-depth surface.
  final bool showCrossbar;

  static const String fontFamily = 'FamiljenGrotesk';

  /// Smallest size the spec allows.
  static const double minFontSize = 11;

  /// −0.035em (−3.5%) at all sizes.
  static const double trackingRatio = -0.035;

  /// Cap height as a fraction of font size, per the spec's own conversion:
  /// the stacked icon is both 3.2 × cap height and 2.08 × font size.
  static const double capHeightRatio = 0.65;

  static const String _text = 'ProsperFlow';

  /// Index of the F — where the accent bar is anchored.
  static const int _fIndex = 7;

  // The bar, in em. Horizontal offsets are measured from the F's box, which
  // means the same thing in both CSS and Flutter.
  static const double _barLeft = 0.37;
  static const double _barWidth = 0.345;
  static const double _barHeight = 0.08;
  static const double _barRadius = 0.04;

  /// Height of the bar's top edge above the alphabetic baseline.
  ///
  /// The spec states the bar as `top: 0.509em` from the F's box *and* as
  /// derived from the glyph's crossbar at 0.31–0.39em above the baseline.
  /// Those agree in CSS but not here, because "the box's top" is not the same
  /// line in both models: with `line-height: 1` and this face's ascent +
  /// descent of ~1.247em, CSS half-leading is negative and the baseline lands
  /// 0.899em down the box, whereas Flutter's `height: 1` scales the metrics
  /// proportionally and puts it at 0.820em. Taking `0.509em` literally drops
  /// the bar 0.08em — a full bar height — off the glyph's crossbar.
  ///
  /// So the bar is anchored to the baseline, which is the same line in both
  /// models and is what the crossbar's position is a fact about.
  static const double _barTopAboveBaseline = 0.39;

  static TextStyle styleFor(double fontSize, Color color) => TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w600,
    fontSize: fontSize,
    letterSpacing: trackingRatio * fontSize,
    height: 1,
    color: color,
  );

  /// Lays the wordmark out at [fontSize].
  ///
  /// Never text-scaled: this is a logo, not copy. Scaling it with the user's
  /// text size would stretch the lockup's geometry away from the spec ratios
  /// and push the brand block out of the chrome it sits in.
  static TextPainter layOut(double fontSize, Color color) => TextPainter(
    text: TextSpan(text: _text, style: styleFor(fontSize, color)),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  )..layout();

  /// Left edge of the F's box, measured from the laid-out wordmark rather than
  /// assumed: the prefix width depends on the font's metrics and on tracking,
  /// so a hardcoded offset would drift at every size and break outright if the
  /// face were ever swapped.
  static double crossbarOriginFor(TextPainter painter) => painter
      .getOffsetForCaret(const TextPosition(offset: _fIndex), Rect.zero)
      .dx;

  /// The accent bar in the painter's coordinate space.
  static RRect crossbarRectFor(TextPainter painter, double fontSize) {
    final origin = crossbarOriginFor(painter);
    final baseline = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    return RRect.fromRectAndRadius(
      Rect.fromLTWH(
        origin + _barLeft * fontSize,
        baseline - _barTopAboveBaseline * fontSize,
        _barWidth * fontSize,
        _barHeight * fontSize,
      ),
      Radius.circular(_barRadius * fontSize),
    );
  }

  @override
  Widget build(BuildContext context) {
    final painter = layOut(fontSize, color);
    return CustomPaint(
      size: painter.size,
      painter: _BrandWordmarkPainter(
        fontSize: fontSize,
        color: color,
        crossbarColor: crossbarColor,
        showCrossbar: showCrossbar,
      ),
    );
  }
}

class _BrandWordmarkPainter extends CustomPainter {
  const _BrandWordmarkPainter({
    required this.fontSize,
    required this.color,
    required this.crossbarColor,
    required this.showCrossbar,
  });

  final double fontSize;
  final Color color;
  final Color crossbarColor;
  final bool showCrossbar;

  @override
  void paint(Canvas canvas, Size size) {
    final painter = BrandWordmark.layOut(fontSize, color);
    painter.paint(canvas, Offset.zero);

    if (!showCrossbar) return;
    canvas.drawRRect(
      BrandWordmark.crossbarRectFor(painter, fontSize),
      Paint()..color = crossbarColor,
    );
  }

  @override
  bool shouldRepaint(covariant _BrandWordmarkPainter oldDelegate) =>
      oldDelegate.fontSize != fontSize ||
      oldDelegate.color != color ||
      oldDelegate.crossbarColor != crossbarColor ||
      oldDelegate.showCrossbar != showCrossbar;
}
