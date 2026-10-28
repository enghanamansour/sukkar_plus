import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukkar_core/sukkar_core.dart';

import '../../core/format/ar_format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_controller.dart';
import '../../data/app_state.dart';
import '../../data/providers.dart';

const _fieldOrder = [
  MetricKey.timeInRange,
  MetricKey.timeVeryLow,
  MetricKey.timeLow,
  MetricKey.timeHigh,
  MetricKey.timeVeryHigh,
  MetricKey.timeBelowRangeTotal,
  MetricKey.timeAboveRangeTotal,
  MetricKey.meanGlucose,
  MetricKey.gmi,
  MetricKey.cv,
  MetricKey.sd,
  MetricKey.sensorActive,
];

class ExtractionReviewScreen extends ConsumerWidget {
  const ExtractionReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upload = ref.watch(appControllerProvider.select((s) => s.upload));
    final ctrl = ref.read(appControllerProvider.notifier);
    final t = Theme.of(context).textTheme;
    if (upload == null) {
      return SpPage(title: 'مراجعة القيم المستخرجة', children: [
        EmptyState(
          icon: Icons.inbox_outlined,
          title: 'لا يوجد تقرير قيد المراجعة',
          message: 'ارفع تقريرًا لمراجعة قيمه.',
          actionLabel: 'رفع تقرير',
          onAction: () => context.go('/upload'),
        ),
      ]);
    }
    final r = upload.result;
    final pending = r.fields.values.where((f) => f.isPending).length;
    final periodAmbiguous = r.metricsPeriod.status != ExtractionStatus.found && upload.periodOverride == null;

    return SpPage(
      title: 'مراجعة القيم المستخرجة',
      actions: [
        TextButton(
          onPressed: () async {
            final ok = await confirmDialog(context,
                title: 'إلغاء المراجعة؟', message: 'ستُحذف القيم المستخرجة ولن يُحفظ شيء.', confirmLabel: 'إلغاء المراجعة', destructive: true);
            if (ok) {
              ctrl.discardUpload();
              if (context.mounted) context.go('/');
            }
          },
          child: const Text('إلغاء'),
        ),
      ],
      children: [
        SpCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(upload.fileName, style: t.titleSmall, overflow: TextOverflow.ellipsis)),
              upload.isDemoFixture
                  ? const StatusChip(label: 'ملف تجريبي', tone: Tone.demo, icon: Icons.science_outlined)
                  : const StatusChip(label: 'ملف المستخدم', tone: Tone.neutral, icon: Icons.person_outline),
            ]),
            const SizedBox(height: SpSpace.xs),
            Wrap(spacing: 6, runSpacing: 6, children: [
              r.formatVerified
                  ? const StatusChip(label: 'تنسيق مُتحقَّق منه: Omnipod Discover', tone: Tone.info, icon: Icons.verified_outlined)
                  : const StatusChip(label: 'تنسيق غير مُتحقَّق منه', tone: Tone.warning, icon: Icons.help_outline),
              if (r.deviceLabel != null) StatusChip(label: r.deviceLabel!, tone: Tone.neutral, icon: Icons.devices_other_outlined),
              StatusChip(label: r.aiUsed ? 'قراءة محلية + ذكاء اصطناعي' : 'قراءة محلية فقط', tone: Tone.neutral, icon: Icons.memory_outlined),
            ]),
            if (upload.aiNoteAr != null) ...[const SizedBox(height: SpSpace.sm), Text(upload.aiNoteAr!, style: t.bodySmall)],
          ]),
        ),
        const SizedBox(height: SpSpace.md),
        _PeriodsCard(upload: upload),
        if (periodAmbiguous) ...[
          const SizedBox(height: SpSpace.sm),
          const InfoNote(tone: Tone.warning, text: 'تعذّر التأكد من فترة البيانات. حدّدها من البطاقة أعلاه، وإلا ستُعامل الفترة كغير معروفة.'),
        ],
        for (final w in r.warningsAr) ...[const SizedBox(height: SpSpace.sm), InfoNote(text: w)],
        const SizedBox(height: SpSpace.lg),
        _ChecksCard(checks: r.checks),
        const SizedBox(height: SpSpace.lg),
        const SectionHeader(title: 'القيم المستخرجة', subtitle: 'أكّد كل قيمة أو صححها أو حدّدها كغير متاحة. القيم غير المؤكدة لا تُستخدم.'),
        if (r.fields.values.any((f) => f.isPending && f.eligibleForBulkConfirm))
          Padding(
            padding: const EdgeInsets.only(bottom: SpSpace.md),
            child: OutlinedButton.icon(
              onPressed: ctrl.confirmAllEligible,
              icon: const Icon(Icons.done_all_rounded),
              label: const Text('تأكيد كل القيم التي اجتازت التحقق'),
            ),
          ),
        for (final k in _fieldOrder)
          if (r.fields[k] != null) Padding(padding: const EdgeInsets.only(bottom: SpSpace.sm), child: _FieldCard(field: r.fields[k]!, unit: r.glucoseUnit)),
      ],
      bottom: FilledButton(
        onPressed: pending > 0
            ? null
            : () async {
                try {
                  final id = await ctrl.acceptUpload();
                  if (context.mounted) context.go('/report/$id');
                } on UserFacingError catch (e) {
                  if (context.mounted) showSnack(context, e.messageAr);
                }
              },
        child: Text(pending > 0 ? 'بقيت $pending قيمة تحتاج قرارك' : 'اعتماد القيم وعرض التحليل'),
      ),
    );
  }
}

