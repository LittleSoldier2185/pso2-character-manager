import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class FileService {
  static Future<String> get _appDataDir async {
    final dir = await getApplicationDocumentsDirectory();
    final appDir = Directory(p.join(dir.path, 'PSO2CharacterManager'));
    await Directory(p.join(appDir.path, 'characters')).create(recursive: true);
    await Directory(p.join(appDir.path, 'thumbnails')).create(recursive: true);
    return appDir.path;
  }

  static Future<String> copyCharacterFile(String sourcePath) async {
    final appDir = await _appDataDir;
    final fileName = p.basename(sourcePath);
    final destPath = p.join(appDir, 'characters', fileName);
    final dest = await _uniquePath(destPath);
    await File(sourcePath).copy(dest);
    return dest;
  }

  static Future<String> copyThumbnailFile(String sourcePath) async {
    final appDir = await _appDataDir;
    final ext = p.extension(sourcePath);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';
    final destPath = p.join(appDir, 'thumbnails', fileName);
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  static Future<void> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  static Future<String> _uniquePath(String path) async {
    if (!await File(path).exists()) return path;
    final dir = p.dirname(path);
    final name = p.basenameWithoutExtension(path);
    final ext = p.extension(path);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return p.join(dir, '${name}_$stamp$ext');
  }
}
