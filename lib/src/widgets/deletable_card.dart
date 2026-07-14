import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The app's delete confirmation dialog, shared by the swipe, long-press,
/// and overflow-menu paths.
Future<bool?> showDeleteConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
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
            style: AppText.style(FontWeight.w700, 13, AppColors.textSecondary),
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

/// Visible three-dot menu on a card offering Delete (and optionally Edit) —
/// the discoverable, mouse-friendly path (web/desktop) alongside swipe and
/// long-press.
class CardOverflowMenu extends StatelessWidget {
  const CardOverflowMenu({
    super.key,
    required this.title,
    required this.message,
    required this.onDelete,
    this.onEdit,
  });

  /// Confirm-dialog title, e.g. 'Delete Palm Oil (25L)?'.
  final String title;

  /// Confirm-dialog body explaining the consequence.
  final String message;

  final Future<void> Function() onDelete;

  /// When set, the menu gains an Edit item above Delete.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More',
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppShape.controlRadius),
      ),
      onSelected: (value) async {
        if (value == 'edit') {
          onEdit?.call();
          return;
        }
        final confirmed = await showDeleteConfirmDialog(
          context,
          title: title,
          message: message,
        );
        if (confirmed == true) await onDelete();
      },
      itemBuilder: (_) => [
        if (onEdit != null)
          PopupMenuItem(
            value: 'edit',
            height: 40,
            child: Row(
              children: [
                const Icon(Icons.edit_rounded,
                    size: 16, color: AppColors.textPrimary),
                const SizedBox(width: 8),
                Text(
                  'Edit',
                  style: AppText.style(
                      FontWeight.w700, 13, AppColors.textPrimary),
                ),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'delete',
          height: 40,
          child: Row(
            children: [
              const Icon(Icons.delete_rounded,
                  size: 16, color: AppColors.accentRed),
              const SizedBox(width: 8),
              Text(
                'Delete',
                style: AppText.style(FontWeight.w700, 13, AppColors.accentRed),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        child: const Icon(Icons.more_vert,
            size: 18, color: AppColors.placeholder),
      ),
    );
  }
}

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

  Future<void> _longPressDelete(BuildContext context) async {
    final confirmed =
        await showDeleteConfirmDialog(context, title: title, message: message);
    if (confirmed == true) await onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(itemKey),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) =>
          showDeleteConfirmDialog(context, title: title, message: message),
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
