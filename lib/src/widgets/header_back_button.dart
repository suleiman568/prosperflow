import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Header back arrow with a full 44×44 hit area (the visible icon stays
/// 20px). Pops when possible, otherwise returns to the dashboard — the
/// same behavior every screen header used individually.
class HeaderBackButton extends StatelessWidget {
  const HeaderBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
        } else {
          navigator.pushReplacementNamed('/dashboard');
        }
      },
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Icon(Icons.arrow_back, size: 20, color: AppColors.textPrimary),
      ),
    );
  }
}
