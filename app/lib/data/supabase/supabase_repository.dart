import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sukkar_core/sukkar_core.dart';

import 'wire.dart';

/// Postgres-backed repository. Row Level Security (supabase/migrations) is the
/// real access control; follow-up status changes go through RPCs that enforce
/// the state machine server-side.
class SupabaseHealthRepository implements HealthRepository {
  SupabaseHealthRepository(this.client);
  final SupabaseClient client;

  @override
  bool get isDemo => false;

  // ------------------------------------------------------------ profile

  @override
  Future<PatientProfile?> getProfile(Actor a) async {
    final p = await client.from('profiles').select('id, pseudo_id, role, target_profile').eq('id', a.userId).maybeSingle();
    if (p == null) return null;
    final ident = await client.from('patient_identities').select('display_name').eq('user_id', a.userId).maybeSingle();
    return PatientProfile(
      userId: a.userId,
      pseudoId: '${p['pseudo_id']}',
      displayName: (ident?['display_name'] as String?) ?? '',
      role: p['role'] == 'reviewer' ? UserRole.reviewer : UserRole.patient,
      targetProfile: fromWire(TargetProfile.values, p['target_profile'], TargetProfile.unspecified),
      provenance: DataProvenance.real,
    );
  }

  @override
  Future<void> saveProfile(Actor a, PatientProfile p) async {
    await client.from('profiles').update({'target_profile': wire(p.targetProfile)}).eq('id', a.userId);
    await client.from('patient_identities').upsert({'user_id': a.userId, 'display_name': p.displayName});
  }

  // ------------------------------------------------------------ reports

  @override
  Future<List<CgmReport>> listReports(Actor a) async {
    final rows = await client
        .from('device_reports')
        .select('*, verified_metrics(*)')
        .eq('status', 'accepted')
        .order('created_at');
    return [for (final r in rows) _report(r)];
  }

  CgmReport _report(Map<String, dynamic> r) {
    final metrics = <MetricKey, MetricValue>{};
    for (final m in (r['verified_metrics'] as List? ?? const [])) {
      final row = m as Map<String, dynamic>;
      final key = metricKeyFromWire('${row['metric_key']}');
      if (key == null) continue;
      metrics[key] = MetricValue(
        key: key,
        value: numOrNull(row['value']),
        unit: '${row['unit']}',
        origin: fromWire(ValueOrigin.values, row['origin'], ValueOrigin.extractedFromReport),
        status: fromWire(VerificationStatus.values, row['verification_status'], VerificationStatus.unavailable),
        originalExtractedValue: numOrNull(row['original_extracted_value']),
        sourcePage: (row['source_page'] as num?)?.toInt(),
        sourceLabel: row['source_label'] as String?,
      );
    }
    ReportPeriod? period(String a, String b) {
      final s = parseDate(r[a]), e = parseDate(r[b]);
      return (s == null || e == null) ? null : ReportPeriod(s, e);
    }

    return CgmReport(
      id: '${r['id']}',
      userId: '${r['user_id']}',
      provenance: fromWire(DataProvenance.values, r['provenance'], DataProvenance.real),
      sourceType: fromWire(ReportSourceType.values, r['source_type'], ReportSourceType.pdfUpload),
      glucoseUnit: GlucoseUnit.mgdl,
      metrics: metrics,
      quality: qualityFromJson(r['data_quality']),
      createdAt: parseDate(r['created_at']) ?? DateTime.now(),
      reportPeriod: period('report_period_start', 'report_period_end'),
      metricsPeriod: period('metrics_period_start', 'metrics_period_end'),
      formatId: r['format_id'] as String?,
      deviceLabel: r['device_label'] as String?,
      warningsAr: [for (final w in (r['warnings'] as List? ?? const [])) '$w'],
    );
  }

