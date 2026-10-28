import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class PickedPdf {
  const PickedPdf({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
  int get size => bytes.length;
}

abstract class ReportFilePicker {
  /// Returns null when the user cancels.
  Future<PickedPdf?> pickPdf();
}

class PlatformReportFilePicker implements ReportFilePicker {
  @override
  Future<PickedPdf?> pickPdf() async {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'اختر تقرير PDF',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (files.isEmpty) return null;
    final f = files.first;
    final bytes = await f.xFile.readAsBytes();
    return PickedPdf(name: f.name, bytes: bytes);
  }
}
