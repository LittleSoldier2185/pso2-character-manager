import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/character.dart';
import '../models/character_data.dart';
import '../models/collection.dart';
import '../models/collection_data.dart';
import '../models/gallery_data.dart';
import '../models/gallery_item.dart';
import '../models/tag.dart';
import '../models/tag_data.dart';
import 'data_service.dart';

// ── Migration result ──────────────────────────────────────────────

class MigrationResult {
  final int succeeded;
  final List<String> failed; // character names that failed

  const MigrationResult({required this.succeeded, required this.failed});

  bool get hasErrors => failed.isNotEmpty;
}

// ── MigrationService ──────────────────────────────────────────────

class MigrationService {
  static const String _charactersBox  = 'characters';
  static const String _collectionsBox = 'collections';
  static const String _galleryBox     = 'gallery';
  static const String _tagsBox        = 'tags';
  static const String _settingsBox    = 'settings';

  static const String _keyGameFolder      = 'gameFolderPath';
  static const String _keySaveLocation    = 'saveLocation';
  static const String _keyAccentColor     = 'accentColor';
  static const String _keyGalleryColumns  = 'galleryColumns';
  static const String _keyGallerySize     = 'gallerySize';
  static const String _keyCardSize        = 'cardSize';
  static const String _keyPersistedFilter = 'persistedFilter';
  static const String _keyPersistFilter   = 'persistFilterEnabled';
  static const String _keySavedPresets    = 'savedFilterPresets';

  /// Returns true if old Hive data exists and needs migration.
  static Future<bool> needsMigration() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final appRoot = p.join(docs.path, 'PSO2CharacterManager');

      // Fast-exit: if app_data.json already has a valid data version,
      // migration already completed successfully — skip regardless of any
      // leftover .hive files that backup may not have been able to delete.
      final appDataFile = File(p.join(appRoot, 'app_data.json'));
      if (appDataFile.existsSync()) {
        try {
          final j = jsonDecode(appDataFile.readAsStringSync())
              as Map<String, dynamic>;
          if ((j['dataVersion'] as int? ?? 0) >= DataService.currentDataVersion) {
            return false;
          }
        } catch (_) {}
      }

      // No version marker — check for Hive files to decide if old data exists.
      final hiveDir = Directory(appRoot);
      return File(p.join(hiveDir.path, 'characters.hive')).existsSync() ||
             File(p.join(hiveDir.path, 'characters.hive.lock')).existsSync() ||
             await _hiveFileExists(docs.path);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _hiveFileExists(String basePath) async {
    for (final name in ['characters', 'collections', 'tags', 'gallery']) {
      if (File(p.join(basePath, '$name.hive')).existsSync()) return true;
    }
    return false;
  }

