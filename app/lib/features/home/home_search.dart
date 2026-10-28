import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/ar_format.dart';
import '../../core/theme/tokens.dart';
import '../../data/providers.dart';

class _Entry {
  const _Entry(this.title, this.subtitle, this.icon, this.keywords, this.open);
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> keywords;
  final void Function(BuildContext, void Function(int)) open;
}

final _staticEntries = <_Entry>[
  _Entry('رفع تقرير جديد', 'تقرير الحساس بصيغة PDF', Icons.upload_file_outlined, ['رفع', 'تقرير', 'pdf', 'حساس', 'omnipod', 'dexcom'],
      (c, _) => c.push('/upload')),
  _Entry('مقارنة GMI مع HbA1c', 'مع التواريخ وحدود المقارنة', Icons.compare_arrows_rounded, ['gmi', 'hba1c', 'تراكمي', 'مقارنة'],
      (c, _) => c.push('/labs/gmi')),
  _Entry('مقارنة فترات الحساس', 'الفترة السابقة مقابل الحالية', Icons.timeline_rounded, ['مقارنة', 'فترة', 'تاريخ', 'سابق'],
      (c, _) => c.push('/history')),
  _Entry('التحاليل الدورية', 'التذكيرات المطلوبة قبل الموعد', Icons.event_repeat_outlined, ['تذكير', 'تحليل', 'دوري', 'موعد'],
      (c, _) => c.push('/reminders')),
  _Entry('إضافة نتيجة مختبر', 'HbA1c أو تحليل آخر', Icons.add_chart_outlined, ['مختبر', 'نتيجة', 'إضافة', 'hba1c', 'ldl'],
      (c, _) => c.push('/labs/add')),
  _Entry('استعد لموعدك', 'ملخص قابل للتصدير وأسئلة مقترحة', Icons.assignment_outlined, ['موعد', 'ملخص', 'أسئلة', 'استعد'],
      (c, tab) => tab(2)),
  _Entry('طلبات المراجعة', 'حالة الطلبات المرسلة', Icons.support_agent_outlined, ['مراجعة', 'طلب', 'حالة'], (c, _) => c.push('/followups')),
  _Entry('مساعد السكري الذكي', 'شرح بياناتك الموثّقة', Icons.chat_bubble_outline_rounded, ['مساعد', 'شرح', 'ذكي'], (c, tab) => tab(3)),
];

class HomeSearchField extends ConsumerStatefulWidget {
  const HomeSearchField({super.key, required this.onOpenTab});
  final void Function(int) onOpenTab;

  @override
  ConsumerState<HomeSearchField> createState() => _HomeSearchFieldState();
}

class _HomeSearchFieldState extends ConsumerState<HomeSearchField> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onOpenTab = widget.onOpenTab;
    void search(String q) {
      final s = ref.read(appControllerProvider);
      final query = q.trim().toLowerCase();
      final results = <_Entry>[
        ..._staticEntries.where((e) => query.isEmpty || e.title.toLowerCase().contains(query) || e.keywords.any((k) => k.contains(query) || query.contains(k))),
        for (final l in s.labs)
          if (query.isNotEmpty && l.testName.toLowerCase().contains(query))
            _Entry(l.testName, '${ArFormat.number(l.value, decimals: 2)} ${l.unit}${l.collectionDate == null ? '' : ' — ${ArFormat.date(l.collectionDate!)}'}',
                Icons.science_outlined, const [], (c, tab) => tab(1)),
      ];
      showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: results.isEmpty
              ? const Padding(padding: EdgeInsets.all(SpSpace.xl), child: Text('لا توجد نتائج مطابقة. جرّب كلمة أخرى مثل "تقرير" أو "HbA1c".'))
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final e in results)
                      ListTile(
                        leading: Icon(e.icon, color: SpColors.tealDeep),
                        title: Text(e.title),
                        subtitle: Text(e.subtitle),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          e.open(context, onOpenTab);
                        },
                      ),
                  ],
                ),
        ),
      );
    }

    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: search,
      decoration: InputDecoration(
        hintText: 'ابحث في تقاريرك وتحاليلك… مثال: HbA1c',
        suffixIcon: Padding(
          padding: const EdgeInsets.all(6),
          child: Material(
            color: SpColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: SpColors.teal, width: 1.4)),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => search(controller.text),
              child: const SizedBox(width: 38, height: 38, child: Icon(Icons.search_rounded, color: SpColors.tealDeep)),
            ),
          ),
        ),
      ),
    );
  }
}
