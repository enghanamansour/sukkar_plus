import 'package:sukkar_core/sukkar_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  final now = DateTime(2026, 10, 28);

  group('HbA1c units', () {
    test('IFCC–NGSP master equation both ways', () {
      expect(HbA1c.percentToMmolMol(7.0), closeTo(53.0, 0.05));
      expect(HbA1c.mmolMolToPercent(54), closeTo(7.092, 0.001));
      expect(HbA1c.mmolMolToPercent(HbA1c.percentToMmolMol(8.1)), closeTo(8.1, 1e-9));
    });
    test('unit parsing', () {
      expect(parseHbA1cUnit('%'), HbA1cUnit.percent);
      expect(parseHbA1cUnit(' mmol/mol '), HbA1cUnit.mmolMol);
      expect(parseHbA1cUnit('mg/dL'), isNull);
    });
    test('validation catches unit mix-ups and impossible values', () {
      List<String> fields(double v, String u, {DateTime? d}) => validateLabEntry(
              code: LabTestCode.hba1c, testName: '', value: v, unit: u, collectionDate: d ?? now, now: now)
          .map((i) => i.field)
          .toList();
      expect(fields(7.1, '%'), isEmpty);
      expect(fields(54, 'mmol/mol'), isEmpty);
      expect(fields(54, '%'), contains('value'));
      expect(fields(7.1, 'mmol/mol'), contains('value'));
      expect(fields(7.1, 'mg/dL'), contains('unit'));
      expect(fields(7.1, '%', d: now.add(const Duration(days: 2))), contains('collectionDate'));
    });
    test('generic lab validation', () {
      final issues = validateLabEntry(
        code: LabTestCode.other,
        testName: ' ',
        value: null,
        unit: '',
        collectionDate: null,
        now: now,
        referenceInterval: const ReferenceInterval(low: 10, high: 5),
      ).map((i) => i.field).toSet();
      expect(issues, equals({'testName', 'value', 'unit', 'referenceInterval'}));
    });
  });

  group('GMI vs HbA1c', () {
    final report = summaryReport(values: {MetricKey.gmi: 7.0, MetricKey.meanGlucose: 154});

    test('aligned: lab within 30 days after the CGM period → difference shown', () {
      final c = compareGmiWithHbA1c(report: report, hba1c: hba1cLab(value: 7.4, date: DateTime(2026, 10, 20)));
      expect(c.comparability, Comparability.aligned);
      expect(c.daysFromPeriodEndToLab, 6);
      expect(c.differencePercentPoints, closeTo(0.4, 1e-9));
    });
    test('lab collected during the CGM period is aligned', () {
      final c = compareGmiWithHbA1c(report: report, hba1c: hba1cLab(date: DateTime(2026, 10, 5)));
      expect(c.comparability, Comparability.aligned);
    });
    test('lab long after the period: values shown, no difference', () {
      final c = compareGmiWithHbA1c(report: report, hba1c: hba1cLab(value: 7.4, date: DateTime(2026, 12, 1)));
      expect(c.comparability, Comparability.notAligned);
      expect(c.differencePercentPoints, isNull);
      expect(c.hba1cPercent, 7.4);
      expect(c.gmiPercent, 7.0);
    });
    test('lab before the period is not aligned', () {
      final c = compareGmiWithHbA1c(report: report, hba1c: hba1cLab(date: DateTime(2026, 9, 20)));
      expect(c.comparability, Comparability.notAligned);
      expect(c.daysFromPeriodEndToLab, -24);
    });
    test('undated, unverified or missing data is insufficient', () {
      expect(compareGmiWithHbA1c(report: report, hba1c: hba1cLab(undated: true)).comparability, Comparability.insufficient);
      expect(compareGmiWithHbA1c(report: report, hba1c: hba1cLab(verification: VerificationStatus.needsReview)).comparability,
          Comparability.insufficient);
      expect(compareGmiWithHbA1c(report: report, hba1c: null).comparability, Comparability.insufficient);
      expect(compareGmiWithHbA1c(report: summaryReport(values: {MetricKey.gmi: null}), hba1c: hba1cLab()).comparability,
          Comparability.insufficient);
    });
    test('mmol/mol results are converted for the comparison and flagged', () {
      final c = compareGmiWithHbA1c(report: report, hba1c: hba1cLab(value: 54, unit: 'mmol/mol'));
      expect(c.hba1cWasConverted, isTrue);
      expect(c.differencePercentPoints, closeTo(0.0919, 1e-3));
    });
    test('insufficient CGM data adds a caveat but does not invent values', () {
      final weak = summaryReport(values: {MetricKey.gmi: 7.0}, coverage: 50);
      final c = compareGmiWithHbA1c(report: weak, hba1c: hba1cLab());
      expect(c.notesAr.any((n) => n.contains('14 يومًا')), isTrue);
    });
    test('compareLatest pairs the latest lab with the report covering it', () {
      final older = summaryReport(id: 'old', values: {MetricKey.gmi: 7.6}, period: ReportPeriod(DateTime(2026, 7, 1), DateTime(2026, 7, 14)));
      final c = compareLatest(reports: [older, report], labs: [hba1cLab(id: 'a', date: DateTime(2026, 7, 20)), hba1cLab(id: 'b', date: DateTime(2026, 10, 20))]);
      expect(c.reportId, 'r1');
      expect(c.hba1c!.id, 'b');
    });
  });

  group('historical trends', () {
    test('HbA1c trend uses dated, verified results in % order', () {
      final t = hba1cTrend([
        hba1cLab(id: 'b', value: 54, unit: 'mmol/mol', date: DateTime(2026, 9, 1)),
        hba1cLab(id: 'a', value: 7.6, date: DateTime(2026, 6, 1)),
        hba1cLab(id: 'c', undated: true),
      ]);
      expect(t.points.map((p) => p.sourceId).toList(), ['a', 'b']);
      expect(t.change!.direction, ChangeDirection.decrease);
      expect(t.change!.delta, closeTo(7.092 - 7.6, 1e-3));
      expect(t.change!.daysBetween, 92);
      expect(t.missingAr.any((m) => m.contains('بلا تاريخ')), isTrue);
    });
    test('fewer than two results: no comparison, explanation given', () {
      final t = hba1cTrend([hba1cLab()]);
      expect(t.hasComparison, isFalse);
      expect(t.missingAr, isNotEmpty);
    });
    test('lab trend refuses mixed units', () {
      LabResult ldl(String id, double v, String u, DateTime d) => LabResult(
            id: id, userId: 'u1', testCode: LabTestCode.ldl, testName: 'LDL', value: v, unit: u, collectionDate: d,
            source: LabSource.manual, verification: VerificationStatus.verified, provenance: DataProvenance.real, createdAt: d);
      final t = labTrend([ldl('a', 104, 'mg/dL', DateTime(2026, 1, 1)), ldl('b', 2.6, 'mmol/L', DateTime(2026, 6, 1))], code: LabTestCode.ldl);
      expect(t.hasComparison, isFalse);
      expect(t.missingAr.single, contains('وحدات مختلفة'));
      final same = labTrend([ldl('a', 104, 'mg/dL', DateTime(2026, 1, 1)), ldl('b', 98, 'mg/dL', DateTime(2026, 6, 1))], code: LabTestCode.ldl);
      expect(same.change!.delta, -6);
    });
    test('CGM period comparison reports missing periods between reports', () {
      final a = summaryReport(id: 'a', values: {MetricKey.timeInRange: 62}, period: ReportPeriod(DateTime(2026, 7, 1), DateTime(2026, 7, 14)));
      final b = summaryReport(id: 'b', values: {MetricKey.timeInRange: 68}, period: ReportPeriod(DateTime(2026, 10, 1), DateTime(2026, 10, 14)));
      final c = compareLatestCgmPeriods([b, a])!;
      expect(c.previous.id, 'a');
      expect(c.changes[MetricKey.timeInRange]!.delta, 6);
      expect(c.changes[MetricKey.timeInRange]!.direction, ChangeDirection.increase);
      expect(c.gapDaysBetweenPeriods, 78);
      expect(c.changes.containsKey(MetricKey.cv), isFalse);
    });
    test('overlapping CGM periods are not compared', () {
      final a = summaryReport(id: 'a', values: {MetricKey.timeInRange: 62}, period: ReportPeriod(DateTime(2026, 10, 1), DateTime(2026, 10, 14)));
      final b = summaryReport(id: 'b', values: {MetricKey.timeInRange: 68}, period: ReportPeriod(DateTime(2026, 10, 10), DateTime(2026, 10, 23)));
      final c = compareLatestCgmPeriods([a, b])!;
      expect(c.comparable, isFalse);
      expect(c.changes, isEmpty);
    });
    test('a single report gives no comparison', () {
      expect(compareLatestCgmPeriods([summaryReport(values: {MetricKey.timeInRange: 62})]), isNull);
    });
  });
}