  @override
  Future<void> saveReport(Actor a, CgmReport r) async {
    await client.from('device_reports').insert({
      'id': r.id,
      'user_id': a.userId,
      'provenance': wire(r.provenance),
      'source_type': wire(r.sourceType),
      'format_id': r.formatId,
      'device_label': r.deviceLabel,
      'report_period_start': dateOnlyWire(r.reportPeriod?.start),
      'report_period_end': dateOnlyWire(r.reportPeriod?.end),
      'metrics_period_start': dateOnlyWire(r.metricsPeriod?.start),
      'metrics_period_end': dateOnlyWire(r.metricsPeriod?.end),
      'status': 'accepted',
      'data_quality': r.quality.toJson(),
      'warnings': r.warningsAr,
    });
    await client.from('verified_metrics').insert([
      for (final m in r.metrics.values)
        {
          'report_id': r.id,
          'user_id': a.userId,
          'metric_key': m.key.wireName,
          'value': m.isAvailable ? m.value : null,
          'unit': m.unit,
          'origin': wire(m.origin),
          'verification_status': m.isAvailable ? wire(m.status) : 'unavailable',
          'original_extracted_value': m.originalExtractedValue,
          'source_page': m.sourcePage,
          'source_label': m.sourceLabel,
        },
    ]);
  }

  @override
  Future<void> deleteReport(Actor a, String id) async {
    await client.from('device_reports').delete().eq('id', id);
  }

  @override
  Future<void> recordAnalysisRun(Actor a, String reportId, RuleEvaluation e, TargetProfile profile) async {
    await client.from('analysis_runs').insert({
      'report_id': reportId,
      'user_id': a.userId,
      'rules_version': e.rulesVersion,
      'target_profile': wire(profile),
      'outcome': e.outcome.wireName,
      'data_quality': {'reasons': e.reasonsAr, 'limitations': e.limitationsAr},
      'rule_results': [
        for (final r in e.results) {'rule_id': r.rule.id, 'version': r.rule.version, 'status': r.status.name, 'evidence': r.evidence},
      ],
    });
  }

  // --------------------------------------------------------------- labs

  @override
  Future<List<LabResult>> listLabs(Actor a) async {
    final rows = await client.from('lab_results').select().order('collection_date');
    return [
      for (final r in rows)
        LabResult(
          id: '${r['id']}',
          userId: '${r['user_id']}',
          testCode: fromWire(LabTestCode.values, r['test_code'], LabTestCode.other),
          testName: '${r['test_name']}',
          value: numOrNull(r['value']) ?? 0,
          unit: '${r['unit']}',
          collectionDate: parseDate(r['collection_date']),
          source: fromWire(LabSource.values, r['source'], LabSource.manual),
          verification: fromWire(VerificationStatus.values, r['verification_status'], VerificationStatus.needsReview),
          provenance: fromWire(DataProvenance.values, r['provenance'], DataProvenance.real),
          createdAt: parseDate(r['created_at']) ?? DateTime.now(),
          referenceInterval: ReferenceInterval(low: numOrNull(r['ref_low']), high: numOrNull(r['ref_high']), text: r['ref_text'] as String?),
          labName: r['lab_name'] as String?,
        ),
    ];
  }

  @override
  Future<void> saveLab(Actor a, LabResult l) async {
    await client.from('lab_results').upsert({
      'id': l.id,
      'user_id': a.userId,
      'test_code': wire(l.testCode),
      'test_name': l.testName,
      'value': l.value,
      'unit': l.unit,
      'collection_date': dateOnlyWire(l.collectionDate),
      'ref_low': l.referenceInterval?.low,
      'ref_high': l.referenceInterval?.high,
      'ref_text': l.referenceInterval?.text,
      'source': wire(l.source),
      'lab_name': l.labName,
      'verification_status': wire(l.verification),
      'provenance': wire(l.provenance),
    });
  }

  @override
  Future<void> deleteLab(Actor a, String id) async {
    await client.from('lab_results').delete().eq('id', id);
  }

  // ---------------------------------------------------------- reminders

  @override
  Future<List<TestReminder>> listReminders(Actor a) async {
    final rows = await client.from('test_reminders').select().order('due_date');
    return [
      for (final r in rows)
        TestReminder(
          id: '${r['id']}',
          userId: '${r['user_id']}',
          testCode: fromWire(LabTestCode.values, r['test_code'], LabTestCode.other),
          testName: '${r['test_name']}',
          dueDate: parseDate(r['due_date']) ?? DateTime.now(),
          source: fromWire(ScheduleSource.values, r['schedule_source'], ScheduleSource.userConfirmed),
          status: fromWire(ReminderStatus.values, r['status'], ReminderStatus.scheduled),
          provenance: fromWire(DataProvenance.values, r['provenance'], DataProvenance.real),
          remindAt: parseDate(r['remind_at']),
          appointmentId: r['appointment_id'] as String?,
          completedAt: parseDate(r['completed_at']),
          collectionDate: parseDate(r['collection_date']),
          resultId: r['result_id'] as String?,
          note: r['note'] as String?,
          history: [
            for (final h in (r['history'] as List? ?? const []))
              if (h is Map) ReminderEvent(parseDate(h['at']) ?? DateTime.now(), '${h['text']}'),
          ],
        ),
    ];
  }

