import 'package:flutter/widgets.dart';

import 'brand_colors.dart';

/// The ProsperFlow monogram: a constructed P, drawn as two stroked paths on a
/// 100 × 100 grid (Identity Spec §02).
///
/// Painted rather than shipped as an SVG asset, matching how the app already
/// draws vector chrome and keeping the dependency list unchanged.
///
/// The widget's box is the full 100-unit grid, not the ink. Ink occupies
/// 19–81 × 6–94 within it, so the box carries a 19-unit left margin — that
/// margin is exactly what [stemInset] describes, and what the stacked lockup
/// pulls back out to sit the stem on the wordmark's left edge.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    required this.size,
    this.color = BrandColors.ink,
  });

  /// Width and height of the grid box, in logical pixels.
  ///
  /// The spec's minimum is 16; below that the counter closes up and the mark
  /// stops reading as a P.
  final double size;

  /// [BrandColors.ink] on light grounds, [BrandColors.marigold] on dark.
  final Color color;

  /// Smallest size the spec allows.
  static const double minSize = 16;

  /// Distance from the box's left edge to the stem's left edge, as a fraction
  /// of [size] — the stroke's outer edge at 27 − 16/2 = 19 units.
  static const double stemInset = 0.19;

  /// Ink height as a fraction of [size] (6 → 94 units).
  static const double inkHeightRatio = 0.88;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BrandMarkPainter(color)),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 100;

    // 16 units normally; 18 at 16px and below, so the mark holds its weight
    // against a cluttered home screen instead of thinning out.
    final strokeUnits = size.width <= BrandMark.minSize ? 18.0 : 16.0;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeUnits * u
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // M27 86 L27 14
    final stem = Path()
      ..moveTo(27 * u, 86 * u)
      ..lineTo(27 * u, 14 * u);

    // M27 14 H51 C65.5 14 73 22.4 73 34 C73 45.6 65.5 54 51 54 H27
    final bowl = Path()
      ..moveTo(27 * u, 14 * u)
      ..lineTo(51 * u, 14 * u)
      ..cubicTo(65.5 * u, 14 * u, 73 * u, 22.4 * u, 73 * u, 34 * u)
      ..cubicTo(73 * u, 45.6 * u, 65.5 * u, 54 * u, 51 * u, 54 * u)
      ..lineTo(27 * u, 54 * u);

    canvas.drawPath(stem, paint);
    canvas.drawPath(bowl, paint);
  }

  @override
  bool shouldRepaint(covariant _BrandMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
