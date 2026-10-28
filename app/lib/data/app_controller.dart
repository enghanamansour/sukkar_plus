import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:sukkar_core/sukkar_core.dart';

import 'app_state.dart';
import 'platform/pdf_text.dart';
import 'providers.dart';
import 'services/backend_services.dart';
import 'supabase/wire.dart';

/// Orchestrates every user action. All medical logic lives in sukkar_core;
/// this class only sequences it, persists results and refreshes state.
class AppController extends Notifier<AppState> {
  static const _wf = FollowUpWorkflow();
  static const _reminders = ReminderService();

  @override
  AppState build() {
    final cfg = ref.read(configProvider);
    Future.microtask(_init);
    return AppState.initial(demoMode: cfg.demoMode);
  }

  DateTime get _now => ref.read(clockProvider)();
  HealthRepository get _repo => ref.read(repositoryProvider);
  Actor get _actor => state.actor ?? (throw UserFacingError('يرجى تسجيل الدخول أولًا.'));

  Future<void> _init() async {
    if (state.demoMode) {
      state = state.copyWith(actor: demoPatientActor);
      await reload();
      _addDueReminderNotices();
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      state = state.copyWith(ready: true);
      return;
    }
    await _loadLiveActor(user.id);
  }

  Future<void> _loadLiveActor(String userId) async {
    final probe = Actor(userId: userId, role: UserRole.patient);
    final profile = await _repo.getProfile(probe);
    final role = profile?.role ?? UserRole.patient;
    state = state.copyWith(actor: Actor(userId: userId, role: role), profile: profile, onboardingDone: true);
    await reload();
  }

  /// Reloads everything visible to the current actor.
  Future<void> reload() async {
    final a = state.actor;
    if (a == null) return;
    try {
      final profile = await _repo.getProfile(a);
      if (a.role == UserRole.reviewer) {
        state = state.copyWith(
          ready: true,
          profile: profile,
          followUps: await _repo.listFollowUps(a),
          reports: const [],
          labs: const [],
          reminders: const [],
          appointments: const [],
          clearError: true,
        );
        return;
      }
      final consent = await _repo.activeConsent(a);
      state = state.copyWith(
        ready: true,
        profile: profile,
        reports: await _repo.listReports(a),
        labs: await _repo.listLabs(a),
        reminders: await _repo.listReminders(a),
        appointments: await _repo.listAppointments(a),
        followUps: await _repo.listFollowUps(a),
        consent: consent,
        clearConsent: consent == null,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(ready: true, errorAr: 'تعذّر تحميل البيانات. تحقق من الاتصال ثم أعد المحاولة.');
    }
  }

  // ------------------------------------------------------------ session

  Future<void> signIn(String email, String password) async {
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(email: email.trim(), password: password);
      final user = res.user;
      if (user == null) throw UserFacingError('تعذّر تسجيل الدخول.');
      await _loadLiveActor(user.id);
    } on UserFacingError {
      rethrow;
    } catch (_) {
      throw UserFacingError('البريد الإلكتروني أو كلمة المرور غير صحيحة.');
    }
  }

  Future<void> signOut() async {
    if (!state.demoMode) await Supabase.instance.client.auth.signOut();
    state = state.copyWith(clearActor: true, reports: const [], labs: const [], reminders: const [], followUps: const [], appointments: const []);
  }

  void completeOnboarding() => state = state.copyWith(onboardingDone: true);

  /// Demo only: switch between the synthetic patient and the demo reviewer.
  /// Real role changes are an administrator action in the database.
  Future<void> switchDemoRole(UserRole role) async {
    if (!state.demoMode) throw UserFacingError('تبديل الدور متاح في وضع العرض فقط.');
    state = state.copyWith(actor: role == UserRole.reviewer ? demoReviewerActor : demoPatientActor);
    await reload();
  }