class _PeriodsCard extends ConsumerWidget {
  const _PeriodsCard({required this.upload});
  final UploadSession upload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = upload.result;
    String show(ExtractedPeriod p) => p.period == null ? 'غير موجودة' : '${ArFormat.period(p.period!)} (${ArFormat.days(p.period!.days)})';
    return SpCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        KeyValueRow(label: 'فترة التقرير المطبوعة', value: show(r.reportPeriod)),
        KeyValueRow(
          label: 'فترة المؤشرات المستخدمة',
          value: upload.periodOverride != null ? '${ArFormat.period(upload.periodOverride!)} (حددتها)' : show(r.metricsPeriod),
          emphasize: true,
        ),
        if (r.metricsPeriod.noteAr != null) Text(r.metricsPeriod.noteAr!, style: Theme.of(context).textTheme.bodySmall),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: () async {
              final now = ref.read(clockProvider)();
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(now.year - 3),
                lastDate: now,
                initialDateRange: r.metricsPeriod.period == null
                    ? null
                    : DateTimeRange(start: r.metricsPeriod.period!.start, end: r.metricsPeriod.period!.end),
                helpText: 'حدد فترة المؤشرات كما في التقرير',
              );
              if (picked != null) ref.read(appControllerProvider.notifier).setPeriodOverride(ReportPeriod(picked.start, picked.end));
            },
            icon: const Icon(Icons.edit_calendar_outlined, size: 18),
            label: const Text('تعديل الفترة'),
          ),
        ),
      ]),
    );
  }
}

class _ChecksCard extends StatelessWidget {
  const _ChecksCard({required this.checks});
  final List<ConsistencyCheck> checks;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SpCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('فحوص الاتساق الحسابية', style: t.titleSmall),
        Text('تُجرى بشيفرة ثابتة، لا بالذكاء الاصطناعي.', style: t.bodySmall),
        const SizedBox(height: SpSpace.sm),
        for (final c in checks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(
                c.passed == null ? Icons.remove_circle_outline : (c.passed! ? Icons.check_circle_outline : Icons.error_outline),
                size: 18,
                color: c.passed == null ? SpColors.inkMuted : (c.passed! ? SpColors.teal : SpColors.critical),
              ),
              const SizedBox(width: SpSpace.sm),
              Expanded(child: Text(c.messageAr, style: t.bodySmall?.copyWith(color: SpColors.ink))),
            ]),
          ),
      ]),
    );
  }
}

class _FieldCard extends ConsumerWidget {
  const _FieldCard({required this.field, required this.unit});
  final ExtractedField field;
  final GlucoseUnit unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final ctrl = ref.read(appControllerProvider.notifier);
    final f = field;
    final v = f.effectiveValue;
    final valueText = v == null ? (f.markedUnavailable ? 'حُدّد كغير متاح' : 'غير موجود في التقرير') : '${ArFormat.number(v, decimals: 2)} ${f.unit}';

