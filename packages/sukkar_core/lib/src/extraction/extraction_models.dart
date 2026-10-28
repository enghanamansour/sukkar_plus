import '../cgm/summary_checks.dart';
import '../common/units.dart';
import '../models/cgm.dart';
import '../models/enums.dart';

enum ExtractionStatus { found, notFound, ambiguous }

enum FieldValidation { valid, outOfRange, inconsistent, notCrossChecked }

enum ExtractionMethod { localText, ai, localAndAiAgree, localAndAiDisagree }

extension ExtractionStatusAr on ExtractionStatus {
  String get labelAr => switch (this) {
        ExtractionStatus.found => 'تم العثور عليه',
        ExtractionStatus.notFound => 'غير موجود في التقرير',
        ExtractionStatus.ambiguous => 'غير واضح',
      };
}

extension FieldValidationAr on FieldValidation {
  String get labelAr => switch (this) {
        FieldValidation.valid => 'اجتاز التحقق',
        FieldValidation.outOfRange => 'خارج النطاق المعقول',
        FieldValidation.inconsistent => 'غير متسق مع قيم أخرى',
        FieldValidation.notCrossChecked => 'لم يُتحقق منه آليًا',
      };
}

extension ExtractionMethodAr on ExtractionMethod {
  String get labelAr => switch (this) {
        ExtractionMethod.localText => 'قراءة نص الملف محليًا',
        ExtractionMethod.ai => 'استخراج بالذكاء الاصطناعي فقط',
        ExtractionMethod.localAndAiAgree => 'تطابق القراءة المحلية والذكاء الاصطناعي',
        ExtractionMethod.localAndAiDisagree => 'اختلاف بين القراءة المحلية والذكاء الاصطناعي',
      };
}

class ExtractedField {
  const ExtractedField({
    required this.key,
    required this.extractedValue,
    required this.unit,
    required this.extractionStatus,
    required this.validation,
    required this.method,
    this.sourcePage,
    this.sourceLabel,
    this.messagesAr = const [],
    this.aiValue,
    this.correctedValue,
    this.markedUnavailable = false,
    this.confirmed = false,
  });

  factory ExtractedField.notFound(MetricKey key, String unit) => ExtractedField(
        key: key,
        extractedValue: null,
        unit: unit,
        extractionStatus: ExtractionStatus.notFound,
        validation: FieldValidation.notCrossChecked,
        method: ExtractionMethod.localText,
      );

  final MetricKey key;
  final double? extractedValue;
  final String unit;
  final ExtractionStatus extractionStatus;
  final FieldValidation validation;
  final ExtractionMethod method;
  final int? sourcePage;

  /// The printed label the value was found next to (never personal data).
  final String? sourceLabel;
  final List<String> messagesAr;
  final double? aiValue;
  final double? correctedValue;
  final bool markedUnavailable;
  final bool confirmed;

  double? get effectiveValue => markedUnavailable ? null : (correctedValue ?? extractedValue);
  bool get isCorrected => correctedValue != null && correctedValue != extractedValue;

  VerificationStatus get verification {
    if (markedUnavailable) return VerificationStatus.unavailable;
    if (effectiveValue == null) return VerificationStatus.unavailable;
    return confirmed ? VerificationStatus.verified : VerificationStatus.needsReview;
  }

  /// A field the user still has to act on before the report can be accepted.
  bool get isPending => verification == VerificationStatus.needsReview;

  /// Eligible for the "confirm all values that passed checks" shortcut.
  bool get eligibleForBulkConfirm =>
      extractionStatus == ExtractionStatus.found &&
      validation == FieldValidation.valid &&
      (method == ExtractionMethod.localText || method == ExtractionMethod.localAndAiAgree);

  ExtractedField copyWith({
    double? correctedValue,
    bool clearCorrection = false,
    bool? markedUnavailable,
    bool? confirmed,
    FieldValidation? validation,
    List<String>? messagesAr,
  }) =>
      ExtractedField(
        key: key,
        extractedValue: extractedValue,
        unit: unit,
        extractionStatus: extractionStatus,
        validation: validation ?? this.validation,
        method: method,
        sourcePage: sourcePage,
        sourceLabel: sourceLabel,
        messagesAr: messagesAr ?? this.messagesAr,
        aiValue: aiValue,
        correctedValue: clearCorrection ? null : (correctedValue ?? this.correctedValue),
        markedUnavailable: markedUnavailable ?? this.markedUnavailable,
        confirmed: confirmed ?? this.confirmed,
      );
}

class ExtractedPeriod {
  const ExtractedPeriod({this.period, required this.status, this.sourceLabel, this.noteAr, this.page});
  final ReportPeriod? period;
  final ExtractionStatus status;
  final String? sourceLabel;
  final String? noteAr;
  final int? page;

  static const notFound = ExtractedPeriod(status: ExtractionStatus.notFound);
}

class ExtractionResult {
  const ExtractionResult({
    required this.formatId,
    required this.formatVerified,
    required this.glucoseUnit,
    required this.reportPeriod,
    required this.metricsPeriod,
    required this.fields,
    required this.checks,
    required this.warningsAr,
    required this.sensorLabel,
    required this.limitedDataNotice,
    this.deviceLabel,
    this.reportDaysLabel,
    this.aiUsed = false,
  });

  /// e.g. 'omnipod_discover_agp_summary_v1' or 'generic_agp_unverified'.
  final String formatId;

  /// True only for layouts checked against a real supplied report.
  final bool formatVerified;
  final GlucoseUnit glucoseUnit;
  final ExtractedPeriod reportPeriod;
  final ExtractedPeriod metricsPeriod;
  final Map<MetricKey, ExtractedField> fields;
  final List<ConsistencyCheck> checks;
  final List<String> warningsAr;
  final String sensorLabel;
  final bool limitedDataNotice;
  final String? deviceLabel;
  final int? reportDaysLabel;
  final bool aiUsed;

  int get foundCount => fields.values.where((f) => f.extractionStatus != ExtractionStatus.notFound).length;
  bool get hasPending => fields.values.any((f) => f.isPending);
  bool get isEmpty => foundCount == 0;

  ExtractionResult copyWith({Map<MetricKey, ExtractedField>? fields, List<ConsistencyCheck>? checks, bool? aiUsed, List<String>? warningsAr}) =>
      ExtractionResult(
        formatId: formatId,
        formatVerified: formatVerified,
        glucoseUnit: glucoseUnit,
        reportPeriod: reportPeriod,
        metricsPeriod: metricsPeriod,
        fields: fields ?? this.fields,
        checks: checks ?? this.checks,
        warningsAr: warningsAr ?? this.warningsAr,
        sensorLabel: sensorLabel,
        limitedDataNotice: limitedDataNotice,
        deviceLabel: deviceLabel,
        reportDaysLabel: reportDaysLabel,
        aiUsed: aiUsed ?? this.aiUsed,
      );
}

/// Plausible ranges used to reject misreads. These are sanity bounds for
/// parsing, not clinical thresholds.
(double, double) plausibleRange(MetricKey key, GlucoseUnit unit) {
  switch (key) {
    case MetricKey.meanGlucose:
      return unit == GlucoseUnit.mgdl ? (40, 400) : (2.2, 22.2);
    case MetricKey.sd:
      return unit == GlucoseUnit.mgdl ? (0, 200) : (0, 11.1);
    case MetricKey.gmi:
      return (4, 14);
    default:
      return (0, 100);
  }
}

bool isPlausible(MetricKey key, double v, GlucoseUnit unit) {
  final (lo, hi) = plausibleRange(key, unit);
  return v.isFinite && v >= lo && v <= hi;
}