  /// Runs the full migration. Also initialises DataService as a side effect.
  static Future<MigrationResult> run({
    void Function(String message, int done, int total)? onProgress,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final appRoot = p.join(docs.path, 'PSO2CharacterManager');

    // Init Hive at the documents root — v1.2.0 called initFlutter() with no
    // path, so .hive files live in Documents/ directly, not PSO2CharacterManager/.
    await Hive.initFlutter(docs.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CharacterAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(CollectionAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(GalleryItemAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(TagAdapter());

    final characterBox  = await Hive.openBox<Character>(_charactersBox);
    final collectionBox = await Hive.openBox<Collection>(_collectionsBox);
    final galleryBox    = await Hive.openBox<GalleryItem>(_galleryBox);
    final tagBox        = await Hive.openBox<Tag>(_tagsBox);
    final settingsBox   = await Hive.openBox(_settingsBox);

    // Read old settings and init DataService
    final saveLocation = settingsBox.get(_keySaveLocation) as String?;
    await DataService.init(saveLocation: saveLocation);
    final svc = DataService.instance;

    // Migrate settings
    await svc.saveSettings(AppSettings(
      gameFolderPath: settingsBox.get(_keyGameFolder) as String?,
      saveLocation: saveLocation,
      accentColor: (settingsBox.get(_keyAccentColor) as int?) ?? 0xFF00B4D8,
      galleryColumns: (settingsBox.get(_keyGalleryColumns) as int?) ?? 3,
      gallerySize: (settingsBox.get(_keyGallerySize) as int?) ?? 3,
      cardSize: (settingsBox.get(_keyCardSize) as int?) ?? 2,
      persistFilter: (settingsBox.get(_keyPersistFilter) as bool?) ?? false,
      persistedFilter: settingsBox.get(_keyPersistedFilter) as String?,
      savedPresets: settingsBox.get(_keySavedPresets) as String?,
    ));

    // Migrate tags
    await svc.saveTags(tagBox.values.map((t) => TagData(
      id: t.id, name: t.name, colorValue: t.colorValue, createdAt: t.createdAt,
    )).toList());

    // Migrate collections
    await svc.saveCollections(collectionBox.values.map((c) => CollectionData(
      id: c.id, name: c.name, createdAt: c.createdAt,
      description: c.description, accentColorValue: c.accentColorValue,
    )).toList());

    // Build gallery map: characterId → items
    final galleryMap = <String, List<GalleryItem>>{};
    for (final item in galleryBox.values) {
      galleryMap.putIfAbsent(item.characterId, () => []).add(item);
    }

    // Migrate characters
    final chars = characterBox.values.toList();
    int done = 0;
    final failed = <String>[];

    for (final char in chars) {
      onProgress?.call('Migrating ${char.name}…', done, chars.length);
      try {
        final variantFolderName = _toFolderName(
            char.name.isNotEmpty ? char.name : 'main');
        final charFolderName = CharacterData.toFolderName(char.name, char.id);
        final charFolder = svc.characterFolderPath(charFolderName);
        final variantFolder = p.join(charFolder, variantFolderName);
        final galleryFolder = p.join(charFolder, 'character_gallery');

        await Directory(variantFolder).create(recursive: true);
        await Directory(galleryFolder).create(recursive: true);
        await Directory(p.join(charFolder, 'backup')).create(recursive: true);

        // Copy character file into variant folder
        if (char.characterFilePath.isNotEmpty) {
          final src = File(char.characterFilePath);
          if (await src.exists()) {
            await src.copy(
                p.join(variantFolder, p.basename(char.characterFilePath)));
          }
        }

        // Copy thumbnail into variant folder
        if (char.thumbnailPath != null && char.thumbnailPath!.isNotEmpty) {
          final src = File(char.thumbnailPath!);
          if (await src.exists()) {
            final ext = p.extension(char.thumbnailPath!);
            final clean = variantFolderName.replaceAll('_', ' ').trim();
            await src.copy(p.join(variantFolder, '${clean}_Thumbnail$ext'));
          }
        }

        final variant = VariantData(
          folderName: variantFolderName,
          displayName: 'Main',
          createdAt: char.createdAt,
          lastSyncedAt: char.lastSyncedAt,
          originalFileName: char.originalFileName,
        );

        final collectionIds = char.collectionIds.isNotEmpty
            ? char.collectionIds
            : (char.collectionId != null ? [char.collectionId!] : <String>[]);

        final charData = CharacterData(
          id: char.id,
          name: char.name,
          race: char.race,
          gender: char.gender,
          description: char.description,
          tags: char.tags,
          collectionIds: collectionIds,
          isFavourite: char.isFavourite,
          tierIndex: char.tierIndex,
          createdAt: char.createdAt,
          mainVariant: variantFolderName,
          appliedVariants: char.isApplied ? [variantFolderName] : [],
          variants: [variant],
          folderPath: charFolder,
        );

        await svc.saveCharacter(charData);
        await File(p.join(charFolder, 'character_update_log.json'))
            .writeAsString('[]');

        // Migrate gallery items
        final newItems = <GalleryItemData>[];
        for (final item in galleryMap[char.id] ?? []) {
          final src = File(item.filePath);
          if (await src.exists()) {
            final ext = p.extension(item.filePath);
            final fileName = '${item.addedAt.millisecondsSinceEpoch}$ext';
            await src.copy(p.join(galleryFolder, fileName));
            newItems.add(GalleryItemData(
              id: item.id,
              characterId: item.characterId,
              fileName: fileName,
              addedAt: item.addedAt,
            ));
          }
        }
        await svc.saveGalleryItems(charData, newItems);

        done++;
      } catch (_) {
        failed.add(char.name);
        done++;
      }
    }

    await svc.saveDataVersion(DataService.currentDataVersion);
    await Hive.close();

    return MigrationResult(succeeded: done - failed.length, failed: failed);
  }

  static String _toFolderName(String name) => name
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '')
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'_{2,}'), '_')
      .trim();
}
