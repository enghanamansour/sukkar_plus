/// Glucose units and deterministic conversions.
///
/// Conversion factor: 1 mmol/L glucose = 18.0182 mg/dL (molar mass of glucose
/// 180.16 g/mol / 10). See docs/METRICS.md.
library;

enum GlucoseUnit { mgdl, mmoll }

const double mgdlPerMmoll = 18.0182;

extension GlucoseUnitLabel on GlucoseUnit {
  String get label => this == GlucoseUnit.mgdl ? 'mg/dL' : 'mmol/L';
}

GlucoseUnit? parseGlucoseUnit(String raw) {
  final s = raw.toLowerCase().replaceAll(' ', '');
  if (s.contains('mg/dl')) return GlucoseUnit.mgdl;
  if (s.contains('mmol/l')) return GlucoseUnit.mmoll;
  return null;
}

double toMgdl(double value, GlucoseUnit unit) =>
    unit == GlucoseUnit.mgdl ? value : value * mgdlPerMmoll;

double toMmoll(double value, GlucoseUnit unit) =>
    unit == GlucoseUnit.mmoll ? value : value / mgdlPerMmoll;

/// Rounds half away from zero to [decimals] places (display helper only;
/// calculations keep full precision).
double roundTo(double value, int decimals) {
  var f = 1.0;
  for (var i = 0; i < decimals; i++) {
    f *= 10;
  }
  final scaled = value * f;
  final r = scaled >= 0 ? (scaled + 0.5).floorToDouble() : (scaled - 0.5).ceilToDouble();
  return r / f;
}

/// Formats a number with up to [decimals] decimals and no trailing zeros.
String formatNumber(double value, {int decimals = 1}) {
  final r = roundTo(value, decimals);
  if (r == r.truncateToDouble()) return r.toInt().toString();
  var s = r.toStringAsFixed(decimals);
  while (s.contains('.') && s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// Calendar-day difference (b - a) ignoring time of day.
int daysBetween(DateTime a, DateTime b) {
  final da = DateTime.utc(a.year, a.month, a.day);
  final db = DateTime.utc(b.year, b.month, b.day);
  return db.difference(da).inDays;
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

const arMonths = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

/// Human-facing Arabic date, e.g. "13 سبتمبر 2026". Used instead of ISO
/// dates in any text shown to people, because ISO dates are reordered by the
/// bidirectional algorithm inside Arabic sentences.
String arDate(DateTime d) => '${d.day} ${arMonths[d.month - 1]} ${d.year}';

/// "16 يوليو إلى 29 يوليو 2026" — words between dates avoid bidi reordering.
String arPeriod(DateTime start, DateTime end) {
  if (start.year == end.year) return '${start.day} ${arMonths[start.month - 1]} إلى ${arDate(end)}';
  return '${arDate(start)} إلى ${arDate(end)}';
}

/// ISO yyyy-MM-dd (used in payloads and PDF output; UI uses Arabic labels).
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
