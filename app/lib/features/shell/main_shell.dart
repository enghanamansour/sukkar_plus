import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../assistant/assistant_screen.dart';
import '../home/home_screen.dart';
import '../labs/labs_screen.dart';
import '../profile/profile_screen.dart';
import '../reviewer/reviewer_dashboard.dart';
import '../visit/visit_prep_screen.dart';

/// Five-tab shell (mirrors the reference layout's bottom bar). Reviewers see
/// the review dashboard instead of patient tabs.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  late int _index = widget.initialTab.clamp(0, 4);

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) _index = widget.initialTab.clamp(0, 4);
  }

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final reviewer = ref.watch(appControllerProvider.select((s) => s.isReviewer));
    if (reviewer) return const ReviewerDashboard();
    final pages = [
      HomeScreen(onOpenTab: _go),
      const LabsScreen(),
      const VisitPrepScreen(),
      const AssistantScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.science_outlined), selectedIcon: Icon(Icons.science_rounded), label: 'التحاليل'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note_rounded), label: 'موعدي'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline_rounded), selectedIcon: Icon(Icons.chat_bubble_rounded), label: 'المساعد'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'ملفي'),
        ],
      ),
    );
  }
}
