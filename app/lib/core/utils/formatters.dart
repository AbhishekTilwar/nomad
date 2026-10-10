import 'package:intl/intl.dart';

class Formatters {
  const Formatters._();

  /// Absolute date used on detail/preview cards: "Sat, 11 May · 10:00 AM".
  static String activityDate(DateTime d) =>
      '${DateFormat('EEE, d MMM').format(d)} · ${DateFormat.jm().format(d)}';

  /// "Sat, 11 May · 10:00 AM - 1:00 PM".
  static String activityRange(DateTime start, DateTime end) =>
      '${DateFormat('EEE, d MMM').format(start)} · ${DateFormat.jm().format(start)} - ${DateFormat.jm().format(end)}';

  static String activityWhen(DateTime d, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final day = DateTime(d.year, d.month, d.day);
    final t0 = DateTime(today.year, today.month, today.day);
    final diff = day.difference(t0).inDays;
    final time = DateFormat.jm().format(d);
    if (diff == 0) return 'Today, $time';
    if (diff == 1) return 'Tomorrow, $time';
    if (diff > 1 && diff < 7) return '${DateFormat.EEEE().format(d)}, $time';
    return '${DateFormat('d MMM').format(d)}, $time';
  }

  static String distance(double? km) {
    if (km == null) return '';
    if (km < 1) return '${(km * 1000).round()} m away';
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km away';
  }

  /// "just now", "9 minutes ago", "3 hours ago", "2 days ago", else a date.
  static String timeAgo(DateTime d, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m minute${m == 1 ? '' : 's'} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h hour${h == 1 ? '' : 's'} ago';
    }
    if (diff.inDays < 7) {
      final n = diff.inDays;
      return '$n day${n == 1 ? '' : 's'} ago';
    }
    return DateFormat('d MMM').format(d);
  }

  static String chatTime(DateTime d, {DateTime? now}) {
    final today = now ?? DateTime.now();
    if (d.year == today.year && d.month == today.month && d.day == today.day) {
      return DateFormat.jm().format(d);
    }
    return DateFormat('d MMM').format(d);
  }
}
