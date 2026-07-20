import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Centered first-run/empty message: muted icon, short title, friendly
/// line of guidance — the tone set by Credits' "All credits collected!".
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

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
            const SizedBox(height: 12),
            Text(
              title,
              style: AppText.style(FontWeight.w800, 16, AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  AppText.style(FontWeight.w600, 13, AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
