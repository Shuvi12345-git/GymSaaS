// ---------------------------------------------------------------------------
// Date utilities – display and API date formatting.
// ---------------------------------------------------------------------------
// Use [formatDisplayDate] / [formatDisplayTime] for UI; [formatApiDate] for
// request query/body (YYYY-MM-DD). [parseApiDate] for parsing API responses.
// ---------------------------------------------------------------------------

import 'package:intl/intl.dart';

/// App-wide date display: "12 Feb 2026" (day, short month, year).
const String kDateDisplayPattern = 'd MMM yyyy';

/// Format [date] for display. Use for all user-visible dates (attendance, payments, invoices, etc.).
String formatDisplayDate(DateTime? date) {
  if (date == null) return '—';
  return DateFormat(kDateDisplayPattern, 'en').format(date.toLocal());
}

/// Format date for API (YYYY-MM-DD).
String formatApiDate(DateTime date) {
  return DateFormat('yyyy-MM-dd').format(date.toLocal());
}

/// Format time for display (e.g. 02:30 PM).
String formatDisplayTime(DateTime? date) {
  if (date == null) return '—';
  return DateFormat('hh:mm a', 'en').format(date.toLocal());
}

/// Format date + time for display (e.g. 12 Feb 2026, 02:30 PM).
String formatDisplayDateTime(DateTime? date) {
  if (date == null) return '—';
  return '${formatDisplayDate(date)}, ${formatDisplayTime(date)}';
}

/// Display date with weekday (e.g. "Monday, 15 Feb 2026").
String formatDisplayDateWithWeekday(DateTime? date) {
  if (date == null) return '—';
  return DateFormat('EEEE, $kDateDisplayPattern', 'en').format(date.toLocal());
}

/// Parse API date string (YYYY-MM-DD or ISO) to DateTime. Returns null if invalid.
DateTime? parseApiDate(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    return DateTime.parse(value.length > 10 ? value.substring(0, 10) : value);
  } catch (_) {
    return null;
  }
}
