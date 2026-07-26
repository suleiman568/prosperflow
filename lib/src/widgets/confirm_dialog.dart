import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A generic confirm/cancel dialog. Returns true if the user confirmed, false
/// if they cancelled or dismissed it. [destructive] tints the confirm action
/// red for consequential actions (sign out, etc.).
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        title,
        style: AppText.style(FontWeight.w800, 17, AppColors.textPrimary),
      ),
      content: Text(message, style: AppText.dialogBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            cancelLabel,
            style: AppText.style(FontWeight.w700, 14, AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            confirmLabel,
            style: AppText.style(
              FontWeight.w700,
              14,
              destructive ? AppColors.accentRed : AppColors.primary,
            ),
          ),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
