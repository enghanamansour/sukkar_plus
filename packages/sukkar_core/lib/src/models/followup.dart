import 'enums.dart';

enum FollowUpStatus { draft, awaitingReview, underReview, moreInfoRequested, reviewed, closed }

extension FollowUpStatusInfo on FollowUpStatus {
  String get labelAr => switch (this) {
        FollowUpStatus.draft => 'مسودة',
        FollowUpStatus.awaitingReview => 'بانتظار المراجعة',
        FollowUpStatus.underReview => 'قيد المراجعة',
        FollowUpStatus.moreInfoRequested => 'مطلوب معلومات إضافية',
        FollowUpStatus.reviewed => 'تمت المراجعة',
        FollowUpStatus.closed => 'مغلق',
      };

  String get wireName => switch (this) {
        FollowUpStatus.draft => 'draft',
        FollowUpStatus.awaitingReview => 'awaiting_review',
        FollowUpStatus.underReview => 'under_review',
        FollowUpStatus.moreInfoRequested => 'more_info_requested',
        FollowUpStatus.reviewed => 'reviewed',
        FollowUpStatus.closed => 'closed',
      };

  bool get isOpen => this != FollowUpStatus.closed;
}

FollowUpStatus? followUpStatusFromWire(String s) {
  for (final v in FollowUpStatus.values) {
    if (v.wireName == s) return v;
  }
  return null;
}

/// Simulated reviewer decisions. None of them books an appointment or changes
/// treatment.
enum ReviewDecision { reviewRequired, dataCompletion, noFurtherActionDemo }

extension ReviewDecisionInfo on ReviewDecision {
  String get labelAr => switch (this) {
        ReviewDecision.reviewRequired => 'مراجعة مطلوبة',
        ReviewDecision.dataCompletion => 'استكمال البيانات',
        ReviewDecision.noFurtherActionDemo => 'لا إجراء إضافي (عرض تجريبي)',
      };

  String get patientMessageAr => switch (this) {
        ReviewDecision.reviewRequired =>
          'أشار المراجع التجريبي إلى أن البيانات تستحق النقاش مع فريقك الصحي. هذا ليس تشخيصًا ولم يُحجز أي موعد.',
        ReviewDecision.dataCompletion => 'طلب المراجع التجريبي استكمال البيانات قبل المتابعة.',
        ReviewDecision.noFurtherActionDemo => 'تمت مراجعة الطلب في العرض التجريبي دون إجراء إضافي.',
      };

  String get wireName => switch (this) {
        ReviewDecision.reviewRequired => 'review_required',
        ReviewDecision.dataCompletion => 'data_completion',
        ReviewDecision.noFurtherActionDemo => 'no_further_action_demo',
      };
}

enum FollowUpTrigger { rule, userRequest }

extension FollowUpTriggerAr on FollowUpTrigger {
  String get labelAr => this == FollowUpTrigger.rule ? 'قاعدة مُعدّة مسبقًا' : 'طلب من المستخدم';
  String get wireName => this == FollowUpTrigger.rule ? 'rule' : 'user_request';
}

class StatusHistoryEntry {
  const StatusHistoryEntry({
    required this.from,
    required this.to,
    required this.at,
    required this.actorRole,
    this.noteAr,
  });

  final FollowUpStatus? from;
  final FollowUpStatus to;
  final DateTime at;
  final UserRole actorRole;
  final String? noteAr;
}

class ReviewNote {
  const ReviewNote({required this.at, required this.textAr, required this.authorLabel});
  final DateTime at;
  final String textAr;

  /// Always a demo label such as "مراجع تجريبي"; never a real clinician name.
  final String authorLabel;
}

/// The exact information the patient agreed to share with the reviewer.
/// Reviewers see this snapshot only, not the patient's full record.
class SharedSnapshot {
  const SharedSnapshot({
    required this.periodLabel,
    required this.items,
    this.qualityNotesAr = const [],
  });

  final String periodLabel;

  /// Arabic label → formatted verified value.
  final Map<String, String> items;
  final List<String> qualityNotesAr;

  Map<String, Object?> toJson() => {'period': periodLabel, 'items': items, 'quality_notes': qualityNotesAr};
}

enum DispatchState { notSent, mockRecorded, sent, failed }

extension DispatchStateAr on DispatchState {
  String get labelAr => switch (this) {
        DispatchState.notSent => 'لم يُرسل',
        DispatchState.mockRecorded => 'سُجّل في المحاكي (Mock)',
        DispatchState.sent => 'أُرسل إلى Make.com',
        DispatchState.failed => 'فشل الإرسال',
      };
}

class IntegrationDispatch {
  const IntegrationDispatch({
    required this.state,
    required this.adapterName,
    required this.isMock,
    this.attempts = 0,
    this.lastError,
    this.lastAttemptAt,
  });

  final DispatchState state;
  final String adapterName;
  final bool isMock;
  final int attempts;
  final String? lastError;
  final DateTime? lastAttemptAt;

  static const none = IntegrationDispatch(state: DispatchState.notSent, adapterName: 'none', isMock: true);
}

class FollowUpRequest {
  const FollowUpRequest({
    required this.id,
    required this.pseudoId,
    required this.userId,
    required this.trigger,
    required this.ruleIds,
    required this.rulesVersion,
    required this.reasonAr,
    required this.snapshot,
    required this.status,
    required this.idempotencyKey,
    required this.createdAt,
    required this.updatedAt,
    required this.provenance,
    this.reportId,
    this.decision,
    this.history = const [],
    this.notes = const [],
    this.dispatch = IntegrationDispatch.none,
  });

  final String id;

  /// Pseudonymous reference shown to reviewers and sent to automation.
  final String pseudoId;
  final String userId;
  final FollowUpTrigger trigger;
  final List<String> ruleIds;
  final String rulesVersion;
  final String reasonAr;
  final SharedSnapshot snapshot;
  final FollowUpStatus status;
  final String idempotencyKey;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DataProvenance provenance;
  final String? reportId;
  final ReviewDecision? decision;
  final List<StatusHistoryEntry> history;
  final List<ReviewNote> notes;
  final IntegrationDispatch dispatch;

  FollowUpRequest copyWith({
    FollowUpStatus? status,
    ReviewDecision? decision,
    List<StatusHistoryEntry>? history,
    List<ReviewNote>? notes,
    IntegrationDispatch? dispatch,
    DateTime? updatedAt,
  }) =>
      FollowUpRequest(
        id: id,
        pseudoId: pseudoId,
        userId: userId,
        trigger: trigger,
        ruleIds: ruleIds,
        rulesVersion: rulesVersion,
        reasonAr: reasonAr,
        snapshot: snapshot,
        status: status ?? this.status,
        idempotencyKey: idempotencyKey,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        provenance: provenance,
        reportId: reportId,
        decision: decision ?? this.decision,
        history: history ?? this.history,
        notes: notes ?? this.notes,
        dispatch: dispatch ?? this.dispatch,
      );
}