  Future<void> resetDemo() async {
    if (!state.demoMode) return;
    ref.invalidate(repositoryProvider);
    ref.invalidate(mockNotifierProvider);
    state = AppState.initial(demoMode: true).copyWith(actor: demoPatientActor, onboardingDone: true);
    await reload();
    _addDueReminderNotices();
  }

  // ------------------------------------------------------- consent/profile

  Future<void> grantConsent({required bool allowExternalAi}) async {
    final c = ConsentRecord(
      id: newUuid(),
      userId: _actor.userId,
      version: ConsentRecord.currentVersion,
      grantedAt: _now,
      allowsExternalAi: allowExternalAi && !state.demoMode,
    );
    await _repo.saveConsent(_actor, c);
    state = state.copyWith(consent: c, onboardingDone: true);
  }

  Future<void> revokeConsent() async {
    final c = state.consent;
    if (c == null) return;
    await _repo.saveConsent(
      _actor,
      ConsentRecord(id: c.id, userId: c.userId, version: c.version, grantedAt: c.grantedAt, allowsExternalAi: c.allowsExternalAi, revokedAt: _now),
    );
    state = state.copyWith(clearConsent: true);
  }

  Future<void> setTargetProfile(TargetProfile p) async {
    final profile = state.profile;
    if (profile == null) return;
    final updated = profile.copyWith(targetProfile: p);
    await _repo.saveProfile(_actor, updated);
    state = state.copyWith(profile: updated);
  }

  Future<void> deleteAllMyData() async {
    await _repo.deleteAllMyData(_actor);
    state = state.copyWith(clearConsent: true, clearUpload: true);
    await reload();
  }

  // --------------------------------------------------------------- upload

  /// Validates and extracts a PDF. Stages are reported via [onStage].
  /// Real files require consent; demo fixtures never claim consent.
  Future<void> startUpload({
    required String fileName,
    required Uint8List bytes,
    required bool isDemoFixture,
    bool useAi = false,
    void Function(String stageAr)? onStage,
  }) async {
    if (!isDemoFixture && state.consent == null) {
      throw UserFacingError('يلزم إكمال الموافقة قبل معالجة تقرير حقيقي.');
    }
    onStage?.call('التحقق من الملف');
    final v = validatePdfBytes(fileName, bytes);
    if (!v.isValid) throw UserFacingError(v.messageAr);

    onStage?.call('قراءة نص الملف على الجهاز');
    List<String> pages;
    try {
      pages = await ref.read(pdfTextExtractorProvider).extractPages(bytes);
    } on PdfReadException catch (e) {
      throw UserFacingError(e.messageAr);
    }
    if (pages.every((p) => p.trim().isEmpty)) {
      throw UserFacingError('لا يحتوي الملف على نص قابل للقراءة (قد يكون صورة ممسوحة ضوئيًا). هذا النوع غير مدعوم حاليًا.');
    }

    onStage?.call('استخراج المؤشرات والتحقق منها');
    var result = reportTextParser.parse(pages);
    String? aiNote;
    final ai = ref.read(aiExtractionProvider);
    if (useAi && !isDemoFixture) {
      if (!(state.consent?.allowsExternalAi ?? false)) {
        aiNote = 'لم يُرسل الملف للذكاء الاصطناعي لأنك لم توافق على المعالجة الخارجية.';
      } else if (!ai.isAvailable) {
        aiNote = 'الذكاء الاصطناعي غير مفعّل؛ استُخدمت القراءة المحلية فقط.';
      } else {
        onStage?.call('مقارنة القيم مع استخراج الذكاء الاصطناعي');
        try {
          result = reconcileWithAi(result, await ai.extract(bytes));
          aiNote = 'قورنت القيم المحلية مع استخراج Gemini عبر الخادم.';
        } on ServiceUnavailable catch (e) {
          aiNote = e.messageAr;
        }
      }
    }
    if (result.isEmpty) {
      throw UserFacingError('لم نعثر على مؤشرات سكر معروفة في الملف. التنسيق المدعوم: صفحة الملخص في تقرير Omnipod Discover (Omnipod 5 وDexcom G7).');
    }
    state = state.copyWith(
      upload: UploadSession(
        fileName: fileName,
        sizeBytes: bytes.length,
        isDemoFixture: isDemoFixture,
        result: result,
        startedAt: _now,
        aiNoteAr: aiNote,
      ),
    );
  }

