import 'package:flutter/material.dart';

import '../theme/tokens.dart';

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
  })  : color = AppColors.surface,
        borderColor = null,
        hasShadow = true;

  const AppCard.tinted({
    super.key,
    required this.child,
    required this.color,
    this.borderColor,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  }) : hasShadow = false;

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color? borderColor;
  final bool hasShadow;
  final VoidCallback? onTap;

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
    return GestureDetector(onTap: onTap, child: card);
  }
}
