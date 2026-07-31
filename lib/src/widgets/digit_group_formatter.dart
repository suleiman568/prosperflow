import 'package:flutter/services.dart';

import '../utils/naira.dart';

/// Inserts thousands separators as a money amount is typed ("1339000" shows
/// as "1,339,000"), so an order-of-magnitude slip is obvious while entering it.
///
/// The caret is kept next to the same digit the trader was editing: separators
/// shift character offsets, so the offset is recomputed from how many digits
/// precede the caret rather than carried over verbatim.
class DigitGroupFormatter extends TextInputFormatter {
  const DigitGroupFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsBeforeCaret = newValue.text
        .substring(0, newValue.selection.end.clamp(0, newValue.text.length))
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;

    final grouped = groupDigits(newValue.text);

    // Walk the formatted text until the same number of digits has passed.
    var caret = grouped.length;
    var seen = 0;
    for (var i = 0; i < grouped.length; i++) {
      if (seen == digitsBeforeCaret) {
        caret = i;
        break;
      }
      if (grouped[i] != ',') seen++;
    }
    if (seen == digitsBeforeCaret && caret == grouped.length) {
      caret = grouped.length;
    }

    return TextEditingValue(
      text: grouped,
      selection: TextSelection.collapsed(offset: caret),
    );
  }
}