  void _updateUpload(ExtractionResult Function(ExtractionResult) f) {
    final u = state.upload;
    if (u == null) return;
    state = state.copyWith(upload: u.copyWith(result: f(u.result)));
  }

  void confirmField(MetricKey k) => _updateUpload((r) => ExtractionReview.confirm(r, k));
  void markUnavailable(MetricKey k) => _updateUpload((r) => ExtractionReview.markUnavailable(r, k));
  void restoreField(MetricKey k) => _updateUpload((r) => ExtractionReview.restoreExtracted(r, k));
  void confirmAllEligible() => _updateUpload(ExtractionReview.confirmAllEligible);

  void correctField(MetricKey k, double value) {
    try {
      _updateUpload((r) => ExtractionReview.correct(r, k, value));
    } on ArgumentError catch (e) {
      throw UserFacingError('${e.message}');
    }
  }

  void setPeriodOverride(ReportPeriod p) {
    final u = state.upload;
    if (u != null) state = state.copyWith(upload: u.copyWith(periodOverride: p));
  }

  void discardUpload() => state = state.copyWith(clearUpload: true);

  /// Saves the reviewed report and its rule evaluation. Returns the report id.
  Future<String> acceptUpload() async {
    final u = state.upload;
    if (u == null) throw UserFacingError('لا يوجد تقرير قيد المراجعة.');
    final CgmReport report;
    try {
      report = buildReportFromExtraction(
        u.result,
        id: newUuid(),
        userId: _actor.userId,
        provenance: u.isDemoFixture ? DataProvenance.synthetic : DataProvenance.real,
        sourceType: u.isDemoFixture ? ReportSourceType.demoFixture : ReportSourceType.pdfUpload,
        createdAt: _now,
        metricsPeriodOverride: u.periodOverride,
      );
    } on ExtractionNotReviewedException catch (e) {
      throw UserFacingError('بقيت ${e.pending.length} قيمة تحتاج تأكيدًا أو تحديدها كغير متاحة.');
    }
    await _repo.saveReport(_actor, report);
    final eval = ref.read(ruleEngineProvider).evaluate(report, profile: state.targetProfile, now: _now);
    await _repo.recordAnalysisRun(_actor, report.id, eval, state.targetProfile);
    state = state.copyWith(clearUpload: true);
    await reload();
    return report.id;
  }

  Future<void> deleteReport(String id) async {
    await _repo.deleteReport(_actor, id);
    await reload();
  }

  // ----------------------------------------------------------------- labs

  Future<LabResult> addLab({
    required LabTestCode code,
    required String testName,
    required double? value,
    required String unit,
    required DateTime? collectionDate,
    ReferenceInterval? referenceInterval,
    String? labName,
    String? linkedReminderId,
  }) async {
    final issues = validateLabEntry(
      code: code,
      testName: testName,
      value: value,
      unit: unit,
      collectionDate: collectionDate,
      now: _now,
      referenceInterval: referenceInterval,
    );
    if (issues.isNotEmpty) throw UserFacingError(issues.map((i) => i.messageAr).join('\n'));
    final lab = LabResult(
      id: newUuid(),
      userId: _actor.userId,
      testCode: code,
      testName: code == LabTestCode.other ? testName.trim() : code.labelAr,
      value: value!,
      unit: unit.trim(),
      collectionDate: collectionDate == null ? null : dateOnly(collectionDate),
      source: LabSource.manual,
      // The user typed and reviewed the value in the form.
      verification: VerificationStatus.verified,
      provenance: state.demoMode ? DataProvenance.synthetic : DataProvenance.real,
      createdAt: _now,
      referenceInterval: (referenceInterval == null || referenceInterval.isEmpty) ? null : referenceInterval,
      labName: (labName == null || labName.trim().isEmpty) ? null : labName.trim(),
      linkedReminderId: linkedReminderId,
    );
    await _repo.saveLab(_actor, lab);
    if (linkedReminderId != null) {
      for (final r in state.reminders) {
        if (r.id == linkedReminderId && r.isOpen) {
          await _repo.saveReminder(_actor, _reminders.complete(r, now: _now, collectionDate: collectionDate, resultId: lab.id));
        }
      }
    }
    await reload();
    return lab;
  }

