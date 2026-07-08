import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Toast per the component inventory: #1A1A1A background, white 600 · 13px,
/// 14px radius, floats above the tab bar, auto-dismisses after ~3s.
void showAppToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: AppText.style(FontWeight.w600, 13, Colors.white),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        duration: const Duration(milliseconds: 3200),
      ),
    );
}
