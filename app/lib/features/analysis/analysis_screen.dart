import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukkar_core/sukkar_core.dart';

import '../../core/charts/range_bands.dart';
import '../../core/format/ar_format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../common/explain.dart';
import '../home/home_screen.dart' show OutcomeChip;

class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key, required this.reportId});
  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appControllerProvider);
    final report = s.reportById(reportId);
    final t = Theme.of(context).textTheme;
    if (report == null) {
      return const SpPage(title: 'تحليل التقرير', children: [
        EmptyState(icon: Icons.search_off_rounded, title: 'التقرير غير موجود', message: 'ربما حُذف أو لم يكتمل حفظه.'),
      ]);
    }
    final eval = ref.watch(evaluationProvider(reportId));
    final targets = consensusTargetsFor(s.targetProfile);
    final openRequest = s.followUps.where((f) => f.reportId == reportId && f.status != FollowUpStatus.closed).toList();
    final p = report.effectivePeriod;

    return SpPage(
      title: 'تحليل التقرير',
      actions: [
        PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'delete') {
              final ok = await confirmDialog(context,
                  title: 'حذف التقرير؟', message: 'ستُحذف القيم المؤكدة لهذا التقرير نهائيًا.', confirmLabel: 'حذف', destructive: true);
              if (ok) {
                await ref.read(appControllerProvider.notifier).deleteReport(reportId);
                if (context.mounted) context.go('/');
              }
            }
          },
          itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('حذف التقرير'))],
        ),
      ],
      children: [
        // ---------------------------------------------------------- header
        SpCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(p == null ? 'فترة غير معروفة' : ArFormat.period(p), style: t.titleMedium)),
              SyntheticChip(show: report.provenance == DataProvenance.synthetic),
            ]),
            if (report.reportPeriod != null && report.reportPeriod != p)
              Text('فترة التقرير المطبوعة: ${ArFormat.period(report.reportPeriod!)} — المؤشرات تخص فترة توفر بيانات الحساس فقط.',
                  style: t.bodySmall),
            const SizedBox(height: SpSpace.xs),
            Wrap(spacing: 6, runSpacing: 4, children: [
              StatusChip(label: report.sourceType.labelAr, tone: Tone.neutral, icon: Icons.description_outlined),
              if (report.deviceLabel != null) StatusChip(label: report.deviceLabel!, tone: Tone.neutral),
              StatusChip(
                label: report.hasRawReadings ? 'محسوب من قراءات تفصيلية' : 'ملخص مطبوع (دون قراءات تفصيلية)',
                tone: Tone.info,
                icon: report.hasRawReadings ? Icons.functions : Icons.print_outlined,
              ),
            ]),
          ]),
        ),
        const SizedBox(height: SpSpace.lg),

        // ---------------------------------------------------------- outcome
        if (eval != null) _OutcomeCard(reportId: reportId, eval: eval, hasOpenRequest: openRequest.isNotEmpty, openRequestId: openRequest.isEmpty ? null : openRequest.first.id),
        const SizedBox(height: SpSpace.lg),

        // ---------------------------------------------------- sufficiency
        _QualityCard(report: report),
        const SizedBox(height: SpSpace.lg),

        // ----------------------------------------------------- time in ranges
        SectionHeader(title: 'الوقت في النطاقات', subtitle: targets.isEmpty ? null : 'مع الأهداف المرجعية العامة للفئة: ${s.targetProfile.labelAr}'),
        SpCard(
          child: Column(children: [
            RangeStrip(report: report, height: 16),
            const SizedBox(height: SpSpace.md),
            RangeLegend(report: report, targets: targets),
            const SizedBox(height: SpSpace.sm),
            for (final n in targets.notesAr) Padding(padding: const EdgeInsets.only(top: 4), child: InfoNote(text: n)),
          ]),
        ),
        const SizedBox(height: SpSpace.lg),

        // ----------------------------------------------------------- metrics
        const SectionHeader(title: 'المؤشرات الموثّقة', subtitle: 'كل قيمة موسومة بمصدرها: مستخرجة أو محسوبة أو مصححة أو غير متاحة.'),
        SpCard(
          child: Column(children: [
            for (final k in summaryMetricOrder) _MetricRow(metric: report.metrics[k], keyName: k, target: targets[k]),
          ]),
        ),
        if (report.hasRawReadings) ...[
          const SizedBox(height: SpSpace.lg),
          _EpisodesCard(report: report),
        ],
        const SizedBox(height: SpSpace.lg),
        for (final w in report.warningsAr) Padding(padding: const EdgeInsets.only(bottom: SpSpace.sm), child: InfoNote(text: w)),
        const SizedBox(height: SpSpace.sm),
        Wrap(spacing: SpSpace.sm, runSpacing: SpSpace.sm, children: [
          OutlinedButton.icon(onPressed: () => context.push('/history'), icon: const Icon(Icons.timeline_rounded), label: const Text('مقارنة بالفترة السابقة')),
          OutlinedButton.icon(onPressed: () => context.push('/labs/gmi'), icon: const Icon(Icons.compare_arrows_rounded), label: const Text('GMI مقابل HbA1c')),
          OutlinedButton.icon(
            onPressed: () => showExplanationSheet(context, ref, reportContext(report, eval)),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('اشرح لي هذا التقرير'),
          ),
        ]),
      ],
    );
  }
}

