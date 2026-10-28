import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sukkar_core/sukkar_core.dart';

import 'pdf_builders.dart' as builders;

const _regular = 'assets/fonts/IBMPlexSansArabic_400Regular.ttf';
const _bold = 'assets/fonts/IBMPlexSansArabic_700Bold.ttf';

Future<(pw.Font, pw.Font)> _fonts() async =>
    (pw.Font.ttf(await rootBundle.load(_regular)), pw.Font.ttf(await rootBundle.load(_bold)));

/// See [builders.buildSyntheticReportPdf].
Future<Uint8List> buildSyntheticReportPdf(List<String> lines) async {
  final (regular, _) = await _fonts();
  return builders.buildSyntheticReportPdf(lines, regular: regular);
}

/// See [builders.buildVisitSummaryPdf].
Future<Uint8List> buildVisitSummaryPdf(VisitSummary s) async {
  final (regular, bold) = await _fonts();
  return builders.buildVisitSummaryPdf(s, regular: regular, bold: bold);
}

Future<void> shareVisitSummaryPdf(Uint8List bytes) =>
    Printing.sharePdf(bytes: bytes, filename: 'sukkar-plus-visit-summary.pdf');
