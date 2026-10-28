import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukkar_core/sukkar_core.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_state.dart';
import '../../data/platform/pdf_documents.dart';
import '../../data/providers.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});
  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  static const _stages = [
    'التحقق من الملف',
    'قراءة نص الملف على الجهاز',
    'مقارنة القيم مع استخراج الذكاء الاصطناعي',
    'استخراج المؤشرات والتحقق منها',
  ];

  String? _fileName;
  int? _size;
  bool _demoFile = false;
  String? _stage;
  final _done = <String>[];
  String? _error;
  bool _busy = false;
  bool _useAi = false;

  Future<void> _run({required String name, required Future<List<int>> Function() load, required bool demo}) async {
    setState(() {
      _busy = true;
      _error = null;
      _done.clear();
      _stage = null;
      _demoFile = demo;
    });
    try {
      final bytes = await load();
      setState(() {
        _fileName = name;
        _size = bytes.length;
      });
      await ref.read(appControllerProvider.notifier).startUpload(
            fileName: name,
            bytes: bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
            isDemoFixture: demo,
            useAi: _useAi,
            onStage: (st) => setState(() {
              if (_stage != null) _done.add(_stage!);
              _stage = st;
            }),
          );
      if (!mounted) return;
      setState(() {
        if (_stage != null) _done.add(_stage!);
        _stage = null;
      });
      await context.push('/upload/review');
    } on UserFacingError catch (e) {
      setState(() => _error = e.messageAr);
    } catch (_) {
      setState(() => _error = 'حدث خطأ غير متوقع أثناء معالجة الملف. حاول مجددًا أو اختر ملفًا آخر.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickReal() async {
    final picked = await ref.read(filePickerProvider).pickPdf();
    if (picked == null) return;
    await _run(name: picked.name, load: () async => picked.bytes, demo: false);
  }

  Future<void> _useDemo() async {
    final now = ref.read(clockProvider)();
    await _run(
      name: 'synthetic_demo_report.pdf',
      load: () => buildSyntheticReportPdf(demoUploadLines(now)),
      demo: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appControllerProvider);
    final ai = ref.watch(aiExtractionProvider);
    final t = Theme.of(context).textTheme;
    final aiPossible = ai.isAvailable && (s.consent?.allowsExternalAi ?? false);

    return SpPage(
      title: 'رفع تقرير جديد',
      children: [
        SpCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('التنسيق المدعوم', style: t.titleSmall),
            const SizedBox(height: SpSpace.xs),
            Text(
              'صفحة الملخص (N-Day Summary) من تقرير Omnipod Discover لنظام Omnipod 5 مع حساس Dexcom G7، بصيغة PDF نصية. '
              'التقارير الأخرى بنمط AGP تُقرأ تجريبيًا ويجب تأكيد كل قيمة فيها.',
              style: t.bodyMedium,
            ),
            const SizedBox(height: SpSpace.sm),
            Text('لا يتصل التطبيق بالحساس أو المضخة مباشرة، ولا يقرأ بيانات الإنسولين. الحد الأقصى للحجم ${maxPdfBytes ~/ (1024 * 1024)} ميغابايت.',
                style: t.bodySmall),
          ]),
        ),
        const SizedBox(height: SpSpace.lg),
        if (s.consent == null)
          const InfoNote(
            tone: Tone.warning,
            title: 'الموافقة مطلوبة لرفع تقرير حقيقي',
            text: 'يمكنك تجربة التدفق كاملًا بالتقرير التجريبي دون موافقة. لرفع تقريرك أنت، أكمل الموافقة أولًا.',
          ),
        if (s.consent == null) ...[
          const SizedBox(height: SpSpace.sm),
          OutlinedButton.icon(onPressed: () => context.push('/consent'), icon: const Icon(Icons.verified_user_outlined), label: const Text('مراجعة الموافقة')),
        ],
        const SizedBox(height: SpSpace.lg),
        FilledButton.icon(
          onPressed: (_busy || s.consent == null) ? null : _pickReal,
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text('اختيار ملف PDF من جهازك'),
        ),
        const SizedBox(height: SpSpace.sm),
        OutlinedButton.icon(
          onPressed: _busy ? null : _useDemo,
          icon: const Icon(Icons.science_outlined),
          label: const Text('استخدم تقريرًا تجريبيًا (بيانات اصطناعية)'),
        ),
        if (!s.demoMode) ...[
          const SizedBox(height: SpSpace.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _useAi && aiPossible,
            onChanged: aiPossible ? (v) => setState(() => _useAi = v) : null,
            title: Text('مقارنة القيم مع استخراج Gemini', style: t.bodyMedium),
            subtitle: Text(
              aiPossible ? 'يُرسل الملف إلى الخادم ثم إلى Gemini لمرة واحدة، ولا يُخزّن.' : 'غير متاح: يتطلب موافقة على المعالجة الخارجية وإعداد الخادم.',
              style: t.bodySmall,
            ),
          ),
        ],
        if (_fileName != null) ...[
          const SizedBox(height: SpSpace.xl),
          SpCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.picture_as_pdf_outlined, color: SpColors.tealDeep),
                const SizedBox(width: SpSpace.sm),
                Expanded(child: Text(_fileName!, style: t.titleSmall, overflow: TextOverflow.ellipsis)),
                if (_demoFile) const StatusChip(label: 'ملف تجريبي', tone: Tone.demo, icon: Icons.science_outlined)
                else const StatusChip(label: 'ملف المستخدم', tone: Tone.neutral, icon: Icons.person_outline),
              ]),
              if (_size != null) Text(formatFileSize(_size!), style: t.bodySmall),
              const SizedBox(height: SpSpace.md),
              for (final st in _stages)
                if (_done.contains(st) || _stage == st)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      if (_done.contains(st))
                        const Icon(Icons.check_circle_rounded, size: 18, color: SpColors.teal)
                      else
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: SpSpace.sm),
                      Text(st, style: t.bodyMedium),
                    ]),
                  ),
              if (_busy && _stage == null && _done.isEmpty) const LinearProgressIndicator(),
            ]),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: SpSpace.lg),
          InfoNote(tone: Tone.critical, title: 'تعذّرت معالجة الملف', text: _error!),
        ],
      ],
    );
  }
}
