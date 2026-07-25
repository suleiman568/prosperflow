import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'pressable.dart';

/// Centered first-run/empty message: muted icon, short title, friendly
/// line of guidance — the tone set by Credits' "All credits collected!".
///
/// Pass [actionLabel] + [onAction] to offer a direct call-to-action (e.g.
/// "Add product") right in the empty state, so a first-run user doesn't have
/// to hunt for the FAB.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;

  /// Label for the optional call-to-action button. Rendered only when both
  /// this and [onAction] are provided.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final action = actionLabel;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppShape.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.placeholder),
            const SizedBox(height: AppShape.gapMd),
            Text(title, style: AppText.emptyTitle),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.style(
                FontWeight.w600,
                13,
                AppColors.textSecondary,
              ),
            ),
            if (action != null && onAction != null) ...[
              const SizedBox(height: AppShape.gapLg),
              Pressable(
                onTap: onAction,
                semanticLabel: action,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppShape.controlRadius),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        action,
                        style: AppText.style(FontWeight.w700, 14, Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
