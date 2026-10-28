import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukkar_core/sukkar_core.dart';

import '../../core/format/ar_format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_state.dart';
import '../../data/providers.dart';

/// Manual laboratory entry — the primary, always-available path.
class LabEntryScreen extends ConsumerStatefulWidget {
  const LabEntryScreen({super.key, this.reminderId, this.initialCode});
  final String? reminderId;
  final LabTestCode? initialCode;

  @override
  ConsumerState<LabEntryScreen> createState() => _LabEntryScreenState();
}

class _LabEntryScreenState extends ConsumerState<LabEntryScreen> {
  late LabTestCode _code = widget.initialCode ?? LabTestCode.hba1c;
  final _name = TextEditingController();
  final _value = TextEditingController();
  final _unit = TextEditingController();
  final _refLow = TextEditingController();
  final _refHigh = TextEditingController();
  final _refText = TextEditingController();
  final _labName = TextEditingController();
  DateTime? _date;
  bool _unknownDate = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final rid = widget.reminderId;
    if (rid != null) {
      for (final r in ref.read(appControllerProvider).reminders) {
        if (r.id == rid) _code = r.testCode;
      }
    }
    _unit.text = _code.suggestedUnits.isEmpty ? '' : _code.suggestedUnits.first;
  }

  @override
  void dispose() {
    for (final c in [_name, _value, _unit, _refLow, _refHigh, _refText, _labName]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) => double.tryParse(AiTextValidator.normalizeDigits(c.text.trim()).replaceAll(',', '.'));

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(appControllerProvider.notifier).addLab(
            code: _code,
            testName: _name.text,
            value: _num(_value),
            unit: _unit.text,
            collectionDate: _unknownDate ? null : _date,
            referenceInterval: ReferenceInterval(low: _num(_refLow), high: _num(_refHigh), text: _refText.text.trim().isEmpty ? null : _refText.text.trim()),
            labName: _labName.text,
            linkedReminderId: widget.reminderId,
          );
      if (!mounted) return;
      showSnack(context, 'حُفظت النتيجة.');
      context.pop();
    } on UserFacingError catch (e) {
      if (mounted) showSnack(context, e.messageAr);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final now = ref.read(clockProvider)();
    final v = _num(_value);
    final hbUnit = parseHbA1cUnit(_unit.text);
    String? preview;
    if (_code == LabTestCode.hba1c && v != null && hbUnit != null) {
      preview = hbUnit == HbA1cUnit.percent
          ? 'يعادل تقريبًا ${ArFormat.number(HbA1c.percentToMmolMol(v), decimals: 0)} mmol/mol'
          : 'يعادل تقريبًا ${ArFormat.number(HbA1c.mmolMolToPercent(v))}%';
    }
    final numberInput = <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'[0-9.,٠-٩٫]'))];

    return SpPage(
      title: 'إضافة نتيجة مختبر',
      children: [
        if (widget.reminderId != null)
          const Padding(
            padding: EdgeInsets.only(bottom: SpSpace.md),
            child: InfoNote(tone: Tone.info, text: 'سيُسجَّل التذكير المرتبط كمكتمل عند حفظ هذه النتيجة.'),
          ),
        DropdownButtonFormField<LabTestCode>(
          initialValue: _code,
          decoration: const InputDecoration(labelText: 'التحليل'),
          items: [for (final c in LabTestCode.values) DropdownMenuItem(value: c, child: Text(c.labelAr))],
          onChanged: (c) => setState(() {
            _code = c ?? _code;
            _unit.text = _code.suggestedUnits.isEmpty ? '' : _code.suggestedUnits.first;
          }),
        ),
        if (_code == LabTestCode.other) ...[
          const SizedBox(height: SpSpace.md),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم التحليل كما في تقرير المختبر')),
        ],
        const SizedBox(height: SpSpace.md),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _value,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: numberInput,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'القيمة'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: SpSpace.sm),
          Expanded(
            flex: 2,
            child: _code.suggestedUnits.isEmpty
                ? TextField(controller: _unit, decoration: const InputDecoration(labelText: 'الوحدة'), onChanged: (_) => setState(() {}))
                : DropdownButtonFormField<String>(
                    initialValue: _code.suggestedUnits.contains(_unit.text) ? _unit.text : _code.suggestedUnits.first,
                    decoration: const InputDecoration(labelText: 'الوحدة'),
                    items: [for (final u in _code.suggestedUnits) DropdownMenuItem(value: u, child: Text(u, textDirection: TextDirection.ltr))],
                    onChanged: (u) => setState(() => _unit.text = u ?? _unit.text),
                  ),
          ),
        ]),
        if (preview != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(preview, style: t.bodySmall)),
        const SizedBox(height: SpSpace.md),
        SpCard(
          padding: const EdgeInsets.symmetric(horizontal: SpSpace.md, vertical: SpSpace.xs),
          child: Column(children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: !_unknownDate,
              leading: const Icon(Icons.event_outlined),
              title: const Text('تاريخ سحب العينة'),
              subtitle: Text(_unknownDate ? 'غير معروف' : (_date == null ? 'اختر التاريخ' : ArFormat.date(_date!))),
              onTap: () async {
                final d = await showDatePicker(context: context, firstDate: DateTime(now.year - 10), lastDate: now, initialDate: _date ?? now);
                if (d != null) setState(() => _date = d);
              },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _unknownDate,
              onChanged: (v) => setState(() => _unknownDate = v ?? false),
              title: const Text('لا أعرف تاريخ السحب'),
              subtitle: const Text('لن تُستخدم النتيجة في المقارنات المرتبطة بالتاريخ.'),
            ),
          ]),
        ),
        const SizedBox(height: SpSpace.lg),
        Text('مرجع المختبر (اختياري)', style: t.titleSmall),
        Text('انسخه كما هو مطبوع في تقرير المختبر. يختلف من مختبر لآخر وليس هدفًا علاجيًا.', style: t.bodySmall),
        const SizedBox(height: SpSpace.sm),
        Row(children: [
          Expanded(child: TextField(controller: _refLow, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: numberInput, decoration: const InputDecoration(labelText: 'الحد الأدنى'))),
          const SizedBox(width: SpSpace.sm),
          Expanded(child: TextField(controller: _refHigh, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: numberInput, decoration: const InputDecoration(labelText: 'الحد الأعلى'))),
        ]),
        const SizedBox(height: SpSpace.sm),
        TextField(controller: _refText, decoration: const InputDecoration(labelText: 'نص المرجع كما هو (مثل: أقل من 100)')),
        const SizedBox(height: SpSpace.md),
        TextField(controller: _labName, decoration: const InputDecoration(labelText: 'اسم المختبر (اختياري)')),
        const SizedBox(height: SpSpace.lg),
        const InfoNote(text: 'بحفظ النتيجة تؤكد أن القيمة والوحدة والتاريخ مطابقة لتقرير المختبر.'),
      ],
      bottom: FilledButton(onPressed: _saving ? null : _save, child: const Text('حفظ النتيجة')),
    );
  }
}
