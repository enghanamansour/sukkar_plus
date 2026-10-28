import 'package:sukkar_core/sukkar_core.dart';
import 'package:test/test.dart';

void main() {
  ExtractionResult parsed() => reportTextParser.parse([
        syntheticDiscoverSummaryLines(
          periodStart: DateTime(2026, 10, 13),
          periodEnd: DateTime(2026, 10, 26),
          generated: DateTime(2026, 10, 27),
          v: demoUploadValues,
        ).join('\n'),
      ]);

  CgmReport build(ExtractionResult r) => buildReportFromExtraction(r,
      id: 'x', userId: 'u', provenance: DataProvenance.real, sourceType: ReportSourceType.pdfUpload, createdAt: DateTime(2026, 10, 27));

  group('review actions', () {
    test('nothing is verified until the user confirms', () {
      final r = parsed();
      expect(r.hasPending, isTrue);
      expect(() => build(r), throwsA(isA<ExtractionNotReviewedException>()));
    });

    test('bulk confirm verifies only eligible fields', () {
      final r = ExtractionReview.confirmAllEligible(parsed());
      expect(r.hasPending, isFalse);
      final rep = build(r);
      expect(rep.metrics[MetricKey.timeInRange]!.status, VerificationStatus.verified);
      expect(rep.metrics[MetricKey.timeInRange]!.origin, ValueOrigin.extractedFromReport);
      expect(rep.quality.sufficient, isTrue);
      expect(rep.formatId, ReportTextParser.discoverFormatId);
    });

    test('correction keeps the original extracted value', () {
      var r = ExtractionReview.confirmAllEligible(parsed());
      r = ExtractionReview.correct(r, MetricKey.cv, 39.6);
      final f = r.fields[MetricKey.cv]!;
      expect(f.extractedValue, 39.5);
      expect(f.correctedValue, 39.6);
      expect(f.isCorrected, isTrue);
      final rep = build(r);
      expect(rep.metrics[MetricKey.cv]!.value, 39.6);
      expect(rep.metrics[MetricKey.cv]!.origin, ValueOrigin.userCorrected);
      expect(rep.metrics[MetricKey.cv]!.originalExtractedValue, 39.5);
    });

    test('implausible corrections are rejected', () {
      expect(() => ExtractionReview.correct(parsed(), MetricKey.timeInRange, 140), throwsArgumentError);
    });

    test('correcting a value can resolve an inconsistency', () {
      final bad = reportTextParser.parse([
        syntheticDiscoverSummaryLines(
          periodStart: DateTime(2026, 10, 13),
          periodEnd: DateTime(2026, 10, 26),
          generated: DateTime(2026, 10, 27),
          v: demoUploadValues,
        ).map((x) => x == '7.3%' ? '8.3%' : x).join('\n'),
      ]);
      expect(bad.fields[MetricKey.gmi]!.validation, FieldValidation.inconsistent);
      final fixed = ExtractionReview.correct(bad, MetricKey.gmi, 7.3);
      expect(fixed.fields[MetricKey.gmi]!.validation, FieldValidation.valid);
      expect(fixed.fields[MetricKey.meanGlucose]!.validation, FieldValidation.valid);
    });

    test('marking unavailable stores null, never zero', () {
      var r = ExtractionReview.confirmAllEligible(parsed());
      r = ExtractionReview.markUnavailable(r, MetricKey.sd);
      final rep = build(r);
      expect(rep.metrics[MetricKey.sd]!.value, isNull);
      expect(rep.metrics[MetricKey.sd]!.status, VerificationStatus.unavailable);
    });

    test('restoring the extracted value clears the correction and asks for review again', () {
      var r = ExtractionReview.correct(parsed(), MetricKey.cv, 40);
      r = ExtractionReview.restoreExtracted(r, MetricKey.cv);
      expect(r.fields[MetricKey.cv]!.correctedValue, isNull);
      expect(r.fields[MetricKey.cv]!.isPending, isTrue);
    });

    test('missing sensor coverage makes the report insufficient', () {
      var r = reportTextParser.parse([
        (syntheticDiscoverSummaryLines(
          periodStart: DateTime(2026, 10, 13),
          periodEnd: DateTime(2026, 10, 26),
          generated: DateTime(2026, 10, 27),
          v: demoUploadValues,
        )..removeWhere((x) => x.startsWith('Connected'))).join('\n'),
      ]);
      r = ExtractionReview.confirmAllEligible(r);
      final rep = build(r);
      expect(rep.quality.coveragePercent, isNull);
      expect(rep.quality.sufficient, isFalse);
    });
  });

  group('AI extraction validation (invalid model output)', () {
    const v = AiExtractionValidator();
    test('non-map output is rejected entirely', () {
      final a = v.validate('not json');
      expect(a.values, isEmpty);
      expect(a.rejectedAr, isNotEmpty);
    });
    test('missing fields list is rejected', () {
      expect(v.validate({'provider': 'gemini'}).values, isEmpty);
    });
    test('strings, wrong units, unknown keys and out-of-range values are dropped', () {
      final a = v.validate({
        'provider': 'gemini',
        'glucose_unit': 'mg/dL',
        'fields': [
          {'key': 'time_in_range', 'value': '65.5', 'unit': '%'},
          {'key': 'mean_glucose', 'value': 168, 'unit': 'mmol/L'},
          {'key': 'insulin_total', 'value': 22, 'unit': 'U'},
          {'key': 'cv', 'value': 140, 'unit': '%'},
          {'key': 'gmi', 'value': 7.3, 'unit': '%', 'label': 'GMI'},
          {'key': 'sd', 'value': null, 'unit': 'mg/dL'},
        ],
      });
      expect(a.values.keys.toList(), [MetricKey.gmi]);
      expect(a.rejectedAr, hasLength(4));
    });
    test('duplicate keys drop both values', () {
      final a = v.validate({
        'fields': [
          {'key': 'gmi', 'value': 7.3, 'unit': '%'},
          {'key': 'gmi', 'value': 7.9, 'unit': '%'},
        ],
      });
      expect(a.values, isEmpty);
    });
  });

  group('reconciling local and AI extraction', () {
    test('agreement keeps eligibility; disagreement requires review', () {
      final local = parsed();
      final ai = const AiExtractionValidator().validate({
        'provider': 'gemini',
        'glucose_unit': 'mg/dL',
        'fields': [
          {'key': 'time_in_range', 'value': 65.5, 'unit': '%'},
          {'key': 'mean_glucose', 'value': 186, 'unit': 'mg/dL'},
        ],
      });
      final r = reconcileWithAi(local, ai);
      expect(r.aiUsed, isTrue);
      expect(r.fields[MetricKey.timeInRange]!.method, ExtractionMethod.localAndAiAgree);
      expect(r.fields[MetricKey.timeInRange]!.eligibleForBulkConfirm, isTrue);
      final mean = r.fields[MetricKey.meanGlucose]!;
      expect(mean.method, ExtractionMethod.localAndAiDisagree);
      expect(mean.extractionStatus, ExtractionStatus.ambiguous);
      expect(mean.extractedValue, 168);
      expect(mean.aiValue, 186);
      expect(mean.eligibleForBulkConfirm, isFalse);
    });
    test('AI-only values are never bulk-confirmed', () {
      final local = reportTextParser.parse([
        (syntheticDiscoverSummaryLines(
          periodStart: DateTime(2026, 10, 13),
          periodEnd: DateTime(2026, 10, 26),
          generated: DateTime(2026, 10, 27),
          v: demoUploadValues,
        )..removeWhere((x) => x.startsWith('Connected'))).join('\n'),
      ]);
      final ai = const AiExtractionValidator().validate({
        'fields': [
          {'key': 'sensor_active', 'value': 88, 'unit': '%'},
        ],
      });
      final r = ExtractionReview.confirmAllEligible(reconcileWithAi(local, ai));
      final f = r.fields[MetricKey.sensorActive]!;
      expect(f.method, ExtractionMethod.ai);
      expect(f.isPending, isTrue);
    });
  });
}
