import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/album_data.dart';

class AlbumExportService {
  /// Returns null on success, error string on failure.
  static Future<String?> exportZip(AlbumData album, List<String> paths) async {
    final save = await FilePicker.platform.saveFile(
      dialogTitle: 'Save "${album.name}" as ZIP',
      fileName: '${_safeName(album.name)}.zip',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (save == null) return null;

    final encoder = ZipFileEncoder();
    encoder.create(save);
    for (int i = 0; i < paths.length; i++) {
      final f = File(paths[i]);
      if (!f.existsSync()) continue;
      final ext = paths[i].split('.').last.toLowerCase();
      await encoder.addFile(f, '${(i + 1).toString().padLeft(3, '0')}.$ext');
    }
    await encoder.close();
    return null;
  }

  /// Returns null on success, error string on failure.
  static Future<String?> exportPdf(AlbumData album, List<String> paths) async {
    final save = await FilePicker.platform.saveFile(
      dialogTitle: 'Save "${album.name}" as PDF',
      fileName: '${_safeName(album.name)}.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (save == null) return null;

    final doc = pw.Document();
    int added = 0;
    for (final path in paths) {
      final f = File(path);
      if (!f.existsSync()) continue;
      try {
        final bytes = await f.readAsBytes();
        final img = pw.MemoryImage(bytes);
        final w = (img.width ?? 595).toDouble();
        final h = (img.height ?? 842).toDouble();
        doc.addPage(pw.Page(
          pageFormat: PdfPageFormat(w, h),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(img, fit: pw.BoxFit.contain),
        ));
        added++;
      } catch (_) {
        // skip unsupported image format
      }
    }

    if (added == 0) return 'No images could be added to the PDF';
    await File(save).writeAsBytes(await doc.save());
    return null;
  }

  static String _safeName(String name) =>
      name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}
