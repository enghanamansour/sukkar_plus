import '../common/units.dart';
import 'enums.dart';
import 'lab.dart';

/// A simulated appointment. Sukkar Plus never books or modifies a real one.
class Appointment {
  const Appointment({
    required this.id,
    required this.userId,
    required this.dateTime,
    required this.clinicLabel,
    required this.provenance,
    this.isSimulated = true,
  });

  final String id;
  final String userId;
  final DateTime dateTime;
  final String clinicLabel;
  final DataProvenance provenance;
  final bool isSimulated;
}

/// Who defined the testing schedule. The app never invents a schedule.
enum ScheduleSource { clinicianProvided, userConfirmed }

extension ScheduleSourceAr on ScheduleSource {
  String get labelAr => this == ScheduleSource.clinicianProvided ? 'بطلب من مقدم الرعاية' : 'جدول أكّده المستخدم';
}

/// Stored state. "Upcoming" and "overdue" are derived from dates.
enum ReminderStatus { scheduled, completed, cancelled }

enum ReminderDisplayState { upcoming, overdue, completed, cancelled }

extension ReminderDisplayStateAr on ReminderDisplayState {
  String get labelAr => switch (this) {
        ReminderDisplayState.upcoming => 'قادم',
        ReminderDisplayState.overdue => 'متأخر',
        ReminderDisplayState.completed => 'مكتمل',
        ReminderDisplayState.cancelled => 'ملغى',
      };
}

class ReminderEvent {
  const ReminderEvent(this.at, this.descriptionAr);
  final DateTime at;
  final String descriptionAr;
}

class TestReminder {
  const TestReminder({
    required this.id,
    required this.userId,
    required this.testCode,
    required this.testName,
    required this.dueDate,
    required this.source,
    required this.status,
    required this.provenance,
    this.remindAt,
    this.appointmentId,
    this.completedAt,
    this.collectionDate,
    this.resultId,
    this.note,
    this.history = const [],
  });

  final String id;
  final String userId;
  final LabTestCode testCode;
  final String testName;
  final DateTime dueDate;
  final ScheduleSource source;
  final ReminderStatus status;
  final DataProvenance provenance;
  final DateTime? remindAt;
  final String? appointmentId;
  final DateTime? completedAt;
  final DateTime? collectionDate;
  final String? resultId;
  final String? note;
  final List<ReminderEvent> history;

  bool get isOpen => status == ReminderStatus.scheduled;

  ReminderDisplayState displayState(DateTime now) {
    switch (status) {
      case ReminderStatus.completed:
        return ReminderDisplayState.completed;
      case ReminderStatus.cancelled:
        return ReminderDisplayState.cancelled;
      case ReminderStatus.scheduled:
        return daysBetween(now, dueDate) < 0 ? ReminderDisplayState.overdue : ReminderDisplayState.upcoming;
    }
  }

  TestReminder copyWith({
    DateTime? dueDate,
    DateTime? remindAt,
    ReminderStatus? status,
    DateTime? completedAt,
    DateTime? collectionDate,
    String? resultId,
    String? note,
    String? appointmentId,
    List<ReminderEvent>? history,
  }) =>
      TestReminder(
        id: id,
        userId: userId,
        testCode: testCode,
        testName: testName,
        dueDate: dueDate ?? this.dueDate,
        source: source,
        status: status ?? this.status,
        provenance: provenance,
        remindAt: remindAt ?? this.remindAt,
        appointmentId: appointmentId ?? this.appointmentId,
        completedAt: completedAt ?? this.completedAt,
        collectionDate: collectionDate ?? this.collectionDate,
        resultId: resultId ?? this.resultId,
        note: note ?? this.note,
        history: history ?? this.history,
      );
}

/// Record of the user's consent. Demo mode never creates one.
class ConsentRecord {
  const ConsentRecord({
    required this.id,
    required this.userId,
    required this.version,
    required this.grantedAt,
    required this.allowsExternalAi,
    this.revokedAt,
  });

  final String id;
  final String userId;
  final String version;
  final DateTime grantedAt;

  /// Separate opt-in for sending a PDF to the external AI provider.
  final bool allowsExternalAi;
  final DateTime? revokedAt;

  bool get isActive => revokedAt == null;

  static const currentVersion = 'consent-2026-10-v1';
}

class PatientProfile {
  const PatientProfile({
    required this.userId,
    required this.pseudoId,
    required this.displayName,
    required this.role,
    required this.targetProfile,
    required this.provenance,
  });

  final String userId;

  /// Pseudonymous identifier; the only identifier shared with reviewers or
  /// automation.
  final String pseudoId;

  /// Kept locally / in a separate identity table, never sent to automation.
  final String displayName;
  final UserRole role;
  final TargetProfile targetProfile;
  final DataProvenance provenance;

  PatientProfile copyWith({TargetProfile? targetProfile, UserRole? role, String? displayName}) => PatientProfile(
        userId: userId,
        pseudoId: pseudoId,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        targetProfile: targetProfile ?? this.targetProfile,
        provenance: provenance,
      );
}
