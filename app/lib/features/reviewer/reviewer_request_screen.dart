import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukkar_core/sukkar_core.dart';

import '../../core/format/ar_format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_state.dart';
import '../../data/providers.dart';
import '../followup/followup_widgets.dart';

class ReviewerRequestScreen extends ConsumerStatefulWidget {
  const ReviewerRequestScreen({super.key, required this.requestId});
  final String requestId;
  @override
  ConsumerState<ReviewerRequestScreen> createState() => _ReviewerRequestScreenState();
}

class _ReviewerRequestScreenState extends ConsumerState<ReviewerRequestScreen> {
  final _note = TextEditingController();
  ReviewDecision _decision = ReviewDecision.reviewRequired;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() f, String done) async {
    setState(() => _busy = true);
    try {
      await f();
      if (mounted) showSnack(context, done);
    } on UserFacingError catch (e) {
      if (mounted) showSnack(context, e.messageAr);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appControllerProvider);
    final r = s.followUpById(widget.requestId);
    final ctrl = ref.read(appControllerProvider.notifier);
    final t = Theme.of(context).textTheme;
    if (r == null) {
      return const SpPage(title: 'مراجعة الطلب', children: [EmptyState(icon: Icons.search_off_rounded, title: 'الطلب غير موجود', message: '')]);
    }

    return SpPage(
      title: 'مراجعة الطلب',
      children: [
        SpCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(r.pseudoId, style: t.headlineSmall)),
              FollowUpStatusChip(status: r.status),
            ]),
            Text('${r.trigger.labelAr} — أُنشئ ${ArFormat.dateTime(r.createdAt)} — قواعد ${r.rulesVersion}', style: t.bodySmall),
            if (r.provenance == DataProvenance.synthetic) const Padding(padding: EdgeInsets.only(top: 6), child: SyntheticChip()),
          ]),
        ),
        const SizedBox(height: SpSpace.lg),
        const SectionHeader(title: 'لماذا أُنشئ الطلب؟'),
        SpCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.reasonAr, style: t.bodyMedium),
            if (r.ruleIds.isNotEmpty) ...[
              const SizedBox(height: SpSpace.sm),
              Wrap(spacing: 6, runSpacing: 4, children: [for (final id in r.ruleIds) StatusChip(label: id, tone: Tone.neutral, icon: Icons.rule_rounded)]),
              const SizedBox(height: 4),
              Text('قواعد تجريبية تعتمد على أهداف مرجعية عامة؛ ليست معايير فرز سريرية.', style: t.labelSmall),
            ],
          ]),
        ),
        const SizedBox(height: SpSpace.lg),
        const SectionHeader(title: 'المؤشرات الموثّقة وفترة المصدر', subtitle: 'هذا كل ما وافق المستخدم على مشاركته.'),
        SpCard(child: SnapshotView(snapshot: r.snapshot)),
        const SizedBox(height: SpSpace.lg),
        const SectionHeader(title: 'السجل'),
        SpCard(child: HistoryTimeline(history: r.history)),
        if (r.notes.isNotEmpty) ...[
          const SizedBox(height: SpSpace.lg),
          const SectionHeader(title: 'الملاحظات'),
          for (final n in r.notes)
            Padding(
              padding: const EdgeInsets.only(bottom: SpSpace.sm),
              child: SpCard(padding: const EdgeInsets.all(SpSpace.md), child: Text('${n.textAr}\n${n.authorLabel} — ${ArFormat.dateTime(n.at)}', style: t.bodySmall?.copyWith(color: SpColors.ink))),
            ),
        ],
        const SizedBox(height: SpSpace.lg),
        SpCard(child: DispatchView(dispatch: r.dispatch, onRetry: () => _run(() => ctrl.retryDispatch(r), 'أُعيدت المحاولة.'))),
        const SizedBox(height: SpSpace.lg),
        if (r.status == FollowUpStatus.awaitingReview)
          FilledButton.icon(
            onPressed: _busy ? null : () => _run(() => ctrl.startReview(r), 'بدأت المراجعة.'),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('بدء المراجعة'),
          ),
        if (r.status == FollowUpStatus.underReview) ...[
          const SectionHeader(title: 'تسجيل قرار تجريبي'),
          SpCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              RadioGroup<ReviewDecision>(
                groupValue: _decision,
                onChanged: (v) => setState(() => _decision = v ?? _decision),
                child: Column(children: [
                  for (final d in ReviewDecision.values)
                    RadioListTile<ReviewDecision>(contentPadding: EdgeInsets.zero, value: d, title: Text(d.labelAr), subtitle: Text(d.patientMessageAr, style: t.bodySmall)),
                ]),
              ),
              const SizedBox(height: SpSpace.sm),
              TextField(controller: _note, maxLines: 3, decoration: const InputDecoration(hintText: 'ملاحظة تجريبية للمستخدم (اختيارية)')),
              const SizedBox(height: SpSpace.md),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                          await ctrl.decide(r, _decision, noteAr: _note.text.trim().isEmpty ? null : _note.text.trim());
                          _note.clear();
                        }, 'سُجّل القرار وأصبح ظاهرًا للمستخدم.'),
                child: const Text('حفظ القرار وتحديث الحالة'),
              ),
            ]),
          ),
        ],
        if (r.status == FollowUpStatus.reviewed)
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _run(() => ctrl.closeFollowUp(r), 'أُغلق الطلب.'),
            icon: const Icon(Icons.lock_outline_rounded),
            label: const Text('إغلاق الطلب'),
          ),
        if (r.status != FollowUpStatus.closed && r.status != FollowUpStatus.underReview) ...[
          const SizedBox(height: SpSpace.lg),
          TextField(controller: _note, maxLines: 2, decoration: const InputDecoration(hintText: 'إضافة ملاحظة تجريبية')),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                        await ctrl.addReviewNote(r, _note.text);
                        _note.clear();
                      }, 'أُضيفت الملاحظة.'),
              child: const Text('إضافة الملاحظة'),
            ),
          ),
        ],
      ],
    );
  }
}
