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
