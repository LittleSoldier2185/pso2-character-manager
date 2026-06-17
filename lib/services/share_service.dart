import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import '../models/character_data.dart';
import '../models/gallery_data.dart';

/// Bundle format version — increment when structure changes.
const int _kBundleVersion = 1;

/// Extension used for character bundle files.
const String kBundleExtension = 'pso2char';

/// Options for what to include in an export bundle.
class ExportOptions {
  final bool includeGallery;
  final bool includeTags;
  final bool includeDescription;

  const ExportOptions({
    this.includeGallery = true,
    this.includeTags = true,
    this.includeDescription = true,
  });
}

/// Result of reading a bundle — before the user confirms import.
class BundlePreview {
  final String characterName;
  final String race;
  final String gender;
  final String originalFileName;
  final String? description;
  final List<String> tagNames;
  final List<String> tagColors; // hex strings
  final int galleryImageCount;
  final int bundleVersion;

  // Raw bytes kept in memory until user confirms import.
  final List<int> bundleBytes;

  const BundlePreview({
    required this.characterName,
    required this.race,
    required this.gender,
    required this.originalFileName,
    this.description,
    required this.tagNames,
    required this.tagColors,
    required this.galleryImageCount,
    required this.bundleVersion,
    required this.bundleBytes,
  });
}

class ShareService {
  // ── Export ─────────────────────────────────────────────────────

  /// Packs a character into a .pso2char bundle and writes it to [destPath].
  /// Returns null on success, error string on failure.
  static Future<String?> exportBundle({
    required CharacterData character,
    required List<GalleryItemData> galleryItems,
    required String destPath,
    required ExportOptions options,
  }) async {
    try {
      final archive = Archive();

      // 1. Character file
      final charFilePath = character.characterFilePath;
      if (charFilePath == null) {
        return 'Character file not found for main variant';
      }
      final charFile = File(charFilePath);
      if (!await charFile.exists()) {
        return 'Character file not found: $charFilePath';
      }
      final charBytes = await charFile.readAsBytes();
      archive.addFile(
          ArchiveFile(character.gameFileName, charBytes.length, charBytes));

      // 2. Thumbnail (if exists)
      final thumbPath = character.thumbnailPath;
      if (thumbPath != null) {
        final thumbFile = File(thumbPath);
        if (await thumbFile.exists()) {
          final thumbBytes = await thumbFile.readAsBytes();
          final thumbExt = p.extension(thumbPath);
          archive.addFile(
              ArchiveFile('thumbnail$thumbExt', thumbBytes.length, thumbBytes));
        }
      }

      // 3. Gallery images
      if (options.includeGallery) {
        for (int i = 0; i < galleryItems.length; i++) {
          final itemPath = galleryItems[i].filePath(character.folderPath);
          final imgFile = File(itemPath);
          if (await imgFile.exists()) {
            final imgBytes = await imgFile.readAsBytes();
            final imgExt = p.extension(itemPath);
            archive.addFile(ArchiveFile(
                'gallery/image_$i$imgExt', imgBytes.length, imgBytes));
          }
        }
      }

      // 4. meta.json
      final meta = {
        'version': _kBundleVersion,
        'characterName': character.name,
        'race': character.race,
        'gender': character.gender,
        'originalFileName': character.gameFileName,
        'description': options.includeDescription ? character.description : '',
        'tags': options.includeTags
            ? (character.tierIndex != null
                ? {'tierIndex': character.tierIndex}
                : <String, dynamic>{})
            : <String, dynamic>{},
        'galleryCount': options.includeGallery ? galleryItems.length : 0,
      };
      final metaBytes = utf8.encode(jsonEncode(meta));
      archive.addFile(ArchiveFile('meta.json', metaBytes.length, metaBytes));

      final encoder = ZipEncoder();
      final zipBytes = encoder.encode(archive);
      if (zipBytes == null) return 'Failed to encode bundle';
      await File(destPath).writeAsBytes(zipBytes);
      return null;
    } catch (e) {
      return 'Export failed: $e';
    }
  }

  /// Packs a single variant into a .pso2char bundle and writes it to [destPath].
  /// Returns null on success, error string on failure.
  static Future<String?> exportVariantBundle({
    required CharacterData character,
    required VariantData variant,
    required String destPath,
  }) async {
    try {
      final archive = Archive();

      final charFilePath = character.charFileForVariant(variant.folderName);
      if (charFilePath == null) {
        return 'No character file found for variant "${variant.displayName}"';
      }
      final charFile = File(charFilePath);
      if (!await charFile.exists()) return 'Character file not found';
      final charBytes = await charFile.readAsBytes();
      final gameFileName =
          variant.originalFileName ?? p.basename(charFilePath);
      archive.addFile(
          ArchiveFile(gameFileName, charBytes.length, charBytes));

      final thumbPath = character.thumbnailForVariant(variant.folderName);
      if (thumbPath != null) {
        final thumbFile = File(thumbPath);
        if (await thumbFile.exists()) {
          final thumbBytes = await thumbFile.readAsBytes();
          final thumbExt = p.extension(thumbPath);
          archive.addFile(ArchiveFile(
              'thumbnail$thumbExt', thumbBytes.length, thumbBytes));
        }
      }

      final meta = {
        'version': _kBundleVersion,
        'characterName': '${character.name} — ${variant.displayName}',
        'race': character.race,
        'gender': character.gender,
        'originalFileName': gameFileName,
        'description': character.description,
        'tags': <String, dynamic>{},
        'galleryCount': 0,
      };
      final metaBytes = utf8.encode(jsonEncode(meta));
      archive
          .addFile(ArchiveFile('meta.json', metaBytes.length, metaBytes));

      final encoder = ZipEncoder();
      final zipBytes = encoder.encode(archive);
      if (zipBytes == null) return 'Failed to encode bundle';
      await File(destPath).writeAsBytes(zipBytes);
      return null;
    } catch (e) {
      return 'Export failed: $e';
    }
  }

