import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukkar_core/sukkar_core.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../common/explain.dart';

enum _Intent { report, gmi, missing, questions, urgent, dosing, unknown }

/// "مساعد السكري الذكي": a bounded assistant. It explains verified data,
/// lists missing data and suggests neutral questions. It does not chat
/// freely, diagnose, triage or discuss doses.
_Intent classify(String text) {
  final s = text.toLowerCase();
  bool any(List<String> words) => words.any(s.contains);
  if (any(['طارئ', 'طوارئ', 'إغماء', 'اغماء', 'فقدان الوعي', 'لا أستطيع التنفس', 'ألم شديد', 'تشنج', 'قلق عاجل', 'emergency', 'نوبة شديدة'])) return _Intent.urgent;
  if (any(['جرعة', 'جرعات', 'وحدة', 'وحدات', 'كم آخذ', 'إنسولين', 'انسولين', 'dose', 'insulin'])) return _Intent.dosing;
  if (any(['gmi', 'hba1c', 'تراكمي', 'الفرق'])) return _Intent.gmi;
  if (any(['ناقص', 'نقص', 'مفقود', 'كافية', 'كفاية'])) return _Intent.missing;
  if (any(['سؤال', 'أسئلة', 'اسأل', 'موعد'])) return _Intent.questions;
  if (any(['تقرير', 'نطاق', 'نسبة', 'اشرح', 'شرح', 'tir'])) return _Intent.report;
  return _Intent.unknown;
}

