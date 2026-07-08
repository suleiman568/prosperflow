import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The ProsperFlow logo: an 88px circle with the brand's green gradient
/// (160° from primary to primaryDark) holding a white outlined crate icon.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // CSS linear-gradient(160deg, primary, primaryDark).
        gradient: const LinearGradient(
          begin: Alignment(-0.34, -0.94),
          end: Alignment(0.34, 0.94),
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x590B8F4E),
            offset: Offset(0, 10),
            blurRadius: 24,
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size.square(size * 42 / 88),
          painter: const _CrateIconPainter(),
        ),
      ),
    );
  }
}

/// Draws the crate/package outline from the design's SVG:
///   M3 7l9-4 9 4v10l-9 4-9-4V7z  +  M3 7l9 4 9-4  +  M12 11v10
/// White stroke, width 1.8 (in the 24-unit viewBox), rounded joins.
class _CrateIconPainter extends CustomPainter {
  const _CrateIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * s
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final outline = Path()
      ..moveTo(3 * s, 7 * s)
      ..lineTo(12 * s, 3 * s)
      ..lineTo(21 * s, 7 * s)
      ..lineTo(21 * s, 17 * s)
      ..lineTo(12 * s, 21 * s)
      ..lineTo(3 * s, 17 * s)
      ..close();

    final inner = Path()
      ..moveTo(3 * s, 7 * s)
      ..lineTo(12 * s, 11 * s)
      ..lineTo(21 * s, 7 * s)
      ..moveTo(12 * s, 11 * s)
      ..lineTo(12 * s, 21 * s);

    canvas.drawPath(outline, paint);
    canvas.drawPath(inner, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
