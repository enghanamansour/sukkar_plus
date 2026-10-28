import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukkar_core/sukkar_core.dart';

import '../../core/format/ar_format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../followup/followup_widgets.dart';

enum _Filter { pending, info, done }

/// Prototype reviewer dashboard. Shows only submitted requests and only the
/// snapshot each patient agreed to share. The reviewer is a demo role, not a
/// real clinician.
class ReviewerDashboard extends ConsumerStatefulWidget {
  const ReviewerDashboard({super.key});
  @override
  ConsumerState<ReviewerDashboard> createState() => _ReviewerDashboardState();
}

class _ReviewerDashboardState extends ConsumerState<ReviewerDashboard> {
  _Filter _filter = _Filter.pending;

  bool _match(FollowUpRequest r) => switch (_filter) {
        _Filter.pending => r.status == FollowUpStatus.awaitingReview || r.status == FollowUpStatus.underReview,
        _Filter.info => r.status == FollowUpStatus.moreInfoRequested,
        _Filter.done => r.status == FollowUpStatus.reviewed || r.status == FollowUpStatus.closed,
      };

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appControllerProvider);
    final dispatcher = ref.watch(dispatcherProvider);
    final t = Theme.of(context).textTheme;
    final items = s.followUps.where(_match).toList();
    int count(_Filter f) {
      final prev = _filter;
      _filter = f;
      final n = s.followUps.where(_match).length;
      _filter = prev;
      return n;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة المراجعة'),
        actions: [IconButton(onPressed: () => ref.read(appControllerProvider.notifier).reload(), icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث')],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(appControllerProvider.notifier).reload(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(SpSpace.page, SpSpace.sm, SpSpace.page, SpSpace.xxl),
          children: [
            const InfoNote(
              tone: Tone.demo,
              title: 'واجهة تجريبية',
              text: 'هذه لوحة مراجعة ضمن نموذج أولي. المراجع هنا دور تجريبي وليس طبيبًا، والقرارات لا تُنشئ مواعيد ولا تغيّر علاجًا.',
            ),
            const SizedBox(height: SpSpace.md),
            SegmentedButton<_Filter>(
              segments: [
                ButtonSegment(value: _Filter.pending, label: Text('بانتظار المراجعة (${count(_Filter.pending)})')),
                ButtonSegment(value: _Filter.info, label: Text('معلومات (${count(_Filter.info)})')),
                ButtonSegment(value: _Filter.done, label: Text('منتهية (${count(_Filter.done)})')),
              ],
              selected: {_filter},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _filter = v.first),
            ),
            const SizedBox(height: SpSpace.md),
            if (items.isEmpty) const EmptyState(icon: Icons.inbox_outlined, title: 'لا توجد طلبات هنا', message: 'ستظهر الطلبات المرسلة من المستخدمين في هذه القائمة.'),
            for (final r in items)
              Padding(
                padding: const EdgeInsets.only(bottom: SpSpace.sm),
                child: SpCard(
                  onTap: () => context.push('/reviewer/request/${r.id}'),
                  padding: const EdgeInsets.all(SpSpace.md),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(r.pseudoId, style: t.titleSmall)),
                      FollowUpStatusChip(status: r.status),
                    ]),
                    Text('${r.trigger.labelAr} — ${ArFormat.dateTime(r.updatedAt)}', style: t.bodySmall),
                    if (r.ruleIds.isNotEmpty) Text('القواعد: ${r.ruleIds.join('، ')}', style: t.labelSmall),
                    Text('الفترة: ${r.snapshot.periodLabel}', style: t.labelSmall),
                    if (r.provenance == DataProvenance.synthetic) const Padding(padding: EdgeInsets.only(top: 4), child: SyntheticChip()),
                  ]),
                ),
              ),
            const SizedBox(height: SpSpace.lg),
            SpCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('حالة التكامل', style: t.titleSmall),
                KeyValueRow(label: 'إشعارات الطلبات', value: dispatcher.isMock ? 'محاكي محلي' : 'الخادم'),
                Text(dispatcher.label, style: t.bodySmall),
              ]),
            ),
            if (s.demoMode) ...[
              const SizedBox(height: SpSpace.lg),
              OutlinedButton.icon(
                onPressed: () => ref.read(appControllerProvider.notifier).switchDemoRole(UserRole.patient),
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('العودة إلى واجهة المستخدم (تجريبي)'),
              ),
            ] else ...[
              const SizedBox(height: SpSpace.lg),
              OutlinedButton.icon(
                onPressed: () => ref.read(appControllerProvider.notifier).signOut(),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('تسجيل الخروج'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