  Future<void> deleteLab(String id) async {
    await _repo.deleteLab(_actor, id);
    await reload();
  }

  // ------------------------------------------------------------ reminders

  Future<void> createReminder({
    required LabTestCode code,
    required String testName,
    required DateTime dueDate,
    required ScheduleSource source,
    DateTime? remindAt,
    String? appointmentId,
    String? note,
  }) async {
    final TestReminder r;
    try {
      r = _reminders.create(
        id: newUuid(),
        userId: _actor.userId,
        testCode: code,
        testName: testName,
        dueDate: dueDate,
        source: source,
        now: _now,
        remindAt: remindAt,
        appointmentId: appointmentId,
        note: note,
        provenance: state.demoMode ? DataProvenance.synthetic : DataProvenance.real,
      );
    } on InvalidTransitionException catch (e) {
      throw UserFacingError(e.messageAr);
    }
    await _repo.saveReminder(_actor, r);
    await reload();
  }

  Future<void> _reminderAction(TestReminder Function() f) async {
    try {
      await _repo.saveReminder(_actor, f());
    } on InvalidTransitionException catch (e) {
      throw UserFacingError(e.messageAr);
    }
    await reload();
  }

  Future<void> completeReminder(TestReminder r, {DateTime? collectionDate}) =>
      _reminderAction(() => _reminders.complete(r, now: _now, collectionDate: collectionDate));
  Future<void> rescheduleReminder(TestReminder r, DateTime due, {DateTime? remindAt}) =>
      _reminderAction(() => _reminders.reschedule(r, newDueDate: due, now: _now, newRemindAt: remindAt));
  Future<void> cancelReminder(TestReminder r) => _reminderAction(() => _reminders.cancel(r, now: _now));

  void _addDueReminderNotices() {
    final due = _reminders.dueNow(state.reminders, _now);
    if (due.isEmpty) return;
    state = state.copyWith(notices: [
      for (final r in due)
        AppNotice(
          id: 'rem-${r.id}',
          textAr: 'تذكير: ${r.testName} — الاستحقاق ${arDate(r.dueDate)}',
          at: _now,
          simulated: true,
          route: '/reminders',
        ),
      ...state.notices,
    ]);
  }

  void dismissNotice(String id) => state = state.copyWith(notices: state.notices.where((n) => n.id != id).toList());

  // ----------------------------------------------------- follow-up (patient)

