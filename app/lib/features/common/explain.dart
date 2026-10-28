import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukkar_core/sukkar_core.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';

Set<int> _dateParts(Iterable<DateTime> ds) => {for (final d in ds) ...[d.year, d.month, d.day]};

/// Grounded context for a report: only verified values are included.
ExplanationContext reportContext(CgmReport r, RuleEvaluation? e) {
  final p = r.effectivePeriod;
  return ExplanationContext(
    topic: ExplanationTopic.reportSummary,
    values: [
      for (final k in summaryMetricOrder)
        if (r.metrics[k]?.isVerified ?? false) GroundedValue(labelAr: k.labelAr, value: r.metrics[k]!.value!, unit: r.metrics[k]!.unit),
    ],
    periodLabel: p == null ? null : '${isoDate(p.start)} — ${isoDate(p.end)}',
    periodDays: p?.days,
    dateNumbers: p == null ? const {} : _dateParts([p.start, p.end]),
    missingAr: [
      ...r.quality.reasonsAr,
      for (final k in summaryMetricOrder)
        if (!(r.metrics[k]?.isVerified ?? false)) '${k.labelAr}: غير متاح',
    ],
    outcome: e?.outcome,
  );
}

ExplanationContext gmiContext(GmiHbA1cComparison c) => ExplanationContext(
      topic: ExplanationTopic.gmiVsHbA1c,
      values: [
        if (c.gmiPercent != null) GroundedValue(labelAr: 'GMI (تقدير من الحساس)', value: c.gmiPercent!, unit: '%'),
        if (c.hba1cPercent != null) GroundedValue(labelAr: 'HbA1c (تحليل مخبري)', value: c.hba1cPercent!, unit: '%'),
        if (c.differencePercentPoints != null) GroundedValue(labelAr: 'الفرق', value: c.differencePercentPoints!, unit: 'نقطة مئوية'),
      ],
      periodLabel: c.period == null ? null : '${isoDate(c.period!.start)} — ${isoDate(c.period!.end)}',
      periodDays: c.period?.days,
      dateNumbers: _dateParts([if (c.period != null) ...[c.period!.start, c.period!.end], if (c.hba1c?.collectionDate != null) c.hba1c!.collectionDate!]),
      extraAllowedNumbers: {if (c.daysFromPeriodEndToLab != null) c.daysFromPeriodEndToLab!.abs().toDouble(), 30},
      missingAr: c.notesAr,
    );

/// Shows an explanation in a bottom sheet with its source clearly labelled.
Future<void> showExplanationSheet(BuildContext context, WidgetRef ref, ExplanationContext ctx) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx2) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (_, scroll) => FutureBuilder<Explanation>(
        future: ref.read(appControllerProvider.notifier).explain(ctx),
        builder: (context, snap) {
          if (!snap.hasData) return const LoadingView(message: 'جارٍ إعداد الشرح…');
          final e = snap.data!;
          final t = Theme.of(context).textTheme;
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(SpSpace.xl, 0, SpSpace.xl, SpSpace.xxl),
            children: [
              Text('شرح مبسّط', style: t.titleLarge),
              const SizedBox(height: SpSpace.xs),
              StatusChip(
                label: e.sourceLabelAr,
                tone: e.source == ExplanationSource.ai ? Tone.info : Tone.neutral,
                icon: e.source == ExplanationSource.ai ? Icons.auto_awesome_outlined : Icons.article_outlined,
              ),
              if (e.fallbackReasonAr != null) ...[const SizedBox(height: SpSpace.sm), InfoNote(text: e.fallbackReasonAr!)],
              const SizedBox(height: SpSpace.md),
              SelectableText(e.text, style: t.bodyLarge),
              const SizedBox(height: SpSpace.lg),
              const InfoNote(tone: Tone.warning, text: 'شرح تعليمي يعتمد على القيم الموثّقة فقط، وليس تشخيصًا أو توصية علاجية.'),
            ],
          );
        },
      ),
    ),
  );
}
