import '../common/units.dart';
import '../models/cgm.dart';
import '../models/enums.dart';
import 'gmi.dart';

/// Result of a deterministic cross-check between printed summary metrics.
class ConsistencyCheck {
  const ConsistencyCheck({required this.id, required this.passed, required this.messageAr, required this.involved});
  final String id;

  /// null = could not be evaluated (a value was missing).
  final bool? passed;
  final String messageAr;
  final Set<MetricKey> involved;
}

/// Tolerances for printed (rounded) values. Each band may be printed as an
/// integer ("2%") or with one decimal, so sums can drift.
class SummaryTolerances {
  static const bandSum = 2.0;
  static const totalVsBands = 1.0;
  static const cvVsSdMean = 1.0;
}

/// Deterministic checks on a set of summary values (mg/dL basis).
/// The AI is never asked to judge numeric consistency.
List<ConsistencyCheck> runSummaryChecks(Map<MetricKey, double?> v) {
  final checks = <ConsistencyCheck>[];
  double? g(MetricKey k) => v[k];

  final bands = [MetricKey.timeVeryLow, MetricKey.timeLow, MetricKey.timeInRange, MetricKey.timeHigh, MetricKey.timeVeryHigh];
  if (bands.every((k) => g(k) != null)) {
    final s = bands.fold<double>(0, (a, k) => a + g(k)!);
    final ok = (s - 100).abs() <= SummaryTolerances.bandSum;
    checks.add(ConsistencyCheck(
      id: 'band_sum',
      passed: ok,
      messageAr: ok ? 'مجموع نطاقات السكر الخمسة ${formatNumber(s)}% (متسق).' : 'مجموع نطاقات السكر الخمسة ${formatNumber(s)}% ولا يقارب 100%.',
      involved: bands.toSet(),
    ));
  } else {
    checks.add(ConsistencyCheck(id: 'band_sum', passed: null, messageAr: 'تعذّر التحقق من مجموع النطاقات لنقص بعض القيم.', involved: bands.toSet()));
  }

  void totalCheck(String id, MetricKey total, MetricKey a, MetricKey b, String nameAr) {
    if (g(total) == null || g(a) == null || g(b) == null) return;
    final s = g(a)! + g(b)!;
    final ok = (g(total)! - s).abs() <= SummaryTolerances.totalVsBands;
    checks.add(ConsistencyCheck(
      id: id,
      passed: ok,
      messageAr: ok
          ? '$nameAr ${formatNumber(g(total)!)}% يطابق مجموع فئتيه (${formatNumber(s)}%).'
          : '$nameAr ${formatNumber(g(total)!)}% لا يطابق مجموع فئتيه (${formatNumber(s)}%).',
      involved: {total, a, b},
    ));
  }

  totalCheck('tbr_total', MetricKey.timeBelowRangeTotal, MetricKey.timeVeryLow, MetricKey.timeLow, 'إجمالي الوقت تحت النطاق');
  totalCheck('tar_total', MetricKey.timeAboveRangeTotal, MetricKey.timeHigh, MetricKey.timeVeryHigh, 'إجمالي الوقت فوق النطاق');

  if (g(MetricKey.timeBelowRangeTotal) != null && g(MetricKey.timeInRange) != null && g(MetricKey.timeAboveRangeTotal) != null) {
    final s = g(MetricKey.timeBelowRangeTotal)! + g(MetricKey.timeInRange)! + g(MetricKey.timeAboveRangeTotal)!;
    final ok = (s - 100).abs() <= SummaryTolerances.bandSum;
    checks.add(ConsistencyCheck(
      id: 'triple_sum',
      passed: ok,
      messageAr: ok ? 'تحت النطاق + ضمنه + فوقه = ${formatNumber(s)}% (متسق).' : 'تحت النطاق + ضمنه + فوقه = ${formatNumber(s)}% ولا يقارب 100%.',
      involved: {MetricKey.timeBelowRangeTotal, MetricKey.timeInRange, MetricKey.timeAboveRangeTotal},
    ));
  }

  if (g(MetricKey.gmi) != null && g(MetricKey.meanGlucose) != null) {
    final expected = Gmi.percentFromMeanMgdl(g(MetricKey.meanGlucose)!);
    final ok = Gmi.isConsistent(reportedGmiPercent: g(MetricKey.gmi)!, meanMgdl: g(MetricKey.meanGlucose)!);
    checks.add(ConsistencyCheck(
      id: 'gmi_mean',
      passed: ok,
      messageAr: ok
          ? 'قيمة GMI تتسق مع متوسط السكر (المحسوب ${formatNumber(expected, decimals: 2)}%).'
          : 'قيمة GMI المطبوعة لا تتسق مع متوسط السكر (المتوقع ${formatNumber(expected, decimals: 2)}%).',
      involved: {MetricKey.gmi, MetricKey.meanGlucose},
    ));
  }

  if (g(MetricKey.cv) != null && g(MetricKey.sd) != null && g(MetricKey.meanGlucose) != null && g(MetricKey.meanGlucose)! > 0) {
    final expected = g(MetricKey.sd)! / g(MetricKey.meanGlucose)! * 100;
    final ok = (g(MetricKey.cv)! - expected).abs() <= SummaryTolerances.cvVsSdMean;
    checks.add(ConsistencyCheck(
      id: 'cv_sd_mean',
      passed: ok,
      messageAr: ok
          ? 'قيمة CV تتسق مع SD ÷ المتوسط (${formatNumber(expected)}%).'
          : 'قيمة CV لا تتسق مع SD ÷ المتوسط (${formatNumber(expected)}%).',
      involved: {MetricKey.cv, MetricKey.sd, MetricKey.meanGlucose},
    ));
  }
  return checks;
}

