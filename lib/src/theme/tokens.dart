import 'package:flutter/material.dart';

/// Design tokens from the ProsperFlow Developer Handoff (v1.0 — 7 July 2026).
abstract final class AppColors {
  /// Primary buttons, active tabs, cash, money-in, success.
  static const primary = Color(0xFF0B8F4E);

  /// Pressed states, gradient end (135° from primary).
  static const primaryDark = Color(0xFF086B3A);

  /// Green icon circles, highlight backgrounds, track of green bars.
  static const mintTint = Color(0xFFE8F5E9);

  /// Screen background.
  static const appBg = Color(0xFFFAFAFA);

  /// Filled inputs, inactive pills, icon-button circles.
  static const inputBg = Color(0xFFF0EFEC);

  /// Primary text, toast background.
  static const textPrimary = Color(0xFF1A1A1A);

  /// Secondary text, labels (never lighter than this on white).
  static const textSecondary = Color(0xFF666666);

  /// Placeholder text in filled inputs.
  static const placeholder = Color(0xFF999999);

  /// Bank transfer, weekly stats.
  static const accentBlue = Color(0xFF1565C0);
  static const blueTint = Color(0xFFE3F2FD);

  /// POS payments, reports.
  static const accentPurple = Color(0xFF6A1B9A);
  static const purpleTint = Color(0xFFF3E5F5);

  /// Credit, low stock, warnings.
  static const accentOrange = Color(0xFFEF6C00);
  static const orangeTint = Color(0xFFFFF3E0);
  static const orangeBorder = Color(0xFFFFE0B2);

  /// Expenses, losses.
  static const accentRed = Color(0xFFC62828);
  static const redTint = Color(0xFFFFEBEE);
  static const redBorder = Color(0xFFFFCDD2);

  /// Dark end of the loss gradient (pairs with [accentRed] the way
  /// [primaryDark] pairs with [primary]).
  static const lossRed = Color(0xFFB71C1C);

  /// Card surfaces, tab bar.
  static const surface = Colors.white;

  /// Tab bar top border, app bar bottom border.
  static const divider = Color(0xFFECECEC);

  /// Offline pill / pending-sync row — calm gray, never red (handoff §6).
  static const offlineBg = Color(0xFFECEAE6);
  static const offlineFg = Color(0xFF555555);
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
