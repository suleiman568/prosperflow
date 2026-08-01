import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'brand_lockup.dart';
import 'brand_mark.dart';
import 'brand_wordmark.dart';

/// The brand colours as PDF colours, so a printed report and the screen agree.
const brandInkPdf = PdfColor.fromInt(0xFF17150F);
const brandMarigoldPdf = PdfColor.fromInt(0xFFE5A21C);

/// The horizontal lockup, drawn into a PDF (Identity Spec §04 — the secondary
/// lockup is for receipt headers, which is what this is).
///
/// Drawn straight onto the canvas rather than assembled from PDF text widgets:
/// the accent bar is positioned off the baseline, and [PdfGraphics.drawString]
/// takes a baseline directly, so this keeps the same geometry as the on-screen
/// widget instead of re-deriving it from a text box whose leading model
/// differs again.
///
/// Wrapped in a [pw.Builder] because the glyph metrics needed to place the bar
/// only resolve once there is a document context to build the font against.
pw.Widget brandLockupPdf({
  required pw.Font font,
  required double fontSize,
  PdfColor color = brandInkPdf,
  PdfColor crossbarColor = brandMarigoldPdf,
  bool showCrossbar = true,
}) => pw.Builder(
  builder: (context) {
    final pdfFont = font.getFont(context);
    final iconSize = fontSize * BrandLockup.horizontalIconRatio;
    final gap = BrandLockup.horizontalGapRatio * iconSize;
    const tracking = BrandWordmark.trackingRatio;

    // stringMetrics takes letter spacing in em; TextStyle takes it in points.
    double widthOf(String s) =>
        pdfFont.stringMetrics(s, letterSpacing: tracking).width * fontSize;

    final prefixWidth = widthOf('Prosper');
    final wordmarkWidth = widthOf('ProsperFlow');

    return pw.CustomPaint(
      size: PdfPoint(iconSize + gap + wordmarkWidth, iconSize),
      painter: (canvas, size) {
        _paintMark(canvas, iconSize, color);

        // PDF space is y-up. Centre the cap block on the mark's centre: the
        // cap spans baseline..baseline + capHeight and the mark's ink is
        // centred in its own box, so this puts both midpoints on one line.
        final capHeight = BrandWordmark.capHeightRatio * fontSize;
        final baseline = (iconSize - capHeight) / 2;
        final textLeft = iconSize + gap;

        canvas
          ..setFillColor(color)
          ..drawString(
            pdfFont,
            fontSize,
            'ProsperFlow',
            textLeft,
            baseline,
            charSpace: tracking * fontSize,
          );

        if (!showCrossbar) return;

        // 0.31-0.39em above the baseline, 0.37em right of the F's box — the
        // same two numbers the widget uses.
        canvas
          ..setFillColor(crossbarColor)
          ..drawRRect(
            textLeft + prefixWidth + 0.37 * fontSize,
            baseline + 0.31 * fontSize,
            0.345 * fontSize,
            0.08 * fontSize,
            0.04 * fontSize,
            0.04 * fontSize,
          )
          ..fillPath();
      },
    );
  },
);

/// The mark alone, for the report footer.
pw.Widget brandMarkPdf({required double size, PdfColor color = brandInkPdf}) =>
    pw.CustomPaint(
      size: PdfPoint(size, size),
      painter: (canvas, _) => _paintMark(canvas, size, color),
    );

/// The constructed P on its 100-unit grid, flipped into PDF's y-up space.
void _paintMark(PdfGraphics canvas, double size, PdfColor color) {
  final u = size / 100;
  double x(double v) => v * u;
  double y(double v) => size - v * u;

  canvas
    ..setStrokeColor(color)
    ..setLineWidth((size <= BrandMark.minSize ? 18.0 : 16.0) * u)
    ..setLineCap(PdfLineCap.round)
    ..setLineJoin(PdfLineJoin.round)
    // M27 86 L27 14
    ..moveTo(x(27), y(86))
    ..lineTo(x(27), y(14))
    ..strokePath()
    // M27 14 H51 C65.5 14 73 22.4 73 34 C73 45.6 65.5 54 51 54 H27
    ..moveTo(x(27), y(14))
    ..lineTo(x(51), y(14))
    ..curveTo(x(65.5), y(14), x(73), y(22.4), x(73), y(34))
    ..curveTo(x(73), y(45.6), x(65.5), y(54), x(51), y(54))
    ..lineTo(x(27), y(54))
    ..strokePath();
}
