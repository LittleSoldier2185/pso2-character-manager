import 'dart:io';
import 'package:path/path.dart' as p;
import 'storage_service.dart';

/// Result of a filename conflict check
class ConflictResult {
  /// The name of the already-registered character using this filename
  final String existingCharacterName;
  /// The original filename that caused the conflict (e.g. "3001.fhp")
  final String fileName;

  const ConflictResult({
    required this.existingCharacterName,
    required this.fileName,
  });
}

class FileService {
  /// Checks if a character file's name already exists in the managed folder.
  /// Returns the conflicting filename if found, null if no conflict.
  static Future<String?> checkFileNameConflict(String sourcePath) async {
    final charsDir = await StorageService.charactersDir;
    final fileName = p.basename(sourcePath);
    final destPath = p.join(charsDir, fileName);
    final exists = await File(destPath).exists();
    return exists ? fileName : null;
  }

  /// Copies a character file using a custom storage name but remembers the
  /// original PSO2 filename separately.
  /// [sourcePath] — the file the user picked
  /// [customStorageName] — what to name it in our storage folder (without ext)
  /// Returns the new stored path.
  static Future<String> copyCharacterFileWithName(
      String sourcePath, String customStorageName) async {
    final charsDir = await StorageService.charactersDir;
    final ext = p.extension(sourcePath); // e.g. ".fhp"
    final fileName = '$customStorageName$ext';
    final destPath = p.join(charsDir, fileName);
    // If even the custom name conflicts, append timestamp
    final finalPath = await StorageService.uniquePath(destPath);
    await File(sourcePath).copy(finalPath);
    return finalPath;
  }

  /// Copies a character file into the managed characters folder.
  /// Uses the original filename directly — call checkFileNameConflict first
  /// if you want to detect conflicts before copying.
  static Future<String> copyCharacterFile(String sourcePath) async {
    final charsDir = await StorageService.charactersDir;
    final fileName = p.basename(sourcePath);
    final destPath = p.join(charsDir, fileName);
    final dest = await StorageService.uniquePath(destPath);
    await File(sourcePath).copy(dest);
    return dest;
  }

  /// Replaces an existing character file with a new one, keeping the same path.
  static Future<void> replaceCharacterFile(
      String sourcePath, String existingStoredPath) async {
    await File(sourcePath).copy(existingStoredPath);
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

  /// Exports (copies) a character file to a user-chosen destination path,
  /// using the original PSO2 filename.
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

  /// Copies an image file into the managed gallery folder.
  /// Returns the new stored path.
  static Future<String> copyGalleryFile(String sourcePath) async {
    final galleryDir = await StorageService.galleryDir;
    final ext = p.extension(sourcePath);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';
    final destPath = p.join(galleryDir, fileName);
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  /// Safely deletes a gallery file only if it lives inside the managed
  /// gallery folder.
  static Future<void> deleteGalleryFileIfOwned(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return;
    try {
      final galleryDir = await StorageService.galleryDir;
      final normalized = p.normalize(filePath);
      final normalizedDir = p.normalize(galleryDir);
      if (!normalized.startsWith(normalizedDir)) return;
      final file = File(normalized);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Safely deletes a thumbnail file only if it lives inside the managed
  /// thumbnails folder. This prevents accidentally deleting files outside
  /// the app's storage (e.g. if a path somehow points elsewhere).
  static Future<void> deleteThumbnailIfOwned(String? thumbnailPath) async {
    if (thumbnailPath == null || thumbnailPath.isEmpty) return;
    try {
      final thumbsDir = await StorageService.thumbnailsDir;
      // Normalize both paths for a safe comparison
      final normalized = p.normalize(thumbnailPath);
      final normalizedDir = p.normalize(thumbsDir);
      if (!normalized.startsWith(normalizedDir)) return; // not ours — skip
      final file = File(normalized);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Checks whether the game folder has a newer version of a character file
  /// than what is stored in the app library.
  /// Returns the game folder file's modification time if it is newer, else null.
  static Future<DateTime?> checkForGameFolderUpdate(
      String storedFilePath, String gameFolderPath, String gameFileName) async {
    try {
      final gameFile = File(p.join(gameFolderPath, gameFileName));
      if (!await gameFile.exists()) return null;
      final storedFile = File(storedFilePath);
      if (!await storedFile.exists()) return null;
      final gameModified = await gameFile.lastModified();
      final storedModified = await storedFile.lastModified();
      // Only report update if game file is meaningfully newer (>5 seconds)
      if (gameModified.difference(storedModified).inSeconds > 5) {
        return gameModified;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Syncs a character's file from the game folder back into the library.
  /// Returns null on success, error string on failure.
  static Future<String?> syncFromGameFolder(
      String gameFolderPath, String gameFileName, String storedFilePath) async {
    try {
      final gameFile = File(p.join(gameFolderPath, gameFileName));
      if (!await gameFile.exists()) {
        return 'File not found in game folder: $gameFileName';
      }
      await gameFile.copy(storedFilePath);
      return null;
    } catch (e) {
      return 'Sync failed: $e';
    }
  }

  /// Scans a folder for PSO2 character files not already in the known set.
  static Future<List<String>> scanForUnregisteredFiles(
    String folderPath,
    Set<String> registeredFileNames,
  ) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return [];

    const validExts = [
      'fhp', 'mhp', 'fnp', 'mnp', 'fdp', 'mdp', 'fcp', 'mcp'
    ];
    final unregistered = <String>[];

    await for (final entity in dir.list()) {
      if (entity is File) {
        final ext =
            p.extension(entity.path).replaceFirst('.', '').toLowerCase();
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
