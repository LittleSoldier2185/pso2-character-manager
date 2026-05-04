import 'dart:io';
import 'package:path/path.dart' as p;
import 'storage_service.dart';

class FileService {
  /// Copies a character file (.fhp/.mhp etc.) into the managed characters folder.
  static Future<String> copyCharacterFile(String sourcePath) async {
    final charsDir = await StorageService.charactersDir;
    final fileName = p.basename(sourcePath);
    final destPath = p.join(charsDir, fileName);
    final dest = await StorageService.uniquePath(destPath);
    await File(sourcePath).copy(dest);
    return dest;
  }

  /// Copies an image file into the managed thumbnails folder.
  static Future<String> copyThumbnailFile(String sourcePath) async {
    final thumbsDir = await StorageService.thumbnailsDir;
    final ext = p.extension(sourcePath);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';
    final destPath = p.join(thumbsDir, fileName);
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  /// Exports (copies) a character file to a user-chosen destination.
  static Future<void> exportCharacterFile(
      String sourcePath, String destPath) async {
    await File(sourcePath).copy(destPath);
  }

  /// Safely deletes a file if it exists.
  static Future<void> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Scans a folder for PSO2 character files not already in the known set.
  /// Returns list of file paths that are unregistered.
  static Future<List<String>> scanForUnregisteredFiles(
    String folderPath,
    Set<String> registeredFileNames,
  ) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return [];

    const validExts = ['fhp', 'mhp', 'fnp', 'mnp', 'fdp', 'mdp', 'fcp', 'mcp'];
    final unregistered = <String>[];

    await for (final entity in dir.list()) {
      if (entity is File) {
        final ext = p.extension(entity.path).replaceFirst('.', '').toLowerCase();
        if (validExts.contains(ext)) {
          final fileName = p.basename(entity.path);
          if (!registeredFileNames.contains(fileName)) {
            unregistered.add(entity.path);
          }
        }
      }
    }
    return unregistered;
  }
}
