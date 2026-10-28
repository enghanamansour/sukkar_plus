import '../common/units.dart';
import '../labs/hba1c.dart';
import '../models/cgm.dart';
import '../models/lab.dart';

enum ChangeDirection { increase, decrease, noChange }

extension ChangeDirectionAr on ChangeDirection {
  /// Neutral wording: we describe direction, never "better" or "worse".
  String get labelAr => switch (this) {
        ChangeDirection.increase => 'ارتفاع',
        ChangeDirection.decrease => 'انخفاض',
        ChangeDirection.noChange => 'دون تغيّر',
      };
}

class TrendPoint {
  const TrendPoint({required this.date, required this.value, required this.unit, required this.sourceId, this.converted = false});
  final DateTime date;
  final double value;
  final String unit;
  final String sourceId;
  final bool converted;
}

class TrendChange {
  const TrendChange({
    required this.previous,
    required this.current,
    required this.delta,
    required this.direction,
    required this.daysBetween,
    this.notesAr = const [],
  });
  final TrendPoint previous;
  final TrendPoint current;
  final double delta;
  final ChangeDirection direction;
  final int daysBetween;
  final List<String> notesAr;
}

class TrendSeries {
  const TrendSeries({required this.points, required this.change, required this.missingAr});
  final List<TrendPoint> points;

  /// Latest vs previous point; null when fewer than two comparable points.
  final TrendChange? change;
  final List<String> missingAr;

  bool get hasComparison => change != null;
}

ChangeDirection _direction(double delta) => delta == 0 ? ChangeDirection.noChange : (delta > 0 ? ChangeDirection.increase : ChangeDirection.decrease);

const causationNoteAr = 'التغيّر عبر الزمن لا يدل وحده على سبب محدد.';

/// HbA1c trend in %, using only verified, dated results.
TrendSeries hba1cTrend(List<LabResult> labs) {
  final all = labs.where((l) => l.testCode == LabTestCode.hba1c).toList();
  final usable = comparableHbA1c(all);
  final missing = <String>[];
  final undated = all.where((l) => l.collectionDate == null).length;
  final unverified = all.where((l) => !l.isVerified).length;
  if (undated > 0) missing.add('$undated نتيجة بلا تاريخ سحب لم تُدرج في الاتجاه.');
  if (unverified > 0) missing.add('$unverified نتيجة غير مؤكدة لم تُدرج في الاتجاه.');
  final points = [
    for (final l in usable)
      TrendPoint(
        date: l.collectionDate!,
        value: HbA1c.toPercent(l.value, parseHbA1cUnit(l.unit)!),
        unit: '%',
        sourceId: l.id,
        converted: parseHbA1cUnit(l.unit) == HbA1cUnit.mmolMol,
      ),
  ];
  if (points.length < 2) {
    missing.add('نحتاج نتيجتين مؤرختين ومؤكدتين على الأقل لعرض التغيّر.');
    return TrendSeries(points: points, change: null, missingAr: missing);
  }
  final prev = points[points.length - 2], cur = points.last;
  final delta = cur.value - prev.value;
  return TrendSeries(
    points: points,
    change: TrendChange(
      previous: prev,
      current: cur,
      delta: delta,
      direction: _direction(roundTo(delta, 1)),
      daysBetween: daysBetween(prev.date, cur.date),
      notesAr: [if (prev.converted || cur.converted) 'بعض القيم حُوّلت من mmol/mol.', causationNoteAr],
    ),
    missingAr: missing,
  );
}

