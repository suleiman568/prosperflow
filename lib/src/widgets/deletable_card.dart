import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Swipe a card left — or long-press it — to delete it, with a confirmation
/// dialog in the app's design language. Long-press covers mouse-driven
/// platforms (web/desktop) where a swipe is awkward; on Android both work.
/// Used by the Products and Expenses lists; deletion is a soft delete in
/// the local store that syncs to Supabase like any update.
class DeletableCard extends StatelessWidget {
  const DeletableCard({
    super.key,
    required this.itemKey,
    required this.title,
    required this.message,
    required this.onDelete,
    required this.child,
  });

  /// Stable identity for the dismissed row (the entity's id).
  final String itemKey;

  /// Dialog title, e.g. 'Delete Palm Oil (25L)?'.
  final String title;

  /// Dialog body explaining the consequence.
  final String message;

  final Future<void> Function() onDelete;
  final Widget child;

  Future<bool?> _confirm(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShape.cardRadius),
        ),
        title: Text(
          title,
          style: AppText.style(FontWeight.w800, 17, AppColors.textPrimary),
        ),
        content: Text(
          message,
          style: AppText.style(FontWeight.w500, 13, AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style:
                  AppText.style(FontWeight.w700, 13, AppColors.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppShape.controlRadius),
              ),
            ),
            child: Text(
              'Delete',
              style: AppText.style(FontWeight.w700, 13, Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _longPressDelete(BuildContext context) async {
    final confirmed = await _confirm(context);
    if (confirmed == true) await onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(itemKey),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirm(context),
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.accentRed,
          borderRadius: BorderRadius.circular(AppShape.cardRadius),
        ),
        child: const Icon(Icons.delete_rounded, size: 24, color: Colors.white),
      ),
      child: GestureDetector(
        onLongPress: () => _longPressDelete(context),
        child: child,
      ),
    );
  }
}
