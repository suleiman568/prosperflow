import 'package:flutter/material.dart';

import '../brand/brand_colors.dart';

/// Design tokens from the ProsperFlow Developer Handoff (v1.0 — 7 July 2026),
/// remapped onto the identity system's palette (Identity Spec §01).
abstract final class AppColors {
  // ---- Ground and surface (Identity Spec §01) ----

  /// Screen background. Bone, the brand's light-mode ground.
  static const appBg = BrandColors.bone;

  /// Card surfaces, tab bar. White is permitted and reads as a raised plane
  /// against bone, which is why cards keep it while the screen does not.
  static const surface = Colors.white;

  /// Filled inputs, inactive pills, icon-button circles — a warm step down
  /// from [appBg] so a field reads as recessed without a border.
  static const inputBg = Color(0xFFF0EBE0);

  /// Tab bar top border, app bar bottom border.
  static const divider = Color(0xFFE4DFD4);

  // ---- Type ----

  /// Primary text. Ink carries every text role; 17.1:1 on bone.
  static const textPrimary = BrandColors.ink;

  /// Secondary text, labels — 5.5:1 on bone. A warm neutral rather than a
  /// grey, so it sits in the same family as ink and bone.
  static const textSecondary = Color(0xFF6B6459);

  /// Placeholder text in filled inputs — 3.8:1 on [inputBg].
  ///
  /// Short of AA on purpose: a hint dark enough to pass reads as a filled
  /// value, and a trader thinking a field is already answered is the worse
  /// failure. Still a clear improvement on the 2.5:1 this was.
  static const placeholder = Color(0xFF7E766A);

  // ---- The single accent ----

  /// Marigold. One primary action per screen, and nothing else: it is 2.1:1
  /// on bone, so it can be a fill but never type, an icon on light, or a
  /// border carrying meaning.
  static const action = BrandColors.marigold;

  /// Pressed state for [action] — 6.2:1 against [onAction].
  static const actionPressed = Color(0xFFC98A12);

  /// Labels and icons on [action]. Ink at 8.3:1; white would be 2.2:1 and is
  /// the reason the old white-on-green button label could not simply carry
  /// over.
  static const onAction = BrandColors.ink;

  // ---- Semantic roles ----
  //
  // These are data, not brand: they encode what a figure *means* (money in,
  // money out, owed) and are the one thing a trader reads at a glance. The
  // spec's single-accent rule is about brand colour, and is kept by a
  // division of labour — marigold is only ever a fill, and these are only
  // ever type or an icon tint. Nothing here competes to look tappable.
  //
  // All are >= 5:1 on bone, on white, and on their own tint. The greens and
  // ambers they replace were not: the old primary green was 3.9:1 and the old
  // credit orange 2.9:1, both failing AA as text.

  /// Cash, money in, success.
  static const positive = Color(0xFF0A6B3C);
  static const positiveTint = Color(0xFFE7EFE4);

  /// Expenses, money out.
  static const negative = Color(0xFFB3261E);
  static const negativeTint = Color(0xFFF6E7E3);
  static const negativeBorder = Color(0xFFE9CFC9);

  /// The deep end of a loss figure, pairing with [negative] the way
  /// [actionPressed] pairs with [action].
  static const negativeDeep = Color(0xFF8E1B14);

  /// Credit, low stock, warnings.
  ///
  /// Deliberately a deep amber-brown rather than the orange this replaces:
  /// that orange sat inside marigold's hue band and read as a second accent
  /// competing with the primary action.
  static const credit = Color(0xFF8A5A12);
  static const creditTint = Color(0xFFF4EBDA);
  static const creditBorder = Color(0xFFE6D5B4);

  /// Bank transfer, weekly stats.
  static const transfer = Color(0xFF1554A8);
  static const transferTint = Color(0xFFE3EAF4);

  /// POS payments, reports.
  static const pos = Color(0xFF6A1B9A);
  static const posTint = Color(0xFFEEE7F2);

  /// Offline pill / pending-sync row — calm, never red (handoff §6).
  static const offlineBg = Color(0xFFEDE8DD);
  static const offlineFg = Color(0xFF6B6459);
}

/// Inter text styles per the handoff's typography table.
abstract final class AppText {
  static const _family = 'Inter';

