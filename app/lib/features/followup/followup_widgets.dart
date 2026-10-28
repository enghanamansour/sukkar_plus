import 'package:flutter/material.dart';
import 'package:sukkar_core/sukkar_core.dart';

import '../../core/format/ar_format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';

class FollowUpStatusChip extends StatelessWidget {
  const FollowUpStatusChip({super.key, required this.status});
  final FollowUpStatus status;
  @override
  Widget build(BuildContext context) => switch (status) {
        FollowUpStatus.draft => StatusChip(label: status.labelAr, tone: Tone.neutral, icon: Icons.edit_note_rounded),
        FollowUpStatus.awaitingReview => StatusChip(label: status.labelAr, tone: Tone.warning, icon: Icons.hourglass_top_rounded),
        FollowUpStatus.underReview => StatusChip(label: status.labelAr, tone: Tone.info, icon: Icons.manage_search_rounded),
        FollowUpStatus.moreInfoRequested => StatusChip(label: status.labelAr, tone: Tone.warning, icon: Icons.info_outline),
        FollowUpStatus.reviewed => StatusChip(label: status.labelAr, tone: Tone.info, icon: Icons.task_alt_rounded),
        FollowUpStatus.closed => StatusChip(label: status.labelAr, tone: Tone.neutral, icon: Icons.lock_outline_rounded),
      };
}

class SnapshotView extends StatelessWidget {
  const SnapshotView({super.key, required this.snapshot});
  final SharedSnapshot snapshot;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      KeyValueRow(label: 'الفترة', value: snapshot.periodLabel),
      for (final e in snapshot.items.entries) KeyValueRow(label: e.key, value: e.value),
      for (final q in snapshot.qualityNotesAr) Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $q', style: t.bodySmall)),
    ]);
  }
}

class HistoryTimeline extends StatelessWidget {
  const HistoryTimeline({super.key, required this.history});
  final List<StatusHistoryEntry> history;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(children: [
      for (var i = 0; i < history.length; i++)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: i == history.length - 1 ? SpColors.teal : SpColors.border, shape: BoxShape.circle),
            ),
            if (i < history.length - 1) Container(width: 2, height: 34, color: SpColors.border),
          ]),
          const SizedBox(width: SpSpace.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: SpSpace.sm),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(history[i].to.labelAr, style: t.titleSmall),
                Text(
                  '${ArFormat.dateTime(history[i].at)} — ${history[i].actorRole == UserRole.reviewer ? 'المراجع التجريبي' : 'المستخدم'}${history[i].noteAr == null ? '' : ' — ${history[i].noteAr}'}',
                  style: t.bodySmall,
                ),
              ]),
            ),
          ),
        ]),
    ]);
  }
}

class DispatchView extends StatelessWidget {
  const DispatchView({super.key, required this.dispatch, this.onRetry});
  final IntegrationDispatch dispatch;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final d = dispatch;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('إشعار الأتمتة', style: t.titleSmall)),
        StatusChip(
          label: d.state.labelAr,
          tone: d.state == DispatchState.failed ? Tone.critical : (d.isMock ? Tone.demo : Tone.info),
          icon: d.isMock ? Icons.science_outlined : Icons.cloud_done_outlined,
        ),
      ]),
      Text(
        d.isMock
            ? 'محاكي: سُجّل حدث مختصر بمعرّف مستعار فقط، ولم يُرسل إلى Make.com أو أي جهة.'
            : 'أُرسل حدث مختصر بمعرّف مستعار فقط إلى Make.com عبر الخادم.',
        style: t.bodySmall,
      ),
      if (d.attempts > 0) Text('المحاولات: ${d.attempts}${d.lastAttemptAt == null ? '' : ' — آخرها ${ArFormat.dateTime(d.lastAttemptAt!)}'}', style: t.labelSmall),
      if (d.lastError != null) Text('الخطأ: ${d.lastError}', style: t.labelSmall?.copyWith(color: SpColors.critical)),
      if (d.state == DispatchState.failed && onRetry != null)
        Align(alignment: AlignmentDirectional.centerEnd, child: TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة'))),
    ]);
  }
}

const notSentToProvidersAr = 'هذا طلب محاكى ضمن نموذج أولي. لا يُرسل إلى أي طبيب أو مستشفى أو جهة صحية حقيقية، ولا يُنشئ موعدًا.';
