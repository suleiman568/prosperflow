import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Filled input per the component inventory: inputBg fill, 12px radius,
/// 16px vertical / 18px horizontal padding, 500 · 15px text, #999 placeholder.
class FilledInput extends StatelessWidget {
  const FilledInput({
    super.key,
    required this.hint,
    this.controller,
    this.obscureText = false,
    this.digitsOnly = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
  });

  final String hint;
  final TextEditingController? controller;
  final bool obscureText;
  final ValueChanged<String>? onChanged;

  /// Integer-only fields (prices, stock, amounts) — numeric keyboard and
  /// digit filtering, per the "amounts are integers" rule.
  final bool digitsOnly;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      onChanged: onChanged,
      keyboardType: digitsOnly ? TextInputType.number : keyboardType,
      inputFormatters:
          digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
      textInputAction: textInputAction,
      style: AppText.input,
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.inputHint,
        filled: true,
        fillColor: AppColors.inputBg,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShape.controlRadius),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
