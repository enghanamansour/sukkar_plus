import '../cgm/summary_checks.dart';
import '../common/units.dart';
import '../models/cgm.dart';
import '../models/enums.dart';
import 'extraction_models.dart';
import 'report_parser.dart';

/// A validated AI extraction (Gemini via the backend). Numeric values from the
/// model are never trusted until they pass [AiExtractionValidator] and are
/// reconciled with local extraction and confirmed by the user.
class AiExtraction {
  const AiExtraction({required this.values, required this.rejectedAr, required this.provider});
  final Map<MetricKey, (double, String?)> values; // value, printed label
  final List<String> rejectedAr;
  final String provider;
}

class AiExtractionValidator {
  const AiExtractionValidator();

  /// Validates the JSON object returned by the `extract-report` function.
  /// Anything malformed is dropped with an explanation; nothing is coerced.
  AiExtraction validate(Object? json, {GlucoseUnit fallbackUnit = GlucoseUnit.mgdl}) {
    final rejected = <String>[];
    final values = <MetricKey, (double, String?)>{};
    if (json is! Map) {
      return const AiExtraction(values: {}, rejectedAr: ['استجابة الذكاء الاصطناعي ليست بالبنية المتوقعة.'], provider: 'unknown');
    }
    final provider = json['provider'] is String ? json['provider'] as String : 'unknown';
    final unitRaw = json['glucose_unit'];
    final unit = unitRaw is String ? (parseGlucoseUnit(unitRaw) ?? fallbackUnit) : fallbackUnit;
    final fields = json['fields'];
    if (fields is! List) {
      return AiExtraction(values: const {}, rejectedAr: const ['لا تحتوي الاستجابة على قائمة الحقول.'], provider: provider);
    }
    final seen = <MetricKey>{};
    final dupes = <MetricKey>{};
    for (final f in fields) {
      if (f is! Map) {
        rejected.add('عنصر غير صالح في قائمة الحقول.');
        continue;
      }
      final keyRaw = f['key'];
      final key = keyRaw is String ? metricKeyFromWire(keyRaw) : null;
      if (key == null) {
        rejected.add('حقل غير معروف: $keyRaw');
        continue;
      }
      final v = f['value'];
      if (v == null) continue; // explicitly not found
      if (v is! num) {
        rejected.add('${key.labelAr}: القيمة ليست رقمًا.');
        continue;
      }
      final d = v.toDouble();
      final u = f['unit'];
      final expectsGlucoseUnit = key == MetricKey.meanGlucose || key == MetricKey.sd;
      final unitOk = u is String &&
          (expectsGlucoseUnit ? parseGlucoseUnit(u) == unit : u.trim() == '%');
      if (!unitOk) {
        rejected.add('${key.labelAr}: الوحدة غير متوقعة ($u).');
        continue;
      }
      if (!isPlausible(key, d, unit)) {
        rejected.add('${key.labelAr}: القيمة ${formatNumber(d, decimals: 2)} خارج النطاق المعقول.');
        continue;
      }
      if (!seen.add(key)) {
        dupes.add(key);
        continue;
      }
      values[key] = (d, f['label'] is String ? f['label'] as String : null);
    }
    for (final k in dupes) {
      values.remove(k);
      rejected.add('${k.labelAr}: ظهرت أكثر من قيمة في الاستجابة.');
    }
    return AiExtraction(values: values, rejectedAr: rejected, provider: provider);
  }
}

/// Combines local text extraction with a validated AI extraction.
ExtractionResult reconcileWithAi(ExtractionResult local, AiExtraction ai, {double tolerance = 0.05}) {
  final fields = <MetricKey, ExtractedField>{};
  local.fields.forEach((k, f) {
    final a = ai.values[k];
    if (a == null) {
      fields[k] = f;
      return;
    }
    final aiV = a.$1;
    if (f.extractedValue != null && f.extractionStatus != ExtractionStatus.notFound) {
      final agree = (f.extractedValue! - aiV).abs() <= tolerance;
      fields[k] = ExtractedField(
        key: k,
        extractedValue: f.extractedValue,
        unit: f.unit,
        extractionStatus: agree ? f.extractionStatus : ExtractionStatus.ambiguous,
        validation: f.validation,
        method: agree ? ExtractionMethod.localAndAiAgree : ExtractionMethod.localAndAiDisagree,
        sourcePage: f.sourcePage,
        sourceLabel: f.sourceLabel,
        aiValue: aiV,
        messagesAr: agree
            ? f.messagesAr
            : [...f.messagesAr, 'القراءة المحلية ${formatNumber(f.extractedValue!, decimals: 2)} والذكاء الاصطناعي ${formatNumber(aiV, decimals: 2)}؛ يرجى المقارنة بالتقرير.'],
      );
    } else {
      fields[k] = ExtractedField(
        key: k,
        extractedValue: aiV,
        unit: f.unit,
        extractionStatus: ExtractionStatus.found,
        validation: FieldValidation.notCrossChecked,
        method: ExtractionMethod.ai,
        sourceLabel: a.$2,
        aiValue: aiV,
        messagesAr: const ['استُخرجت هذه القيمة بالذكاء الاصطناعي فقط؛ تحقق منها في التقرير قبل التأكيد.'],
      );
    }
  });
  return applyConsistencyChecks(local.copyWith(
    fields: fields,
    aiUsed: true,
    warningsAr: [
      ...local.warningsAr,
      if (ai.rejectedAr.isNotEmpty) 'رُفضت ${ai.rejectedAr.length} قيمة من استجابة الذكاء الاصطناعي لعدم اجتيازها التحقق.',
    ],
  ));
}