/// Generic trend for another lab test: only same-unit, verified, dated results.
TrendSeries labTrend(List<LabResult> labs, {required LabTestCode code, String? testName}) {
  final relevant = labs.where((l) => l.testCode == code && (code != LabTestCode.other || l.testName == testName)).toList();
  final usable = relevant.where((l) => l.isVerified && l.collectionDate != null).toList()
    ..sort((a, b) => a.collectionDate!.compareTo(b.collectionDate!));
  final missing = <String>[];
  if (usable.length < relevant.length) missing.add('${relevant.length - usable.length} نتيجة غير مؤرخة أو غير مؤكدة لم تُدرج.');
  final units = usable.map((l) => l.unit.trim()).toSet();
  if (units.length > 1) {
    missing.add('النتائج مسجلة بوحدات مختلفة (${units.join('، ')})؛ لا تُجرى مقارنة رقمية دون تحويل معتمد.');
    return TrendSeries(points: const [], change: null, missingAr: missing);
  }
  final points = [for (final l in usable) TrendPoint(date: l.collectionDate!, value: l.value, unit: l.unit, sourceId: l.id)];
  if (points.length < 2) {
    missing.add('نحتاج نتيجتين مؤرختين ومؤكدتين على الأقل لعرض التغيّر.');
    return TrendSeries(points: points, change: null, missingAr: missing);
  }
  final prev = points[points.length - 2], cur = points.last;
  final delta = cur.value - prev.value;
  return TrendSeries(
    points: points,
    change: TrendChange(
      previous: prev,
      current: cur,
      delta: delta,
      direction: _direction(delta),
      daysBetween: daysBetween(prev.date, cur.date),
      notesAr: const [causationNoteAr],
    ),
    missingAr: missing,
  );
}

class CgmPeriodComparison {
  const CgmPeriodComparison({
    required this.previous,
    required this.current,
    required this.changes,
    required this.notesAr,
    required this.comparable,
    this.gapDaysBetweenPeriods,
  });
  final CgmReport previous;
  final CgmReport current;

  /// Metric → change (only metrics verified in both reports).
  final Map<MetricKey, TrendChange> changes;
  final List<String> notesAr;
  final bool comparable;

  /// Days with no report coverage between the two periods (missing period).
  final int? gapDaysBetweenPeriods;
}

/// Compares the two most recent reports with known periods.
/// Overlapping periods are not compared. Large differences in length or data
/// sufficiency are reported as caveats.
CgmPeriodComparison? compareLatestCgmPeriods(List<CgmReport> reports) {
  final dated = reports.where((r) => r.effectivePeriod != null).toList()
    ..sort((a, b) => a.effectivePeriod!.end.compareTo(b.effectivePeriod!.end));
  if (dated.length < 2) return null;
  final prev = dated[dated.length - 2], cur = dated.last;
  final pp = prev.effectivePeriod!, cp = cur.effectivePeriod!;
  final notes = <String>[];
  var comparable = true;
  if (pp.overlaps(cp)) {
    comparable = false;
    notes.add('الفترتان متداخلتان، لذلك لا تُعرض الفروق.');
  }
  if (!prev.quality.sufficient || !cur.quality.sufficient) {
    notes.add('إحدى الفترتين لا تستوفي الحد العام لكفاية البيانات (14 يومًا و70% تغطية)؛ فسّر الفروق بحذر.');
  }
  final ratio = pp.days > cp.days ? pp.days / cp.days : cp.days / pp.days;
  if (ratio > 2) notes.add('طول الفترتين مختلف كثيرًا (${pp.days} مقابل ${cp.days} يومًا).');
  final gap = daysBetween(pp.end, cp.start) - 1;
  if (gap > 0) notes.add('لا توجد بيانات حساس مسجلة في التطبيق لمدة $gap يومًا بين الفترتين.');
  notes.add(causationNoteAr);

  final changes = <MetricKey, TrendChange>{};
  if (comparable) {
    for (final k in MetricKey.values) {
      final a = prev.verifiedValue(k), b = cur.verifiedValue(k);
      if (a == null || b == null) continue;
      final delta = b - a;
      changes[k] = TrendChange(
        previous: TrendPoint(date: pp.end, value: a, unit: prev.metrics[k]!.unit, sourceId: prev.id),
        current: TrendPoint(date: cp.end, value: b, unit: cur.metrics[k]!.unit, sourceId: cur.id),
        delta: delta,
        direction: _direction(roundTo(delta, 1)),
        daysBetween: daysBetween(pp.end, cp.end),
      );
    }
  }
  return CgmPeriodComparison(
    previous: prev,
    current: cur,
    changes: changes,
    notesAr: notes,
    comparable: comparable,
    gapDaysBetweenPeriods: gap > 0 ? gap : null,
  );
}
