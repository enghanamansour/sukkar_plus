import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukkar_core/sukkar_core.dart';

import '../../core/charts/range_bands.dart';
import '../../core/format/ar_format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/demo_banner.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_state.dart';
import '../../data/providers.dart';
import 'home_search.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onOpenTab});
  final void Function(int tab) onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appControllerProvider);
    final now = ref.read(clockProvider)();
    final t = Theme.of(context).textTheme;
    final latest = s.latestReport;
    final name = s.profile?.displayName ?? '';
    final firstName = name.split(' ').first;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () => ref.read(appControllerProvider.notifier).reload(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(SpSpace.page, SpSpace.sm, SpSpace.page, SpSpace.xxl),
          children: [
            _TopBar(noticeCount: s.notices.length, onMenu: () => onOpenTab(4)),
            const SizedBox(height: SpSpace.md),
            Text(firstName.isEmpty ? 'مرحبًا' : 'مرحبًا، $firstName', style: t.displaySmall),
            Text('تابع تقاريرك وتحاليلك واستعد لموعدك القادم.', style: t.bodyMedium?.copyWith(color: SpColors.inkSecondary)),
            const SizedBox(height: SpSpace.lg),
            HomeSearchField(onOpenTab: onOpenTab),
            const SizedBox(height: SpSpace.lg),
            _NoticeCard(state: s, now: now),
            const SizedBox(height: SpSpace.xl),
            SectionHeader(
              title: 'ملخصي الصحي',
              actionLabel: latest == null ? null : 'عرض التحليل',
              onAction: latest == null ? null : () => context.push('/report/${latest.id}'),
            ),
            if (latest == null)
              SpCard(
                child: EmptyState(
                  icon: Icons.upload_file_outlined,
                  title: 'لا يوجد تقرير بعد',
                  message: 'ارفع صفحة الملخص من تقرير الحساس لعرض مؤشراتك المؤكدة.',
                  actionLabel: 'رفع تقرير جديد',
                  onAction: () => context.push('/upload'),
                ),
              )
            else
              _SummaryCard(report: latest),
            const SizedBox(height: SpSpace.lg),
            _QuickActions(onOpenTab: onOpenTab),
            const SizedBox(height: SpSpace.xl),
            SectionHeader(title: 'آخر مستجداتك', actionLabel: 'عرض الكل', onAction: () => context.push('/notices')),
            _Updates(state: s, now: now, onOpenTab: onOpenTab),
            const SizedBox(height: SpSpace.xl),
            Text(
              'سكر بلس نموذج أولي مستقل للعرض، غير مرتبط بتطبيق صحتي أو أي جهة حكومية أو صحية، ولا يغني عن استشارة فريقك الصحي.',
              style: t.labelSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.noticeCount, required this.onMenu});
  final int noticeCount;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(onPressed: onMenu, icon: const Icon(Icons.menu_rounded, color: SpColors.tealDeep), tooltip: 'ملفي والإعدادات'),
        IconButton(
          onPressed: () => context.push('/notices'),
          tooltip: 'التنبيهات',
          icon: Badge(
            isLabelVisible: noticeCount > 0,
            label: Text('$noticeCount'),
            child: const Icon(Icons.notifications_none_rounded, color: SpColors.tealDeep),
          ),
        ),
        const Spacer(),
        const SukkarLogo(size: 36),
      ],
    );
  }
}