class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({required this.reportId, required this.eval, required this.hasOpenRequest, this.openRequestId});
  final String reportId;
  final RuleEvaluation eval;
  final bool hasOpenRequest;
  final String? openRequestId;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SpCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          OutcomeChip(outcome: eval.outcome),
          const Spacer(),
          Text('قواعد ${eval.rulesVersion}', style: t.labelSmall),
        ]),
        const SizedBox(height: SpSpace.sm),
        Text(eval.outcome.explanationAr, style: t.bodyMedium),
        if (eval.reasonsAr.isNotEmpty) ...[
          const SizedBox(height: SpSpace.sm),
          for (final r in eval.reasonsAr)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(padding: EdgeInsets.only(top: 7), child: Icon(Icons.circle, size: 5, color: SpColors.inkSecondary)),
                const SizedBox(width: SpSpace.sm),
                Expanded(child: Text(r, style: t.bodySmall?.copyWith(color: SpColors.ink))),
              ]),
            ),
        ],
        for (final l in eval.limitationsAr) Padding(padding: const EdgeInsets.only(top: SpSpace.xs), child: InfoNote(text: l)),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('تفاصيل القواعد المطبقة', style: t.labelLarge?.copyWith(color: SpColors.tealDeep)),
            children: [for (final r in eval.results) _RuleDetail(result: r)],
          ),
        ),
        const SizedBox(height: SpSpace.xs),
        if (hasOpenRequest)
          OutlinedButton.icon(
            onPressed: () => context.push('/followup/$openRequestId'),
            icon: const Icon(Icons.support_agent_outlined),
            label: const Text('متابعة طلب المراجعة المفتوح'),
          )
        else if (eval.outcome == ReviewOutcome.reviewSuggested)
          FilledButton.icon(
            onPressed: () => context.push('/followup/new/$reportId'),
            icon: const Icon(Icons.support_agent_outlined),
            label: const Text('طلب مراجعة بشرية (محاكاة)'),
          )
        else
          OutlinedButton.icon(
            onPressed: () => context.push('/followup/new/$reportId?trigger=user'),
            icon: const Icon(Icons.support_agent_outlined),
            label: const Text('أرغب في مراجعة بشرية رغم ذلك'),
          ),
      ]),
    );
  }
}

class _RuleDetail extends StatelessWidget {
  const _RuleDetail({required this.result});
  final RuleResult result;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = result.rule;
    final (label, tone) = switch (result.status) {
      RuleStatus.triggered => ('انطبقت', Tone.warning),
      RuleStatus.notTriggered => ('لم تنطبق', Tone.info),
      RuleStatus.notAssessable => ('تعذّر التقييم', Tone.neutral),
      RuleStatus.notApplicable => ('لا تنطبق على هذا النوع', Tone.neutral),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: SpSpace.sm),
      padding: const EdgeInsets.all(SpSpace.md),
      decoration: BoxDecoration(color: SpColors.surfaceMuted, borderRadius: BorderRadius.circular(SpRadius.inner), border: Border.all(color: SpColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${r.id} v${r.version}', style: t.titleSmall)),
          StatusChip(label: label, tone: tone),
        ]),
        Text(r.titleAr, style: t.bodySmall?.copyWith(color: SpColors.ink)),
        const SizedBox(height: 4),
        Text(result.explanationAr, style: t.bodySmall),
        const SizedBox(height: 6),
        KeyValueRow(label: 'المؤشر', value: r.metricDescriptionAr),
        KeyValueRow(label: 'فترة الملاحظة', value: r.observationWindowAr),
        KeyValueRow(label: 'الحد', value: r.thresholdDescriptionAr),
        KeyValueRow(label: 'متطلبات جودة البيانات', value: '${r.minDays} يومًا و${formatNumber(r.minCoveragePercent)}% تغطية'),
        KeyValueRow(label: 'المكررات', value: r.duplicatesPolicyAr),
        KeyValueRow(label: 'الفجوات', value: r.gapsPolicyAr),
        KeyValueRow(label: 'المصدر', value: r.sourceRef),
        KeyValueRow(label: 'الإجراء المتوقع', value: r.expectedActionAr),
        const SizedBox(height: 4),
        StatusChip(label: r.approvalLabelAr, tone: Tone.warning, icon: Icons.science_outlined),
        const SizedBox(height: 4),
        Text(r.limitationsAr, style: t.labelSmall),
      ]),
    );
  }
}

