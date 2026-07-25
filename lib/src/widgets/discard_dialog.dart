import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Wraps a form sheet so a system back or scrim-tap dismiss asks to confirm
/// when [isDirty] reports unsaved input; a clean form dismisses straight away.
///
/// Only system-driven pops are guarded — a successful save that calls
/// `Navigator.pop` directly is unaffected. Pair with `enableDrag: false` on the
/// sheet so a drag-dismiss (which bypasses [PopScope]) can't slip past it.
class DiscardGuard extends StatelessWidget {
  const DiscardGuard({super.key, required this.isDirty, required this.child});

  final bool Function() isDirty;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (!isDirty() || await confirmDiscard(context)) {
          navigator.pop();
        }
      },
      child: child,
    );
  }
}

/// Asks the trader to confirm before throwing away half-entered form input.
/// Returns true if they chose to discard, false if they want to keep editing
/// (including when the dialog is dismissed without a choice).
Future<bool> confirmDiscard(BuildContext context) async {
  final discard = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        'Discard changes?',
        style: AppText.style(FontWeight.w800, 17, AppColors.textPrimary),
      ),
      content: Text(
        "The details you entered won't be saved.",
        style: AppText.dialogBody,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Keep editing',
            style: AppText.style(FontWeight.w700, 14, AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            'Discard',
            style: AppText.style(FontWeight.w700, 14, AppColors.accentRed),
          ),
        ),
      ],
    ),
  );
  return discard ?? false;
}
