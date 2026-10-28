import '../common/units.dart';
import 'enums.dart';

/// The CGM metrics Sukkar Plus understands. Range bands follow the 2019
/// International Consensus on Time in Range, Table 2 (see SOURCE_MAPPING.md).
enum MetricKey {
  meanGlucose,
  gmi,
  cv,
  sd,

  /// < 54 mg/dL (< 3.0 mmol/L) — TBR level 2.
  timeVeryLow,

  /// 54–69 mg/dL (3.0–3.8 mmol/L) — TBR level 1.
  timeLow,

  /// 70–180 mg/dL (3.9–10.0 mmol/L).
  timeInRange,

  /// 181–250 mg/dL (10.1–13.9 mmol/L) — TAR level 1.
  timeHigh,

  /// > 250 mg/dL (> 13.9 mmol/L) — TAR level 2.
  timeVeryHigh,

  /// < 70 mg/dL total (level 1 + level 2).
  timeBelowRangeTotal,

  /// > 180 mg/dL total (level 1 + level 2).
  timeAboveRangeTotal,

  /// Percentage of time CGM was active / connected, as printed or computed.
  sensorActive,
}

const percentMetrics = {
  MetricKey.cv,
  MetricKey.timeVeryLow,
  MetricKey.timeLow,
  MetricKey.timeInRange,
  MetricKey.timeHigh,
  MetricKey.timeVeryHigh,
  MetricKey.timeBelowRangeTotal,
  MetricKey.timeAboveRangeTotal,
  MetricKey.sensorActive,
};

extension MetricKeyInfo on MetricKey {
  String get labelAr => switch (this) {
        MetricKey.meanGlucose => 'متوسط السكر',
        MetricKey.gmi => 'مؤشر إدارة الجلوكوز (GMI)',
        MetricKey.cv => 'تذبذب السكر (CV)',
        MetricKey.sd => 'الانحراف المعياري (SD)',
        MetricKey.timeVeryLow => 'منخفض جدًا (أقل من 54)',
        MetricKey.timeLow => 'منخفض (54–69)',
        MetricKey.timeInRange => 'الوقت ضمن النطاق (70–180)',
        MetricKey.timeHigh => 'مرتفع (181–250)',
        MetricKey.timeVeryHigh => 'مرتفع جدًا (أعلى من 250)',
        MetricKey.timeBelowRangeTotal => 'إجمالي الوقت تحت النطاق (أقل من 70)',
        MetricKey.timeAboveRangeTotal => 'إجمالي الوقت فوق النطاق (أعلى من 180)',
        MetricKey.sensorActive => 'نسبة عمل الحساس',
      };

  String get shortLabelAr => switch (this) {
        MetricKey.meanGlucose => 'المتوسط',
        MetricKey.gmi => 'GMI',
        MetricKey.cv => 'CV',
        MetricKey.sd => 'SD',
        MetricKey.timeVeryLow => '<54',
        MetricKey.timeLow => '54–69',
        MetricKey.timeInRange => 'TIR',
        MetricKey.timeHigh => '181–250',
        MetricKey.timeVeryHigh => '>250',
        MetricKey.timeBelowRangeTotal => 'TBR',
        MetricKey.timeAboveRangeTotal => 'TAR',
        MetricKey.sensorActive => 'الحساس',
      };

  /// Stable snake_case identifier used in JSON, SQL and the AI schema.
  String get wireName => switch (this) {
        MetricKey.meanGlucose => 'mean_glucose',
        MetricKey.gmi => 'gmi',
        MetricKey.cv => 'cv',
        MetricKey.sd => 'sd',
        MetricKey.timeVeryLow => 'time_very_low',
        MetricKey.timeLow => 'time_low',
        MetricKey.timeInRange => 'time_in_range',
        MetricKey.timeHigh => 'time_high',
        MetricKey.timeVeryHigh => 'time_very_high',
        MetricKey.timeBelowRangeTotal => 'time_below_range_total',
        MetricKey.timeAboveRangeTotal => 'time_above_range_total',
        MetricKey.sensorActive => 'sensor_active',
      };

  bool get isPercent => percentMetrics.contains(this);
}

MetricKey? metricKeyFromWire(String s) {
  for (final k in MetricKey.values) {
    if (k.wireName == s) return k;
  }
  return null;
}

/// A single metric value with full provenance.
class MetricValue {
  const MetricValue({
    required this.key,
    required this.value,
    required this.unit,
    required this.origin,
    required this.status,
    this.sourceLabel,
    this.sourcePage,
    this.originalExtractedValue,
    this.note,
  });

  final MetricKey key;

  /// null means unavailable. Missing values are never replaced with zero.
  final double? value;

  /// '%', 'mg/dL' or 'mmol/L'.
  final String unit;
  final ValueOrigin origin;
  final VerificationStatus status;
  final String? sourceLabel;
  final int? sourcePage;

  /// When the user corrected an extracted value, the extracted value is kept.
  final double? originalExtractedValue;
  final String? note;

  bool get isAvailable => value != null && status != VerificationStatus.unavailable && status != VerificationStatus.rejected;
  bool get isVerified => isAvailable && status == VerificationStatus.verified;