    final Widget status = switch (f.verification) {
      VerificationStatus.verified => const StatusChip(label: 'مؤكَّد', tone: Tone.info, icon: Icons.check_rounded),
      VerificationStatus.needsReview => const StatusChip(label: 'بانتظار قرارك', tone: Tone.warning, icon: Icons.pending_outlined),
      _ => const StatusChip(label: 'غير متاح', tone: Tone.neutral, icon: Icons.remove_rounded),
    };

    return SpCard(
      color: f.isPending ? SpColors.surface : SpColors.surfaceMuted,
      padding: const EdgeInsets.all(SpSpace.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(f.key.labelAr, style: t.titleSmall)),
          status,
        ]),
        const SizedBox(height: 2),
        Text(valueText, style: t.titleMedium?.copyWith(color: v == null ? SpColors.inkMuted : SpColors.ink)),
        if (f.isCorrected) Text('القيمة المستخرجة أصلًا: ${ArFormat.number(f.extractedValue!, decimals: 2)}', style: t.bodySmall),
        const SizedBox(height: SpSpace.xs),
        Wrap(spacing: 6, runSpacing: 4, children: [
          StatusChip(label: f.extractionStatus.labelAr, tone: f.extractionStatus == ExtractionStatus.found ? Tone.neutral : Tone.warning),
          if (f.extractionStatus != ExtractionStatus.notFound)
            StatusChip(
              label: f.validation.labelAr,
              tone: f.validation == FieldValidation.valid ? Tone.info : (f.validation == FieldValidation.notCrossChecked ? Tone.neutral : Tone.critical),
            ),
          if (f.extractionStatus != ExtractionStatus.notFound) StatusChip(label: f.method.labelAr, tone: Tone.neutral),
        ]),
        if (f.sourceLabel != null || f.sourcePage != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('المصدر: ${f.sourcePage == null ? '' : 'صفحة ${f.sourcePage} — '}${f.sourceLabel ?? ''}', style: t.labelSmall),
          ),
        for (final m in f.messagesAr) Padding(padding: const EdgeInsets.only(top: 4), child: Text(m, style: t.bodySmall?.copyWith(color: SpColors.warning))),
        const SizedBox(height: SpSpace.xs),
        Wrap(spacing: 4, children: [
          if (v != null && f.verification != VerificationStatus.verified)
            TextButton.icon(onPressed: () => ctrl.confirmField(f.key), icon: const Icon(Icons.check_rounded, size: 18), label: const Text('تأكيد')),
          TextButton.icon(
            onPressed: () => _correct(context, ctrl),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(v == null ? 'إدخال من التقرير' : 'تصحيح'),
          ),
          if (f.isCorrected)
            TextButton.icon(onPressed: () => ctrl.restoreField(f.key), icon: const Icon(Icons.undo_rounded, size: 18), label: const Text('استعادة المستخرج')),
          if (!f.markedUnavailable && v != null)
            TextButton.icon(onPressed: () => ctrl.markUnavailable(f.key), icon: const Icon(Icons.block_rounded, size: 18), label: const Text('غير متاح')),
        ]),
      ]),
    );
  }

  Future<void> _correct(BuildContext context, AppController ctrl) async {
    final c = TextEditingController(text: field.effectiveValue == null ? '' : ArFormat.number(field.effectiveValue!, decimals: 2));
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تصحيح: ${field.key.labelAr}'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('أدخل القيمة كما هي مطبوعة في التقرير. ستُحفظ القيمة الأصلية للمقارنة.', style: TextStyle(fontFamily: spFontFamily, height: 1.6)),
          const SizedBox(height: SpSpace.md),
          TextField(
            controller: c,
            autofocus: true,
            textDirection: TextDirection.ltr,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,٠-٩٫]'))],
            decoration: InputDecoration(suffixText: field.unit),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(double.tryParse(AiTextValidator.normalizeDigits(c.text).replaceAll(',', '.'))),
            child: const Text('حفظ التصحيح'),
          ),
        ],
      ),
    );
    c.dispose();
    if (value == null) return;
    try {
      ctrl.correctField(field.key, value);
    } on UserFacingError catch (e) {
      if (context.mounted) showSnack(context, e.messageAr);
    }
  }
}
