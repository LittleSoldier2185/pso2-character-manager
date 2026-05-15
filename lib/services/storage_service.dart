import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StorageService {
  static String? _customPath;

  static void init(String? savedPath) {
    _customPath = savedPath;
  }

  static void setPath(String path) {
    _customPath = path;
  }

  static Future<String> get rootDir async {
    final String base;
    if (_customPath != null && _customPath!.isNotEmpty) {
      base = _customPath!;
    } else {
      final docs = await getApplicationDocumentsDirectory();
      base = p.join(docs.path, 'PSO2CharacterManager');
    }
    await Directory(p.join(base, 'characters')).create(recursive: true);
    await Directory(p.join(base, 'thumbnails')).create(recursive: true);
    return base;
  }

  static Future<String> get charactersDir async {
    final root = await rootDir;
    return p.join(root, 'characters');
  }

  static Future<String> get thumbnailsDir async {
    final root = await rootDir;
    return p.join(root, 'thumbnails');
  }

  static Future<String> get galleryDir async {
    final root = await rootDir;
    final dir = Directory(p.join(root, 'gallery'));
    await dir.create(recursive: true);
    return dir.path;
  }

  static Future<bool> get isAccessible async {
    try {
      final root = await rootDir;
      return Directory(root).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Builds a unique file path — appends timestamp if name already exists.
  /// Used as a fallback only; prefer UUID-based naming for new files.
  static Future<String> uniquePath(String fullPath) async {
    if (!await File(fullPath).exists()) return fullPath;
    final dir = p.dirname(fullPath);
    final name = p.basenameWithoutExtension(fullPath);
    final ext = p.extension(fullPath);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return p.join(dir, '${name}_$stamp$ext');
  }

  static Future<Map<String, String>> migrateFiles({
    required String oldRoot,
    required String newRoot,
    required void Function(int done, int total) onProgress,
  }) async {
    final pathMap = <String, String>{};

    final oldChars = Directory(p.join(oldRoot, 'characters'));
    final oldThumbs = Directory(p.join(oldRoot, 'thumbnails'));

    final newCharsDir = Directory(p.join(newRoot, 'characters'));
    final newThumbsDir = Directory(p.join(newRoot, 'thumbnails'));
    await newCharsDir.create(recursive: true);
    await newThumbsDir.create(recursive: true);

    final List<FileSystemEntity> allFiles = [];
    if (await oldChars.exists()) allFiles.addAll(oldChars.listSync());
    if (await oldThumbs.exists()) allFiles.addAll(oldThumbs.listSync());

    int done = 0;
    for (final entity in allFiles) {
      if (entity is File) {
        final isChar = entity.path.contains('characters');
        final subDir = isChar ? 'characters' : 'thumbnails';
        final fileName = p.basename(entity.path);
        final newPath = p.join(newRoot, subDir, fileName);
        try {
          await entity.copy(newPath);
          await entity.delete();
          pathMap[entity.path] = newPath;
        } catch (_) {}
      }
      done++;
      onProgress(done, allFiles.length);
    }
    return pathMap;
  }
}
