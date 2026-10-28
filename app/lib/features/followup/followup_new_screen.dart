import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukkar_core/sukkar_core.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_state.dart';
import '../../data/providers.dart';
import 'followup_widgets.dart';

/// Step 5–7 of the patient flow: review the reason and exactly what will be
/// shared, then confirm submission.
class FollowUpNewScreen extends ConsumerStatefulWidget {
  const FollowUpNewScreen({super.key, required this.reportId, required this.trigger});
  final String reportId;
  final FollowUpTrigger trigger;
  @override
  ConsumerState<FollowUpNewScreen> createState() => _FollowUpNewScreenState();
}

class _FollowUpNewScreenState extends ConsumerState<FollowUpNewScreen> {
  final _note = TextEditingController();
  bool _agree = false;
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appControllerProvider);
    final report = s.reportById(widget.reportId);
    final eval = ref.watch(evaluationProvider(widget.reportId));
    final dispatcher = ref.watch(dispatcherProvider);
    final t = Theme.of(context).textTheme;
    if (report == null || eval == null) {
      return const SpPage(title: 'طلب مراجعة بشرية', children: [EmptyState(icon: Icons.search_off_rounded, title: 'التقرير غير موجود', message: '')]);
    }
    final trigger = (widget.trigger == FollowUpTrigger.rule && eval.triggered.isEmpty) ? FollowUpTrigger.userRequest : widget.trigger;
    final snapshot = snapshotFromReport(report);

    return SpPage(
      title: 'طلب مراجعة بشرية',
      children: [
        const InfoNote(tone: Tone.demo, title: 'محاكاة', text: notSentToProvidersAr),
        const SizedBox(height: SpSpace.lg),
        const SectionHeader(title: 'سبب الطلب'),
        SpCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            StatusChip(label: trigger.labelAr, tone: Tone.neutral, icon: trigger == FollowUpTrigger.rule ? Icons.rule_rounded : Icons.person_outline),
            const SizedBox(height: SpSpace.sm),
            if (trigger == FollowUpTrigger.rule)
              for (final r in eval.triggered) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('• ${r.explanationAr}', style: t.bodyMedium))
            else ...[
              Text('تطلب مراجعة بشرية لهذا التقرير بنفسك.', style: t.bodyMedium),
              const SizedBox(height: SpSpace.sm),
              TextField(
                controller: _note,
                maxLines: 3,
                maxLength: 300,
                decoration: const InputDecoration(hintText: 'ملاحظة اختيارية للمراجع (لا تكتب معلومات تعريفية)'),
              ),
            ],
            Text('هذا ليس تشخيصًا. القواعد المستخدمة تجريبية وتتطلب مراجعة سريرية قبل أي استخدام فعلي.', style: t.bodySmall),
          ]),
        ),
        const SizedBox(height: SpSpace.lg),
        const SectionHeader(title: 'ما سيُشارك مع المراجع', subtitle: 'القيم الموثّقة لهذا التقرير فقط، مع معرّف مستعار.'),
        SpCard(child: SnapshotView(snapshot: snapshot)),
        const SizedBox(height: SpSpace.md),
        const InfoNote(text: 'لن يُشارك: اسمك، تاريخ ميلادك، ملف PDF، نتائج المختبر، أو أي تقارير أخرى.'),
        const SizedBox(height: SpSpace.md),
        SpCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('إشعار الأتمتة', style: t.titleSmall),
            Text(dispatcher.label, style: t.bodySmall),
          ]),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _agree,
          onChanged: (v) => setState(() => _agree = v ?? false),
          title: Text('راجعت السبب والمعلومات أعلاه وأوافق على مشاركتها ضمن هذا العرض.', style: t.bodyMedium),
        ),
      ],
      bottom: FilledButton(
        onPressed: (!_agree || _sending)
            ? null
            : () async {
                setState(() => _sending = true);
                try {
                  final req = await ref.read(appControllerProvider.notifier).createAndSubmitFollowUp(
                        report: report,
                        evaluation: eval,
                        trigger: trigger,
                        userNoteAr: _note.text,
                      );
                  if (context.mounted) context.pushReplacement('/followup/${req.id}');
                } on UserFacingError catch (e) {
                  if (context.mounted) showSnack(context, e.messageAr);
                } finally {
                  if (mounted) setState(() => _sending = false);
                }
              },
        child: Text(_sending ? 'جارٍ الإرسال…' : 'تأكيد إرسال الطلب'),
      ),
    );
  }
}
