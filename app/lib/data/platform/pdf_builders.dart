// Pure-Dart PDF builders (no Flutter imports) so they can be exercised by
// the Dart VM in tests; fonts are supplied by the caller.
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sukkar_core/sukkar_core.dart';

import '../../core/format/ar_format.dart';

/// Renders the SYNTHETIC demo report lines into a real PDF so that the demo
/// "upload" goes through the same validation and PDFium extraction path as a
/// user's file. The document is labelled synthetic on its first line.
Future<Uint8List> buildSyntheticReportPdf(List<String> lines, {required pw.Font regular}) async {
  final doc = pw.Document(title: 'Synthetic demo report - not a real patient', author: 'Sukkar Plus demo');
  String clean(String s) => s.replaceAll('≤', '<=').replaceAll('®', '');
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(36),
    build: (_) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [for (final l in lines) pw.Text(clean(l), style: pw.TextStyle(font: regular, fontSize: 9.5))],
    ),
  ));
  return doc.save();
}

/// The visit-preparation summary as an A4 RTL PDF.
final _boundarySpace = RegExp(r'(?<=[\u0600-\u06FF]) (?=[0-9A-Za-z(+\u2212-])|(?<=[0-9A-Za-z)%]) (?=[\u0600-\u06FF])');

/// Keeps spaces at Arabic/Latin-digit boundaries as no-break spaces so the
/// PDF bidi pass does not drop them.
String _keepSpaces(String s) => s
    // Final forms of non-joining letters (ر ز د ذ و) have a narrow advance in
    // the PDF renderer, which visually swallows the following space.
    .replaceAllMapped(RegExp(r'([\u0631\u0632\u062F\u0630\u0648]) '), (m) => '${m[1]}\u00A0 ')
    .replaceAll(_boundarySpace, '\u00A0');