  /// Creates the request and submits it in one confirmed step (the patient
  /// has already reviewed the reason and the information to be shared).
  Future<FollowUpRequest> createAndSubmitFollowUp({
    required CgmReport report,
    required RuleEvaluation evaluation,
    required FollowUpTrigger trigger,
    String? userNoteAr,
  }) async {
    final a = _actor;
    final triggered = evaluation.triggered;
    final reason = trigger == FollowUpTrigger.rule
        ? triggered.map((r) => r.explanationAr).join('\n')
        : 'طلب المستخدم مراجعة بشرية لهذا التقرير.${(userNoteAr == null || userNoteAr.trim().isEmpty) ? '' : '\nملاحظة المستخدم: ${userNoteAr.trim()}'}';
    final FollowUpRequest draft;
    try {
      draft = _wf.createDraft(
        id: newUuid(),
        pseudoId: newPseudoRef('REQ'),
        userId: a.userId,
        trigger: trigger,
        ruleIds: trigger == FollowUpTrigger.rule ? [for (final r in triggered) r.rule.id] : const [],
        rulesVersion: evaluation.rulesVersion,
        reasonAr: reason,
        snapshot: snapshotFromReport(report),
        now: _now,
        existing: state.followUps,
        provenance: report.provenance,
        reportId: report.id,
      );
      await _repo.createFollowUp(a, draft);
    } on DuplicateRequestException {
      throw UserFacingError('يوجد طلب مراجعة مفتوح لهذا التقرير وللسبب نفسه. يمكنك متابعة حالته من قائمة الطلبات.');
    }
    final dispatcher = ref.read(dispatcherProvider);
    if (state.demoMode) {
      final submitted = _wf.submit(draft, a, _now);
      await _repo.applyFollowUpTransition(a, draft, submitted);
      final outcome = await dispatcher.submit(submitted);
      final withDispatch = submitted.copyWith(dispatch: outcome.dispatch);
      await _repo.applyFollowUpTransition(a, submitted, withDispatch);
      _notice('أُرسل طلب المراجعة ${draft.pseudoId} إلى لوحة المراجع التجريبي (محاكاة — لم يُرسل لأي جهة صحية).', '/followup/${draft.id}');
    } else {
      try {
        await dispatcher.submit(draft);
      } on ServiceUnavailable catch (e) {
        await reload();
        throw UserFacingError(e.messageAr);
      }
    }
    await reload();
    return state.followUpById(draft.id) ?? draft;
  }

  Future<void> resubmitFollowUp(FollowUpRequest r, String noteAr) async {
    if (state.demoMode) {
      final next = _wf.submit(r, _actor, _now, noteAr: noteAr);
      await _repo.applyFollowUpTransition(_actor, r, next);
      final outcome = await ref.read(dispatcherProvider).submit(next);
      await _repo.applyFollowUpTransition(_actor, next, next.copyWith(dispatch: outcome.dispatch));
    } else {
      await ref.read(dispatcherProvider).submit(r, noteAr: noteAr);
    }
    await reload();
  }

  Future<void> retryDispatch(FollowUpRequest r) async {
    final outcome = await ref.read(dispatcherProvider).retry(r);
    if (state.demoMode) await _repo.applyFollowUpTransition(_actor, r, r.copyWith(dispatch: outcome.dispatch));
    await reload();
  }

  Future<void> withdrawFollowUp(FollowUpRequest r) => _transition(r, () => _wf.withdraw(r, _actor, _now));
  Future<void> closeFollowUp(FollowUpRequest r) => _transition(r, () => _wf.close(r, _actor, _now));

  // ---------------------------------------------------- follow-up (reviewer)

  Future<void> startReview(FollowUpRequest r) => _transition(r, () => _wf.startReview(r, _actor, _now));

  Future<void> decide(FollowUpRequest r, ReviewDecision d, {String? noteAr}) async {
    await _transition(r, () => _wf.decide(r, _actor, _now, d, noteAr: noteAr));
    if (state.demoMode) {
      _notice('تحديث على الطلب ${r.pseudoId}: ${d.labelAr} (محاكاة).', '/followup/${r.id}');
    }
  }

  Future<void> addReviewNote(FollowUpRequest r, String text) => _transition(r, () => _wf.addNote(r, _actor, _now, text));

  Future<void> _transition(FollowUpRequest r, FollowUpRequest Function() f) async {
    try {
      await _repo.applyFollowUpTransition(_actor, r, f());
    } on InvalidTransitionException catch (e) {
      throw UserFacingError(e.messageAr);
    } on AccessDeniedException catch (e) {
      throw UserFacingError(e.messageAr);
    }
    await reload();
  }

  void _notice(String text, String route) {
    state = state.copyWith(notices: [AppNotice(id: newUuid(), textAr: text, at: _now, simulated: true, route: route), ...state.notices]);
  }

  // ---------------------------------------------------------- explanation

  Future<Explanation> explain(ExplanationContext ctx) => ref.read(explanationProvider).explain(ctx);
}
