import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

class PdfReadException implements Exception {
  PdfReadException(this.messageAr);
  final String messageAr;
  @override
  String toString() => 'PdfReadException: $messageAr';
}

/// Extracts the text of each page. The bytes never leave the device.
abstract class PdfTextExtractor {
  Future<List<String>> extractPages(Uint8List bytes);
}

/// PDFium-based extraction (pdfrx). The core parser was verified against the
/// text PDFium produces for the supplied report layout.
class PdfrxTextExtractor implements PdfTextExtractor {
  bool _initialized = false;

  @override
  Future<List<String>> extractPages(Uint8List bytes) async {
    if (!_initialized) {
      await pdfrxFlutterInitialize();
      _initialized = true;
    }
    PdfDocument? doc;
    try {
      doc = await PdfDocument.openData(bytes, sourceName: 'upload-${bytes.length}-${DateTime.now().microsecondsSinceEpoch}');
      final pages = <String>[];
      for (final page in doc.pages) {
        final text = await page.loadText();
        pages.add(text?.fullText ?? '');
      }
      return pages;
    } catch (_) {
      throw PdfReadException('تعذّرت قراءة الملف. قد يكون تالفًا أو بتنسيق غير مدعوم.');
    } finally {
      await doc?.dispose();
    }
  }
}
