import '../followup/followup_workflow.dart';
import '../models/care.dart';
import '../models/cgm.dart';
import '../models/enums.dart';
import '../models/followup.dart';
import '../models/lab.dart';
import '../rules/rules.dart';

/// Storage abstraction. Implementations:
/// * [InMemoryHealthRepository] — demo mode and tests; enforces the same
///   ownership and role rules as the Supabase RLS policies.
/// * SupabaseHealthRepository (in the app) — Postgres with RLS and RPCs.
abstract class HealthRepository {
  bool get isDemo;

  Future<PatientProfile?> getProfile(Actor a);
  Future<void> saveProfile(Actor a, PatientProfile p);

  Future<List<CgmReport>> listReports(Actor a);
  Future<void> saveReport(Actor a, CgmReport r);
  Future<void> deleteReport(Actor a, String id);

  /// Persists a versioned rule evaluation for audit (which rules ran, on
  /// which verified values, with which outcome).
  Future<void> recordAnalysisRun(Actor a, String reportId, RuleEvaluation e, TargetProfile profile);

  Future<List<LabResult>> listLabs(Actor a);
  Future<void> saveLab(Actor a, LabResult l);
  Future<void> deleteLab(Actor a, String id);

  Future<List<TestReminder>> listReminders(Actor a);
  Future<void> saveReminder(Actor a, TestReminder r);

  Future<List<Appointment>> listAppointments(Actor a);

  /// Patients: own requests. Reviewers: every non-draft request (snapshot only).
  Future<List<FollowUpRequest>> listFollowUps(Actor a);
  Future<void> createFollowUp(Actor a, FollowUpRequest draft);

  /// Persists a workflow transition computed by [FollowUpWorkflow].
  Future<void> applyFollowUpTransition(Actor a, FollowUpRequest before, FollowUpRequest after);

  Future<ConsentRecord?> activeConsent(Actor a);
  Future<void> saveConsent(Actor a, ConsentRecord c);

  /// Deletes every record owned by the patient (retention control).
  Future<void> deleteAllMyData(Actor a);
}

class InMemoryHealthRepository implements HealthRepository {
  InMemoryHealthRepository({this.isDemo = true, FollowUpAccessPolicy policy = const FollowUpAccessPolicy()}) : _policy = policy;

  @override
  final bool isDemo;
  final FollowUpAccessPolicy _policy;

  final Map<String, PatientProfile> profiles = {};
  final Map<String, CgmReport> reports = {};
  final Map<String, LabResult> labs = {};
  final Map<String, TestReminder> reminders = {};
  final Map<String, Appointment> appointments = {};
  final Map<String, FollowUpRequest> followUps = {};
  final Map<String, ConsentRecord> consents = {};

  void _ownerOnly(Actor a, String ownerId) {
    if (a.role != UserRole.patient || a.userId != ownerId) {
      throw AccessDeniedException('لا تملك صلاحية الوصول إلى هذه البيانات.');
    }
  }

  void _patientOnly(Actor a) {
    if (a.role != UserRole.patient) throw AccessDeniedException('هذه البيانات متاحة لصاحبها فقط.');
  }

  @override
  Future<PatientProfile?> getProfile(Actor a) async => profiles[a.userId];

  @override
  Future<void> saveProfile(Actor a, PatientProfile p) async {
    if (a.userId != p.userId) throw AccessDeniedException('لا يمكن تعديل ملف مستخدم آخر.');
    final existing = profiles[p.userId];
    if (existing != null && existing.role != p.role && !isDemo) {
      throw AccessDeniedException('لا يمكن للمستخدم تغيير دوره.');
    }
    profiles[p.userId] = p;
  }

  @override
  Future<List<CgmReport>> listReports(Actor a) async {
    _patientOnly(a);
    return reports.values.where((r) => r.userId == a.userId).toList()..sort((x, y) => x.createdAt.compareTo(y.createdAt));
  }

  @override
  Future<void> saveReport(Actor a, CgmReport r) async {
    _ownerOnly(a, r.userId);
    reports[r.id] = r;
  }