  MetricValue copyWith({double? value, VerificationStatus? status, ValueOrigin? origin, double? originalExtractedValue, String? note}) =>
      MetricValue(
        key: key,
        value: value ?? this.value,
        unit: unit,
        origin: origin ?? this.origin,
        status: status ?? this.status,
        sourceLabel: sourceLabel,
        sourcePage: sourcePage,
        originalExtractedValue: originalExtractedValue ?? this.originalExtractedValue,
        note: note ?? this.note,
      );

  Map<String, Object?> toJson() => {
        'key': key.wireName,
        'value': value,
        'unit': unit,
        'origin': origin.name,
        'status': status.name,
        'source_label': sourceLabel,
        'source_page': sourcePage,
        'original_extracted_value': originalExtractedValue,
        'note': note,
      };
}

class ReportPeriod {
  ReportPeriod(DateTime start, DateTime end)
      : start = dateOnly(start),
        end = dateOnly(end) {
    if (this.end.isBefore(this.start)) {
      throw ArgumentError('Period end precedes start');
    }
  }

  final DateTime start;
  final DateTime end;

  /// Inclusive calendar days.
  int get days => daysBetween(start, end) + 1;

  bool contains(DateTime d) {
    final x = dateOnly(d);
    return !x.isBefore(start) && !x.isAfter(end);
  }

  bool overlaps(ReportPeriod o) => !o.end.isBefore(start) && !o.start.isAfter(end);

  @override
  bool operator ==(Object other) => other is ReportPeriod && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '${isoDate(start)}..${isoDate(end)}';
}

class GlucoseReading {
  const GlucoseReading(this.timestamp, this.mgdl);
  final DateTime timestamp;
  final double mgdl;
}

/// Data sufficiency assessment. Thresholds (14 days, 70 %) come from the
/// consensus Table 2 recommendations.
class DataQuality {
  const DataQuality({
    required this.daysOfData,
    required this.coveragePercent,
    required this.coverageSource,
    required this.sufficient,
    this.reasonsAr = const [],
    this.duplicateReadings = 0,
    this.conflictingDuplicates = 0,
    this.invalidReadings = 0,
    this.gapCount = 0,
    this.longestGapMinutes = 0,
  });

  final int? daysOfData;
  final double? coveragePercent;

  /// Human-readable description of what the coverage number means.
  final String coverageSource;
  final bool sufficient;
  final List<String> reasonsAr;
  final int duplicateReadings;
  final int conflictingDuplicates;
  final int invalidReadings;
  final int gapCount;
  final int longestGapMinutes;

  static const minDays = 14;
  static const minCoveragePercent = 70.0;

  Map<String, Object?> toJson() => {
        'days_of_data': daysOfData,
        'coverage_percent': coveragePercent,
        'coverage_source': coverageSource,
        'sufficient': sufficient,
        'reasons': reasonsAr,
        'duplicate_readings': duplicateReadings,
        'conflicting_duplicates': conflictingDuplicates,
        'invalid_readings': invalidReadings,
        'gap_count': gapCount,
        'longest_gap_minutes': longestGapMinutes,
      };
}

enum ReportSourceType { pdfUpload, demoFixture, readingsImport }

extension ReportSourceTypeAr on ReportSourceType {
  String get labelAr => switch (this) {
        ReportSourceType.pdfUpload => 'تقرير PDF مرفوع',
        ReportSourceType.demoFixture => 'ملف تجريبي',
        ReportSourceType.readingsImport => 'قراءات مستوردة',
      };
}

/// An accepted CGM report (after the user reviewed extracted values).
class CgmReport {
  const CgmReport({
    required this.id,
    required this.userId,
    required this.provenance,
    required this.sourceType,
    required this.glucoseUnit,
    required this.metrics,
    required this.quality,
    required this.createdAt,
    this.reportPeriod,
    this.metricsPeriod,
    this.formatId,
    this.deviceLabel,
    this.readings,
    this.warningsAr = const [],
  });

  final String id;
  final String userId;
  final DataProvenance provenance;
  final ReportSourceType sourceType;
  final GlucoseUnit glucoseUnit;
  final Map<MetricKey, MetricValue> metrics;
  final DataQuality quality;
  final DateTime createdAt;

  /// The period printed on the report header.
  final ReportPeriod? reportPeriod;

  /// The window the metrics actually describe (e.g. "sensor data is only
  /// available from ..."). Falls back to [reportPeriod].
  final ReportPeriod? metricsPeriod;
  final String? formatId;
  final String? deviceLabel;

  /// Raw readings exist only for synthetic demo data or imported datasets.
  /// Uploaded PDFs contain printed summaries only; no time series is invented.
  final List<GlucoseReading>? readings;
  final List<String> warningsAr;

  ReportPeriod? get effectivePeriod => metricsPeriod ?? reportPeriod;

  MetricValue? metric(MetricKey k) => metrics[k];

  double? verifiedValue(MetricKey k) {
    final m = metrics[k];
    return (m != null && m.isVerified) ? m.value : null;
  }

  bool get hasRawReadings => readings != null && readings!.isNotEmpty;
}