class _QualityCard extends StatelessWidget {
  const _QualityCard({required this.report});
  final CgmReport report;

  @override
  Widget build(BuildContext context) {
    final q = report.quality;
    final t = Theme.of(context).textTheme;
    return SpCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('كفاية البيانات', style: t.titleSmall)),
          q.sufficient
              ? const StatusChip(label: 'تستوفي الحد العام', tone: Tone.info, icon: Icons.check_circle_outline)
              : const StatusChip(label: 'غير كافية للتقييم', tone: Tone.warning, icon: Icons.warning_amber_rounded),
        ]),
        Text('الحد العام: 14 يومًا من البيانات مع تغطية 70% على الأقل (الإجماع الدولي 2019).', style: t.bodySmall),
        const SizedBox(height: SpSpace.sm),
        KeyValueRow(label: 'عدد الأيام', value: q.daysOfData == null ? 'غير معروف' : ArFormat.days(q.daysOfData!)),
        KeyValueRow(label: 'التغطية', value: q.coveragePercent == null ? 'غير معروفة' : '${ArFormat.number(q.coveragePercent!)}%'),
        Text(q.coverageSource, style: t.labelSmall),
        if (report.hasRawReadings) ...[
          KeyValueRow(label: 'قراءات مكررة حُذفت', value: '${q.duplicateReadings}'),
          KeyValueRow(label: 'تعارضات بنفس التوقيت', value: '${q.conflictingDuplicates}'),
          KeyValueRow(label: 'فجوات في البيانات', value: q.gapCount == 0 ? 'لا توجد' : '${q.gapCount} (أطولها ${q.longestGapMinutes} دقيقة)'),
        ],
        for (final r in q.reasonsAr) Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $r', style: t.bodySmall?.copyWith(color: SpColors.warning))),
      ]),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.metric, required this.keyName, this.target});
  final MetricValue? metric;
  final MetricKey keyName;
  final TargetSpec? target;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final m = metric;
    final v = (m?.isVerified ?? false) ? m!.value : null;
    String? targetText;
    if (target != null && v != null) {
      targetText = '${target!.isMetBy(v) ? 'ضمن' : 'خارج'} الهدف المرجعي العام (${target!.textAr})';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpSpace.sm),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(keyName.labelAr, style: t.bodyMedium),
            const SizedBox(height: 2),
            OriginChip(metric: m),
            if (m?.originalExtractedValue != null) Text('الأصل المستخرج: ${ArFormat.number(m!.originalExtractedValue!)}', style: t.labelSmall),
            if (m?.note != null) Text(m!.note!, style: t.labelSmall),
            if (targetText != null) Text(targetText, style: t.labelSmall),
          ]),
        ),
        Text(ArFormat.metric(m), style: t.titleSmall?.copyWith(color: v == null ? SpColors.inkMuted : SpColors.ink)),
      ]),
    );
  }
}

class _EpisodesCard extends StatelessWidget {
  const _EpisodesCard({required this.report});
  final CgmReport report;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final eps = const CgmCalculator().compute(report.readings!, window: report.effectivePeriod).episodesBelow54;
    return SpCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('نوبات أقل من 54 ملغم/دل (15 دقيقة أو أكثر)', style: t.titleSmall),
        Text('محسوبة من القراءات التفصيلية بفاصل 5 دقائق؛ لا تُدمج النوبات عبر فجوات البيانات.', style: t.bodySmall),
        const SizedBox(height: SpSpace.sm),
        if (eps.isEmpty) Text('لم تُرصد نوبات.', style: t.bodyMedium),
        for (final e in eps)
          KeyValueRow(label: '${ArFormat.weekdayDate(e.start)} — ${ArFormat.time(e.start)}', value: '${e.durationMinutes} دقيقة، أدنى ${ArFormat.number(e.nadirMgdl, decimals: 0)}'),
      ]),
    );
  }
}
