import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosperflow/src/brand/brand_colors.dart';
import 'package:prosperflow/src/theme/tokens.dart';

/// WCAG 2.1 relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('brand pairings (Identity Spec §01)', () {
    test('ink is the type colour on every ground', () {
      expect(contrast(BrandColors.ink, BrandColors.bone), greaterThan(7));
      expect(contrast(BrandColors.ink, AppColors.surface), greaterThan(7));
      expect(contrast(BrandColors.ink, AppColors.inputBg), greaterThan(7));
    });

    test(
      'marigold fails as type on light, which is why it only ever fills',
      () {
        // The spec's own number: 2.0:1. This test exists to keep the constraint
        // visible — if someone "fixes" the contrast by lightening the ground,
        // marigold still must not become text.
        expect(contrast(AppColors.action, BrandColors.bone), lessThan(3));
        expect(contrast(AppColors.action, AppColors.surface), lessThan(3));
      },
    );

    test('labels on the accent are ink, not white', () {
      expect(contrast(AppColors.onAction, AppColors.action), greaterThan(4.5));
      // The reason the old white-on-green button label could not carry over.
      expect(contrast(Colors.white, AppColors.action), lessThan(3));
      expect(
        contrast(AppColors.onAction, AppColors.actionPressed),
        greaterThan(4.5),
      );
    });
  });

  group('semantic colours are readable as type', () {
    // These carry meaning a trader reads at a glance — money in, money out,
    // owed — so each has to clear AA on every ground it lands on. The colours
    // they replaced did not: the old primary green was 3.9:1 on bone and the
    // old credit orange 2.9:1.
    final onLight = {
      'positive': AppColors.positive,
      'negative': AppColors.negative,
      'negativeDeep': AppColors.negativeDeep,
      'credit': AppColors.credit,
      'transfer': AppColors.transfer,
      'pos': AppColors.pos,
      'textPrimary': AppColors.textPrimary,
      'textSecondary': AppColors.textSecondary,
    };

    onLight.forEach((name, colour) {
      test('$name clears AA on bone and on white', () {
        expect(
          contrast(colour, AppColors.appBg),
          greaterThanOrEqualTo(4.5),
          reason: '$name on bone',
        );
        expect(
          contrast(colour, AppColors.surface),
          greaterThanOrEqualTo(4.5),
          reason: '$name on white',
        );
      });
    });

    final onTint = {
      'positive': (AppColors.positive, AppColors.positiveTint),
      'negative': (AppColors.negative, AppColors.negativeTint),
      'credit': (AppColors.credit, AppColors.creditTint),
      'transfer': (AppColors.transfer, AppColors.transferTint),
      'pos': (AppColors.pos, AppColors.posTint),
    };

    onTint.forEach((name, pair) {
      test('$name clears AA on its own tint', () {
        expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      });
    });

    test('white reads on the flat semantic fills the hero cards use', () {
      // The profit/loss hero and the mark-as-paid pill are filled with a
      // semantic colour and labelled in white.
      expect(contrast(Colors.white, AppColors.positive), greaterThan(4.5));
      expect(contrast(Colors.white, AppColors.negative), greaterThan(4.5));
    });
  });

  group('the accent stays single', () {
    test('no semantic colour sits in marigold territory', () {
      // The old credit orange (#EF6C00) was close enough to marigold to read
      // as a second accent. Nothing may drift back into that band.
      for (final c in [
        AppColors.positive,
        AppColors.negative,
        AppColors.credit,
        AppColors.transfer,
        AppColors.pos,
      ]) {
        final h = HSLColor.fromColor(c);
        final marigold = HSLColor.fromColor(AppColors.action);
        final hueGap = (h.hue - marigold.hue).abs();
        final nearHue = math.min(hueGap, 360 - hueGap) < 20;
        expect(
          nearHue && h.lightness > 0.35,
          isFalse,
          reason: 'colour is bright and close to marigold in hue',
        );
      }
    });

    test('the accent is never a text token', () {
      for (final t in [
        AppColors.textPrimary,
        AppColors.textSecondary,
        AppColors.placeholder,
      ]) {
        expect(t, isNot(AppColors.action));
      }
    });
  });
}
