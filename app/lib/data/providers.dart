import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sukkar_core/sukkar_core.dart';

import '../core/config/app_config.dart';
import 'app_controller.dart';
import 'app_state.dart';
import 'platform/file_pick.dart';
import 'platform/pdf_text.dart';
import 'services/backend_services.dart';
import 'supabase/supabase_repository.dart';

/// Overridable in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final configProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment());

SupabaseClient? _liveClient(AppConfig c) => c.demoMode ? null : Supabase.instance.client;

final repositoryProvider = Provider<HealthRepository>((ref) {
  final cfg = ref.watch(configProvider);
  final client = _liveClient(cfg);
  if (client == null) return buildDemoRepository(ref.read(clockProvider)());
  return SupabaseHealthRepository(client);
});

final pdfTextExtractorProvider = Provider<PdfTextExtractor>((ref) => PdfrxTextExtractor());
final filePickerProvider = Provider<ReportFilePicker>((ref) => PlatformReportFilePicker());

final aiExtractionProvider = Provider<AiExtractionClient>((ref) {
  final client = _liveClient(ref.watch(configProvider));
  return client == null ? const NoAiExtraction() : EdgeAiExtraction(client);
});

final explanationProvider = Provider<ExplanationProvider>((ref) {
  final client = _liveClient(ref.watch(configProvider));
  return client == null ? const LocalTemplateExplainer() : GuardedExplainer(EdgeExplanationProvider(client));
});

final mockNotifierProvider = Provider<MockFollowUpNotifier>((ref) => MockFollowUpNotifier());

final dispatcherProvider = Provider<FollowUpDispatcher>((ref) {
  final client = _liveClient(ref.watch(configProvider));
  return client == null ? MockDispatcher(ref.watch(mockNotifierProvider)) : EdgeDispatcher(client);
});

final appControllerProvider = NotifierProvider<AppController, AppState>(AppController.new);

// ------------------------------------------------------------ derived data

final ruleEngineProvider = Provider<RuleEngine>((ref) => const RuleEngine());

final evaluationProvider = Provider.family<RuleEvaluation?, String>((ref, reportId) {
  final s = ref.watch(appControllerProvider);
  final r = s.reportById(reportId);
  if (r == null) return null;
  return ref.watch(ruleEngineProvider).evaluate(r, profile: s.targetProfile, now: ref.read(clockProvider)());
});

final gmiComparisonProvider = Provider<GmiHbA1cComparison>((ref) {
  final s = ref.watch(appControllerProvider);
  return compareLatest(reports: s.reports, labs: s.labs);
});

final visitSummaryProvider = Provider<VisitSummary>((ref) {
  final s = ref.watch(appControllerProvider);
  final now = ref.read(clockProvider)();
  return const VisitSummaryBuilder().build(
    now: now,
    reports: s.reports,
    labs: s.labs,
    reminders: s.reminders,
    followUps: s.followUps,
    appointment: s.nextAppointment(now),
    targetProfile: s.targetProfile,
  );
});
