import '../models/enums.dart';
import '../models/followup.dart';
import '../reminders/reminder_service.dart' show InvalidTransitionException;

export '../reminders/reminder_service.dart' show InvalidTransitionException;

class Actor {
  const Actor({required this.userId, required this.role});
  final String userId;
  final UserRole role;
}

enum FollowUpAction { view, submit, withdraw, startReview, decide, close, addNote, retryDispatch }

class AccessDeniedException implements Exception {
  AccessDeniedException(this.messageAr);
  final String messageAr;
  @override
  String toString() => 'AccessDeniedException: $messageAr';
}

class DuplicateRequestException implements Exception {
  DuplicateRequestException(this.existingId);
  final String existingId;
  @override
  String toString() => 'DuplicateRequestException: open request $existingId already exists';
}

/// Authorization mirrors the Supabase RLS policies and RPC checks:
/// * patients see and act on their own requests only;
/// * reviewers see submitted requests (never drafts) and only the shared
///   snapshot, and can perform review actions.
class FollowUpAccessPolicy {
  const FollowUpAccessPolicy();

  bool can(Actor a, FollowUpAction action, FollowUpRequest r) {
    final owner = a.role == UserRole.patient && a.userId == r.userId;
    final reviewer = a.role == UserRole.reviewer;
    switch (action) {
      case FollowUpAction.view:
        return owner || (reviewer && r.status != FollowUpStatus.draft);
      case FollowUpAction.submit:
      case FollowUpAction.withdraw:
        return owner;
      case FollowUpAction.startReview:
      case FollowUpAction.decide:
        return reviewer;
      case FollowUpAction.close:
        return owner || reviewer;
      case FollowUpAction.addNote:
        return reviewer;
      case FollowUpAction.retryDispatch:
        return owner || reviewer;
    }
  }

  void require(Actor a, FollowUpAction action, FollowUpRequest r) {
    if (!can(a, action, r)) throw AccessDeniedException('لا تملك صلاحية تنفيذ هذا الإجراء على الطلب.');
  }
}

/// Deterministic idempotency key: one open request per user, report, trigger
/// and rule set.
String followUpIdempotencyKey({
  required String userId,
  required String? reportId,
  required FollowUpTrigger trigger,
  required List<String> ruleIds,
}) {
  final rules = [...ruleIds]..sort();
  return '$userId|${reportId ?? 'none'}|${trigger.wireName}|${rules.join(',')}';
}

/// The follow-up state machine:
///
/// draft ──submit──▶ awaiting_review ──startReview──▶ under_review
/// under_review ──decide(data_completion)──▶ more_info_requested ──submit──▶ awaiting_review
/// under_review ──decide(review_required | no_further_action)──▶ reviewed ──close──▶ closed
/// draft | awaiting_review ──withdraw (patient)──▶ closed
class FollowUpWorkflow {
  const FollowUpWorkflow({this.policy = const FollowUpAccessPolicy()});
  final FollowUpAccessPolicy policy;

  static const demoReviewerLabel = 'مراجع تجريبي (ليس طبيبًا حقيقيًا)';

  FollowUpRequest createDraft({
    required String id,
    required String pseudoId,
    required String userId,
    required FollowUpTrigger trigger,
    required List<String> ruleIds,
    required String rulesVersion,
    required String reasonAr,
    required SharedSnapshot snapshot,
    required DateTime now,
    required Iterable<FollowUpRequest> existing,
    required DataProvenance provenance,
    String? reportId,
  }) {
    final key = followUpIdempotencyKey(userId: userId, reportId: reportId, trigger: trigger, ruleIds: ruleIds);
    for (final e in existing) {
      if (e.idempotencyKey == key && e.status.isOpen) throw DuplicateRequestException(e.id);
    }
    return FollowUpRequest(
      id: id,
      pseudoId: pseudoId,
      userId: userId,
      trigger: trigger,
      ruleIds: ruleIds,
      rulesVersion: rulesVersion,
      reasonAr: reasonAr,
      snapshot: snapshot,
      status: FollowUpStatus.draft,
      idempotencyKey: key,
      createdAt: now,
      updatedAt: now,
      provenance: provenance,
      reportId: reportId,
      history: [StatusHistoryEntry(from: null, to: FollowUpStatus.draft, at: now, actorRole: UserRole.patient)],
    );
  }

  FollowUpRequest _move(FollowUpRequest r, FollowUpStatus to, Actor a, DateTime now, {String? noteAr, ReviewDecision? decision}) =>
      r.copyWith(
        status: to,
        decision: decision,
        updatedAt: now,
        history: [...r.history, StatusHistoryEntry(from: r.status, to: to, at: now, actorRole: a.role, noteAr: noteAr)],
      );

  FollowUpRequest submit(FollowUpRequest r, Actor a, DateTime now, {String? noteAr}) {
    policy.require(a, FollowUpAction.submit, r);
    if (r.status != FollowUpStatus.draft && r.status != FollowUpStatus.moreInfoRequested) {
      throw InvalidTransitionException('لا يمكن إرسال طلب حالته "${r.status.labelAr}".');
    }
    return _move(r, FollowUpStatus.awaitingReview, a, now, noteAr: noteAr);
  }

  FollowUpRequest withdraw(FollowUpRequest r, Actor a, DateTime now) {
    policy.require(a, FollowUpAction.withdraw, r);
    if (r.status != FollowUpStatus.draft && r.status != FollowUpStatus.awaitingReview) {
      throw InvalidTransitionException('لا يمكن سحب الطلب بعد بدء مراجعته.');
    }
    return _move(r, FollowUpStatus.closed, a, now, noteAr: 'سحب المستخدم الطلب');
  }

  FollowUpRequest startReview(FollowUpRequest r, Actor a, DateTime now) {
    policy.require(a, FollowUpAction.startReview, r);
    if (r.status != FollowUpStatus.awaitingReview) {
      throw InvalidTransitionException('الطلب ليس بانتظار المراجعة.');
    }
    return _move(r, FollowUpStatus.underReview, a, now);
  }

  FollowUpRequest decide(FollowUpRequest r, Actor a, DateTime now, ReviewDecision decision, {String? noteAr}) {
    policy.require(a, FollowUpAction.decide, r);
    if (r.status != FollowUpStatus.underReview) {
      throw InvalidTransitionException('يجب بدء المراجعة قبل تسجيل القرار.');
    }
    final to = decision == ReviewDecision.dataCompletion ? FollowUpStatus.moreInfoRequested : FollowUpStatus.reviewed;
    var next = _move(r, to, a, now, noteAr: decision.labelAr, decision: decision);
    if (noteAr != null && noteAr.trim().isNotEmpty) {
      next = next.copyWith(notes: [...next.notes, ReviewNote(at: now, textAr: noteAr.trim(), authorLabel: demoReviewerLabel)]);
    }
    return next;
  }

  FollowUpRequest addNote(FollowUpRequest r, Actor a, DateTime now, String textAr) {
    policy.require(a, FollowUpAction.addNote, r);
    if (textAr.trim().isEmpty) throw InvalidTransitionException('الملاحظة فارغة.');
    return r.copyWith(updatedAt: now, notes: [...r.notes, ReviewNote(at: now, textAr: textAr.trim(), authorLabel: demoReviewerLabel)]);
  }

  FollowUpRequest close(FollowUpRequest r, Actor a, DateTime now) {
    policy.require(a, FollowUpAction.close, r);
    if (r.status != FollowUpStatus.reviewed) {
      throw InvalidTransitionException('يُغلق الطلب بعد مراجعته فقط.');
    }
    return _move(r, FollowUpStatus.closed, a, now);
  }
}
