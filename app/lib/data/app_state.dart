import 'dart:typed_data';

import 'package:sukkar_core/sukkar_core.dart';

/// An upload being reviewed. The PDF bytes are kept only in memory until the
/// user accepts or discards the extraction; they are never persisted.
class UploadSession {
  const UploadSession({
    required this.fileName,
    required this.sizeBytes,
    required this.isDemoFixture,
    required this.result,
    required this.startedAt,
    this.aiNoteAr,
    this.bytes,
    this.periodOverride,
  });

  final String fileName;
  final int sizeBytes;
  final bool isDemoFixture;
  final ExtractionResult result;
  final DateTime startedAt;
  final String? aiNoteAr;
  final Uint8List? bytes;
  final ReportPeriod? periodOverride;

  UploadSession copyWith({ExtractionResult? result, String? aiNoteAr, ReportPeriod? periodOverride, bool dropBytes = false}) => UploadSession(
        fileName: fileName,
        sizeBytes: sizeBytes,
        isDemoFixture: isDemoFixture,
        result: result ?? this.result,
        startedAt: startedAt,
        aiNoteAr: aiNoteAr ?? this.aiNoteAr,
        bytes: dropBytes ? null : bytes,
        periodOverride: periodOverride ?? this.periodOverride,
      );
}

/// In-app notification. In demo mode these simulate push notifications and
/// are always labelled as simulated.
class AppNotice {
  const AppNotice({required this.id, required this.textAr, required this.at, this.simulated = true, this.route});
  final String id;
  final String textAr;
  final DateTime at;
  final bool simulated;
  final String? route;
}

class AppState {
  const AppState({
    required this.ready,
    required this.demoMode,
    this.actor,
    this.profile,
    this.reports = const [],
    this.labs = const [],
    this.reminders = const [],
    this.appointments = const [],
    this.followUps = const [],
    this.consent,
    this.onboardingDone = false,
    this.upload,
    this.notices = const [],
    this.errorAr,
  });

  factory AppState.initial({required bool demoMode}) => AppState(ready: false, demoMode: demoMode);

  final bool ready;
  final bool demoMode;
  final Actor? actor;
  final PatientProfile? profile;
  final List<CgmReport> reports;
  final List<LabResult> labs;
  final List<TestReminder> reminders;
  final List<Appointment> appointments;
  final List<FollowUpRequest> followUps;
  final ConsentRecord? consent;
  final bool onboardingDone;
  final UploadSession? upload;
  final List<AppNotice> notices;
  final String? errorAr;

  bool get signedIn => actor != null;
  bool get isReviewer => actor?.role == UserRole.reviewer;
  TargetProfile get targetProfile => profile?.targetProfile ?? TargetProfile.unspecified;

  /// Reports with a known period, oldest first.
  List<CgmReport> get datedReports => reports.where((r) => r.effectivePeriod != null).toList()
    ..sort((a, b) => a.effectivePeriod!.end.compareTo(b.effectivePeriod!.end));

  CgmReport? get latestReport {
    final d = datedReports;
    if (d.isNotEmpty) return d.last;
    return reports.isEmpty ? null : reports.last;
  }

  CgmReport? reportById(String id) {
    for (final r in reports) {
      if (r.id == id) return r;
    }
    return null;
  }

  FollowUpRequest? followUpById(String id) {
    for (final f in followUps) {
      if (f.id == id) return f;
    }
    return null;
  }

  Appointment? nextAppointment(DateTime now) {
    final upcoming = appointments.where((a) => !a.dateTime.isBefore(dateOnly(now))).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  bool get anySynthetic =>
      reports.any((r) => r.provenance == DataProvenance.synthetic) || labs.any((l) => l.provenance == DataProvenance.synthetic);

  AppState copyWith({
    bool? ready,
    Actor? actor,
    bool clearActor = false,
    PatientProfile? profile,
    List<CgmReport>? reports,
    List<LabResult>? labs,
    List<TestReminder>? reminders,
    List<Appointment>? appointments,
    List<FollowUpRequest>? followUps,
    ConsentRecord? consent,
    bool clearConsent = false,
    bool? onboardingDone,
    UploadSession? upload,
    bool clearUpload = false,
    List<AppNotice>? notices,
    String? errorAr,
    bool clearError = false,
  }) =>
      AppState(
        ready: ready ?? this.ready,
        demoMode: demoMode,
        actor: clearActor ? null : (actor ?? this.actor),
        profile: clearActor ? null : (profile ?? this.profile),
        reports: reports ?? this.reports,
        labs: labs ?? this.labs,
        reminders: reminders ?? this.reminders,
        appointments: appointments ?? this.appointments,
        followUps: followUps ?? this.followUps,
        consent: clearConsent ? null : (consent ?? this.consent),
        onboardingDone: onboardingDone ?? this.onboardingDone,
        upload: clearUpload ? null : (upload ?? this.upload),
        notices: notices ?? this.notices,
        errorAr: clearError ? null : (errorAr ?? this.errorAr),
      );
}

/// Error with a message that is safe and useful to show to the user.
class UserFacingError implements Exception {
  UserFacingError(this.messageAr);
  final String messageAr;
  @override
  String toString() => messageAr;
}
