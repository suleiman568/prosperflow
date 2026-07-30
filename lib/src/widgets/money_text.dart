import 'package:flutter/material.dart';

import '../utils/naira.dart';

/// A single-line money figure.
///
/// A formatted amount has no sensible line-break points: wrapped, "₦1,339,000"
/// renders as "₦1,339,0 / 00" and reads as two numbers; ellipsized, it shows a
/// wrong amount. So when the figure is too wide for its slot it scales down
/// slightly to stay on one intact line instead ([BoxFit.scaleDown] never
/// enlarges, so values that fit render at their natural size, unchanged).
///
/// The slot must be width-bounded for the scaling to engage — inside an
/// unbounded [Row] child, wrap the parent in [Expanded] or [Flexible].
class MoneyText extends StatelessWidget {
  MoneyText(int amount, {super.key, required this.style})
    : text = formatNaira(amount);

  /// For pre-composed money strings a plain amount can't express — a signed
  /// profit ("+₦4,800"), a footnote marker ("₦12,000*"), or the "—" of an
  /// unknown value. Same single-line, scale-down rendering.
  const MoneyText.raw(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text(text, maxLines: 1, style: style),
    );
  }
}
