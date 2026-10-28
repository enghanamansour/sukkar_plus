import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukkar_core/sukkar_core.dart';

import '../../data/providers.dart';
import '../../features/analysis/analysis_screen.dart';
import '../../features/analysis/history_screen.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/followup/followup_detail_screen.dart';
import '../../features/followup/followup_new_screen.dart';
import '../../features/followup/followups_screen.dart';
import '../../features/labs/gmi_comparison_screen.dart';
import '../../features/labs/lab_entry_screen.dart';
import '../../features/notices/notices_screen.dart';
import '../../features/onboarding/consent_screen.dart';
import '../../features/onboarding/welcome_screen.dart';
import '../../features/reminders/reminders_screen.dart';
import '../../features/reviewer/reviewer_request_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/upload/extraction_review_screen.dart';
import '../../features/upload/upload_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(appControllerProvider.select((s) => (s.ready, s.signedIn, s.onboardingDone, s.isReviewer)), (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, st) {
      final s = ref.read(appControllerProvider);
      final loc = st.matchedLocation;
      if (!s.ready) return loc == '/splash' ? null : '/splash';
      if (!s.signedIn) return loc == '/signin' ? null : '/signin';
      if (!s.onboardingDone && !s.isReviewer) {
        return (loc == '/welcome' || loc == '/consent') ? null : '/welcome';
      }
      if (loc == '/splash' || loc == '/signin') return '/';
      if (s.isReviewer && !(loc == '/' || loc.startsWith('/reviewer') || loc == '/notices')) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/signin', builder: (_, _) => const SignInScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/consent', builder: (_, _) => const ConsentScreen()),
      GoRoute(
        path: '/',
        builder: (_, st) => MainShell(initialTab: int.tryParse(st.uri.queryParameters['tab'] ?? '') ?? 0),
      ),
      GoRoute(path: '/upload', builder: (_, _) => const UploadScreen()),
      GoRoute(path: '/upload/review', builder: (_, _) => const ExtractionReviewScreen()),
      GoRoute(path: '/report/:id', builder: (_, st) => AnalysisScreen(reportId: st.pathParameters['id']!)),
      GoRoute(path: '/history', builder: (_, _) => const CgmHistoryScreen()),
      GoRoute(path: '/labs/gmi', builder: (_, _) => const GmiComparisonScreen()),
      GoRoute(
        path: '/labs/add',
        builder: (_, st) => LabEntryScreen(
          reminderId: st.uri.queryParameters['reminder'],
          initialCode: LabTestCode.values.asNameMap()[st.uri.queryParameters['code'] ?? ''],
        ),
      ),
      GoRoute(path: '/reminders', builder: (_, _) => const RemindersScreen()),
      GoRoute(
        path: '/followup/new/:reportId',
        builder: (_, st) => FollowUpNewScreen(
          reportId: st.pathParameters['reportId']!,
          trigger: st.uri.queryParameters['trigger'] == 'user' ? FollowUpTrigger.userRequest : FollowUpTrigger.rule,
        ),
      ),
      GoRoute(path: '/followups', builder: (_, _) => const FollowUpsScreen()),
      GoRoute(path: '/followup/:id', builder: (_, st) => FollowUpDetailScreen(requestId: st.pathParameters['id']!)),
      GoRoute(path: '/reviewer/request/:id', builder: (_, st) => ReviewerRequestScreen(requestId: st.pathParameters['id']!)),
      GoRoute(path: '/notices', builder: (_, _) => const NoticesScreen()),
    ],
  );
});