  @override
  Future<void> deleteReport(Actor a, String id) async {
    final r = reports[id];
    if (r == null) return;
    _ownerOnly(a, r.userId);
    reports.remove(id);
  }

  final List<(String, RuleEvaluation, TargetProfile)> analysisRuns = [];

  @override
  Future<void> recordAnalysisRun(Actor a, String reportId, RuleEvaluation e, TargetProfile profile) async {
    final r = reports[reportId];
    if (r == null) throw StateError('Report not found');
    _ownerOnly(a, r.userId);
    analysisRuns.add((reportId, e, profile));
  }

  @override
  Future<List<LabResult>> listLabs(Actor a) async {
    _patientOnly(a);
    return labs.values.where((l) => l.userId == a.userId).toList();
  }

  @override
  Future<void> saveLab(Actor a, LabResult l) async {
    _ownerOnly(a, l.userId);
    labs[l.id] = l;
  }

  @override
  Future<void> deleteLab(Actor a, String id) async {
    final l = labs[id];
    if (l == null) return;
    _ownerOnly(a, l.userId);
    labs.remove(id);
  }

  @override
  Future<List<TestReminder>> listReminders(Actor a) async {
    _patientOnly(a);
    return reminders.values.where((r) => r.userId == a.userId).toList()..sort((x, y) => x.dueDate.compareTo(y.dueDate));
  }

  @override
  Future<void> saveReminder(Actor a, TestReminder r) async {
    _ownerOnly(a, r.userId);
    reminders[r.id] = r;
  }

  @override
  Future<List<Appointment>> listAppointments(Actor a) async {
    _patientOnly(a);
    return appointments.values.where((x) => x.userId == a.userId).toList()..sort((x, y) => x.dateTime.compareTo(y.dateTime));
  }

  @override
  Future<List<FollowUpRequest>> listFollowUps(Actor a) async {
    return followUps.values.where((r) => _policy.can(a, FollowUpAction.view, r)).toList()..sort((x, y) => y.updatedAt.compareTo(x.updatedAt));
  }

  @override
  Future<void> createFollowUp(Actor a, FollowUpRequest draft) async {
    _ownerOnly(a, draft.userId);
    for (final e in followUps.values) {
      if (e.idempotencyKey == draft.idempotencyKey && e.status.isOpen) throw DuplicateRequestException(e.id);
    }
    followUps[draft.id] = draft;
  }

  @override
  Future<void> applyFollowUpTransition(Actor a, FollowUpRequest before, FollowUpRequest after) async {
    final stored = followUps[before.id];
    if (stored == null) throw StateError('Request not found');
    if (!_policy.can(a, FollowUpAction.view, stored)) {
      throw AccessDeniedException('لا تملك صلاحية الوصول إلى هذا الطلب.');
    }
    if (stored.status != before.status) {
      throw InvalidTransitionException('تغيّرت حالة الطلب؛ حدّث الصفحة وحاول مجددًا.');
    }
    if (after.id != stored.id || after.userId != stored.userId || after.idempotencyKey != stored.idempotencyKey || !identical(after.snapshot, stored.snapshot)) {
      throw AccessDeniedException('لا يمكن تعديل بيانات الطلب الأساسية.');
    }
    followUps[after.id] = after;
  }

  @override
  Future<ConsentRecord?> activeConsent(Actor a) async {
    final c = consents.values.where((c) => c.userId == a.userId && c.isActive).toList();
    return c.isEmpty ? null : c.last;
  }

  @override
  Future<void> saveConsent(Actor a, ConsentRecord c) async {
    _ownerOnly(a, c.userId);
    consents[c.id] = c;
  }

  @override
  Future<void> deleteAllMyData(Actor a) async {
    _patientOnly(a);
    reports.removeWhere((_, v) => v.userId == a.userId);
    labs.removeWhere((_, v) => v.userId == a.userId);
    reminders.removeWhere((_, v) => v.userId == a.userId);
    appointments.removeWhere((_, v) => v.userId == a.userId);
    followUps.removeWhere((_, v) => v.userId == a.userId);
    consents.removeWhere((_, v) => v.userId == a.userId);
  }
}