/// Adds metrics that can be derived deterministically from verified ones,
/// without overwriting anything already present.
Map<MetricKey, MetricValue> withDerivedMetrics(Map<MetricKey, MetricValue> metrics) {
  final out = Map<MetricKey, MetricValue>.of(metrics);
  double? vv(MetricKey k) => (out[k]?.isVerified ?? false) ? out[k]!.value : null;
  bool missing(MetricKey k) => out[k] == null || !out[k]!.isAvailable;

  void derive(MetricKey target, double? value, String unit, String noteAr) {
    if (value == null || !missing(target)) return;
    out[target] = MetricValue(
      key: target,
      value: value,
      unit: unit,
      origin: ValueOrigin.calculatedFromMetrics,
      status: VerificationStatus.verified,
      note: noteAr,
    );
  }

  final vl = vv(MetricKey.timeVeryLow), l = vv(MetricKey.timeLow);
  derive(MetricKey.timeBelowRangeTotal, (vl != null && l != null) ? vl + l : null, '%', 'مجموع فئتي أقل من 54 و54–69');
  final h = vv(MetricKey.timeHigh), vh = vv(MetricKey.timeVeryHigh);
  derive(MetricKey.timeAboveRangeTotal, (h != null && vh != null) ? h + vh : null, '%', 'مجموع فئتي 181–250 وأعلى من 250');
  final mean = vv(MetricKey.meanGlucose);
  derive(MetricKey.gmi, mean != null ? Gmi.percentFromMeanMgdl(mean) : null, '%', 'محسوب من متوسط السكر بمعادلة GMI');
  return out;
}

/// Data quality for a printed summary report (no raw readings).
DataQuality qualityFromSummary({
  required ReportPeriod? metricsPeriod,
  required double? printedSensorPercent,
  required String sensorLabel,
  bool limitedDataNotice = false,
}) {
  final reasons = <String>[];
  final days = metricsPeriod?.days;
  if (days == null) {
    reasons.add('لم تُحدَّد فترة البيانات في التقرير.');
  } else if (days < DataQuality.minDays) {
    reasons.add('مدة البيانات $days يومًا، والتوصية العامة 14 يومًا على الأقل.');
  }
  if (printedSensorPercent == null) {
    reasons.add('لم يُذكر في التقرير ما يكفي لتقييم تغطية بيانات الحساس.');
  } else if (printedSensorPercent < DataQuality.minCoveragePercent) {
    reasons.add('$sensorLabel ${formatNumber(printedSensorPercent)}% كما طُبعت، والتوصية العامة 70% على الأقل.');
  }
  if (limitedDataNotice) {
    reasons.add('يذكر التقرير أن بعض الأيام بياناتها محدودة أو غير موجودة.');
  }
  final sufficient = days != null &&
      days >= DataQuality.minDays &&
      printedSensorPercent != null &&
      printedSensorPercent >= DataQuality.minCoveragePercent;
  return DataQuality(
    daysOfData: days,
    coveragePercent: printedSensorPercent,
    coverageSource: '$sensorLabel كما طُبعت في التقرير (لا يوضح التقرير مقام النسبة)',
    sufficient: sufficient,
    reasonsAr: reasons,
  );
}
