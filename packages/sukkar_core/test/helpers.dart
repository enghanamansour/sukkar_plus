import 'package:sukkar_core/sukkar_core.dart';

/// Builds a verified summary report for rule and comparison tests.
CgmReport summaryReport({
  String id = 'r1',
  String userId = 'u1',
  required Map<MetricKey, double?> values,
  ReportPeriod? period,
  double? coverage = 90,
  List<GlucoseReading>? readings,
  DataProvenance provenance = DataProvenance.real,
}) {
  final p = period ?? ReportPeriod(DateTime(2026, 10, 1), DateTime(2026, 10, 14));
  final metrics = <MetricKey, MetricValue>{
    for (final e in values.entries)
      e.key: MetricValue(
        key: e.key,
        value: e.value,
        unit: e.key == MetricKey.meanGlucose || e.key == MetricKey.sd ? 'mg/dL' : '%',
        origin: ValueOrigin.extractedFromReport,
        status: e.value == null ? VerificationStatus.unavailable : VerificationStatus.verified,
      ),
  };
  return CgmReport(
    id: id,
    userId: userId,
    provenance: provenance,
    sourceType: ReportSourceType.pdfUpload,
    glucoseUnit: GlucoseUnit.mgdl,
    metrics: withDerivedMetrics(metrics),
    quality: qualityFromSummary(metricsPeriod: p, printedSensorPercent: coverage, sensorLabel: 'sensor'),
    createdAt: p.end,
    reportPeriod: p,
    metricsPeriod: p,
    readings: readings,
  );
}

LabResult hba1cLab({
  String id = 'l1',
  double value = 7.0,
  String unit = '%',
  DateTime? date,
  bool undated = false,
  VerificationStatus verification = VerificationStatus.verified,
}) =>
    LabResult(
      id: id,
      userId: 'u1',
      testCode: LabTestCode.hba1c,
      testName: 'HbA1c',
      value: value,
      unit: unit,
      collectionDate: undated ? null : (date ?? DateTime(2026, 10, 20)),
      source: LabSource.manual,
      verification: verification,
      provenance: DataProvenance.real,
      createdAt: DateTime(2026, 10, 20),
    );

/// Regular 5-minute readings starting at [start] with the given values.
List<GlucoseReading> series(DateTime start, List<double> values, {int stepMinutes = 5}) => [
      for (var i = 0; i < values.length; i++) GlucoseReading(start.add(Duration(minutes: stepMinutes * i)), values[i]),
    ];

const fixtureDir = 'test/fixtures';
