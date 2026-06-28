import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/character_data.dart';
import '../models/collection_data.dart';
import '../models/album_data.dart';
import '../models/gallery_data.dart';
import '../models/tag_data.dart';
import '../widgets/tier_border.dart';

// ── App settings ──────────────────────────────────────────────────

class AppSettings {
  String? gameFolderPath;
  String? saveLocation;
  int accentColor;
  int bgColor;
  int gallerySize;
  int cardSize;
  bool persistFilter;
  String? persistedFilter;
  String? savedPresets;
  int galleryColumns;
  bool gameFolderPromptShown;
  String? sortOption;
  String? lastSeenVersion;
  String? tierEffectsJson;
  bool blurSensitiveInViews;

  AppSettings({
    this.gameFolderPath,
    this.saveLocation,
    this.accentColor = 0xFF00B4D8,
    this.bgColor = 0xFF0D1117,
    this.gallerySize = 3,
    this.cardSize = 2,
    this.persistFilter = false,
    this.persistedFilter,
    this.savedPresets,
    this.galleryColumns = 3,
    this.gameFolderPromptShown = false,
    this.sortOption,
    this.lastSeenVersion,
    this.tierEffectsJson,
    this.blurSensitiveInViews = true,
  });

  Color? get accentColorValue =>
      accentColor != 0 ? Color(accentColor) : null;

  Map<String, dynamic> toJson() => {
    'gameFolderPath': gameFolderPath,
    'saveLocation': saveLocation,
    'accentColor': accentColor,
    'bgColor': bgColor,
    'gallerySize': gallerySize,
    'cardSize': cardSize,
    'persistFilter': persistFilter,
    'persistedFilter': persistedFilter,
    'savedPresets': savedPresets,
    'galleryColumns': galleryColumns,
    'gameFolderPromptShown': gameFolderPromptShown,
    'sortOption': sortOption,
    'lastSeenVersion': lastSeenVersion,
    'tierEffectsJson': tierEffectsJson,
    'blurSensitiveInViews': blurSensitiveInViews,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    gameFolderPath: j['gameFolderPath'] as String?,
    saveLocation: j['saveLocation'] as String?,
    accentColor: (j['accentColor'] as int?) ?? 0xFF00B4D8,
    bgColor: (j['bgColor'] as int?) ?? 0xFF0D1117,
    gallerySize: (j['gallerySize'] as int?) ?? 3,
    cardSize: (j['cardSize'] as int?) ?? 2,
    persistFilter: (j['persistFilter'] as bool?) ?? false,
    persistedFilter: j['persistedFilter'] as String?,
    savedPresets: j['savedPresets'] as String?,
    galleryColumns: (j['galleryColumns'] as int?) ?? 3,
    gameFolderPromptShown: (j['gameFolderPromptShown'] as bool?) ?? false,
    sortOption: j['sortOption'] as String?,
    lastSeenVersion: j['lastSeenVersion'] as String?,
    tierEffectsJson: j['tierEffectsJson'] as String?,
    blurSensitiveInViews: (j['blurSensitiveInViews'] as bool?) ?? true,
  );
}

// ── DataService ───────────────────────────────────────────────────

class DataService {
  static DataService? _instance;
  static DataService get instance => _instance!;

  static const int currentDataVersion = 1;

  // Maximum number of backups to keep per variant before pruning the oldest.
  static const int maxBackupsPerVariant = 5;

  // Path where app_data.json and settings.json always live
  // (default documents dir — independent of custom save location)
  late final String _appRootPath;

  // Characters, collections, tags live here
  // (may differ from _appRootPath if user chose a custom save location)
  late String _dataRootPath;

  DataService._();

  // ── Initialisation ────────────────────────────────────────────────

