import '../models/cgm.dart';

/// Result of importing a CGM CSV export.
class CsvImportResult {
  const CsvImportResult({
    required this.readings,
    required this.rowsRead,
    required this.skippedRows,
    required this.timestampColumn,
    required this.glucoseColumn,
    this.warningsAr = const [],
  });

  final List<GlucoseReading> readings;
  final int rowsRead;
  final int skippedRows;
  final String timestampColumn;
  final String glucoseColumn;
  final List<String> warningsAr;
}

class CsvImportException implements Exception {
  CsvImportException(this.messageAr);
  final String messageAr;
  @override
  String toString() => 'CsvImportException: $messageAr';
}

/// Imports glucose readings from a CSV file.
///
/// Column defaults match the AZT1D dataset files inspected for this project
/// (`EventDateTime`, `CGM`; one subject file uses `Readings (CGM / BGM)`).
/// Only the timestamp and glucose columns are read; insulin, carbohydrate and
/// device-mode columns are ignored on purpose. Timestamps are treated as local
/// wall-clock times without a time zone. Values are assumed to be mg/dL.
class CgmCsvImporter {
  const CgmCsvImporter({
    this.timestampColumns = const ['EventDateTime', 'timestamp', 'Timestamp'],
    this.glucoseColumns = const ['CGM', 'Readings (CGM / BGM)', 'glucose_mg_dl', 'Glucose'],
  });

  final List<String> timestampColumns;
  final List<String> glucoseColumns;

  CsvImportResult parse(String content) {
    final lines = content.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) throw CsvImportException('الملف فارغ.');
    final header = _splitCsvLine(lines.first).map((h) => h.trim().replaceAll('﻿', '')).toList();
    final tsIdx = _find(header, timestampColumns);
    final gIdx = _find(header, glucoseColumns);
    if (tsIdx < 0) throw CsvImportException('لم يُعثر على عمود التوقيت.');
    if (gIdx < 0) throw CsvImportException('لم يُعثر على عمود قراءات السكر.');

    final warnings = <String>[];
    if (header[gIdx].contains('BGM')) {
      warnings.add('عمود القراءات قد يجمع بين قراءات الحساس وقراءات الجهاز المنزلي (CGM / BGM).');
    }
    final readings = <GlucoseReading>[];
    var skipped = 0;
    for (final line in lines.skip(1)) {
      final cells = _splitCsvLine(line);
      if (cells.length <= tsIdx || cells.length <= gIdx) {
        skipped++;
        continue;
      }
      final ts = DateTime.tryParse(cells[tsIdx].trim());
      final g = double.tryParse(cells[gIdx].trim());
      if (ts == null || g == null) {
        skipped++;
        continue;
      }
      readings.add(GlucoseReading(ts, g));
    }
    if (skipped > 0) warnings.add('تم تجاهل $skipped صفًا لعدم صلاحية التوقيت أو القيمة.');
    return CsvImportResult(
      readings: readings,
      rowsRead: lines.length - 1,
      skippedRows: skipped,
      timestampColumn: header[tsIdx],
      glucoseColumn: header[gIdx],
      warningsAr: warnings,
    );
  }

  static int _find(List<String> header, List<String> candidates) {
    for (final c in candidates) {
      final i = header.indexOf(c);
      if (i >= 0) return i;
    }
    return -1;
  }

  static List<String> _splitCsvLine(String line) {
    final out = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        out.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    out.add(buf.toString());
    return out;
  }
}
