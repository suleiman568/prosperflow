/// Currency rule from the handoff: all money is integer Naira,
/// formatted `₦1,600` — no decimals, comma thousands separator.
String formatNaira(int amount) {
  final sign = amount < 0 ? '-' : '';
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '$sign₦$buffer';
}
