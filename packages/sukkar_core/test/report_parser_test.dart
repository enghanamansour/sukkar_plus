import 'dart:io';
import 'dart:typed_data';

import 'package:sukkar_core/sukkar_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  const parser = ReportTextParser();

  List<String> lines() => syntheticDiscoverSummaryLines(
        periodStart: DateTime(2026, 10, 13),
        periodEnd: DateTime(2026, 10, 26),
        generated: DateTime(2026, 10, 27),
        v: demoUploadValues,
      );

  group('Omnipod Discover summary (synthetic text, PDFium order)', () {
    test('PDFium-extracted fixture yields every field with expected values', () {
      final text = File('$fixtureDir/synthetic_discover_summary.pdfium.txt').readAsStringSync();
      final r = parser.parse([text]);
      expect(r.formatId, ReportTextParser.discoverFormatId);
      expect(r.formatVerified, isTrue);
      expect(r.glucoseUnit, GlucoseUnit.mgdl);
      expect(r.reportDaysLabel, 14);
      final v = {for (final f in r.fields.values) f.key: f.extractedValue};
      expect(v[MetricKey.meanGlucose], 168);
      expect(v[MetricKey.gmi], 7.3);
      expect(v[MetricKey.cv], 39.5);
      expect(v[MetricKey.sd], 66.4);
      expect(v[MetricKey.sensorActive], 88);
      expect(v[MetricKey.timeVeryLow], 1.4);
      expect(v[MetricKey.timeLow], 3.1);
      expect(v[MetricKey.timeInRange], 65.5);
      expect(v[MetricKey.timeHigh], 23);
      expect(v[MetricKey.timeVeryHigh], 7);
      expect(v[MetricKey.timeBelowRangeTotal], 4.5);
      expect(v[MetricKey.timeAboveRangeTotal], 30);
      expect(r.fields.values.every((f) => f.validation == FieldValidation.valid), isTrue);
      expect(r.checks.every((c) => c.passed == true), isTrue);
      expect(r.fields[MetricKey.meanGlucose]!.sourcePage, 1);
      expect(r.fields[MetricKey.meanGlucose]!.sourceLabel, 'Average Glucose');
    });

    test('report period uses DD/MM/YYYY confirmed by the N-Day header', () {
      final r = parser.parse([lines().join('\n')]);
      expect(r.reportPeriod.status, ExtractionStatus.found);
      expect(r.reportPeriod.period, ReportPeriod(DateTime(2026, 10, 13), DateTime(2026, 10, 26)));
      // No separate sensor window → metrics period equals report period.
      expect(r.metricsPeriod.period, r.reportPeriod.period);
    });

    test('a "sensor data is only available" window becomes the metrics period', () {
      final l = syntheticDiscoverSummaryLines(
        periodStart: DateTime(2026, 7, 31),
        periodEnd: DateTime(2026, 10, 28),
        generated: DateTime(2026, 10, 27),
        v: demoReportAValues,
        sensorFrom: DateTime(2026, 8, 16),
        sensorTo: DateTime(2026, 10, 10),
      );
      final r = parser.parse([l.join('\n')]);
      expect(r.reportDaysLabel, 90);
      expect(r.reportPeriod.period!.days, 90);
      expect(r.metricsPeriod.period, ReportPeriod(DateTime(2026, 8, 16), DateTime(2026, 10, 10)));
      expect(r.metricsPeriod.period!.days, 56);
      expect(r.warningsAr.any((w) => w.contains('فترة توفر بيانات الحساس')), isTrue);
    });

    test('insulin and pump-setting lines are ignored', () {
      final l = [...lines(), 'Avg Total Daily Insulin: 22.2 U Bolus Type', '80.6% 10.9 U', 'Basal/Day', '39%', '8.7 U'];
      final r = parser.parse([l.join('\n')]);
      expect(r.fields[MetricKey.timeInRange]!.extractedValue, 65.5);
      expect(r.warningsAr.any((w) => w.contains('الإنسولين')), isTrue);
    });

    test('personal identifiers never appear in any field label', () {
      final r = parser.parse([['Jane Example', 'DOB: 01/01/1990 (36 years old)', ...lines()].join('\n')]);
      for (final f in r.fields.values) {
        expect((f.sourceLabel ?? '').contains('Jane'), isFalse);
        expect((f.sourceLabel ?? '').contains('DOB'), isFalse);
      }
    });

    test('summary page is found even when it is not the first page', () {
      final r = parser.parse(['Legend\nPage 2 (of 3)', lines().join('\n')]);
      expect(r.fields[MetricKey.meanGlucose]!.sourcePage, 2);
    });
  });

  group('missing and inconsistent fields', () {
    test('a missing field is notFound with a null value, never zero', () {
      final l = lines()..removeWhere((x) => x.startsWith('Connected Sensor Time'));
      final r = parser.parse([l.join('\n')]);
      final f = r.fields[MetricKey.sensorActive]!;
      expect(f.extractionStatus, ExtractionStatus.notFound);
      expect(f.extractedValue, isNull);
      expect(f.verification, VerificationStatus.unavailable);
    });

    test('a misprinted band makes the involved fields inconsistent', () {
      final l = lines().map((x) => x == '23% High' ? '33% High' : x).toList();
      final r = parser.parse([l.join('\n')]);
      expect(r.fields[MetricKey.timeHigh]!.validation, FieldValidation.inconsistent);
      expect(r.fields[MetricKey.timeHigh]!.eligibleForBulkConfirm, isFalse);
      expect(r.checks.firstWhere((c) => c.id == 'band_sum').passed, isFalse);
    });

    test('TIR is ambiguous when the band values needed to confirm it are missing', () {
      final l = lines()..removeWhere((x) => x.endsWith('Very Low'));
      final r = parser.parse([l.join('\n')]);
      expect(r.fields[MetricKey.timeInRange]!.extractionStatus, ExtractionStatus.ambiguous);
    });

    test('GMI inconsistent with mean glucose is flagged', () {
      final l = lines().map((x) => x == '7.3%' ? '8.3%' : x).toList();
      final r = parser.parse([l.join('\n')]);
      expect(r.fields[MetricKey.gmi]!.validation, FieldValidation.inconsistent);
      expect(r.fields[MetricKey.meanGlucose]!.validation, FieldValidation.inconsistent);
    });

    test('an implausible value is out of range', () {
      final l = lines().map((x) => x == '168 mg/dL' ? '868 mg/dL' : x).toList();
      final r = parser.parse([l.join('\n')]);
      expect(r.fields[MetricKey.meanGlucose]!.validation, FieldValidation.outOfRange);
    });

    test('text without any recognisable metric yields an empty result', () {
      final r = parser.parse(['Invoice\nTotal 120 SAR']);
      expect(r.isEmpty, isTrue);
      expect(r.formatVerified, isFalse);
    });

    test('empty page list yields an empty result', () {
      expect(parser.parse(const ['']).isEmpty, isTrue);
    });
  });

  group('generic AGP-style text (unverified layout)', () {
    const generic = '''
AGP Report: Continuous Glucose Monitoring
Test Patient
2026-09-01 - 2026-09-14
% Time CGM is Active 96.4%
Average Glucose 9.1 mmol/L
Glucose Management Indicator (GMI) 7.3%
Glucose Variability 34.0%
Very High >13.9 mmol/L 4%
High 10.1-13.9 mmol/L 21%
Target Range 3.9-10.0 mmol/L 71%
Low 3.0-3.8 mmol/L 3%
Very Low <3.0 mmol/L 1%
Goal: Less than 4%
''';
    test('values are found but must be confirmed one by one', () {
      final r = parser.parse([generic]);
      expect(r.formatId, ReportTextParser.genericFormatId);
      expect(r.formatVerified, isFalse);
      expect(r.glucoseUnit, GlucoseUnit.mmoll);
      expect(r.fields[MetricKey.meanGlucose]!.extractedValue, 9.1);
      expect(r.fields[MetricKey.timeInRange]!.extractedValue, 71);
      expect(r.fields[MetricKey.timeVeryLow]!.extractedValue, 1);
      expect(r.fields[MetricKey.timeLow]!.extractedValue, 3);
      expect(r.fields[MetricKey.sensorActive]!.extractedValue, 96.4);
      expect(r.reportPeriod.period, ReportPeriod(DateTime(2026, 9, 1), DateTime(2026, 9, 14)));
      expect(r.fields.values.any((f) => f.eligibleForBulkConfirm), isFalse);
    });
    test('mmol/L mean is converted to mg/dL when building the report', () {
      var r = parser.parse([generic]);
      for (final f in r.fields.values) {
        r = f.effectiveValue == null ? ExtractionReview.markUnavailable(r, f.key) : ExtractionReview.confirm(r, f.key);
      }
      final rep = buildReportFromExtraction(r,
          id: 'g', userId: 'u', provenance: DataProvenance.real, sourceType: ReportSourceType.pdfUpload, createdAt: DateTime(2026, 9, 15));
      expect(rep.metrics[MetricKey.meanGlucose]!.value, closeTo(9.1 * 18.0182, 1e-9));
      expect(rep.metrics[MetricKey.meanGlucose]!.unit, 'mg/dL');
    });
    test('slash dates that could be day- or month-first are ambiguous', () {
      final r = parser.parse(['Average Glucose 150 mg/dL\n03/04/2026 - 05/04/2026']);
      expect(r.reportPeriod.status, ExtractionStatus.ambiguous);
    });
  });

  group('PDF file validation', () {
    Uint8List b(String s) => Uint8List.fromList(s.codeUnits);
    test('valid synthetic fixture passes', () {
      final bytes = File('$fixtureDir/synthetic_discover_summary.pdf').readAsBytesSync();
      expect(validatePdfBytes('report.PDF', bytes).isValid, isTrue);
    });
    test('wrong extension', () => expect(validatePdfBytes('report.png', b('%PDF-1.4 %%EOF')).error, PdfValidationError.unsupportedType));
    test('empty file', () => expect(validatePdfBytes('a.pdf', Uint8List(0)).error, PdfValidationError.empty));
    test('not a PDF despite extension', () => expect(validatePdfBytes('a.pdf', b('hello world')).error, PdfValidationError.notPdf));
    test('truncated (no %%EOF)', () => expect(validatePdfBytes('a.pdf', b('%PDF-1.7\n1 0 obj')).error, PdfValidationError.truncated));
    test('encrypted', () => expect(validatePdfBytes('a.pdf', b('%PDF-1.7\n/Encrypt 5 0 R\n%%EOF')).error, PdfValidationError.encrypted));
    test('too large', () {
      final big = Uint8List(2048)..setAll(0, '%PDF-1.4'.codeUnits);
      expect(validatePdfBytes('a.pdf', big, maxBytes: 1024).error, PdfValidationError.tooLarge);
    });
  });
}
