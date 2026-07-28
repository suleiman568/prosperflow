const _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  'Sunday', //
];
const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
  'September', 'October', 'November', 'December', //
];

/// "Tuesday, 7 July 2026" — greeting/date format from the handoff.
String formatFullDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';

/// "Friday, 3 July" — expense list date format.
String formatWeekdayDayMonth(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

/// "1 July 2026" — credit "Sold:" date format.
String formatDayMonthYear(DateTime d) =>
    '${d.day} ${_months[d.month - 1]} ${d.year}';

/// "9:05 AM" — sale time in the Reports history detail rows.
String formatTime(DateTime d) {
  final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  return '$hour12:$minute ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// "just now" / "5 min ago" / "3 h ago" — sync row timestamp.
String formatAgo(DateTime time, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(time);
  if (elapsed.inMinutes < 1) return 'just now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes} min ago';
  if (elapsed.inDays < 1) return '${elapsed.inHours} h ago';
  return '${elapsed.inDays} d ago';
}

/// Whole calendar days between two moments, ignoring the time of day (and DST,
/// by comparing UTC-normalized dates). A sale yesterday afternoon and a check
/// this morning is "1 day", not a fractional 24-hour count.
int _calendarDaysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// "Owed today" / "Owed for 5 days" / "Owed for 2 weeks" / "Owed for 3 months"
/// — how long a credit has gone uncollected, coarsened to the largest natural
/// unit so a market trader sees the age of a debt at a glance.
String owedLabel(DateTime soldAt, {DateTime? now}) {
  final days = _calendarDaysBetween(soldAt, now ?? DateTime.now());
  if (days <= 0) return 'Owed today';
  final String span;
  if (days < 7) {
    span = days == 1 ? '1 day' : '$days days';
  } else if (days < 30) {
    final weeks = days ~/ 7;
    span = weeks == 1 ? '1 week' : '$weeks weeks';
  } else if (days < 365) {
    final months = days ~/ 30;
    span = months == 1 ? '1 month' : '$months months';
  } else {
    final years = days ~/ 365;
    span = years == 1 ? '1 year' : '$years years';
  }
  return 'Owed for $span';
}

/// A credit outstanding long enough to flag as overdue (30+ calendar days).
bool creditIsStale(DateTime soldAt, {DateTime? now}) =>
    _calendarDaysBetween(soldAt, now ?? DateTime.now()) >= 30;
