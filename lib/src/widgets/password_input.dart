import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'filled_input.dart';

/// A [FilledInput] for passwords with a reveal toggle: the value is obscured
/// by default, and the trailing eye button flips it so a trader can check what
/// they typed (mistyped passwords behind dots are a common phone frustration).
class PasswordInput extends StatefulWidget {
  const PasswordInput({
    super.key,
    this.hint = '••••••••',
    required this.controller,
    this.textInputAction,
  });

  final String hint;
  final TextEditingController controller;
  final TextInputAction? textInputAction;

  @override
  State<PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<PasswordInput> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return FilledInput(
      hint: widget.hint,
      controller: widget.controller,
      obscureText: _obscured,
      textInputAction: widget.textInputAction,
      suffixIcon: IconButton(
        onPressed: () => setState(() => _obscured = !_obscured),
        tooltip: _obscured ? 'Show password' : 'Hide password',
        // Announce the action for screen-reader users, matching the tooltip.
        icon: Icon(
          _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 20,
          color: AppColors.textSecondary,
          semanticLabel: _obscured ? 'Show password' : 'Hide password',
        ),
      ),
    );
  }
}
