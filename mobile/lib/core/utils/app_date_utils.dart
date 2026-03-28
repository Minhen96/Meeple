import 'package:intl/intl.dart';

/// Date/time formatting helpers used across the app.
///
/// All methods are pure functions — no side effects, easy to test.
abstract final class AppDateUtils {
  static final _date = DateFormat('MMM d, y');
  static final _time = DateFormat('h:mm a');
  static final _dateTime = DateFormat("MMM d, y '·' h:mm a");
  static final _monthYear = DateFormat('MMMM y');
  static final _dayMonth = DateFormat('MMM d');

  /// "Mar 28, 2026"
  static String formatDate(DateTime date) => _date.format(date);

  /// "2:30 PM"
  static String formatTime(DateTime date) => _time.format(date);

  /// "Mar 28, 2026 · 2:30 PM"
  static String formatDateTime(DateTime date) => _dateTime.format(date);

  /// "March 2026"
  static String formatMonthYear(DateTime date) => _monthYear.format(date);

  /// "Mar 28"
  static String formatDayMonth(DateTime date) => _dayMonth.format(date);

  /// Relative human-readable time:
  /// "just now" / "2m ago" / "3h ago" / "yesterday" / "Mar 28"
  static String timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return _date.format(date);
  }

  /// Whether [a] and [b] fall on the same calendar day.
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Whether [date] is today.
  static bool isToday(DateTime date) => isSameDay(date, DateTime.now());

  /// Whether [date] is in the past.
  static bool isPast(DateTime date) => date.isBefore(DateTime.now());

  const AppDateUtils._();
}