  static Future<int> estimateBundleSize({
    required CharacterData character,
    required List<GalleryItemData> galleryItems,
    required ExportOptions options,
  }) async {
    int total = 0;
    try {
      final charFilePath = character.characterFilePath;
      if (charFilePath != null) {
        final charFile = File(charFilePath);
        if (await charFile.exists()) total += await charFile.length();
      }
      final thumbPath = character.thumbnailPath;
      if (thumbPath != null) {
        final thumbFile = File(thumbPath);
        if (await thumbFile.exists()) total += await thumbFile.length();
      }
      if (options.includeGallery) {
        for (final item in galleryItems) {
          final f = File(item.filePath(character.folderPath));
          if (await f.exists()) total += await f.length();
        }
      }
    } catch (_) {}
    return total;
  }

  // ── Import ─────────────────────────────────────────────────────

  /// Reads a .pso2char bundle file and returns a preview without importing.
  /// Returns null if the file is not a valid bundle.
  static Future<BundlePreview?> readBundlePreview(String bundlePath) async {
    try {
      final bytes = await File(bundlePath).readAsBytes();
      return readBundlePreviewFromBytes(bytes);
    } catch (_) {
      return null;
    }
  }

  /// Reads bundle preview from raw bytes (e.g. from drag and drop).
  static BundlePreview? readBundlePreviewFromBytes(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find and parse meta.json
      final metaFile = archive.files
          .where((f) => f.name == 'meta.json')
          .firstOrNull;
      if (metaFile == null) return null;

      final meta =
          jsonDecode(utf8.decode(metaFile.content as List<int>)) as Map;

      // Count gallery images
      final galleryCount = archive.files
          .where((f) => f.name.startsWith('gallery/'))
          .length;

      return BundlePreview(
        characterName: meta['characterName'] as String? ?? 'Unknown',
        race: meta['race'] as String? ?? 'Unknown',
        gender: meta['gender'] as String? ?? 'Unknown',
        originalFileName: meta['originalFileName'] as String? ?? '',
        description: meta['description'] as String?,
        tagNames: const [],
        tagColors: const [],
        galleryImageCount: galleryCount,
        bundleVersion: meta['version'] as int? ?? 1,
        bundleBytes: bytes,
      );
    } catch (_) {
      return null;
    }
  }

  /// Extracts a bundle into the app's storage directories.
  /// Returns the extracted character file path and optional thumbnail path.
  /// Extracts a bundle into the new folder structure.
  /// [variantFolderPath] — absolute path to the variant folder (already created).
  /// [galleryFolderPath] — absolute path to character_gallery/ (already created).
  static Future<_ExtractResult?> extractBundle({
    required List<int> bundleBytes,
    required String variantFolderPath,
    required String galleryFolderPath,
    required String variantFolderName,
    required String? customFileName,
  }) async {
    try {
      final archive = ZipDecoder().decodeBytes(bundleBytes);

      // Find character file
      final charFile = archive.files.where((f) {
        final ext = p.extension(f.name).replaceFirst('.', '').toLowerCase();
        return CharacterData.validExtensions.contains(ext) &&
            !f.name.contains('/');
      }).firstOrNull;
      if (charFile == null) return null;

      final originalName = p.basename(charFile.name);
      final storageName = customFileName ?? originalName;
      final charDestPath = p.join(variantFolderPath, storageName);
      final finalCharPath = await _uniquePath(charDestPath);
      await File(finalCharPath).writeAsBytes(charFile.content as List<int>);

      // Extract thumbnail into variant folder
      String? thumbFileName;
      final thumbFile = archive.files
          .where((f) => f.name.startsWith('thumbnail'))
          .firstOrNull;
      if (thumbFile != null) {
        final thumbExt = p.extension(thumbFile.name);
        thumbFileName = '${variantFolderName}_Thumbnail$thumbExt';
        await File(p.join(variantFolderPath, thumbFileName))
            .writeAsBytes(thumbFile.content as List<int>);
      }

      // Extract gallery images
      final galleryFileNames = <String>[];
      final galleryFiles = archive.files
          .where((f) => f.name.startsWith('gallery/'))
          .toList();
      for (int i = 0; i < galleryFiles.length; i++) {
        final img = galleryFiles[i];
        final imgExt = p.extension(img.name);
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_$i$imgExt';
        await File(p.join(galleryFolderPath, fileName))
            .writeAsBytes(img.content as List<int>);
        galleryFileNames.add(fileName);
      }

      return _ExtractResult(
        characterFilePath: finalCharPath,
        originalFileName: originalName,
        thumbnailFileName: thumbFileName,
        galleryFileNames: galleryFileNames,
      );
    } catch (_) {
      return null;
    }
  }

  /// Returns true if the given file path looks like a .pso2char bundle.
  static bool isBundlePath(String path) =>
      p.extension(path).toLowerCase() == '.$kBundleExtension';

  static Future<String> _uniquePath(String path) async {
    if (!await File(path).exists()) return path;
    final ext = p.extension(path);
    final base = path.substring(0, path.length - ext.length);
    return '${base}_${DateTime.now().millisecondsSinceEpoch}$ext';
  }
}

class _ExtractResult {
  final String characterFilePath;
  final String originalFileName;
  final String? thumbnailFileName; // relative filename inside variant folder
  final List<String> galleryFileNames; // relative filenames inside gallery folder

  const _ExtractResult({
    required this.characterFilePath,
    required this.originalFileName,
    required this.thumbnailFileName,
    required this.galleryFileNames,
  });
}