  /// Call once on startup (after migration check).
  /// [saveLocation] — custom path set by user, or null to use default.
  static Future<DataService> init({String? saveLocation}) async {
    final svc = DataService._();
    final docs = await getApplicationDocumentsDirectory();
    svc._appRootPath = p.join(docs.path, 'PSO2CharacterManager');
    await Directory(svc._appRootPath).create(recursive: true);

    svc._dataRootPath = saveLocation != null && saveLocation.isNotEmpty
        ? saveLocation
        : svc._appRootPath;
    await Directory(svc._charactersPath).create(recursive: true);

    _instance = svc;
    return svc;
  }

  void setDataRoot(String path) {
    _dataRootPath = path;
  }

  // ── Paths ─────────────────────────────────────────────────────────

  String get _appDataPath => p.join(_appRootPath, 'app_data.json');
  String get _settingsPath => p.join(_appRootPath, 'settings.json');
  String get _charactersPath => p.join(_dataRootPath, 'characters');
  String get _collectionsPath => p.join(_dataRootPath, 'collections.json');
  String get _tagsPath      => p.join(_dataRootPath, 'tags.json');
  String get _albumTagsPath => p.join(_dataRootPath, 'album_tags.json');
  String get _albumsPath    => p.join(_dataRootPath, 'albums.json');
  String get _recycleBinPath => p.join(_dataRootPath, 'recycle_bin');
  String get _recycleBinMetaPath => p.join(_recycleBinPath, 'meta.json');

  String characterFolderPath(String folderName) =>
      p.join(_charactersPath, folderName);

  String variantFolderPath(String characterFolder, String variantFolder) =>
      p.join(characterFolderPath(characterFolder), variantFolder);

  // ── App data (version) ────────────────────────────────────────────

