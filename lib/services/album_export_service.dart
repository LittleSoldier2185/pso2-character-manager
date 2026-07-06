import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/album_data.dart';

typedef _Progress = void Function(int done, int total);

class ExportCancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

class AlbumExportService {
  // ── ZIP ───────────────────────────────────────────────────────────

  static Future<String?> pickZipSavePath(AlbumData album) =>
      FilePicker.platform.saveFile(
        dialogTitle: 'Save "${album.name}" as ZIP',
        fileName: '${_safeName(album.name)}.zip',
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

  static Future<String?> doExportZip(
    String savePath,
    List<String> paths, {
    _Progress? onProgress,
    ExportCancelToken? cancelToken,
  }) async {
    final encoder = ZipFileEncoder();
    encoder.create(savePath);
    for (int i = 0; i < paths.length; i++) {
      if (cancelToken?.isCancelled == true) {
        await encoder.close();
        try { await File(savePath).delete(); } catch (_) {}
        return null;
      }
      final f = File(paths[i]);
      if (!f.existsSync()) continue;
      final ext = paths[i].split('.').last.toLowerCase();
      await encoder.addFile(f, '${(i + 1).toString().padLeft(3, '0')}.$ext');
      onProgress?.call(i + 1, paths.length);
    }
    await encoder.close();
    return null;
  }

  // ── PDF ───────────────────────────────────────────────────────────

  static Future<String?> pickPdfSavePath(
          AlbumData album, {bool compress = false}) =>
      FilePicker.platform.saveFile(
        dialogTitle:
            'Save "${album.name}" as ${compress ? 'Compressed PDF' : 'PDF'}',
        fileName: '${_safeName(album.name)}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

  static Future<String?> doExportPdf(
    String savePath,
    List<String> paths, {
    bool compress = false,
    _Progress? onProgress,
    ExportCancelToken? cancelToken,
  }) async {
    final doc = pw.Document();
    int added = 0;
    for (int i = 0; i < paths.length; i++) {
      if (cancelToken?.isCancelled == true) return null;
      final f = File(paths[i]);
      if (!f.existsSync()) { onProgress?.call(i + 1, paths.length); continue; }
      try {
        final bytes = await f.readAsBytes();
        final pw.MemoryImage pdfImg;
        if (compress) {
          final decoded = img.decodeImage(bytes);
          if (decoded == null) { onProgress?.call(i + 1, paths.length); continue; }
          pdfImg = pw.MemoryImage(img.encodeJpg(decoded, quality: 75));
        } else {
          pdfImg = pw.MemoryImage(bytes);
        }
        final w = (pdfImg.width ?? 595).toDouble();
        final h = (pdfImg.height ?? 842).toDouble();
        doc.addPage(pw.Page(
          pageFormat: PdfPageFormat(w, h),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(pdfImg, fit: pw.BoxFit.contain),
        ));
        added++;
      } catch (_) {
        // skip unsupported format
      }
      onProgress?.call(i + 1, paths.length);
    }
    if (cancelToken?.isCancelled == true) return null;
    if (added == 0) return 'No images could be added to the PDF';
    await File(savePath).writeAsBytes(await doc.save());
    return null;
  }

  static String _safeName(String name) =>
      name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}
