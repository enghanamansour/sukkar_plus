import 'package:sukkar_core/sukkar_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  final now = DateTime(2026, 10, 28, 9);
  const svc = ReminderService();

  TestReminder make({DateTime? due, DateTime? remindAt}) => svc.create(
        id: 'r',
        userId: 'u1',
        testCode: LabTestCode.hba1c,
        testName: '',
        dueDate: due ?? DateTime(2026, 11, 3),
        source: ScheduleSource.clinicianProvided,
        now: now,
        remindAt: remindAt,
      );

  group('laboratory reminders', () {
    test('create uses the test label and records history', () {
      final r = make();
      expect(r.testName, LabTestCode.hba1c.labelAr);
      expect(r.status, ReminderStatus.scheduled);
      expect(r.history, hasLength(1));
      expect(r.displayState(now), ReminderDisplayState.upcoming);
    });
    test('due today is upcoming; due yesterday is overdue', () {
      expect(make(due: DateTime(2026, 10, 28)).displayState(now), ReminderDisplayState.upcoming);
      expect(make(due: DateTime(2026, 10, 27)).displayState(now), ReminderDisplayState.overdue);
    });
    test('remind-at after the due date is rejected', () {
      expect(() => make(due: DateTime(2026, 11, 3), remindAt: DateTime(2026, 11, 4, 8)), throwsA(isA<InvalidTransitionException>()));
    });
    test('complete records collection date and result', () {
      final r = svc.complete(make(), now: now, collectionDate: DateTime(2026, 10, 27), resultId: 'lab-1');
      expect(r.status, ReminderStatus.completed);
      expect(r.resultId, 'lab-1');
      expect(r.displayState(now), ReminderDisplayState.completed);
    });
    test('future collection date is rejected', () {
      expect(() => svc.complete(make(), now: now, collectionDate: DateTime(2026, 11, 2)), throwsA(isA<InvalidTransitionException>()));
    });
    test('reschedule moves the due date; cancel is final', () {
      var r = svc.reschedule(make(), newDueDate: DateTime(2026, 11, 10), now: now);
      expect(r.dueDate, DateTime(2026, 11, 10));
      r = svc.cancel(r, now: now, reasonAr: 'طلب الطبيب تأجيله');
      expect(r.displayState(now), ReminderDisplayState.cancelled);
      expect(() => svc.complete(r, now: now), throwsA(isA<InvalidTransitionException>()));
      expect(() => svc.reschedule(r, newDueDate: DateTime(2026, 12, 1), now: now), throwsA(isA<InvalidTransitionException>()));
      expect(() => svc.cancel(r, now: now), throwsA(isA<InvalidTransitionException>()));
    });
    test('completed reminders cannot be completed again', () {
      final r = svc.complete(make(), now: now);
      expect(() => svc.complete(r, now: now), throwsA(isA<InvalidTransitionException>()));
    });
    test('due before appointment lists only open reminders due by the appointment', () {
      final appt = Appointment(id: 'a', userId: 'u1', dateTime: DateTime(2026, 11, 9, 10), clinicLabel: 'x', provenance: DataProvenance.real);
      final before = make(due: DateTime(2026, 11, 3));
      final sameDay = make(due: DateTime(2026, 11, 9));
      final after = make(due: DateTime(2026, 11, 20));
      final done = svc.complete(make(), now: now);
      final list = svc.dueBeforeAppointment([after, sameDay, done, before], appt);
      expect(list.map((r) => r.dueDate).toList(), [DateTime(2026, 11, 3), DateTime(2026, 11, 9)]);
    });
    test('due-now uses remind-at when set', () {
      final soon = make(due: DateTime(2026, 11, 3), remindAt: DateTime(2026, 10, 28, 8));
      final later = make(due: DateTime(2026, 11, 3), remindAt: DateTime(2026, 11, 2, 8));
      expect(svc.dueNow([soon, later], now), hasLength(1));
    });
  });

  group('rule engine', () {
    const engine = RuleEngine();
    Map<MetricKey, double?> base({double veryLow = 0.5, double low = 2, double veryHigh = 3, double high = 20}) => {
          MetricKey.timeVeryLow: veryLow,
          MetricKey.timeLow: low,
          MetricKey.timeInRange: 100 - veryLow - low - high - veryHigh,
          MetricKey.timeHigh: high,
          MetricKey.timeVeryHigh: veryHigh,
        };

    test('all general targets met → routine summary', () {
      final e = engine.evaluate(summaryReport(values: base()), profile: TargetProfile.generalAdultT1T2, now: now);
      expect(e.outcome, ReviewOutcome.routineSummary);
      expect(e.triggered, isEmpty);
      expect(e.rulesVersion, defaultRuleSet.version);
    });
    test('boundary: exactly 1 % below 54 does not meet "< 1 %" and triggers', () {
      final e = engine.evaluate(summaryReport(values: base(veryLow: 1.0)), profile: TargetProfile.generalAdultT1T2, now: now);
      expect(e.outcome, ReviewOutcome.reviewSuggested);
      expect(e.triggered.map((r) => r.rule.id), contains('TBR54-TARGET'));
      expect(e.triggered.first.evidence, isNotEmpty);
    });
    test('0.9 % below 54 does not trigger', () {
      final e = engine.evaluate(summaryReport(values: base(veryLow: 0.9)), profile: TargetProfile.generalAdultT1T2, now: now);
      expect(e.results.firstWhere((r) => r.rule.id == 'TBR54-TARGET').status, RuleStatus.notTriggered);
    });
    test('older/high-risk profile uses its own thresholds', () {
      final values = base(veryLow: 0.2, low: 1.0, veryHigh: 7);
      final general = engine.evaluate(summaryReport(values: values), profile: TargetProfile.generalAdultT1T2, now: now);
      final older = engine.evaluate(summaryReport(values: values), profile: TargetProfile.olderOrHighRisk, now: now);
      expect(general.triggered.map((r) => r.rule.id).toSet(), {'TAR250-TARGET'});
      expect(older.triggered.map((r) => r.rule.id).toSet(), {'TBR70-TARGET'});
      expect(older.results.firstWhere((r) => r.rule.id == 'TBR54-TARGET').status, RuleStatus.notApplicable);
    });
    test('unspecified, pregnancy and pediatric profiles never apply general targets', () {
      for (final p in [TargetProfile.unspecified, TargetProfile.pregnancy, TargetProfile.pediatric]) {
        final e = engine.evaluate(summaryReport(values: base(veryLow: 5)), profile: p, now: now);
        expect(e.outcome, ReviewOutcome.needMoreData);
        expect(e.triggered, isEmpty);
      }
    });
    test('insufficient data blocks rules → need more data', () {
      final e = engine.evaluate(summaryReport(values: base(veryLow: 5), coverage: 62), profile: TargetProfile.generalAdultT1T2, now: now);
      expect(e.outcome, ReviewOutcome.needMoreData);
      expect(e.results.where((r) => r.status == RuleStatus.notAssessable), hasLength(3));
      expect(e.reasonsAr.any((s) => s.contains('70%')), isTrue);
    });
    test('short observation period blocks rules', () {
      final r = summaryReport(values: base(veryLow: 5), period: ReportPeriod(DateTime(2026, 10, 1), DateTime(2026, 10, 7)));
      expect(engine.evaluate(r, profile: TargetProfile.generalAdultT1T2, now: now).outcome, ReviewOutcome.needMoreData);
    });
    test('unverified metric is not assessable', () {
      final values = base()..[MetricKey.timeVeryHigh] = null;
      final r = summaryReport(values: values);
      final e = engine.evaluate(r, profile: TargetProfile.generalAdultT1T2, now: now);
      expect(e.results.firstWhere((x) => x.rule.id == 'TAR250-TARGET').status, RuleStatus.notAssessable);
      expect(e.outcome, ReviewOutcome.needMoreData);
    });
    test('episode rule is not applicable to printed summaries and says why', () {
      final e = engine.evaluate(summaryReport(values: base()), profile: TargetProfile.generalAdultT1T2, now: now);
      expect(e.results.firstWhere((r) => r.rule.id == 'EPI54-REPEATED').status, RuleStatus.notApplicable);
      expect(e.limitationsAr.single, contains('قراءات تفصيلية'));
    });
    test('episode rule on raw readings: 2 episodes trigger, 1 does not', () async {
      final start = DateTime(2026, 10, 1);
      List<GlucoseReading> withLows(int episodes) {
        final vals = List<double>.filled(288 * 14, 130);
        for (var e = 0; e < episodes; e++) {
          final at = 288 * (2 + e * 4) + 36; // 03:00 on days 2, 6, ...
          for (var k = 0; k < 4; k++) {
            vals[at + k] = 48;
          }
        }
        return series(start, vals);
      }

      Future<RuleResult> run(int n) async {
        final comp = const CgmCalculator().compute(withLows(n));
        final rep = CgmReport(
          id: 'raw',
          userId: 'u1',
          provenance: DataProvenance.synthetic,
          sourceType: ReportSourceType.readingsImport,
          glucoseUnit: GlucoseUnit.mgdl,
          metrics: comp.metrics,
          quality: comp.quality,
          createdAt: now,
          metricsPeriod: comp.period,
          readings: comp.cleanedReadings,
        );
        return engine.evaluate(rep, profile: TargetProfile.generalAdultT1T2, now: now).results.firstWhere((r) => r.rule.id == 'EPI54-REPEATED');
      }

      expect((await run(2)).status, RuleStatus.triggered);
      expect((await run(1)).status, RuleStatus.notTriggered);
    });
    test('every default rule is documented and labelled as a demo rule', () {
      for (final r in defaultRuleSet.rules) {
        expect(r.approval, RuleApproval.demonstrationOnly);
        expect(r.sourceRef, isNotEmpty);
        expect(r.limitationsAr, isNotEmpty);
        expect(r.observationWindowAr, isNotEmpty);
        expect(r.duplicatesPolicyAr, isNotEmpty);
        expect(r.gapsPolicyAr, isNotEmpty);
        expect(r.thresholdDescriptionAr, isNotEmpty);
      }
    });
    test('urgent concern always maps to general safety messaging', () {
      expect(engine.urgentConcernOutcome(), ReviewOutcome.seekMedicalHelp);
      expect(ReviewOutcome.seekMedicalHelp.explanationAr, contains('لا يستطيع'));
    });
    test('routine summary wording never claims safety', () {
      expect(ReviewOutcome.routineSummary.explanationAr, contains('لا يعني'));
    });
  });
}
