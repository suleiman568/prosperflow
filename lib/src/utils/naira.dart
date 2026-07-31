/// Currency rule from the handoff: all money is integer Naira,
/// formatted `₦1,600` — no decimals, comma thousands separator.
String formatNaira(int amount) =>
    '${amount < 0 ? '-' : ''}₦'
    '${groupDigits(amount.abs().toString())}';

/// "1339000" → "1,339,000". Groups a bare digit string in threes, so typed
/// amounts read at a glance and an order-of-magnitude slip is obvious.
/// Input must already be digits-only; non-digits are dropped.
String groupDigits(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Parses an amount a trader typed, tolerating the grouping separators the
/// money fields insert ("1,339,000" → 1339000). Returns null when no digits
/// are present, so callers keep their existing "fill in this field" checks.
int? parseAmount(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? null : int.tryParse(digits);
}
