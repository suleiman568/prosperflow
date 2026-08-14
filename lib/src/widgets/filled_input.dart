import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import 'digit_group_formatter.dart';

/// Filled input per the component inventory: inputBg fill, 12px radius,
/// 16px vertical / 18px horizontal padding, 500 · 15px text, #999 placeholder.
class FilledInput extends StatelessWidget {
  const FilledInput({
    super.key,
    required this.hint,
    this.controller,
    this.obscureText = false,
    this.digitsOnly = false,
    this.groupThousands = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.suffixIcon,
  });

  final String hint;
  final TextEditingController? controller;
  final bool obscureText;
  final ValueChanged<String>? onChanged;

  /// Integer-only fields (prices, stock, amounts) — numeric keyboard and
  /// digit filtering, per the "amounts are integers" rule.
  final bool digitsOnly;

  /// Money fields: show thousands separators as the amount is typed. Implies
  /// [digitsOnly]. Left off for counts and percentages, where grouping is
  /// noise or meaningless.
  final bool groupThousands;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  /// Optional trailing affordance inside the field (e.g. a password reveal
  /// toggle). Left null for plain inputs.
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      onChanged: onChanged,
      keyboardType: (digitsOnly || groupThousands)
          ? TextInputType.number
          : keyboardType,
      inputFormatters: groupThousands
          ? const [DigitGroupFormatter()]
          : (digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null),
      textInputAction: textInputAction,
      style: AppText.input,
      cursorColor: AppColors.textPrimary,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.inputHint,
        filled: true,
        fillColor: AppColors.inputBg,
        isDense: true,
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShape.controlRadius),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
