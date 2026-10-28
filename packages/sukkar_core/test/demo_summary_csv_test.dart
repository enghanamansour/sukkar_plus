import 'package:sukkar_core/sukkar_core.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2026, 10, 28, 16);

  group('synthetic demo dataset', () {
    final repo = buildDemoRepository(now);

    test('contains the required synthetic records, all labelled synthetic', () async {
      final reports = await repo.listReports(demoPatientActor);
      final labs = await repo.listLabs(demoPatientActor);
      final reminders = await repo.listReminders(demoPatientActor);
      final appts = await repo.listAppointments(demoPatientActor);
      final fus = await repo.listFollowUps(demoPatientActor);
      expect(reports, hasLength(2));
      expect(labs.where((l) => l.testCode == LabTestCode.hba1c), hasLength(2));
      expect(reminders.where((r) => r.isOpen), isNotEmpty);
      expect(appts, hasLength(1));
      expect(appts.single.isSimulated, isTrue);
      expect(fus.map((f) => f.status).toSet(), {FollowUpStatus.awaitingReview, FollowUpStatus.reviewed});
      expect(reports.every((r) => r.provenance == DataProvenance.synthetic), isTrue);
      expect(labs.every((l) => l.provenance == DataProvenance.synthetic), isTrue);
      expect(fus.every((f) => f.provenance == DataProvenance.synthetic), isTrue);
    });

    test('report B is computed from synthetic readings and is sufficient', () {
      final b = repo.reports['demo-report-b']!;
      expect(b.hasRawReadings, isTrue);
      expect(b.metrics[MetricKey.timeInRange]!.origin, ValueOrigin.calculatedFromReadings);
      expect(b.quality.sufficient, isTrue);
      expect(b.quality.duplicateReadings, 2);
      expect(const CgmCalculator().compute(b.readings!).episodesBelow54, hasLength(3));
    });

    test('reviewer sees the pending request; it carries only the shared snapshot', () async {
      final list = await repo.listFollowUps(demoReviewerActor);
      final pending = list.firstWhere((f) => f.status == FollowUpStatus.awaitingReview);
      expect(pending.ruleIds, ['EPI54-REPEATED']);
      expect(pending.snapshot.items, isNotEmpty);
      expect(pending.dispatch.isMock, isTrue);
    });

    test('the demo upload text parses fully and suggests a review', () {
      var r = reportTextParser.parse([demoUploadLines(now).join('\n')]);
      expect(r.foundCount, 12);
      r = ExtractionReview.confirmAllEligible(r);
      final rep = buildReportFromExtraction(r,
          id: 'up', userId: demoPatientId, provenance: DataProvenance.synthetic, sourceType: ReportSourceType.demoFixture, createdAt: now);
      expect(rep.metricsPeriod!.end, DateTime(2026, 10, 27));
      final ev = const RuleEngine().evaluate(rep, profile: TargetProfile.generalAdultT1T2, now: now);
      expect(ev.outcome, ReviewOutcome.reviewSuggested);
      expect(ev.triggered.map((x) => x.rule.id).toSet(), {'TBR54-TARGET', 'TBR70-TARGET', 'TAR250-TARGET'});
    });

    test('visit summary combines data, flags missing items and asks neutral questions', () async {
      final summary = const VisitSummaryBuilder().build(
        now: now,
        reports: await repo.listReports(demoPatientActor),
        labs: await repo.listLabs(demoPatientActor),
        reminders: await repo.listReminders(demoPatientActor),
        followUps: await repo.listFollowUps(demoPatientActor),
        appointment: (await repo.listAppointments(demoPatientActor)).single,
        targetProfile: TargetProfile.generalAdultT1T2,
      );
      expect(summary.isSynthetic, isTrue);
      expect(summary.latestReport!.id, 'demo-report-b');
      expect(summary.gmiComparison.comparability, Comparability.aligned);
      expect(summary.cgmComparison, isNotNull);
      expect(summary.dueBeforeAppointment.map((r) => r.testCode).toSet(), {LabTestCode.hba1c, LabTestCode.uacr});
      expect(summary.questionsAr, contains('كيف تفسر اختلاف قيمة GMI عن آخر نتيجة HbA1c؟'));
      expect(summary.questionsAr, contains('ما المعلومات الإضافية التي تساعد في فهم الأنماط المتكررة؟'));
      expect(summary.questionsAr.any((q) => q.contains('جرع')), isFalse);
      expect(VisitSummary.disclaimerAr, contains('لا يتضمن تشخيصًا'));
    });

    test('summary without any data lists what is missing', () {
      final s = const VisitSummaryBuilder().build(
        now: now, reports: const [], labs: const [], reminders: const [], followUps: const [], appointment: null, targetProfile: TargetProfile.unspecified);
      expect(s.missingAr, contains('لا يوجد تقرير حساس موثّق.'));
      expect(s.missingAr, contains('لا توجد نتيجة HbA1c مسجلة.'));
      expect(s.questionsAr, contains('ما الأهداف المناسبة لي لنطاقات السكر؟'));
    });

    test('demo data is deterministic', () {
      final a = buildDemoRepository(now).reports['demo-report-b']!.metrics[MetricKey.meanGlucose]!.value;
      final b = buildDemoRepository(now).reports['demo-report-b']!.metrics[MetricKey.meanGlucose]!.value;
      expect(a, b);
    });
  });

  group('CSV import (AZT1D column layout, synthetic rows)', () {
    const importer = CgmCsvImporter();
    test('reads EventDateTime and CGM, ignoring insulin columns', () {
      const csv = 'EventDateTime,DeviceMode,BolusType,Basal,CorrectionDelivered,TotalBolusInsulinDelivered,FoodDelivered,CarbSize,CGM\n'
          '2024-02-23 00:01:53,,,,,,,,82\n'
          '2024-02-23 00:06:53,,Standard,,1.5,1.5,0,0,103\n'
          '2024-02-23 00:06:53,,,,,,,,110\n';
      final r = importer.parse(csv);
      expect(r.readings, hasLength(3));
      expect(r.glucoseColumn, 'CGM');
      final comp = const CgmCalculator().compute(r.readings);
      expect(comp.quality.conflictingDuplicates, 1);
      expect(comp.metrics[MetricKey.meanGlucose]!.value, closeTo((82 + 103) / 2, 1e-9));
    });
    test('alternate column name is accepted with a warning', () {
      const csv = 'EventDateTime,Basal,Readings (CGM / BGM),DeviceMode\n2024-01-13 00:03:00,,128,\n2024-01-13 00:08:00,,135,sleep\n';
      final r = importer.parse(csv);
      expect(r.readings, hasLength(2));
      expect(r.warningsAr.first, contains('BGM'));
    });
    test('invalid rows are skipped and counted', () {
      final r = importer.parse('EventDateTime,CGM\nnot-a-date,100\n2024-01-01 00:00:00,\n2024-01-01 00:05:00,120\n');
      expect(r.readings, hasLength(1));
      expect(r.skippedRows, 2);
    });
    test('missing columns and empty files raise a clear error', () {
      expect(() => importer.parse(''), throwsA(isA<CsvImportException>()));
      expect(() => importer.parse('time,value\n1,2'), throwsA(isA<CsvImportException>()));
    });
  });
}