  static TextStyle style(
    FontWeight weight,
    double size,
    Color color, {
    double? height,
  }) => TextStyle(
    fontFamily: _family,
    fontWeight: weight,
    fontSize: size,
    color: color,
    height: height,
  );

  /// Money hero — 900 · 32px (Total card, Net Profit).
  static final moneyHero = style(FontWeight.w900, 32, Colors.white);

  /// Screen title — 800 · 17px (app bars).
  static final screenTitle = style(FontWeight.w800, 17, AppColors.textPrimary);

  /// Field label — 700 · 12px · UPPERCASE (PRODUCT, QTY, PAYMENT METHOD).
  static final fieldLabel = style(FontWeight.w700, 12, AppColors.textSecondary);

  /// Filled input text — 500 · 15px.
  static final input = style(FontWeight.w500, 15, AppColors.textPrimary);
  static final inputHint = style(FontWeight.w500, 15, AppColors.placeholder);

  // ---- Semantic roles (naming for the repeated elements; same pixels) ----

  /// Section heading over a list/group — 800 · 13px
  /// ("Top Products", "Payment Breakdown", "Sales History for Today").
  static final sectionHeading = style(
    FontWeight.w800,
    13,
    AppColors.textPrimary,
  );

  /// Title on a large tile (product card, quick action) — 700 · 15px.
  static final cardTitle = style(FontWeight.w700, 15, AppColors.textPrimary);

  /// Title on a dense list row (expense/credit/history) — 700 · 13px.
  static final listTitle = style(FontWeight.w700, 13, AppColors.textPrimary);

  /// Secondary meta line under a title — 600 · 12px.
  static final cardMeta = style(FontWeight.w600, 12, AppColors.textSecondary);

  /// Small caption/footnote — 600 · 11px.
  static final caption = style(FontWeight.w600, 11, AppColors.textSecondary);

  /// Dialog / sheet body copy — 500 · 13px.
  static final dialogBody = style(FontWeight.w500, 13, AppColors.textSecondary);

  /// Empty-state title — 800 · 16px.
  static final emptyTitle = style(FontWeight.w800, 16, AppColors.textPrimary);

  /// Prominent stat value on a card — 800 · 20px (Sales/Expenses totals).
  static final statValue = style(FontWeight.w800, 20, AppColors.textPrimary);
}

/// Shape & spacing tokens.
abstract final class AppShape {
  /// Cards: 16px radius.
  static const cardRadius = 16.0;

  /// Buttons & inputs: 12px radius.
  static const controlRadius = 12.0;

  /// Screen padding.
  static const screenPadding = 20.0;

  /// Gap between cards.
  static const cardGap = 14.0;

  /// Grid gap.
  static const gridGap = 12.0;

  // ---- Vertical gap scale (for SizedBox spacers) ----
  /// 4px — tight gap between a label and its value.
  static const gapXs = 4.0;

  /// 8px — small gap between related rows.
  static const gapSm = 8.0;

  /// 12px — medium gap.
  static const gapMd = 12.0;

  /// 16px — gap before a new section/field.
  static const gapLg = 16.0;

  /// Standard screen body padding: [screenPadding] sides, snug top, room for
  /// the floating tab bar / FAB at the bottom.
  static const screenBody = EdgeInsets.fromLTRB(
    screenPadding,
    14,
    screenPadding,
    24,
  );

  /// Screen body padding for lists that sit under a FAB.
  static const screenBodyFab = EdgeInsets.fromLTRB(
    screenPadding,
    14,
    screenPadding,
    96,
  );

  /// Card shadow: 0 2px 10px rgba(0,0,0,0.05).
  static const cardShadow = [
    BoxShadow(color: Color(0x0D000000), offset: Offset(0, 2), blurRadius: 10),
  ];

  /// Colored glow under FABs, the primary button, and the brand logo:
  /// the accent at ~35% (button ~30%), 0 8px 20px by default (the logo
  /// uses a slightly deeper 0 10px 24px).
  static List<BoxShadow> glow(
    Color color, {
    double alpha = 0.35,
    double dy = 8,
    double blur = 20,
  }) => [
    BoxShadow(
      color: color.withValues(alpha: alpha),
      offset: Offset(0, dy),
      blurRadius: blur,
    ),
  ];
}
