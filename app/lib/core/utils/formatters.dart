import 'package:intl/intl.dart';

class Formatters {
  const Formatters._();

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

  static String chatTime(DateTime d, {DateTime? now}) {
    final today = now ?? DateTime.now();
    if (d.year == today.year && d.month == today.month && d.day == today.day) {
      return DateFormat.jm().format(d);
    }
    return DateFormat('d MMM').format(d);
  }
}