Future<Uint8List> buildVisitSummaryPdf(VisitSummary s, {required pw.Font regular, required pw.Font bold}) async {
  const ink = PdfColor.fromInt(0xFF1C2A35);
  const muted = PdfColor.fromInt(0xFF55636E);
  const teal = PdfColor.fromInt(0xFF0D6C66);
  const line = PdfColor.fromInt(0xFFE2E9EC);
  const soft = PdfColor.fromInt(0xFFF3F6F7);

  pw.Widget h(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Text(_keepSpaces(t), style: pw.TextStyle(font: bold, fontSize: 13, color: teal)),
      );
  pw.Widget row(String k, String v, {String? note}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: line, width: 0.6))),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            flex: 5,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(_keepSpaces(k), style: const pw.TextStyle(fontSize: 10.5, color: ink)),
              if (note != null) pw.Text(_keepSpaces(note), style: const pw.TextStyle(fontSize: 8.5, color: muted)),
            ]),
          ),
          pw.Expanded(flex: 4, child: pw.Text(_keepSpaces(v), textAlign: pw.TextAlign.left, style: pw.TextStyle(font: bold, fontSize: 10.5, color: ink))),
        ]),
      );
  pw.Widget bullet(String t) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Text(_keepSpaces('• $t'), style: const pw.TextStyle(fontSize: 10.5, color: ink, lineSpacing: 3)),
      );

  final report = s.latestReport;
  final gmi = s.gmiComparison;
  final doc = pw.Document(title: 'ملخص الاستعداد للموعد — سكر بلس', author: 'Sukkar Plus prototype');
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    textDirection: pw.TextDirection.rtl,
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
    margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
    footer: (ctx) => pw.Text(
      'سكر بلس — نموذج أولي مستقل غير مرتبط بأي جهة صحية • صفحة ${ctx.pageNumber} من ${ctx.pagesCount}',
      style: const pw.TextStyle(fontSize: 8, color: muted),
    ),
    build: (ctx) => [
      pw.Text('ملخص الاستعداد للموعد', style: pw.TextStyle(font: bold, fontSize: 20, color: ink)),
      pw.SizedBox(height: 4),
      pw.Text(_keepSpaces('تاريخ إنشاء الملخص: ${ArFormat.dateTime(s.generatedAt)}'), style: const pw.TextStyle(fontSize: 10, color: muted)),
      if (s.isSynthetic)
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 8),
          padding: const pw.EdgeInsets.all(6),
          color: const PdfColor.fromInt(0xFFFFF1CC),
          child: pw.Text('وضع العرض — يحتوي هذا الملخص على بيانات تجريبية وليست لمريض حقيقي.',
              style: pw.TextStyle(font: bold, fontSize: 10, color: const PdfColor.fromInt(0xFF7A4E00))),
        ),
      if (s.appointment != null) ...[
        h('الموعد'),
        row(s.appointment!.clinicLabel, ArFormat.dateTime(s.appointment!.dateTime), note: 'موعد محاكى — لم يُحجز أو يُعدّل أي موعد حقيقي'),
      ],
      h('أحدث تقرير للحساس'),
      if (report == null)
        bullet('لا يوجد تقرير موثّق.')
      else ...[
        row('فترة المؤشرات', report.effectivePeriod == null ? 'غير معروفة' : ArFormat.period(report.effectivePeriod!)),
        if (report.reportPeriod != null && report.reportPeriod != report.effectivePeriod)
          row('فترة التقرير المطبوعة', ArFormat.period(report.reportPeriod!)),
        for (final l in s.latestMetrics) row(l.labelAr, l.valueAr, note: l.noteAr),
      ],
      if (s.qualityWarningsAr.isNotEmpty) ...[h('ملاحظات جودة البيانات'), for (final w in s.qualityWarningsAr) bullet(w)],
      h('المقارنة التاريخية لتقارير الحساس'),
      if (s.cgmComparison == null)
        bullet('لا يوجد تقريران بفترات معروفة للمقارنة.')
      else ...[
        row('الفترة السابقة', ArFormat.period(s.cgmComparison!.previous.effectivePeriod!)),
        row('الفترة الحالية', ArFormat.period(s.cgmComparison!.current.effectivePeriod!)),
        for (final e in s.cgmComparison!.changes.entries)
          row(e.key.labelAr, ArFormat.change(e.value.previous.value, e.value.current.value)),
        for (final n in s.cgmComparison!.notesAr) bullet(n),
      ],
      h('نتائج المختبر'),
      if (s.labLines.isEmpty) bullet('لا توجد نتائج مسجلة.') else for (final l in s.labLines) row(l.labelAr, l.valueAr, note: l.noteAr),
      h('مقارنة GMI مع HbA1c'),
      row('الحالة', gmi.comparability.labelAr),
      if (gmi.gmiPercent != null) row('GMI (تقدير من الحساس)', '${ArFormat.number(gmi.gmiPercent!)}%'),
      if (gmi.hba1cPercent != null)
        row('HbA1c (تحليل مخبري)', '${ArFormat.number(gmi.hba1cPercent!)}%${gmi.hba1cWasConverted ? ' (محوّل من mmol/mol)' : ''}',
            note: gmi.hba1c?.collectionDate == null ? null : 'تاريخ السحب: ${ArFormat.date(gmi.hba1c!.collectionDate!)}'),
      if (gmi.differencePercentPoints != null) row('الفرق (HbA1c − GMI)', '${ArFormat.signed(gmi.differencePercentPoints!)} نقطة مئوية'),
      for (final n in gmi.notesAr) bullet(n),
      bullet(GmiHbA1cComparison.neutralityNoteAr),
      h('التحاليل والتذكيرات'),
      if (s.reminderLines.isEmpty) bullet('لا توجد تذكيرات مسجلة.') else for (final l in s.reminderLines) row(l.labelAr, l.valueAr, note: l.noteAr),
      h('طلبات المراجعة (محاكاة)'),
      if (s.followUpLines.isEmpty) bullet('لا توجد طلبات.') else for (final l in s.followUpLines) row(l.labelAr, l.valueAr, note: l.noteAr),
      if (s.missingAr.isNotEmpty) ...[h('بيانات ناقصة'), for (final m in s.missingAr) bullet(m)],
      h('أسئلة قد ترغب في طرحها'),
      for (final q in s.questionsAr) bullet(q),
      pw.SizedBox(height: 14),
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        color: soft,
        child: pw.Text(_keepSpaces(VisitSummary.disclaimerAr), style: const pw.TextStyle(fontSize: 9.5, color: ink, lineSpacing: 3)),
      ),
    ],
  ));
  return doc.save();
}