  @override
  Future<void> saveReminder(Actor a, TestReminder r) async {
    await client.from('test_reminders').upsert({
      'id': r.id,
      'user_id': a.userId,
      'test_code': wire(r.testCode),
      'test_name': r.testName,
      'due_date': dateOnlyWire(r.dueDate),
      'remind_at': r.remindAt?.toUtc().toIso8601String(),
      'appointment_id': r.appointmentId,
      'schedule_source': wire(r.source),
      'status': wire(r.status),
      'completed_at': r.completedAt?.toUtc().toIso8601String(),
      'collection_date': dateOnlyWire(r.collectionDate),
      'result_id': r.resultId,
      'note': r.note,
      'history': [for (final h in r.history) {'at': h.at.toUtc().toIso8601String(), 'text': h.descriptionAr}],
      'provenance': wire(r.provenance),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<List<Appointment>> listAppointments(Actor a) async {
    final rows = await client.from('appointments').select().order('scheduled_at');
    return [
      for (final r in rows)
        Appointment(
          id: '${r['id']}',
          userId: '${r['user_id']}',
          dateTime: parseDate(r['scheduled_at']) ?? DateTime.now(),
          clinicLabel: '${r['clinic_label']}',
          provenance: fromWire(DataProvenance.values, r['provenance'], DataProvenance.real),
        ),
    ];
  }

  // ---------------------------------------------------------- follow-ups

  static const _followUpColumns =
      'id, pseudo_ref, report_id, trigger_type, rule_ids, rules_version, reason, shared_snapshot, status, decision, provenance, '
      'created_at, updated_at, followup_status_history(from_status, to_status, actor_role, note, created_at), '
      'review_notes(author_label, body, created_at), integration_events(adapter, state, attempts, last_error, last_attempt_at)';

  @override
  Future<List<FollowUpRequest>> listFollowUps(Actor a) async {
    final rows = await client.from('followup_requests').select(_followUpColumns).order('updated_at', ascending: false);
    return [for (final r in rows) _followUp(r, a)];
  }

  FollowUpRequest _followUp(Map<String, dynamic> r, Actor a) {
    final snap = r['shared_snapshot'] as Map? ?? const {};
    final history = [
      for (final h in (r['followup_status_history'] as List? ?? const []))
        if (h is Map)
          StatusHistoryEntry(
            from: followUpStatusFromWire('${h['from_status']}'),
            to: followUpStatusFromWire('${h['to_status']}') ?? FollowUpStatus.draft,
            at: parseDate(h['created_at']) ?? DateTime.now(),
            actorRole: h['actor_role'] == 'reviewer' ? UserRole.reviewer : UserRole.patient,
            noteAr: h['note'] as String?,
          ),
    ]..sort((x, y) => x.at.compareTo(y.at));
    final events = (r['integration_events'] as List? ?? const []).whereType<Map<dynamic, dynamic>>().toList();
    final last = events.isEmpty ? null : events.last;
    return FollowUpRequest(
      id: '${r['id']}',
      pseudoId: '${r['pseudo_ref']}',
      // user_id is not readable through the API (column grants); patients
      // only ever receive their own rows.
      userId: a.role == UserRole.patient ? a.userId : '',
      trigger: r['trigger_type'] == 'rule' ? FollowUpTrigger.rule : FollowUpTrigger.userRequest,
      ruleIds: [for (final x in (r['rule_ids'] as List? ?? const [])) '$x'],
      rulesVersion: '${r['rules_version']}',
      reasonAr: '${r['reason']}',
      snapshot: SharedSnapshot(
        periodLabel: '${snap['period'] ?? ''}',
        items: {for (final e in ((snap['items'] as Map<dynamic, dynamic>?) ?? const {}).entries) '${e.key}': '${e.value}'},
        qualityNotesAr: [for (final q in (snap['quality_notes'] as List? ?? const [])) '$q'],
      ),
      status: followUpStatusFromWire('${r['status']}') ?? FollowUpStatus.draft,
      idempotencyKey: '',
      createdAt: parseDate(r['created_at']) ?? DateTime.now(),
      updatedAt: parseDate(r['updated_at']) ?? DateTime.now(),
      provenance: fromWire(DataProvenance.values, r['provenance'], DataProvenance.real),
      reportId: r['report_id'] as String?,
      decision: r['decision'] == null ? null : fromWire(ReviewDecision.values, r['decision'], ReviewDecision.noFurtherActionDemo),
      history: history,
      notes: [
        for (final n in (r['review_notes'] as List? ?? const []))
          if (n is Map) ReviewNote(at: parseDate(n['created_at']) ?? DateTime.now(), textAr: '${n['body']}', authorLabel: '${n['author_label']}'),
      ],
      dispatch: last == null
          ? IntegrationDispatch.none
          : IntegrationDispatch(
              state: switch (last['state']) {
                'sent' => DispatchState.sent,
                'mock_recorded' => DispatchState.mockRecorded,
                'failed' => DispatchState.failed,
                _ => DispatchState.notSent,
              },
              adapterName: '${last['adapter']}',
              isMock: last['adapter'] != 'make_webhook',
              attempts: (last['attempts'] as num?)?.toInt() ?? 0,
              lastError: last['last_error'] as String?,
              lastAttemptAt: parseDate(last['last_attempt_at']),
            ),
    );
  }

  @override
  Future<void> createFollowUp(Actor a, FollowUpRequest draft) async {
    try {
      await client.from('followup_requests').insert({
        'id': draft.id,
        'user_id': a.userId,
        'report_id': draft.reportId,
        'trigger_type': draft.trigger.wireName,
        'rule_ids': draft.ruleIds,
        'rules_version': draft.rulesVersion,
        'reason': draft.reasonAr,
        'shared_snapshot': draft.snapshot.toJson(),
        'idempotency_key': draft.idempotencyKey,
        'provenance': wire(draft.provenance),
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw DuplicateRequestException('');
      rethrow;
    }
  }

  @override
  Future<void> applyFollowUpTransition(Actor a, FollowUpRequest before, FollowUpRequest after) async {
    final id = before.id;
    final newNote = after.notes.length > before.notes.length ? after.notes.last.textAr : null;
    if (after.status != before.status) {
      switch (after.status) {
        case FollowUpStatus.awaitingReview:
          await client.rpc<void>('submit_followup', params: {'p_request_id': id, 'p_note': after.history.last.noteAr});
        case FollowUpStatus.underReview:
          await client.rpc<void>('reviewer_start_review', params: {'p_request_id': id});
        case FollowUpStatus.moreInfoRequested:
        case FollowUpStatus.reviewed:
          await client.rpc<void>('reviewer_decide', params: {'p_request_id': id, 'p_decision': after.decision!.wireName, 'p_note': newNote});
        case FollowUpStatus.closed:
          await client.rpc<void>(before.status == FollowUpStatus.reviewed ? 'close_followup' : 'withdraw_followup', params: {'p_request_id': id});
        case FollowUpStatus.draft:
          throw InvalidTransitionException('انتقال غير مدعوم.');
      }
    } else if (newNote != null) {
      await client.rpc<void>('reviewer_add_note', params: {'p_request_id': id, 'p_note': newNote});
    }
  }

  // ------------------------------------------------------------- consent

  @override
  Future<ConsentRecord?> activeConsent(Actor a) async {
    final r = await client
        .from('consents')
        .select()
        .isFilter('revoked_at', null)
        .order('granted_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (r == null) return null;
    return ConsentRecord(
      id: '${r['id']}',
      userId: a.userId,
      version: '${r['version']}',
      grantedAt: parseDate(r['granted_at']) ?? DateTime.now(),
      allowsExternalAi: r['allows_external_ai'] == true,
    );
  }

  @override
  Future<void> saveConsent(Actor a, ConsentRecord c) async {
    await client.from('consents').upsert({
      'id': c.id,
      'user_id': a.userId,
      'version': c.version,
      'allows_external_ai': c.allowsExternalAi,
      'granted_at': c.grantedAt.toUtc().toIso8601String(),
      'revoked_at': c.revokedAt?.toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> deleteAllMyData(Actor a) async {
    await client.rpc<void>('delete_my_data');
  }
}
