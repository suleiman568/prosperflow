import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'pressable.dart';

/// Centered "we couldn't load this" panel — the error counterpart to
/// [EmptyState]. Same calm tone (muted icon, short title, friendly line),
/// plus a compact "Try again" button that re-subscribes the failed stream.
///
/// Shown when a screen's data stream emits an error, so a transient failure
/// reads as recoverable instead of spinning on the loading placeholder.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.onRetry,
    this.icon = Icons.cloud_off_rounded,
    this.title = "Couldn't load",
    this.message = 'Something went wrong. Please try again.',
  });

  final VoidCallback onRetry;
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: AppShape.gapLg),
            Pressable(
              onTap: onRetry,
              semanticLabel: 'Try again',
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
                      Icons.refresh_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    // Flexible so a large accessibility text scale wraps the
                    // label instead of overflowing the pill on a narrow phone.
                    Flexible(
                      child: Text(
                        'Try again',
                        textAlign: TextAlign.center,
                        style: AppText.style(FontWeight.w700, 14, Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