  Future<int> getDataVersion() async {
    final file = File(_appDataPath);
    if (!await file.exists()) return 0;
    try {
      final j = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return (j['dataVersion'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> saveDataVersion(int version) async {
    final file = File(_appDataPath);
    Map<String, dynamic> data = {};
    if (await file.exists()) {
      try {
        data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      } catch (_) {}
    }
    data['dataVersion'] = version;
    data['migratedAt'] = DateTime.now().toIso8601String();
    await file.writeAsString(jsonEncode(data));
  }

  // ── Settings ──────────────────────────────────────────────────────

  Future<AppSettings> getSettings() async {
    final file = File(_settingsPath);
    if (!await file.exists()) return AppSettings();
    try {
      return AppSettings.fromJson(
          jsonDecode(await file.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    await File(_settingsPath).writeAsString(jsonEncode(settings.toJson()));
  }

  // Quick individual setting accessors used throughout the app

  Future<Color?> getAccentColor() async {
    final s = await getSettings();
    return s.accentColor != 0 ? Color(s.accentColor) : null;
  }

  Future<void> saveAccentColor(Color color) async {
    final s = await getSettings();
    s.accentColor = color.toARGB32();
    await saveSettings(s);
  }

  Future<Color?> getBgColor() async {
    final s = await getSettings();
    return s.bgColor != 0 ? Color(s.bgColor) : null;
  }

  Future<void> saveBgColor(Color color) async {
    final s = await getSettings();
    s.bgColor = color.toARGB32();
    await saveSettings(s);
  }

  Future<int> getCardSize() async => (await getSettings()).cardSize;
  Future<void> saveCardSize(int v) async {
    final s = await getSettings();
    s.cardSize = v;
    await saveSettings(s);
  }

  Future<void> saveSortOption(String v) async {
    final s = await getSettings();
    s.sortOption = v;
    await saveSettings(s);
  }

  Future<void> saveLastSeenVersion(String v) async {
    final s = await getSettings();
    s.lastSeenVersion = v;
    await saveSettings(s);
  }

  Future<void> saveTierEffects(Map<CharacterTier, TierBorderEffect> effects) async {
    final s = await getSettings();
    s.tierEffectsJson = jsonEncode(
      effects.map((k, v) => MapEntry(k.label.toLowerCase(), v.name)),
    );
    await saveSettings(s);
  }

  Future<Map<CharacterTier, TierBorderEffect>?> getTierEffects() async {
    final s = await getSettings();
    if (s.tierEffectsJson == null) return null;
    try {
      final raw = jsonDecode(s.tierEffectsJson!) as Map<String, dynamic>;
      return {
        for (final e in raw.entries)
          CharacterTier.values.firstWhere(
            (t) => t.label.toLowerCase() == e.key,
            orElse: () => CharacterTier.d,
          ): TierBorderEffect.values.firstWhere(
            (ef) => ef.name == e.value,
            orElse: () => TierBorderEffect.none,
          ),
      };
    } catch (_) {
      return null;
    }
  }

  Future<int> getGallerySize() async => (await getSettings()).gallerySize;
  Future<void> saveGallerySize(int v) async {
    final s = await getSettings();
    s.gallerySize = v;
    await saveSettings(s);
  }

  Future<int> getGalleryColumns() async => (await getSettings()).galleryColumns;
  Future<void> saveGalleryColumns(int cols) async {
    final s = await getSettings();
    s.galleryColumns = cols;
    await saveSettings(s);
  }

  Future<bool> getPersistFilter() async => (await getSettings()).persistFilter;
  Future<void> savePersistFilter(bool v) async {
    final s = await getSettings();
    s.persistFilter = v;
    await saveSettings(s);
  }

  Future<bool> getBlurSensitiveInViews() async =>
      (await getSettings()).blurSensitiveInViews;
  Future<void> saveBlurSensitiveInViews(bool v) async {
    final s = await getSettings();
    s.blurSensitiveInViews = v;
    await saveSettings(s);
  }

  Future<String?> getPersistedFilter() async =>
      (await getSettings()).persistedFilter;
  Future<void> savePersistedFilter(String? json) async {
    final s = await getSettings();
    s.persistedFilter = json;
    await saveSettings(s);
  }

  Future<String?> getSavedPresets() async =>
      (await getSettings()).savedPresets;
  Future<void> saveSavedPresets(String json) async {
    final s = await getSettings();
    s.savedPresets = json;
    await saveSettings(s);
  }

  // ── Characters ────────────────────────────────────────────────────

  /// Scans the characters/ directory and loads all characters.
  Future<List<CharacterData>> getAllCharacters() async {
    final dir = Directory(_charactersPath);
    if (!await dir.exists()) return [];

    final characters = <CharacterData>[];
    await for (final entry in dir.list()) {
      if (entry is! Directory) continue;
      final jsonFile = File(p.join(entry.path, 'character_data.json'));
      if (!await jsonFile.exists()) continue;
      try {
        final j = jsonDecode(await jsonFile.readAsString())
            as Map<String, dynamic>;
        characters.add(CharacterData.fromJson(j, entry.path));
      } catch (_) {
        // Skip corrupt entries
      }
    }
    return characters;
  }

  /// Writes character_data.json for the given character.
  Future<void> saveCharacter(CharacterData character) async {
    character.lastModifiedAt = DateTime.now();
    final jsonFile =
        File(p.join(character.folderPath, 'character_data.json'));
    await jsonFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(character.toJson()));
  }

  /// Creates the full folder structure for a new character.
  /// Returns the CharacterData with folderPath set.
  Future<CharacterData> createCharacterFolder({
    required String id,
    required String name,
    required String race,
    required String gender,
    required String variantFolderName,
    required String variantDisplayName,
    String description = '',
    List<String>? tags,
    List<String>? collectionIds,
    String? originalFileName,
  }) async {
    final folderName = CharacterData.toFolderName(name, id);
    final charFolder = p.join(_charactersPath, folderName);
    final variantFolder = p.join(charFolder, variantFolderName);
    final galleryFolder = p.join(charFolder, 'character_gallery');
    final backupFolder = p.join(charFolder, 'backup');

    await Directory(variantFolder).create(recursive: true);
    await Directory(galleryFolder).create(recursive: true);
    await Directory(backupFolder).create(recursive: true);

    final variant = VariantData(
      folderName: variantFolderName,
      displayName: variantDisplayName,
      originalFileName: originalFileName,
    );

    final character = CharacterData(
      id: id,
      name: name,
      race: race,
      gender: gender,
      description: description,
      tags: tags ?? [],
      collectionIds: collectionIds ?? [],
      mainVariant: variantFolderName,
      variants: [variant],
      folderPath: charFolder,
    );

    await saveCharacter(character);
    await _writeGalleryJson(charFolder, []);
    await _writeUpdateLog(charFolder, []);
    return character;
  }

  /// Adds a new variant folder to an existing character.
  Future<VariantData> addVariant({
    required CharacterData character,
    required String folderName,
    required String displayName,
    String? originalFileName,
  }) async {
    final variantFolder =
        p.join(character.folderPath, folderName);
    await Directory(variantFolder).create(recursive: true);

    final variant = VariantData(
      folderName: folderName,
      displayName: displayName,
      originalFileName: originalFileName,
    );
    character.variants.add(variant);
    await saveCharacter(character);
    return variant;
  }

  // ── Recycle bin ───────────────────────────────────────────────────

  Future<Map<String, int>> _readTrashMeta() async {
    final file = File(_recycleBinMetaPath);
    if (!await file.exists()) return {};
    try {
      final j = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return j.map((k, v) => MapEntry(k, v as int));
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeTrashMeta(Map<String, int> meta) async {
    await Directory(_recycleBinPath).create(recursive: true);
    await File(_recycleBinMetaPath).writeAsString(jsonEncode(meta));
  }

  Future<void> softDeleteCharacter(CharacterData character) async {
    await Directory(_recycleBinPath).create(recursive: true);
    final dest = p.join(_recycleBinPath, p.basename(character.folderPath));
    await Directory(character.folderPath).rename(dest);
    final meta = await _readTrashMeta();
    meta[character.id] = DateTime.now().millisecondsSinceEpoch;
    await _writeTrashMeta(meta);
  }

  Future<CharacterData?> restoreCharacter(String id) async {
    final meta = await _readTrashMeta();
    if (!meta.containsKey(id)) return null;
    final dir = Directory(_recycleBinPath);
    if (!await dir.exists()) return null;
    await for (final entry in dir.list()) {
      if (entry is! Directory) continue;
      final jsonFile = File(p.join(entry.path, 'character_data.json'));
      if (!await jsonFile.exists()) continue;
      try {
        final j = jsonDecode(await jsonFile.readAsString()) as Map<String, dynamic>;
        if (j['id'] as String == id) {
          var dest = p.join(_charactersPath, p.basename(entry.path));
          if (await Directory(dest).exists()) {
            dest = '${dest}_r${DateTime.now().millisecondsSinceEpoch}';
          }
          await Directory(entry.path).rename(dest);
          meta.remove(id);
          await _writeTrashMeta(meta);
          return CharacterData.fromJson(j, dest);
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> purgeExpiredTrash() async {
    final meta = await _readTrashMeta();
    if (meta.isEmpty) return;
    final now = DateTime.now();
    final toDelete = meta.entries
        .where((e) => now.difference(DateTime.fromMillisecondsSinceEpoch(e.value)).inDays >= 7)
        .map((e) => e.key)
        .toList();
    if (toDelete.isEmpty) return;
    final dir = Directory(_recycleBinPath);
    if (!await dir.exists()) return;
    for (final id in toDelete) {
      await for (final entry in dir.list()) {
        if (entry is! Directory) continue;
        final jsonFile = File(p.join(entry.path, 'character_data.json'));
        if (!await jsonFile.exists()) continue;
        try {
          final j = jsonDecode(await jsonFile.readAsString()) as Map<String, dynamic>;
          if (j['id'] as String == id) {
            await Directory(entry.path).delete(recursive: true);
            break;
          }
        } catch (_) {}
      }
      meta.remove(id);
    }
    await _writeTrashMeta(meta);
  }

  Future<List<({CharacterData character, DateTime deletedAt})>> listTrash() async {
    final meta = await _readTrashMeta();
    final result = <({CharacterData character, DateTime deletedAt})>[];
    final dir = Directory(_recycleBinPath);
    if (!await dir.exists()) return result;
    await for (final entry in dir.list()) {
      if (entry is! Directory) continue;
      final jsonFile = File(p.join(entry.path, 'character_data.json'));
      if (!await jsonFile.exists()) continue;
      try {
        final j = jsonDecode(await jsonFile.readAsString()) as Map<String, dynamic>;
        final id = j['id'] as String;
        if (!meta.containsKey(id)) continue;
        result.add((
          character: CharacterData.fromJson(j, entry.path),
          deletedAt: DateTime.fromMillisecondsSinceEpoch(meta[id]!),
        ));
      } catch (_) {}
    }
    result.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return result;
  }

  Future<void> permanentlyDeleteFromTrash(String id) async {
    final dir = Directory(_recycleBinPath);
    if (!await dir.exists()) return;
    await for (final entry in dir.list()) {
      if (entry is! Directory) continue;
      final jsonFile = File(p.join(entry.path, 'character_data.json'));
      if (!await jsonFile.exists()) continue;
      try {
        final j = jsonDecode(await jsonFile.readAsString()) as Map<String, dynamic>;
        if (j['id'] as String == id) {
          await Directory(entry.path).delete(recursive: true);
          break;
        }
      } catch (_) {}
    }
    final meta = await _readTrashMeta();
    meta.remove(id);
    await _writeTrashMeta(meta);
  }

  // ── Hard delete (bypass bin) ──────────────────────────────────────

  /// Deletes the entire character folder.
  Future<void> deleteCharacter(CharacterData character) async {
    final dir = Directory(character.folderPath);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Deletes a single variant folder and all its contents.
  Future<void> deleteVariantFolder(
      CharacterData character, String variantFolderName) async {
    final dir =
        Directory(p.join(character.folderPath, variantFolderName));
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Copies a file into a variant's folder, returns the stored path.
  Future<String> copyFileToVariant({
    required String characterFolderPath,
    required String variantFolderName,
    required String sourcePath,
    String? targetFileName,
  }) async {
    final variantFolder =
        p.join(characterFolderPath, variantFolderName);
    await Directory(variantFolder).create(recursive: true);
    final fileName = targetFileName ?? p.basename(sourcePath);
    final dest = p.join(variantFolder, fileName);
    await File(sourcePath).copy(dest);
    return dest;
  }

  /// Copies a thumbnail into a variant's folder with naming convention.
  Future<String> copyThumbnailToVariant({
    required String characterFolderPath,
    required String variantFolderName,
    required String sourcePath,
  }) async {
    final ext = p.extension(sourcePath);
    // Clean variant name for thumbnail filename
    final cleanName = variantFolderName.replaceAll('_', ' ').trim();
    final targetName = '${cleanName}_Thumbnail$ext';
    return copyFileToVariant(
      characterFolderPath: characterFolderPath,
      variantFolderName: variantFolderName,
      sourcePath: sourcePath,
      targetFileName: targetName,
    );
  }

  /// Saves a static thumbnail at the character root level.
  Future<String> copyStaticThumbnail({
    required CharacterData character,
    required String sourcePath,
  }) async {
    final ext = p.extension(sourcePath);
    final fileName = '${character.name}_Static_Thumbnail$ext';
    final dest = p.join(character.folderPath, fileName);
    await File(sourcePath).copy(dest);
    return fileName; // return relative filename
  }

  // ── Gallery ───────────────────────────────────────────────────────

  Future<List<GalleryItemData>> getGalleryItems(
      CharacterData character) async {
    final jsonFile = File(
        p.join(character.folderPath, 'character_gallery.json'));
    if (!await jsonFile.exists()) return [];
    try {
      final list =
          jsonDecode(await jsonFile.readAsString()) as List;
      return list
          .map((e) =>
              GalleryItemData.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    } catch (_) {
      return [];
    }
  }

  Future<List<GalleryItemData>> getAllGalleryItems(
      List<CharacterData> characters) async {
    final all = <GalleryItemData>[];
    for (final c in characters) {
      all.addAll(await getGalleryItems(c));
    }
    all.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return all;
  }

  Future<void> saveGalleryItems(
      CharacterData character, List<GalleryItemData> items) async {
    await _writeGalleryJson(character.folderPath, items);
  }

  Future<void> _writeGalleryJson(
      String charFolder, List<GalleryItemData> items) async {
    final file =
        File(p.join(charFolder, 'character_gallery.json'));
    await file.writeAsString(const JsonEncoder.withIndent('  ')
        .convert(items.map((i) => i.toJson()).toList()));
  }

  Future<GalleryItemData> addGalleryItem({
    required CharacterData character,
    required String sourcePath,
  }) async {
    final galleryFolder =
        p.join(character.folderPath, 'character_gallery');
    await Directory(galleryFolder).create(recursive: true);

    final ext = p.extension(sourcePath);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';
    await File(sourcePath).copy(p.join(galleryFolder, fileName));

    final item = GalleryItemData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      characterId: character.id,
      fileName: fileName,
    );
    final items = await getGalleryItems(character);
    items.insert(0, item);
    await saveGalleryItems(character, items);
    return item;
  }

  Future<void> deleteGalleryItem({
    required CharacterData character,
    required GalleryItemData item,
  }) async {
    final file = File(item.filePath(character.folderPath));
    if (await file.exists()) await file.delete();
    final items = await getGalleryItems(character);
    items.removeWhere((i) => i.id == item.id);
    await saveGalleryItems(character, items);
  }

  // ── Update log ────────────────────────────────────────────────────

  Future<void> _writeUpdateLog(
      String charFolder, List<Map<String, dynamic>> entries) async {
    final file =
        File(p.join(charFolder, 'character_update_log.json'));
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(entries));
  }

  Future<void> addUpdateLogEntry({
    required CharacterData character,
    required String variantFolderName,
    required String source,
    required String backupFolderName,
  }) async {
    final logFile = File(
        p.join(character.folderPath, 'character_update_log.json'));
    List<Map<String, dynamic>> entries = [];
    if (await logFile.exists()) {
      try {
        entries = (jsonDecode(await logFile.readAsString()) as List)
            .cast<Map<String, dynamic>>();
      } catch (_) {}
    }
    entries.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'variantFolderName': variantFolderName,
      'savedAt': DateTime.now().toIso8601String(),
      'source': source,
      'backupFolderName': backupFolderName,
    });
    await _writeUpdateLog(character.folderPath, entries);
  }

  /// Creates a timestamped backup of a variant's files inside backup/.
  /// Prunes oldest backups for this variant so at most [maxBackupsPerVariant]
  /// are kept. Returns the backup folder name.
  Future<String> backupVariant({
    required CharacterData character,
    required String variantFolderName,
    required String source,
  }) async {
    final now = DateTime.now();
    final timestamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}'
        'T${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';
    final backupFolderName = '${timestamp}_$variantFolderName';
    final backupRoot = p.join(character.folderPath, 'backup');
    final backupFolder = p.join(backupRoot, backupFolderName);
    await Directory(backupFolder).create(recursive: true);

    final variantFolder = p.join(character.folderPath, variantFolderName);
    final variantDir = Directory(variantFolder);
    if (await variantDir.exists()) {
      await for (final entity in variantDir.list()) {
        if (entity is File) {
          await entity.copy(p.join(backupFolder, p.basename(entity.path)));
        }
      }
    }

    await addUpdateLogEntry(
      character: character,
      variantFolderName: variantFolderName,
      source: source,
      backupFolderName: backupFolderName,
    );

    await _pruneBackups(backupRoot, variantFolderName);

    return backupFolderName;
  }

  /// Deletes the oldest backups for [variantFolderName] so only
  /// [maxBackupsPerVariant] remain.
  Future<void> _pruneBackups(
      String backupRoot, String variantFolderName) async {
    final dir = Directory(backupRoot);
    if (!await dir.exists()) return;

    final suffix = '_$variantFolderName';
    final folders = <String>[];
    await for (final entity in dir.list()) {
      if (entity is Directory &&
          p.basename(entity.path).endsWith(suffix)) {
        folders.add(entity.path);
      }
    }

    if (folders.length <= maxBackupsPerVariant) return;

    // Folder names start with an ISO-like timestamp — lexicographic sort is
    // chronological, so the first entries are the oldest.
    folders.sort();
    final toDelete = folders.sublist(0, folders.length - maxBackupsPerVariant);
    for (final path in toDelete) {
      try {
        await Directory(path).delete(recursive: true);
      } catch (_) {}
    }
  }

  // ── Collections ───────────────────────────────────────────────────

  Future<List<CollectionData>> getAllCollections() async {
    final file = File(_collectionsPath);
    if (!await file.exists()) return [];
    try {
      final list = jsonDecode(await file.readAsString()) as List;
      return list
          .map((e) =>
              CollectionData.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCollections(List<CollectionData> collections) async {
    await File(_collectionsPath).writeAsString(
        const JsonEncoder.withIndent('  ')
            .convert(collections.map((c) => c.toJson()).toList()));
  }

  // ── Tags ──────────────────────────────────────────────────────────

  Future<List<TagData>> getAllTags() async {
    final file = File(_tagsPath);
    if (!await file.exists()) return [];
    try {
      final list = jsonDecode(await file.readAsString()) as List;
      return list
          .map((e) => TagData.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    } catch (_) {
      return [];
    }
  }

  Future<void> saveTags(List<TagData> tags) async {
    await File(_tagsPath).writeAsString(const JsonEncoder.withIndent('  ')
        .convert(tags.map((t) => t.toJson()).toList()));
  }

  Future<List<TagData>> getAllAlbumTags() async {
    final file = File(_albumTagsPath);
    if (!await file.exists()) return [];
    try {
      final list = jsonDecode(await file.readAsString()) as List;
      return list.map((j) => TagData.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAlbumTags(List<TagData> tags) async {
    await File(_albumTagsPath).writeAsString(const JsonEncoder.withIndent('  ')
        .convert(tags.map((t) => t.toJson()).toList()));
  }

  // ── Albums ────────────────────────────────────────────────────────

  Future<List<AlbumData>> loadAlbums() async {
    final file = File(_albumsPath);
    if (!await file.exists()) return [];
    try {
      final list = jsonDecode(await file.readAsString()) as List;
      return list.map((j) => AlbumData.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAlbums(List<AlbumData> albums) async {
    await File(_albumsPath).writeAsString(
        jsonEncode(albums.map((a) => a.toJson()).toList()));
  }

  // ── Apply history ─────────────────────────────────────────────────

  String get _applyHistoryPath => p.join(_appRootPath, 'apply_history.json');

  Future<void> addApplyHistoryEntry({
    required String characterId,
    required String characterName,
    required String variantFolderName,
    required bool isApply,
  }) async {
    final file = File(_applyHistoryPath);
    List<dynamic> entries = [];
    if (await file.exists()) {
      try { entries = jsonDecode(await file.readAsString()) as List; } catch (_) {}
    }
    entries.insert(0, {
      'characterId':       characterId,
      'characterName':     characterName,
      'variantFolderName': variantFolderName,
      'action':            isApply ? 'apply' : 'unapply',
      'at':                DateTime.now().toIso8601String(),
    });
    if (entries.length > 100) entries = entries.sublist(0, 100);
    await file.writeAsString(jsonEncode(entries));
  }

  Future<List<Map<String, dynamic>>> getApplyHistory() async {
    final file = File(_applyHistoryPath);
    if (!await file.exists()) return [];
    try {
      return (jsonDecode(await file.readAsString()) as List)
          .cast<Map<String, dynamic>>();
    } catch (_) { return []; }
  }

  // ── File export ───────────────────────────────────────────────────

  Future<void> exportCharacterFile(
      String sourcePath, String destPath) async {
    await File(sourcePath).copy(destPath);
  }

  Future<List<String>> scanForUnregisteredFiles(
    String gameFolderPath,
    Set<String> registeredFileNames,
  ) async {
    final dir = Directory(gameFolderPath);
    if (!await dir.exists()) return [];
    const validExts = {
      'fhp', 'mhp', 'fnp', 'mnp', 'fdp', 'mdp', 'fcp', 'mcp'
    };
    final unregistered = <String>[];
    await for (final entity in dir.list()) {
      if (entity is File) {
        final ext = p.extension(entity.path)
            .replaceFirst('.', '')
            .toLowerCase();
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

  // ── Library backup ────────────────────────────────────────────────

  Future<void> exportBackupZip(
    String destFilePath,
    void Function(int done, int total)? onProgress,
  ) async {
    final archive = Archive();
    final root = Directory(_dataRootPath);
    if (!await root.exists()) return;

    final entities = root.listSync(recursive: true, followLinks: false);
    final total = entities.length;
    int done = 0;

    for (final entity in entities) {
      if (entity is File) {
        final relative = p.relative(entity.path, from: _dataRootPath);
        // Skip recycle bin to keep backup manageable
        if (relative.startsWith('recycle_bin${p.separator}') ||
            relative.startsWith('recycle_bin/')) {
          onProgress?.call(++done, total);
          continue;
        }
        try {
          final bytes = await entity.readAsBytes();
          archive.addFile(ArchiveFile(
            relative.replaceAll('\\', '/'),
            bytes.length,
            bytes,
          ));
        } catch (_) {}
      }
      onProgress?.call(++done, total);
    }

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes != null) {
      await File(destFilePath).writeAsBytes(zipBytes);
    }
  }

  // ── Duplicate detection ───────────────────────────────────────────

  Future<List<List<CharacterData>>> findDuplicates(
      List<CharacterData> characters) async {
    final groups = <String, List<CharacterData>>{};

    for (final c in characters) {
      final path = c.characterFilePath;
      if (path == null) continue;
      final file = File(path);
      if (!await file.exists()) continue;
      try {
        final bytes = await file.readAsBytes();
        final key = '${bytes.length}_${getCrc32(bytes)}';
        groups.putIfAbsent(key, () => []).add(c);
      } catch (_) {}
    }

    return groups.values.where((g) => g.length > 1).toList();
  }

  // ── Save location migration ───────────────────────────────────────

  /// Moves all character folders and global JSON files to a new root path.
  /// Returns a mapping of old folderPath → new folderPath for all characters.
  Future<Map<String, String>> migrateDataRoot({
    required String newRootPath,
    required List<CharacterData> characters,
    void Function(int done, int total)? onProgress,
  }) async {
    final pathMap = <String, String>{};
    final newCharsPath = p.join(newRootPath, 'characters');
    await Directory(newCharsPath).create(recursive: true);

    int done = 0;
    final total = characters.length + 2; // +2 for collections/tags

    for (final char in characters) {
      final folderName = p.basename(char.folderPath);
      final newFolderPath = p.join(newCharsPath, folderName);
      try {
        await _copyDirectory(char.folderPath, newFolderPath);
        pathMap[char.folderPath] = newFolderPath;
      } catch (_) {}
      onProgress?.call(++done, total);
    }

    // Move global JSON files
    for (final fileName in ['collections.json', 'tags.json']) {
      final src = File(p.join(_dataRootPath, fileName));
      if (await src.exists()) {
        await src.copy(p.join(newRootPath, fileName));
      }
      onProgress?.call(++done, total);
    }

    return pathMap;
  }

  static Future<void> _copyDirectory(String src, String dest) async {
    await Directory(dest).create(recursive: true);
    await for (final entity in Directory(src).list(recursive: false)) {
      if (entity is Directory) {
        await _copyDirectory(
            entity.path,
            p.join(dest, p.basename(entity.path)));
      } else if (entity is File) {
        await entity.copy(p.join(dest, p.basename(entity.path)));
      }
    }
  }
}