/// User actions on the extraction review screen.
class ExtractionReview {
  static ExtractionResult _set(ExtractionResult r, MetricKey k, ExtractedField f) =>
      r.copyWith(fields: {...r.fields, k: f});

  static ExtractionResult confirm(ExtractionResult r, MetricKey k) {
    final f = r.fields[k]!;
    if (f.effectiveValue == null) return r;
    return _set(r, k, f.copyWith(confirmed: true, markedUnavailable: false));
  }

  /// Records a user correction. The originally extracted value is preserved.
  /// Throws [ArgumentError] when the corrected value is implausible.
  static ExtractionResult correct(ExtractionResult r, MetricKey k, double value) {
    if (!isPlausible(k, value, r.glucoseUnit)) {
      throw ArgumentError('القيمة خارج النطاق المعقول لهذا المؤشر.');
    }
    final f = r.fields[k]!;
    final updated = applyConsistencyChecks(_set(r, k, f.copyWith(correctedValue: value, confirmed: true, markedUnavailable: false)));
    return updated;
  }

  static ExtractionResult restoreExtracted(ExtractionResult r, MetricKey k) {
    final f = r.fields[k]!;
    return applyConsistencyChecks(_set(r, k, f.copyWith(clearCorrection: true, confirmed: false)));
  }

  static ExtractionResult markUnavailable(ExtractionResult r, MetricKey k) {
    final f = r.fields[k]!;
    return applyConsistencyChecks(_set(r, k, f.copyWith(markedUnavailable: true, confirmed: false)));
  }

  /// Confirms every field that was found by a verified layout, passed range
  /// and consistency checks, and was not AI-only.
  static ExtractionResult confirmAllEligible(ExtractionResult r) {
    final fields = <MetricKey, ExtractedField>{};
    r.fields.forEach((k, f) {
      fields[k] = (f.eligibleForBulkConfirm && !f.markedUnavailable) ? f.copyWith(confirmed: true) : f;
    });
    return r.copyWith(fields: fields);
  }
}

class ExtractionNotReviewedException implements Exception {
  ExtractionNotReviewedException(this.pending);
  final List<MetricKey> pending;
  @override
  String toString() => 'Extraction has unreviewed fields: $pending';
}

/// Builds an accepted report from a fully reviewed extraction. Only values the
/// user confirmed become verified metrics; everything else is unavailable.
/// Mean glucose and SD are stored in mg/dL (converted from mmol/L if needed).
CgmReport buildReportFromExtraction(
  ExtractionResult r, {
  required String id,
  required String userId,
  required DataProvenance provenance,
  required ReportSourceType sourceType,
  required DateTime createdAt,
  ReportPeriod? metricsPeriodOverride,
}) {
  final pending = r.fields.values.where((f) => f.isPending).map((f) => f.key).toList();
  if (pending.isNotEmpty) throw ExtractionNotReviewedException(pending);

  final metrics = <MetricKey, MetricValue>{};
  r.fields.forEach((k, f) {
    final v = f.effectiveValue;
    final glucoseScale = (k == MetricKey.meanGlucose || k == MetricKey.sd) && r.glucoseUnit == GlucoseUnit.mmoll;
    if (v == null || !f.confirmed) {
      metrics[k] = MetricValue(
        key: k,
        value: null,
        unit: f.unit,
        origin: ValueOrigin.extractedFromReport,
        status: VerificationStatus.unavailable,
        sourceLabel: f.sourceLabel,
        sourcePage: f.sourcePage,
      );
      return;
    }
    metrics[k] = MetricValue(
      key: k,
      value: glucoseScale ? toMgdl(v, GlucoseUnit.mmoll) : v,
      unit: glucoseScale ? 'mg/dL' : f.unit,
      origin: f.isCorrected ? ValueOrigin.userCorrected : ValueOrigin.extractedFromReport,
      status: VerificationStatus.verified,
      sourceLabel: f.sourceLabel,
      sourcePage: f.sourcePage,
      originalExtractedValue: f.isCorrected ? f.extractedValue : null,
      note: glucoseScale ? 'حُوّلت من mmol/L' : null,
    );
  });

  final period = metricsPeriodOverride ??
      (r.metricsPeriod.status == ExtractionStatus.found ? r.metricsPeriod.period : null);
  final derived = withDerivedMetrics(metrics);
  final sensor = derived[MetricKey.sensorActive];
  return CgmReport(
    id: id,
    userId: userId,
    provenance: provenance,
    sourceType: sourceType,
    glucoseUnit: GlucoseUnit.mgdl,
    metrics: derived,
    quality: qualityFromSummary(
      metricsPeriod: period,
      printedSensorPercent: (sensor?.isVerified ?? false) ? sensor!.value : null,
      sensorLabel: r.sensorLabel,
      limitedDataNotice: r.limitedDataNotice,
    ),
    createdAt: createdAt,
    reportPeriod: r.reportPeriod.status == ExtractionStatus.found ? r.reportPeriod.period : null,
    metricsPeriod: period,
    formatId: r.formatId,
    deviceLabel: r.deviceLabel,
    warningsAr: r.warningsAr,
  );
}

/// Parser used by the app; exposed for convenience.
const reportTextParser = ReportTextParser();
