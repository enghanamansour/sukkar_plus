import 'package:sukkar_core/sukkar_core.dart';

/// Arabic date and number formatting without locale-data initialisation.
/// Gregorian month names as used in Saudi Arabia; Western digits for clarity
/// of clinical values.
abstract final class ArFormat {
  static const months = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];
  static const weekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

  static String date(DateTime d) => arDate(d);
  static String shortDate(DateTime d) => '${d.day} ${months[d.month - 1]}';
  static String weekdayDate(DateTime d) => '${weekdays[d.weekday - 1]}، ${date(d)}';

  static String time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? 'ص' : 'م'}';
  }

  static String dateTime(DateTime d) => '${date(d)} — ${time(d)}';

  static String period(ReportPeriod p) => arPeriod(p.start, p.end);

  /// Arabic counting form for days.
  static String days(int n) {
    final a = n.abs();
    if (a == 0) return 'صفر يوم';
    if (a == 1) return 'يوم واحد';
    if (a == 2) return 'يومان';
    if (a <= 10) return '$a أيام';
    return '$a يومًا';
  }

  static String relativeDay(DateTime now, DateTime d) {
    final n = daysBetween(now, d);
    if (n == 0) return 'اليوم';
    if (n == 1) return 'غدًا';
    if (n == -1) return 'أمس';
    return n > 0 ? 'بعد ${days(n)}' : 'قبل ${days(n)}';
  }

  static String number(double v, {int decimals = 1}) => formatNumber(v, decimals: decimals);

  static String metric(MetricValue? m, {int decimals = 1}) {
    if (m == null || !m.isAvailable || m.value == null) return 'غير متاح';
    return m.unit == '%' ? '${formatNumber(m.value!, decimals: decimals)}%' : '${formatNumber(m.value!, decimals: decimals)} ${m.unit}';
  }

  /// "من 172 إلى 153 (−19)" — readable in RTL without arrows.
  static String change(double from, double to, {int decimals = 1, String unit = ''}) =>
      'من ${formatNumber(from, decimals: decimals)}$unit إلى ${formatNumber(to, decimals: decimals)}$unit (${signed(to - from, decimals: decimals)})';

  static String signed(double v, {int decimals = 1, String unit = ''}) {
    final s = formatNumber(v.abs(), decimals: decimals);
    if (roundTo(v, decimals) == 0) return '0$unit';
    return v > 0 ? '+$s$unit' : '−$s$unit';
  }
}
