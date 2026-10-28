import 'package:sukkar_core/sukkar_core.dart';
import 'package:test/test.dart';

void main() {
  const wf = FollowUpWorkflow();
  const patient = Actor(userId: 'p1', role: UserRole.patient);
  const otherPatient = Actor(userId: 'p2', role: UserRole.patient);
  const reviewer = Actor(userId: 'rv1', role: UserRole.reviewer);
  final t = DateTime(2026, 10, 28, 10);
  const snap = SharedSnapshot(periodLabel: '2026-10-13 — 2026-10-26', items: {'TIR': '65.5%'});

  FollowUpRequest draft({List<FollowUpRequest> existing = const [], String id = 'f1', String? reportId = 'rep1'}) => wf.createDraft(
        id: id,
        pseudoId: 'REQ-TEST',
        userId: 'p1',
        trigger: FollowUpTrigger.rule,
        ruleIds: const ['TBR54-TARGET', 'TAR250-TARGET'],
        rulesVersion: defaultRuleSet.version,
        reasonAr: 'سبب',
        snapshot: snap,
        now: t,
        existing: existing,
        provenance: DataProvenance.synthetic,
        reportId: reportId,
      );

  group('state machine', () {
    test('full path: draft → awaiting → under review → reviewed → closed', () {
      var r = draft();
      expect(r.status, FollowUpStatus.draft);
      r = wf.submit(r, patient, t);
      expect(r.status, FollowUpStatus.awaitingReview);
      r = wf.startReview(r, reviewer, t);
      expect(r.status, FollowUpStatus.underReview);
      r = wf.decide(r, reviewer, t, ReviewDecision.reviewRequired, noteAr: 'ملاحظة');
      expect(r.status, FollowUpStatus.reviewed);
      expect(r.decision, ReviewDecision.reviewRequired);
      expect(r.notes.single.authorLabel, FollowUpWorkflow.demoReviewerLabel);
      r = wf.close(r, patient, t);
      expect(r.status, FollowUpStatus.closed);
      expect(r.history.map((h) => h.to).toList(), [
        FollowUpStatus.draft,
        FollowUpStatus.awaitingReview,
        FollowUpStatus.underReview,
        FollowUpStatus.reviewed,
        FollowUpStatus.closed,
      ]);
    });
    test('data completion loops back through more-info-requested', () {
      var r = wf.startReview(wf.submit(draft(), patient, t), reviewer, t);
      r = wf.decide(r, reviewer, t, ReviewDecision.dataCompletion);
      expect(r.status, FollowUpStatus.moreInfoRequested);
      r = wf.submit(r, patient, t, noteAr: 'أضفت تقريرًا');
      expect(r.status, FollowUpStatus.awaitingReview);
    });
    test('invalid transitions are refused', () {
      final d = draft();
      expect(() => wf.startReview(d, reviewer, t), throwsA(isA<InvalidTransitionException>()));
      final submitted = wf.submit(d, patient, t);
      expect(() => wf.decide(submitted, reviewer, t, ReviewDecision.reviewRequired), throwsA(isA<InvalidTransitionException>()));
      expect(() => wf.submit(submitted, patient, t), throwsA(isA<InvalidTransitionException>()));
      expect(() => wf.close(submitted, patient, t), throwsA(isA<InvalidTransitionException>()));
      final under = wf.startReview(submitted, reviewer, t);
      expect(() => wf.withdraw(under, patient, t), throwsA(isA<InvalidTransitionException>()));
    });
    test('patient may withdraw before review starts', () {
      final r = wf.withdraw(wf.submit(draft(), patient, t), patient, t);
      expect(r.status, FollowUpStatus.closed);
    });
  });

  group('authorization', () {
    test('patients cannot perform reviewer actions', () {
      final s = wf.submit(draft(), patient, t);
      expect(() => wf.startReview(s, patient, t), throwsA(isA<AccessDeniedException>()));
      final u = wf.startReview(s, reviewer, t);
      expect(() => wf.decide(u, patient, t, ReviewDecision.noFurtherActionDemo), throwsA(isA<AccessDeniedException>()));
      expect(() => wf.addNote(u, patient, t, 'x'), throwsA(isA<AccessDeniedException>()));
    });
    test('another patient cannot submit or view', () {
      final d = draft();
      expect(() => wf.submit(d, otherPatient, t), throwsA(isA<AccessDeniedException>()));
      expect(const FollowUpAccessPolicy().can(otherPatient, FollowUpAction.view, wf.submit(d, patient, t)), isFalse);
    });
    test('reviewers cannot submit on behalf of patients and cannot see drafts', () {
      final d = draft();
      expect(() => wf.submit(d, reviewer, t), throwsA(isA<AccessDeniedException>()));
      expect(const FollowUpAccessPolicy().can(reviewer, FollowUpAction.view, d), isFalse);
      expect(const FollowUpAccessPolicy().can(reviewer, FollowUpAction.view, wf.submit(d, patient, t)), isTrue);
    });
  });

  group('duplicate prevention', () {
    test('an open request with the same key blocks a new one', () {
      final first = wf.submit(draft(), patient, t);
      expect(() => draft(existing: [first], id: 'f2'), throwsA(isA<DuplicateRequestException>()));
    });
    test('rule order does not change the idempotency key', () {
      final a = followUpIdempotencyKey(userId: 'p1', reportId: 'r', trigger: FollowUpTrigger.rule, ruleIds: ['B', 'A']);
      final b = followUpIdempotencyKey(userId: 'p1', reportId: 'r', trigger: FollowUpTrigger.rule, ruleIds: ['A', 'B']);
      expect(a, b);
    });
    test('a closed request does not block, and a different report does not block', () {
      final closed = wf.withdraw(draft(), patient, t);
      expect(draft(existing: [closed], id: 'f2').status, FollowUpStatus.draft);
      final open = wf.submit(draft(), patient, t);
      expect(draft(existing: [open], id: 'f3', reportId: 'rep2').status, FollowUpStatus.draft);
    });
  });

  group('repository: reviewer decision becomes visible to the patient', () {
    test('end-to-end through the in-memory repository', () async {
      final repo = InMemoryHealthRepository();
      final d = draft();
      await repo.createFollowUp(patient, d);
      expect(await repo.listFollowUps(reviewer), isEmpty, reason: 'drafts are hidden from reviewers');

      final s = wf.submit(d, patient, t);
      await repo.applyFollowUpTransition(patient, d, s);
      final seen = (await repo.listFollowUps(reviewer)).single;
      final u = wf.startReview(seen, reviewer, t);
      await repo.applyFollowUpTransition(reviewer, seen, u);
      final dec = wf.decide(u, reviewer, t, ReviewDecision.dataCompletion, noteAr: 'أرجو رفع تقرير أحدث');
      await repo.applyFollowUpTransition(reviewer, u, dec);

      final mine = (await repo.listFollowUps(patient)).single;
      expect(mine.status, FollowUpStatus.moreInfoRequested);
      expect(mine.decision!.patientMessageAr, isNotEmpty);
      expect(mine.notes.single.textAr, 'أرجو رفع تقرير أحدث');
      expect(await repo.listFollowUps(otherPatient), isEmpty);
    });
    test('stale transitions and tampering are refused', () async {
      final repo = InMemoryHealthRepository();
      final d = draft();
      await repo.createFollowUp(patient, d);
      final s = wf.submit(d, patient, t);
      await repo.applyFollowUpTransition(patient, d, s);
      expect(() => repo.applyFollowUpTransition(patient, d, s), throwsA(isA<InvalidTransitionException>()));
      expect(() => repo.createFollowUp(patient, draft(id: 'dup')), throwsA(isA<DuplicateRequestException>()));
      expect(() => repo.createFollowUp(reviewer, draft(id: 'x', reportId: 'other')), throwsA(isA<AccessDeniedException>()));
    });
    test('patient data tables are not readable by reviewers', () async {
      final repo = InMemoryHealthRepository();
      expect(() => repo.listLabs(reviewer), throwsA(isA<AccessDeniedException>()));
      expect(() => repo.listReports(reviewer), throwsA(isA<AccessDeniedException>()));
    });
    test('a patient cannot write another patient\'s records', () async {
      final repo = InMemoryHealthRepository();
      final lab = LabResult(
          id: 'l', userId: 'p2', testCode: LabTestCode.hba1c, testName: 'x', value: 7, unit: '%', collectionDate: t,
          source: LabSource.manual, verification: VerificationStatus.verified, provenance: DataProvenance.real, createdAt: t);
      expect(() => repo.saveLab(patient, lab), throwsA(isA<AccessDeniedException>()));
    });
    test('outside demo mode a user cannot change their own role', () async {
      final repo = InMemoryHealthRepository(isDemo: false);
      const p = PatientProfile(userId: 'p1', pseudoId: 'SP-1', displayName: 'x', role: UserRole.patient, targetProfile: TargetProfile.unspecified, provenance: DataProvenance.real);
      await repo.saveProfile(patient, p);
      expect(() => repo.saveProfile(patient, p.copyWith(role: UserRole.reviewer)), throwsA(isA<AccessDeniedException>()));
    });
  });

  group('automation payload and mock notifier', () {
    test('payload is minimal and pseudonymous', () {
      final r = wf.submit(draft(), patient, t);
      final p = buildFollowUpEventPayload(r, demo: true);
      expect(p.keys.toSet(), {
        'schema_version', 'event_type', 'request_ref', 'status', 'trigger_type', 'rule_ids', 'rules_version', 'submitted_at', 'environment',
      });
      expect(p['request_ref'], 'REQ-TEST');
      expect(p['rule_ids'], ['TAR250-TARGET', 'TBR54-TARGET']);
      expect(p.keys.any(forbiddenPayloadKeys.contains), isFalse);
      expect(p.values.whereType<String>().any((v) => v.contains('p1')), isFalse);
      expect(p['environment'], 'demo');
    });
    test('mock is idempotent and labelled as a mock', () async {
      final m = MockFollowUpNotifier(clock: () => t);
      final payload = buildFollowUpEventPayload(wf.submit(draft(), patient, t), demo: true);
      final a = await m.notify(payload, idempotencyKey: 'k1');
      final b = await m.notify(payload, idempotencyKey: 'k1');
      expect(a.state, DispatchState.mockRecorded);
      expect(a.isMock, isTrue);
      expect(b.duplicate, isTrue);
      expect(m.events, hasLength(1));
    });
    test('failure can be retried with the same key', () async {
      final m = MockFollowUpNotifier(failNext: true);
      final payload = buildFollowUpEventPayload(wf.submit(draft(), patient, t), demo: true);
      expect((await m.notify(payload, idempotencyKey: 'k')).state, DispatchState.failed);
      expect((await m.notify(payload, idempotencyKey: 'k')).state, DispatchState.mockRecorded);
      expect(m.events, hasLength(1));
    });
    test('forbidden keys are refused by the mock', () async {
      final m = MockFollowUpNotifier();
      expect(() => m.notify({'name': 'x'}, idempotencyKey: 'z'), throwsArgumentError);
    });
  });
}