/// The reference layout's taupe card, used for the single most relevant
/// reminder before the next appointment.
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.state, required this.now});
  final AppState state;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final appt = state.nextAppointment(now);
    final due = appt == null ? <TestReminder>[] : const ReminderService().dueBeforeAppointment(state.reminders, appt);
    final overdue = state.reminders.where((r) => r.displayState(now) == ReminderDisplayState.overdue).toList();
    final String title;
    final String body;
    if (overdue.isNotEmpty) {
      title = 'تحليل متأخر';
      body = '${overdue.first.testName} كان مستحقًا ${ArFormat.relativeDay(now, overdue.first.dueDate)}. حدّث حالته أو أعد جدولته.';
    } else if (appt != null && due.isNotEmpty) {
      title = 'قبل موعدك القادم';
      final names = due.map((r) => r.testName).take(2).join(' و');
      body = '$names مطلوب قبل موعدك ${ArFormat.relativeDay(now, appt.dateTime)}. أول استحقاق ${ArFormat.relativeDay(now, due.first.dueDate)}.';
    } else if (appt != null) {
      title = 'موعدك القادم ${ArFormat.relativeDay(now, appt.dateTime)}';
      body = 'لا توجد تحاليل مسجلة مستحقة قبله. تأكد مع فريقك الصحي إن كان هناك ما يلزم.';
    } else {
      title = 'لا يوجد موعد قادم مسجل';
      body = 'يمكنك تجهيز ملخص بياناتك في أي وقت من تبويب موعدي.';
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SpRadius.card),
        color: SpColors.notice,
        boxShadow: SpShadow.card,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(SpRadius.card),
          onTap: () => context.push('/reminders'),
          child: Stack(
            children: [
              PositionedDirectional(
                end: -8,
                bottom: -14,
                child: Icon(Icons.biotech_outlined, size: 96, color: Colors.white.withValues(alpha: 0.10)),
              ),
              Padding(
                padding: const EdgeInsets.all(SpSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontFamily: spFontFamily, fontSize: 15.5, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(body, style: const TextStyle(fontFamily: spFontFamily, fontSize: 13, height: 1.6, color: Color(0xFFF4EDE8))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({required this.report});
  final CgmReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eval = ref.watch(evaluationProvider(report.id));
    final t = Theme.of(context).textTheme;
    final tir = report.metrics[MetricKey.timeInRange];
    final period = report.effectivePeriod;
    return SpCard(
      onTap: () => context.push('/report/${report.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ArFormat.metric(tir), style: t.displaySmall?.copyWith(fontSize: 34, color: SpColors.tealDeep)),
                    Text('الوقت ضمن النطاق (70–180 ملغم/دل)', style: t.bodySmall),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SyntheticChip(show: report.provenance == DataProvenance.synthetic),
                  const SizedBox(height: 4),
                  Text(period == null ? 'فترة غير معروفة' : ArFormat.period(period), style: t.labelSmall),
                ],
              ),
            ],
          ),
          const SizedBox(height: SpSpace.md),
          RangeStrip(report: report),
          const SizedBox(height: SpSpace.lg),
          Row(
            children: [
              Expanded(child: MiniMetric(icon: Icons.analytics_outlined, color: SpColors.seriesGmi, label: 'GMI', value: ArFormat.metric(report.metrics[MetricKey.gmi]))),
              Expanded(child: MiniMetric(icon: Icons.water_drop_outlined, color: SpColors.teal, label: 'متوسط السكر', value: ArFormat.metric(report.metrics[MetricKey.meanGlucose], decimals: 0))),
              Expanded(child: MiniMetric(icon: Icons.sensors_rounded, color: SpColors.bandInRange, label: 'الحساس', value: ArFormat.metric(report.metrics[MetricKey.sensorActive], decimals: 0))),
            ],
          ),
          if (eval != null) ...[
            const SizedBox(height: SpSpace.md),
            const Divider(),
            const SizedBox(height: SpSpace.sm),
            Row(children: [
              OutcomeChip(outcome: eval.outcome),
              const Spacer(),
              Text(report.sourceType.labelAr, style: t.labelSmall),
            ]),
          ],
        ],
      ),
    );
  }
}

