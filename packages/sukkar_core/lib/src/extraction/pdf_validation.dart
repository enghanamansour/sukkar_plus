import 'dart:convert';
import 'dart:typed_data';

enum PdfValidationError { empty, tooLarge, unsupportedType, notPdf, truncated, encrypted }

class PdfValidationResult {
  const PdfValidationResult._(this.error, this.messageAr);
  const PdfValidationResult.ok() : this._(null, 'الملف صالح للمعالجة.');
  const PdfValidationResult.fail(PdfValidationError e, String m) : this._(e, m);

  final PdfValidationError? error;
  final String messageAr;
  bool get isValid => error == null;
}

/// Maximum accepted upload size. The supplied 20-page report is ~3.8 MB.
const int maxPdfBytes = 15 * 1024 * 1024;

/// Structural validation performed before any text extraction or upload.
/// It does not prove a PDF is well-formed; the text extractor may still fail,
/// which the caller reports as "corrupted or unsupported".
PdfValidationResult validatePdfBytes(String fileName, Uint8List bytes, {int maxBytes = maxPdfBytes}) {
  if (!fileName.toLowerCase().endsWith('.pdf')) {
    return const PdfValidationResult.fail(PdfValidationError.unsupportedType, 'نوع الملف غير مدعوم. يُقبل ملف PDF فقط.');
  }
  if (bytes.isEmpty) {
    return const PdfValidationResult.fail(PdfValidationError.empty, 'الملف فارغ.');
  }
  if (bytes.length > maxBytes) {
    return PdfValidationResult.fail(PdfValidationError.tooLarge,
        'حجم الملف أكبر من الحد المسموح (${(maxBytes / (1024 * 1024)).round()} ميغابايت).');
  }
  final headLen = bytes.length < 1024 ? bytes.length : 1024;
  final head = latin1.decode(bytes.sublist(0, headLen), allowInvalid: true);
  if (!head.contains('%PDF-')) {
    return const PdfValidationResult.fail(PdfValidationError.notPdf, 'الملف لا يبدو ملف PDF صالحًا رغم امتداده.');
  }
  final tailStart = bytes.length > 2048 ? bytes.length - 2048 : 0;
  final tail = latin1.decode(bytes.sublist(tailStart), allowInvalid: true);
  if (!tail.contains('%%EOF')) {
    return const PdfValidationResult.fail(PdfValidationError.truncated, 'يبدو أن الملف ناقص أو تالف (لم يُعثر على نهاية الملف).');
  }
  // Scan for an encryption dictionary. Encrypted reports are not supported.
  final scanLen = bytes.length < 4 * 1024 * 1024 ? bytes.length : 4 * 1024 * 1024;
  final body = latin1.decode(bytes.sublist(bytes.length - scanLen), allowInvalid: true);
  if (body.contains('/Encrypt')) {
    return const PdfValidationResult.fail(PdfValidationError.encrypted, 'الملف محمي أو مشفّر ولا يمكن قراءته.');
  }
  return const PdfValidationResult.ok();
}

String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes بايت';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} كيلوبايت';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} ميغابايت';
}
