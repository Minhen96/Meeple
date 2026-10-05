import 'package:intl/intl.dart';
import 'package:meeple_hearth/l10n/gen/app_localizations.dart';

/// Date/time formatting helpers.
///
/// Formats use the current `Intl.defaultLocale` (kept in sync with the app
/// locale by `MeepleApp`), so dates follow the selected language. Times are
/// always shown in the device's local time zone (stored as UTC).
abstract final class AppDateUtils {
  /// "Mar 28, 2026"
  static String formatDate(DateTime date) =>
      DateFormat.yMMMd().format(date.toLocal());

  /// "2:30 PM"
  static String formatTime(DateTime date) =>
      DateFormat.jm().format(date.toLocal());

  /// "Sat, Mar 28 · 2:30 PM"
  static String formatDateTime(DateTime date) =>
      '${DateFormat.MMMEd().format(date.toLocal())} · ${formatTime(date)}';

  /// "Saturday, March 28, 2026"
  static String formatFullDate(DateTime date) =>
      DateFormat.yMMMMEEEEd().format(date.toLocal());

  /// "March 2026"
  static String formatMonthYear(DateTime date) =>
      DateFormat.yMMMM().format(date.toLocal());

  /// "Mar 28"
  static String formatDayMonth(DateTime date) =>
      DateFormat.MMMd().format(date.toLocal());

  /// "MAR" — short month for date badges.
  static String formatMonthShort(DateTime date) =>
      DateFormat.MMM().format(date.toLocal()).toUpperCase();

  /// "HH:mm" (24h) — the wire format of quiet hours.
  static String formatHhMm(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Relative time: "just now" / "2m ago" / "3h ago" / "yesterday" /
  /// "4d ago" / "Mar 28".
  static String timeAgo(DateTime date, AppLocalizations l10n, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(date);
    if (diff.inSeconds < 60) return l10n.timeJustNow;
    if (diff.inMinutes < 60) return l10n.timeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.timeHoursAgo(diff.inHours);
    if (diff.inDays == 1) return l10n.timeYesterday;
    if (diff.inDays < 7) return l10n.timeDaysAgo(diff.inDays);
    return formatDate(date);
  }

  /// Whether [a] and [b] fall on the same local calendar day.
  static bool isSameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  static bool isToday(DateTime date, {DateTime? now}) =>
      isSameDay(date, now ?? DateTime.now());

  static bool isPast(DateTime date) => date.isBefore(DateTime.now());

  const AppDateUtils._();
}
