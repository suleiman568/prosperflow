import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'pressable.dart';

/// White card per the design system: 16px radius,
/// shadow 0 2px 10px rgba(0,0,0,0.05).
///
/// [AppCard.tinted] is the alert/banner variant: tint background,
/// 1px tint border, no shadow.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.semanticLabel,
  }) : color = AppColors.surface,
       borderColor = null,
       hasShadow = true;

  const AppCard.tinted({
    super.key,
    required this.child,
    required this.color,
    this.borderColor,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.semanticLabel,
  }) : hasShadow = false;

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color? borderColor;
  final bool hasShadow;
  final VoidCallback? onTap;

  /// Screen-reader label for tappable cards (e.g. quick actions).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppShape.cardRadius),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
        boxShadow: hasShadow ? AppShape.cardShadow : null,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Pressable(onTap: onTap, semanticLabel: semanticLabel, child: card);
  }
}