class OutcomeChip extends StatelessWidget {
  const OutcomeChip({super.key, required this.outcome});
  final ReviewOutcome outcome;
  @override
  Widget build(BuildContext context) => switch (outcome) {
        ReviewOutcome.routineSummary => StatusChip(label: outcome.titleAr, tone: Tone.info, icon: Icons.check_circle_outline),
        ReviewOutcome.reviewSuggested => StatusChip(label: outcome.titleAr, tone: Tone.warning, icon: Icons.support_agent_outlined),
        ReviewOutcome.needMoreData => StatusChip(label: outcome.titleAr, tone: Tone.neutral, icon: Icons.hourglass_empty_rounded),
        ReviewOutcome.seekMedicalHelp => StatusChip(label: outcome.titleAr, tone: Tone.critical, icon: Icons.local_hospital_outlined),
      };
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onOpenTab});
  final void Function(int) onOpenTab;

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String label, VoidCallback onTap) => Expanded(
          child: SpCard(
            padding: const EdgeInsets.symmetric(vertical: SpSpace.md, horizontal: SpSpace.sm),
            onTap: onTap,
            child: Column(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: SpColors.tealSoft, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: SpColors.tealDeep, size: 21),
              ),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(fontFamily: spFontFamily, fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.35, color: SpColors.ink)),
            ]),
          ),
        );
    return Row(children: [
      tile(Icons.upload_file_outlined, 'رفع تقرير جديد', () => context.push('/upload')),
      const SizedBox(width: SpSpace.sm),
      tile(Icons.event_repeat_outlined, 'التحاليل الدورية', () => context.push('/reminders')),
      const SizedBox(width: SpSpace.sm),
      tile(Icons.assignment_outlined, 'استعد لموعدك', () => onOpenTab(2)),
      const SizedBox(width: SpSpace.sm),
      tile(Icons.chat_bubble_outline_rounded, 'مساعد السكري الذكي', () => onOpenTab(3)),
    ]);
  }
}

class _Updates extends ConsumerWidget {
  const _Updates({required this.state, required this.now, required this.onOpenTab});
  final AppState state;
  final DateTime now;
  final void Function(int) onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hba = comparableHbA1c(state.labs);
    final cmp = ref.watch(gmiComparisonProvider);
    final appt = state.nextAppointment(now);
    final openRequests = state.followUps.where((f) => f.status != FollowUpStatus.closed).toList();

    Widget card({required IconData icon, required String title, required String value, required String sub, VoidCallback? onTap}) => SizedBox(
          width: 190,
          child: SpCard(
            onTap: onTap,
            padding: const EdgeInsets.all(SpSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icon, size: 18, color: SpColors.tealDeep),
                  const SizedBox(width: 6),
                  Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium)),
                ]),
                const SizedBox(height: SpSpace.sm),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        );

    final cards = <Widget>[
      card(
        icon: Icons.bloodtype_outlined,
        title: 'آخر نتيجة HbA1c',
        value: hba.isEmpty ? 'لا توجد نتيجة' : hba1cDisplay(hba.last).split(' (').first,
        sub: hba.isEmpty ? 'أضف نتيجة مختبر' : 'بتاريخ ${ArFormat.date(hba.last.collectionDate!)}',
        onTap: () => onOpenTab(1),
      ),
      card(
        icon: Icons.compare_arrows_rounded,
        title: 'GMI مقابل HbA1c',
        value: cmp.comparability.labelAr,
        sub: cmp.differencePercentPoints == null ? 'افتح المقارنة لمعرفة التفاصيل' : 'الفرق ${ArFormat.signed(cmp.differencePercentPoints!)} نقطة',
        onTap: () => context.push('/labs/gmi'),
      ),
      card(
        icon: Icons.event_outlined,
        title: 'الموعد القادم (محاكى)',
        value: appt == null ? 'لا يوجد' : ArFormat.shortDate(appt.dateTime),
        sub: appt == null ? 'لا توجد مواعيد مسجلة' : ArFormat.relativeDay(now, appt.dateTime),
        onTap: () => onOpenTab(2),
      ),
      card(
        icon: Icons.support_agent_outlined,
        title: 'طلبات المراجعة',
        value: openRequests.isEmpty ? 'لا طلبات مفتوحة' : openRequests.first.status.labelAr,
        sub: openRequests.isEmpty ? 'سجل الطلبات' : 'الطلب ${openRequests.first.pseudoId}',
        onTap: () => context.push('/followups'),
      ),
    ];
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: SpSpace.sm),
        itemBuilder: (_, i) => cards[i],
      ),
    );
  }
}