class _Msg {
  const _Msg({required this.fromUser, this.text, this.explanation, this.widget});
  final bool fromUser;
  final String? text;
  final Explanation? explanation;
  final Widget? widget;
}

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});
  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _input = TextEditingController();
  final _messages = <_Msg>[];
  bool _thinking = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _ask(String text, {_Intent? intent}) async {
    final i = intent ?? classify(text);
    setState(() {
      _messages.add(_Msg(fromUser: true, text: text));
      _thinking = true;
    });
    final s = ref.read(appControllerProvider);
    final ctrl = ref.read(appControllerProvider.notifier);
    _Msg reply;
    switch (i) {
      case _Intent.urgent:
        reply = const _Msg(fromUser: false, widget: _UrgentCard());
      case _Intent.dosing:
        reply = const _Msg(
          fromUser: false,
          text: 'لا أستطيع تقديم أو تعديل جرعات الإنسولين أو أي دواء. هذه قرارات تُتخذ مع فريقك الصحي. '
              'يمكنني شرح بيانات تقريرك الموثّقة أو تجهيز أسئلة لموعدك.',
        );
      case _Intent.report:
        final r = s.latestReport;
        if (r == null) {
          reply = const _Msg(fromUser: false, text: 'لا يوجد تقرير موثّق بعد. ارفع صفحة الملخص من تقرير الحساس أولًا.');
        } else {
          final e = ref.read(evaluationProvider(r.id));
          reply = _Msg(fromUser: false, explanation: await ctrl.explain(reportContext(r, e)));
        }
      case _Intent.gmi:
        reply = _Msg(fromUser: false, explanation: await ctrl.explain(gmiContext(ref.read(gmiComparisonProvider))));
      case _Intent.missing:
        final v = ref.read(visitSummaryProvider);
        reply = _Msg(
          fromUser: false,
          explanation: await ctrl.explain(ExplanationContext(topic: ExplanationTopic.missingData, values: const [], missingAr: [...v.missingAr, ...v.qualityWarningsAr])),
        );
      case _Intent.questions:
        final v = ref.read(visitSummaryProvider);
        reply = _Msg(fromUser: false, text: 'أسئلة مقترحة لموعدك (أمثلة محايدة، وليست نصيحة طبية):\n${v.questionsAr.map((q) => '• $q').join('\n')}');
      case _Intent.unknown:
        reply = const _Msg(
          fromUser: false,
          text: 'أستطيع: شرح أحدث تقرير، أو توضيح الفرق بين GMI وHbA1c، أو بيان البيانات الناقصة، أو اقتراح أسئلة لموعدك. '
              'اختر أحد الاقتراحات بالأسفل.',
        );
    }
    if (!mounted) return;
    setState(() {
      _messages.add(reply);
      _thinking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final live = ref.watch(explanationProvider).isLive;
    final chips = <(String, _Intent)>[
      ('اشرح لي أحدث تقرير', _Intent.report),
      ('ما الفرق بين GMI وHbA1c؟', _Intent.gmi),
      ('ما البيانات الناقصة؟', _Intent.missing),
      ('أسئلة لموعدي', _Intent.questions),
      ('لدي قلق عاجل على صحتي', _Intent.urgent),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('مساعد السكري الذكي')),
      body: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(SpSpace.page, SpSpace.sm, SpSpace.page, SpSpace.lg),
            children: [
              InfoNote(
                tone: Tone.neutral,
                text: 'يشرح المساعد بياناتك الموثّقة فقط. لا يشخّص، ولا يقيّم الحالات الطارئة، ولا يقترح جرعات. '
                    '${live ? 'قد يُستخدم Gemini عبر الخادم مع فحص النص قبل عرضه.' : 'يعمل الآن بقوالب محلية دون ذكاء اصطناعي.'}',
              ),
              const SizedBox(height: SpSpace.md),
              for (final m in _messages) _Bubble(msg: m),
              if (_thinking) const Padding(padding: EdgeInsets.all(SpSpace.md), child: LinearProgressIndicator()),
              if (_messages.isEmpty) ...[
                const SizedBox(height: SpSpace.xl),
                Text('بماذا أساعدك؟', style: t.titleMedium, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
        Container(
          color: SpColors.surface,
          padding: const EdgeInsets.fromLTRB(SpSpace.page, SpSpace.sm, SpSpace.page, SpSpace.sm),
          child: Column(children: [
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: chips.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, i) => ActionChip(
                  label: Text(chips[i].$1),
                  onPressed: _thinking ? null : () => _ask(chips[i].$1, intent: chips[i].$2),
                ),
              ),
            ),
            const SizedBox(height: SpSpace.sm),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  textInputAction: TextInputAction.send,
                  decoration: const InputDecoration(hintText: 'اكتب سؤالك عن بياناتك…'),
                  onSubmitted: (v) {
                    if (v.trim().isEmpty || _thinking) return;
                    _input.clear();
                    _ask(v.trim());
                  },
                ),
              ),
              const SizedBox(width: SpSpace.sm),
              IconButton.filled(
                onPressed: _thinking
                    ? null
                    : () {
                        final v = _input.text.trim();
                        if (v.isEmpty) return;
                        _input.clear();
                        _ask(v);
                      },
                icon: const Icon(Icons.send_rounded),
                tooltip: 'إرسال',
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg});
  final _Msg msg;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final e = msg.explanation;
    final body = msg.widget ??
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e?.text ?? msg.text ?? '', style: t.bodyMedium?.copyWith(color: msg.fromUser ? Colors.white : SpColors.ink)),
          if (e != null) ...[
            const SizedBox(height: 6),
            StatusChip(label: e.sourceLabelAr, tone: e.source == ExplanationSource.ai ? Tone.info : Tone.neutral),
            if (e.fallbackReasonAr != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(e.fallbackReasonAr!, style: t.labelSmall)),
          ],
        ]);
    return Align(
      alignment: msg.fromUser ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: SpSpace.sm),
        padding: msg.widget == null ? const EdgeInsets.all(SpSpace.md) : EdgeInsets.zero,
        decoration: msg.widget == null
            ? BoxDecoration(
                color: msg.fromUser ? SpColors.teal : SpColors.surface,
                borderRadius: BorderRadius.circular(SpRadius.card),
                border: msg.fromUser ? null : Border.all(color: SpColors.border),
              )
            : null,
        child: body,
      ),
    );
  }
}

/// General safety messaging only. The prototype cannot rule an emergency in
/// or out, so it never tries.
class _UrgentCard extends StatelessWidget {
  const _UrgentCard();
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InfoNote(tone: Tone.critical, title: ReviewOutcome.seekMedicalHelp.titleAr, text: ReviewOutcome.seekMedicalHelp.explanationAr),
      const SizedBox(height: SpSpace.sm),
      OutlinedButton.icon(
        onPressed: () => context.push('/followups'),
        icon: const Icon(Icons.support_agent_outlined),
        label: const Text('طلبات المراجعة ليست بديلًا عن الطوارئ'),
      ),
    ]);
  }
}
