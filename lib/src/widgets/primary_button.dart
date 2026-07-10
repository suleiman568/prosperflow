import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Primary button per the component inventory: 52px tall, primary background,
/// white 700 · 15px label with a leading ✓ icon, green glow shadow,
/// primaryDark when pressed.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.check,
    this.busy = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  /// Shows a spinner and ignores taps while an async action runs.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppShape.controlRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4D0B8F4E),
            offset: Offset(0, 8),
            blurRadius: 20,
          ),
        ],
      ),
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? AppColors.primaryDark
                : AppColors.primary,
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppShape.controlRadius),
            ),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: AppText.style(FontWeight.w700, 15, Colors.white),
                  ),
                ],
              ),
      ),
    );
  }
}
