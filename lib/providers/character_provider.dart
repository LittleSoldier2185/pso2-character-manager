import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/character.dart';
import '../models/collection.dart';
import '../models/gallery_item.dart';
import '../models/tag.dart';
import '../services/hive_service.dart';
import '../services/file_service.dart';
import '../services/share_service.dart';
import '../services/storage_service.dart';

// ── Filter preset model ───────────────────────────────────────────

class FilterPreset {
  final String id;
  final String name;
  final int colorValue;
  final List<String> tokens;
  final String? race;
  final String? gender;
  final bool? applied;
  final List<String> tagIds;
  final List<int> tierIndices;

  const FilterPreset({
    required this.id,
    required this.name,
    required this.colorValue,
    this.tokens = const [],
    this.race,
    this.gender,
    this.applied,
    this.tagIds = const [],
    this.tierIndices = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
    'tokens': tokens,
    'race': race,
    'gender': gender,
    'applied': applied,
    'tagIds': tagIds,
    'tierIndices': tierIndices,
  };

  factory FilterPreset.fromJson(Map<String, dynamic> j) => FilterPreset(
    id: j['id'] as String,
    name: j['name'] as String,
    colorValue: j['colorValue'] as int,
    tokens: (j['tokens'] as List?)?.cast<String>() ?? [],
    race: j['race'] as String?,
    gender: j['gender'] as String?,
    applied: j['applied'] as bool?,
    tagIds: (j['tagIds'] as List?)?.cast<String>() ?? [],
    tierIndices: (j['tierIndices'] as List?)?.cast<int>() ?? [],
  );
}

enum SortOption {
  nameAZ,
  nameZA,
  newestFirst,
  oldestFirst,
  lastApplied,
  tierHighest,
}

extension SortOptionLabel on SortOption {
  String get label {
    switch (this) {
      case SortOption.nameAZ:      return 'Name A → Z';
      case SortOption.nameZA:      return 'Name Z → A';
      case SortOption.newestFirst:  return 'Newest first';
      case SortOption.oldestFirst:  return 'Oldest first';
      case SortOption.lastApplied:  return 'Last applied';
      case SortOption.tierHighest:  return 'Tier (S first)';
    }
  }

  IconData get icon {
    switch (this) {
      case SortOption.nameAZ:      return Icons.sort_by_alpha_rounded;
      case SortOption.nameZA:      return Icons.sort_by_alpha_rounded;
      case SortOption.newestFirst:  return Icons.schedule_rounded;
      case SortOption.oldestFirst:  return Icons.history_rounded;
      case SortOption.lastApplied:  return Icons.check_circle_outline_rounded;
      case SortOption.tierHighest:  return Icons.military_tech_rounded;
    }
  }
}

class CharacterProvider extends ChangeNotifier {
  final HiveService _hive = HiveService();
  final _uuid = const Uuid();

  List<Character> _characters = [];
  List<Collection> _collections = [];
  List<Tag> _tags = [];

  // Characters that have a newer file in the game folder
  // key = character id, value = game folder file's modified time
  final Map<String, DateTime> _pendingUpdates = {};
  Timer? _syncTimer;

  List<String> _pendingTokens = [];
  List<String> _appliedTokens = [];
  String? _filterRace;
  String? _filterGender;
  String? _filterCollectionId;
  bool? _filterApplied;
  List<String> _filterTags = [];         // whitelist tag IDs
  List<String> _filterTagsBlacklist = []; // blacklist tag IDs
  Set<CharacterTier> _filterTiers = {};
  SortOption _sortOption = SortOption.newestFirst;
  bool _favouritesOnTop = true;

  // Saved presets and persist setting
  List<FilterPreset> _savedPresets = [];
  bool _matchAll = true; // true = AND, false = OR — applies to tag filter
  bool _persistFilter = false;

  String? _gameFolderPath;
  String? _saveLocation;

  // ── Getters ────────────────────────────────────────────────────

  List<Character> get allCharacters => _sortedCharacters(_characters);
  List<Collection> get allCollections => _collections;
  List<Tag> get allTags => _tags;

  /// Looks up a Tag by id. Returns null if not found (e.g. tag was deleted).
  Tag? tagById(String id) {
    try { return _tags.firstWhere((t) => t.id == id); } catch (_) { return null; }
  }

  List<String> get pendingTokens => _pendingTokens;
  List<String> get appliedTokens => _appliedTokens;
  String? get filterRace => _filterRace;
  String? get filterGender => _filterGender;
  String? get filterCollectionId => _filterCollectionId;
  bool? get filterApplied => _filterApplied;
  List<String> get filterTags => _filterTags;
  List<String> get filterTagsBlacklist => _filterTagsBlacklist;
  Set<CharacterTier> get filterTiers => _filterTiers;
  SortOption get sortOption => _sortOption;
  bool get favouritesOnTop => _favouritesOnTop;
  List<FilterPreset> get savedPresets => _savedPresets;
  bool get persistFilter => _persistFilter;
  bool get matchAll => _matchAll;
  String? get gameFolderPath => _gameFolderPath;
  String? get saveLocation => _saveLocation;

  /// Returns the game-folder-modified timestamp for a character if an update
  /// is detected, otherwise null.
  DateTime? getUpdateTime(String characterId) => _pendingUpdates[characterId];
  bool hasUpdate(String characterId) => _pendingUpdates.containsKey(characterId);
  int get totalUpdatesCount => _pendingUpdates.length;

  bool get hasPendingChanges {
    if (_pendingTokens.length != _appliedTokens.length) return true;
    for (int i = 0; i < _pendingTokens.length; i++) {
      if (_pendingTokens[i] != _appliedTokens[i]) return true;
    }
    return false;
  }

  List<Character> get appliedCharacters =>
      _characters.where((c) => c.isApplied).toList()
        ..sort((a, b) => (a.slotNumber ?? 999).compareTo(b.slotNumber ?? 999));

  int get appliedCount => _characters.where((c) => c.isApplied).length;

  List<Character> get filteredCharacters {
    var list = _characters.where((c) {
      if (_appliedTokens.isNotEmpty) {
        if (_matchAll) {
          // AND — character must match every token by name
          final matchesAll = _appliedTokens.every(
              (token) => c.name.toLowerCase().contains(token.toLowerCase()));
          if (!matchesAll) return false;
        } else {
          // OR — character must match at least one token by name
          final matchesAny = _appliedTokens.any(
              (token) => c.name.toLowerCase().contains(token.toLowerCase()));
          if (!matchesAny) return false;
        }
      }
      if (_filterRace != null && c.race != _filterRace) return false;
      if (_filterGender != null && c.gender != _filterGender) return false;
      if (_filterCollectionId != null &&
          !c.collectionIds.contains(_filterCollectionId)) return false;
      if (_filterApplied != null && c.isApplied != _filterApplied) return false;
      // Tag whitelist — AND: must have all, OR: must have at least one
      if (_filterTags.isNotEmpty) {
        if (_matchAll) {
          if (!_filterTags.every((id) => c.tags.contains(id))) return false;
        } else {
          if (!_filterTags.any((id) => c.tags.contains(id))) return false;
        }
      }
      // Tag blacklist — character must NOT have any of these tags
      if (_filterTagsBlacklist.isNotEmpty) {
        if (_filterTagsBlacklist.any((id) => c.tags.contains(id))) return false;
      }
      // Tier filter — character must match one of the selected tiers
      if (_filterTiers.isNotEmpty) {
        if (c.tier == null || !_filterTiers.contains(c.tier)) return false;
      }
      return true;
    }).toList();
    return _sortedCharacters(list);
  }

  bool get hasActiveFilters =>
      _appliedTokens.isNotEmpty ||
      _filterRace != null ||
      _filterGender != null ||
      _filterCollectionId != null ||
      _filterApplied != null ||
      _filterTags.isNotEmpty ||
      _filterTagsBlacklist.isNotEmpty ||
      _filterTiers.isNotEmpty;

  int get activeFilterCount {
    int n = 0;
    if (_appliedTokens.isNotEmpty) n++;
    if (_filterRace != null) n++;
    if (_filterGender != null) n++;
    if (_filterCollectionId != null) n++;
    if (_filterApplied != null) n++;
    if (_filterTags.isNotEmpty) n += _filterTags.length;
    if (_filterTagsBlacklist.isNotEmpty) n += _filterTagsBlacklist.length;
    if (_filterTiers.isNotEmpty) n += _filterTiers.length;
    return n;
  }

  // ── Sorting ────────────────────────────────────────────────────

  List<Character> _sortedCharacters(List<Character> list) {
    final sorted = List<Character>.from(list);

    int primaryCompare(Character a, Character b) {
      switch (_sortOption) {
        case SortOption.nameAZ:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case SortOption.nameZA:
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        case SortOption.newestFirst:
          return b.createdAt.compareTo(a.createdAt);
        case SortOption.oldestFirst:
          return a.createdAt.compareTo(b.createdAt);
        case SortOption.lastApplied:
          if (a.isApplied && !b.isApplied) return -1;
          if (!a.isApplied && b.isApplied) return 1;
          if (a.isApplied && b.isApplied) {
            return (a.slotNumber ?? 999).compareTo(b.slotNumber ?? 999);
          }
          return b.createdAt.compareTo(a.createdAt);
        case SortOption.tierHighest:
          // S=0 is highest, null=unrated sorts last
          final at = a.tierIndex ?? 999;
          final bt = b.tierIndex ?? 999;
          if (at != bt) return at.compareTo(bt);
          return b.createdAt.compareTo(a.createdAt);
      }
    }

    sorted.sort((a, b) {
      // Favourites on top — checked first, then fall through to primary sort
      // within each group so order within favourites and non-favourites is
      // fully determined by the selected sort option.
      if (_favouritesOnTop) {
        if (a.isFavourite && !b.isFavourite) return -1;
        if (!a.isFavourite && b.isFavourite) return 1;
      }
      return primaryCompare(a, b);
    });

    return sorted;
  }

  void setSortOption(SortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  void setFavouritesOnTop(bool value) {
    _favouritesOnTop = value;
    notifyListeners();
  }

  // ── Init ───────────────────────────────────────────────────────

  Future<void> loadAllAsync() async {
    // Run tag migration first (one-time, safe to re-run)
    await _hive.migrateStringTagsToIds();
    _characters = _hive.getAllCharacters();
    _collections = _hive.getAllCollections();
    _tags = _hive.getAllTags();
    _gameFolderPath = _hive.getGameFolderPath();
    _saveLocation = _hive.getSaveLocation();
    StorageService.init(_saveLocation);
    // Load persist settings
    _persistFilter = _hive.getPersistFilter();
    _loadSavedPresets();
    if (_persistFilter) _restorePersistedFilter();
    notifyListeners();
    _checkForGameFolderUpdates();
    _startSyncTimer();
  }

  void loadAll() {
    _characters = _hive.getAllCharacters();
    _collections = _hive.getAllCollections();
    _tags = _hive.getAllTags();
    _gameFolderPath = _hive.getGameFolderPath();
    _saveLocation = _hive.getSaveLocation();
    StorageService.init(_saveLocation);
    notifyListeners();
    // Run migration async then reload
    _hive.migrateStringTagsToIds().then((_) {
      _characters = _hive.getAllCharacters();
      _tags = _hive.getAllTags();
      notifyListeners();
    });
    _checkForGameFolderUpdates();
  }

  // ── Character CRUD ─────────────────────────────────────────────

  /// Checks if a file name already exists in storage before adding.
  /// Returns the name of the conflicting character, or null if no conflict.
  Future<String?> checkFileConflict(String sourceFilePath) async {
    final conflictFileName =
        await FileService.checkFileNameConflict(sourceFilePath);
    if (conflictFileName == null) return null;
    // Find which character owns this file
    final ownerChar = _characters.firstWhere(
      (c) => c.gameFileName == conflictFileName ||
          c.characterFilePath.endsWith(conflictFileName),
      orElse: () => _characters.firstWhere(
        (c) => p.basename(c.characterFilePath) == conflictFileName,
        orElse: () => throw StateError('no match'),
      ),
    );
    return ownerChar.name;
  }

  Future<void> addCharacter({
    required String name,
    required String sourceFilePath,
    String? sourceThumbnailPath,
    List<String>? tags,
    List<String>? collectionIds,
    String? description,
    /// If provided, the file will be stored under this custom name
    /// but the original PSO2 filename is remembered separately.
    String? customStorageName,
  }) async {
    final originalFileName = p.basename(sourceFilePath);

    // Copy file — use custom name if provided (rename case), else original
    String charFilePath;
    if (customStorageName != null && customStorageName.isNotEmpty) {
      charFilePath = await FileService.copyCharacterFileWithName(
          sourceFilePath, customStorageName);
    } else {
      charFilePath = await FileService.copyCharacterFile(sourceFilePath);
    }

    String? thumbPath;
    if (sourceThumbnailPath != null) {
      thumbPath = await FileService.copyThumbnailFile(sourceThumbnailPath);
    }
    final raceGender = Character.detectRaceGender(sourceFilePath);
    final character = Character(
      id: _uuid.v4(),
      name: name,
      race: raceGender['race']!,
      gender: raceGender['gender']!,
      characterFilePath: charFilePath,
      thumbnailPath: thumbPath,
      tags: tags ?? [],
      collectionIds: collectionIds ?? [],
      collectionId:
          collectionIds?.isNotEmpty == true ? collectionIds!.first : null,
      description: description ?? '',
      originalFileName: originalFileName,
      lastSyncedAt: DateTime.now(),
    );
    await _hive.addCharacter(character);
    _characters = _hive.getAllCharacters();
    notifyListeners();
  }

  /// Replace an existing character's file with a new source file.
  /// Used when user chooses "Replace existing" in the conflict dialog.
  Future<void> replaceCharacterFile(
      Character existingChar, String newSourcePath) async {
    await FileService.replaceCharacterFile(
        newSourcePath, existingChar.characterFilePath);
    existingChar.originalFileName = p.basename(newSourcePath);
    existingChar.lastSyncedAt = DateTime.now();
    await existingChar.save();
    _characters = _hive.getAllCharacters();
    // Clear any pending update for this character
    _pendingUpdates.remove(existingChar.id);
    notifyListeners();
  }

  Future<void> importLocalFile({
    required String name,
    required String localFilePath,
    String? sourceThumbnailPath,
    List<String>? tags,
    List<String>? collectionIds,
    String? description,
  }) async {
    // Copy the file into app storage (same as addCharacter) so
    // characterFilePath points to our managed folder, not the game folder.
    final charFilePath = await FileService.copyCharacterFile(localFilePath);

    String? thumbPath;
    if (sourceThumbnailPath != null) {
      thumbPath = await FileService.copyThumbnailFile(sourceThumbnailPath);
    }
    final raceGender = Character.detectRaceGender(localFilePath);
    final character = Character(
      id: _uuid.v4(),
      name: name,
      race: raceGender['race']!,
      gender: raceGender['gender']!,
      characterFilePath: charFilePath,
      thumbnailPath: thumbPath,
      tags: tags ?? [],
      collectionIds: collectionIds ?? [],
      collectionId:
          collectionIds?.isNotEmpty == true ? collectionIds!.first : null,
      description: description ?? '',
      isApplied: true,
      originalFileName: p.basename(localFilePath),
      lastSyncedAt: DateTime.now(),
    );
    await _hive.addCharacter(character);
    _characters = _hive.getAllCharacters();
    notifyListeners();
  }

  Future<void> updateCharacter(Character character) async {
    await _hive.updateCharacter(character);
    _characters = _hive.getAllCharacters();
    notifyListeners();
  }

  Future<void> toggleFavourite(Character character) async {
    character.isFavourite = !character.isFavourite;
    await character.save();
    _characters = _hive.getAllCharacters();
    notifyListeners();
  }

  Future<void> setTier(Character character, CharacterTier? tier) async {
    character.tier = tier;
    await character.save();
    _characters = _hive.getAllCharacters();
    notifyListeners();
  }

  Future<void> deleteCharacter(Character character) async {
    if (character.isApplied && _gameFolderPath != null) {
      await _removeFromGameFolder(character);
    }
    await FileService.deleteFile(character.characterFilePath);
    // Use safe helper — only deletes if the file is inside our thumbnails folder
    await FileService.deleteThumbnailIfOwned(character.thumbnailPath);
    // Delete all gallery items for this character
    final galleryItems = _hive.getGalleryItemsForCharacter(character.id);
    for (final item in galleryItems) {
      await FileService.deleteGalleryFileIfOwned(item.filePath);
    }
    await _hive.deleteAllGalleryItemsForCharacter(character.id);
    _pendingUpdates.remove(character.id);
    await _hive.deleteCharacter(character.id);
    _characters = _hive.getAllCharacters();
    notifyListeners();
  }

  // ── Gallery ────────────────────────────────────────────────────

  List<GalleryItem> getGalleryItems(String characterId) =>
      _hive.getGalleryItemsForCharacter(characterId);

  List<GalleryItem> getAllGalleryItems() => _hive.getAllGalleryItems();

  Future<GalleryItem?> addGalleryItem(String characterId, String sourcePath) async {
    try {
      final storedPath = await FileService.copyGalleryFile(sourcePath);
      final item = GalleryItem(
        id: _uuid.v4(),
        characterId: characterId,
        filePath: storedPath,
      );
      await _hive.addGalleryItem(item);
      notifyListeners();
      return item;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteGalleryItem(GalleryItem item) async {
    await FileService.deleteGalleryFileIfOwned(item.filePath);
    await _hive.deleteGalleryItem(item.id);
    notifyListeners();
  }

  // ── Tags ────────────────────────────────────────────────────

  Future<Tag> createTag(String name, Color color) async {
    final tag = Tag(
      id: _uuid.v4(),
      name: name.trim(),
      colorValue: color.toARGB32(),
    );
    await _hive.addTag(tag);
    _tags = _hive.getAllTags();
    notifyListeners();
    return tag;
  }

  Future<void> updateTag(Tag tag, {String? name, Color? color}) async {
    if (name != null) tag.name = name.trim();
    if (color != null) tag.colorValue = color.toARGB32();
    await _hive.updateTag(tag);
    _tags = _hive.getAllTags();
    notifyListeners();
  }

  Future<void> deleteTag(Tag tag) async {
    await _hive.deleteTag(tag.id);
    _tags = _hive.getAllTags();
    _characters = _hive.getAllCharacters(); // tags removed from characters
    notifyListeners();
  }

  /// How many characters use a given tag id.
  int tagUsageCount(String tagId) =>
      _characters.where((c) => c.tags.contains(tagId)).length;

  /// Removes a character's thumbnail — deletes the file from disk and clears
  /// the path in the model. Safe to call even if thumbnailPath is null.
  Future<void> removeCharacterThumbnail(Character character) async {
    await FileService.deleteThumbnailIfOwned(character.thumbnailPath);
    character.thumbnailPath = null;
    await character.save();
    _characters = _hive.getAllCharacters();
    notifyListeners();
  }

  /// Replaces a character's thumbnail with a new image file.
  /// Deletes the old thumbnail from disk before copying the new one.
  Future<void> updateCharacterThumbnail(Character character, String newSourcePath) async {
    await FileService.deleteThumbnailIfOwned(character.thumbnailPath);
    final newPath = await FileService.copyThumbnailFile(newSourcePath);
    character.thumbnailPath = newPath;
    await character.save();
    _characters = _hive.getAllCharacters();
    notifyListeners();
  }

  /// Removes a collection's thumbnail — deletes the file from disk and clears
  /// the path in the model.
  Future<void> removeCollectionThumbnail(Collection collection) async {
    await FileService.deleteThumbnailIfOwned(collection.thumbnailPath);
    collection.thumbnailPath = null;
    await collection.save();
    _collections = _hive.getAllCollections();
    notifyListeners();
  }

  /// Replaces a collection's thumbnail with a new image file.
  /// Deletes the old thumbnail from disk before copying the new one.
  Future<void> updateCollectionThumbnail(Collection collection, String newSourcePath) async {
    await FileService.deleteThumbnailIfOwned(collection.thumbnailPath);
    final newPath = await FileService.copyThumbnailFile(newSourcePath);
    collection.thumbnailPath = newPath;
    await collection.save();
    _collections = _hive.getAllCollections();
    notifyListeners();
  }

  // ── Apply / Unapply ────────────────────────────────────────────

  Future<String?> toggleApply(Character character) async {
    if (character.isApplied) {
      return await _unapplyCharacter(character);
    } else {
      return await _applyCharacter(character);
    }
  }

  Future<String?> _applyCharacter(Character character) async {
    if (appliedCount >= 50) {
      return 'Slot limit reached (50/50). Remove a character first.';
    }
    final usedSlots =
        appliedCharacters.map((c) => c.slotNumber ?? 0).toSet();
    int slot = 1;
    while (usedSlots.contains(slot)) slot++;

    if (_gameFolderPath != null) {
      try {
        // Always use gameFileName (originalFileName) when copying to game folder
        final dest = p.join(_gameFolderPath!, character.gameFileName);
        await File(character.characterFilePath).copy(dest);
      } catch (e) {
        return 'Could not copy to game folder: $e';
      }
    }

    character.isApplied = true;
    character.slotNumber = slot;
    character.lastSyncedAt = DateTime.now();
    await character.save();
    _characters = _hive.getAllCharacters();
    // Clear any pending update since we just synced
    _pendingUpdates.remove(character.id);
    notifyListeners();
    return null;
  }

  Future<String?> _unapplyCharacter(Character character) async {
    if (_gameFolderPath != null) await _removeFromGameFolder(character);
    character.isApplied = false;
    character.slotNumber = null;
    await character.save();
    _characters = _hive.getAllCharacters();
    notifyListeners();
    return null;
  }

  Future<void> _removeFromGameFolder(Character character) async {
    try {
      if (_gameFolderPath == null) return;
      // Use gameFileName so we remove the correct file
      final dest = p.join(_gameFolderPath!, character.gameFileName);
      final file = File(dest);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  // ── Game folder update detection ───────────────────────────────

  /// Checks all applied characters to see if the game folder has newer files.
  /// Runs silently in the background on startup and can be triggered manually.
  Future<void> _checkForGameFolderUpdates() async {
    if (_gameFolderPath == null) return;
    _pendingUpdates.clear();
    bool changed = false;

    for (final char in _characters) {
      final updateTime = await FileService.checkForGameFolderUpdate(
        char.characterFilePath,
        _gameFolderPath!,
        char.gameFileName,
      );
      if (updateTime != null) {
        _pendingUpdates[char.id] = updateTime;
        changed = true;
      }
    }

    if (changed) notifyListeners();
  }

  /// Starts a periodic timer that rechecks the game folder every 30 seconds.
  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkForGameFolderUpdates();
    });
  }

  /// Manually trigger an update check (e.g. user pulls to refresh)
  Future<void> checkForUpdates() async {
    await _checkForGameFolderUpdates();
    _startSyncTimer(); // reset the timer cycle after manual check
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  /// Sync a character's file from the game folder back into the library.
  /// Returns null on success, error string on failure.
  Future<String?> syncCharacterFromGameFolder(Character character) async {
    if (_gameFolderPath == null) {
      return 'Game folder path not set.';
    }
    final error = await FileService.syncFromGameFolder(
      _gameFolderPath!,
      character.gameFileName,
      character.characterFilePath,
    );
    if (error != null) return error;

    character.lastSyncedAt = DateTime.now();
    await character.save();
    _pendingUpdates.remove(character.id);
    _characters = _hive.getAllCharacters();
    notifyListeners();
    return null;
  }

  /// Dismiss an update notification without syncing
  void dismissUpdate(String characterId) {
    _pendingUpdates.remove(characterId);
    notifyListeners();
  }

  // ── Share / Export ─────────────────────────────────────────────

  Future<String?> exportCharacterFile(
      Character character, String destPath) async {
    try {
      await FileService.exportCharacterFile(
          character.characterFilePath, destPath);
      return null;
    } catch (e) {
      return 'Export failed: $e';
    }
  }

  /// Export a character as a .pso2char bundle.
  Future<String?> exportBundle({
    required Character character,
    required String destPath,
    required ExportOptions options,
  }) async {
    final galleryItems = _hive.getGalleryItemsForCharacter(character.id);
    return ShareService.exportBundle(
      character: character,
      galleryItems: galleryItems,
      destPath: destPath,
      options: options,
    );
  }

  /// Estimate bundle size without writing to disk.
  Future<int> estimateBundleSize({
    required Character character,
    required ExportOptions options,
  }) async {
    final galleryItems = _hive.getGalleryItemsForCharacter(character.id);
    return ShareService.estimateBundleSize(
      character: character,
      galleryItems: galleryItems,
      options: options,
    );
  }

  /// Import a character from a .pso2char bundle.
  Future<String?> importBundle({
    required BundlePreview preview,
    required String characterName,
    String? customFileName,
  }) async {
    try {
      final charsDir = await StorageService.charactersDir;
      final thumbsDir = await StorageService.thumbnailsDir;
      final galleryDir = await StorageService.galleryDir;

      final result = await ShareService.extractBundle(
        bundleBytes: preview.bundleBytes,
        charactersDir: charsDir,
        thumbnailsDir: thumbsDir,
        galleryDir: galleryDir,
        customFileName: customFileName,
      );
      if (result == null) return 'Failed to extract bundle';

      final raceGender =
          Character.detectRaceGender(result.characterFilePath);
      final character = Character(
        id: _uuid.v4(),
        name: characterName,
        race: raceGender['race']!,
        gender: raceGender['gender']!,
        characterFilePath: result.characterFilePath,
        thumbnailPath: result.thumbnailPath,
        originalFileName: result.originalFileName,
        description: preview.description ?? '',
        lastSyncedAt: DateTime.now(),
      );
      await _hive.addCharacter(character);

      for (final path in result.galleryPaths) {
        final item = GalleryItem(
          id: _uuid.v4(),
          characterId: character.id,
          filePath: path,
        );
        await _hive.addGalleryItem(item);
      }

      _characters = _hive.getAllCharacters();
      notifyListeners();
      return null;
    } catch (e) {
      return 'Import failed: $e';
    }
  }

  // ── Scan game folder ───────────────────────────────────────────

  Future<List<String>> scanGameFolderForUnregistered() async {
    if (_gameFolderPath == null) return [];
    final registered =
        _characters.map((c) => c.gameFileName).toSet();
    return FileService.scanForUnregisteredFiles(_gameFolderPath!, registered);
  }

  // ── Collection CRUD ────────────────────────────────────────────

  Future<void> addCollection(String name, {
    String? thumbnailPath,
    String description = '',
    int? accentColorValue,
  }) async {
    final collection = Collection(
      id: _uuid.v4(),
      name: name,
      thumbnailPath: thumbnailPath,
      description: description,
      accentColorValue: accentColorValue,
    );
    await _hive.addCollection(collection);
    _collections = _hive.getAllCollections();
    notifyListeners();
  }

  Future<void> updateCollection(Collection collection) async {
    await _hive.updateCollection(collection);
    _collections = _hive.getAllCollections();
    notifyListeners();
  }

  Future<void> deleteCollection(String id) async {
    await _hive.deleteCollection(id);
    _characters = _hive.getAllCharacters();
    _collections = _hive.getAllCollections();
    notifyListeners();
  }

  int getCharacterCountForCollection(String collectionId) =>
      _characters.where((c) => c.collectionIds.contains(collectionId)).length;

  List<Character> getCharactersForCollection(String collectionId) =>
      _characters
          .where((c) => c.collectionIds.contains(collectionId))
          .toList();

  List<Character> sortedCharactersForCollection(
      String collectionId, SortOption option, bool favouritesOnTop) {
    final list = _characters
        .where((c) => c.collectionIds.contains(collectionId))
        .toList();
    final sorted = List<Character>.from(list);
    sorted.sort((a, b) {
      if (favouritesOnTop) {
        if (a.isFavourite && !b.isFavourite) return -1;
        if (!a.isFavourite && b.isFavourite) return 1;
      }
      switch (option) {
        case SortOption.nameAZ:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case SortOption.nameZA:
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        case SortOption.newestFirst:
          return b.createdAt.compareTo(a.createdAt);
        case SortOption.oldestFirst:
          return a.createdAt.compareTo(b.createdAt);
        case SortOption.lastApplied:
          if (a.isApplied && !b.isApplied) return -1;
          if (!a.isApplied && b.isApplied) return 1;
          return b.createdAt.compareTo(a.createdAt);
        case SortOption.tierHighest:
          final at = a.tierIndex ?? 999;
          final bt = b.tierIndex ?? 999;
          if (at != bt) return at.compareTo(bt);
          return b.createdAt.compareTo(a.createdAt);
      }
    });
    return sorted;
  }

  // ── Save location ──────────────────────────────────────────────

  Future<void> setGameFolderPath(String path) async {
    _gameFolderPath = path;
    await _hive.saveGameFolderPath(path);
    notifyListeners();
    // Re-check for updates with new path
    _checkForGameFolderUpdates();
  }

  Future<String?> changeSaveLocation(
    String newPath, {
    bool migrateFiles = true,
    void Function(int done, int total)? onProgress,
  }) async {
    try {
      if (migrateFiles && _saveLocation != null) {
        final oldRoot = _saveLocation!;
        final pathMap = await StorageService.migrateFiles(
          oldRoot: oldRoot,
          newRoot: newPath,
          onProgress: onProgress ?? (_, __) {},
        );
        await _hive.migrateCharacterPaths(pathMap);
      }
      _saveLocation = newPath;
      StorageService.setPath(newPath);
      await _hive.saveSaveLocation(newPath);
      _characters = _hive.getAllCharacters();
      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to change save location: $e';
    }
  }

  // ── Search & Filter ────────────────────────────────────────────

  void addPendingToken(String token) {
    final t = token.trim();
    if (t.isEmpty || _pendingTokens.contains(t)) return;
    _pendingTokens = [..._pendingTokens, t];
    notifyListeners();
  }

  void removePendingToken(String token) {
    _pendingTokens = _pendingTokens.where((t) => t != token).toList();
    notifyListeners();
  }

  void applySearch() {
    _appliedTokens = List.from(_pendingTokens);
    notifyListeners();
    if (_persistFilter) _persistCurrentFilter();
  }

  void clearTokens() {
    _pendingTokens = [];
    _appliedTokens = [];
    notifyListeners();
  }

  void setFilterRace(String? race) {
    _filterRace = (_filterRace == race) ? null : race;
    notifyListeners();
    if (_persistFilter) _persistCurrentFilter();
  }

  void setFilterGender(String? gender) {
    _filterGender = (_filterGender == gender) ? null : gender;
    notifyListeners();
    if (_persistFilter) _persistCurrentFilter();
  }

  void setFilterCollection(String? collectionId) {
    _filterCollectionId = collectionId;
    notifyListeners();
  }

  void setFilterApplied(bool? value) {
    _filterApplied = (_filterApplied == value) ? null : value;
    notifyListeners();
    if (_persistFilter) _persistCurrentFilter();
  }

  void toggleFilterTag(String tag) {
    if (_filterTags.contains(tag)) {
      _filterTags = _filterTags.where((t) => t != tag).toList();
    } else {
      _filterTags = [..._filterTags, tag];
      // Remove from blacklist if added to whitelist
      _filterTagsBlacklist =
          _filterTagsBlacklist.where((t) => t != tag).toList();
    }
    notifyListeners();
    if (_persistFilter) _persistCurrentFilter();
  }

  void toggleFilterTagBlacklist(String tag) {
    if (_filterTagsBlacklist.contains(tag)) {
      _filterTagsBlacklist =
          _filterTagsBlacklist.where((t) => t != tag).toList();
    } else {
      _filterTagsBlacklist = [..._filterTagsBlacklist, tag];
      // Remove from whitelist if added to blacklist
      _filterTags = _filterTags.where((t) => t != tag).toList();
    }
    notifyListeners();
    if (_persistFilter) _persistCurrentFilter();
  }

  void toggleFilterTier(CharacterTier tier) {
    if (_filterTiers.contains(tier)) {
      _filterTiers = {..._filterTiers}..remove(tier);
    } else {
      _filterTiers = {..._filterTiers, tier};
    }
    notifyListeners();
    if (_persistFilter) _persistCurrentFilter();
  }

  void setMatchAll(bool value) {
    _matchAll = value;
    notifyListeners();
  }

  void setFilterTags(List<String> tags) {
    _filterTags = tags;
    notifyListeners();
  }

  void clearAllFilters() {
    _pendingTokens = [];
    _appliedTokens = [];
    _filterRace = null;
    _filterGender = null;
    _filterCollectionId = null;
    _filterApplied = null;
    _filterTags = [];
    _filterTagsBlacklist = [];
    _filterTiers = {};
    notifyListeners();
    if (_persistFilter) _hive.savePersistedFilter(null);
  }

  // ── Persist filter ─────────────────────────────────────

  Future<void> setPersistFilter(bool value) async {
    _persistFilter = value;
    await _hive.savePersistFilter(value);
    if (!value) await _hive.savePersistedFilter(null);
    notifyListeners();
  }

  void _persistCurrentFilter() {
    if (!_persistFilter) return;
    final state = {
      'tokens': _appliedTokens,
      'race': _filterRace,
      'gender': _filterGender,
      'applied': _filterApplied,
      'tagIds': _filterTags,
      'tierIndices': _filterTiers.map((t) => t.index).toList(),
    };
    _hive.savePersistedFilter(jsonEncode(state));
  }

  void _restorePersistedFilter() {
    final raw = _hive.getPersistedFilter();
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _appliedTokens = (j['tokens'] as List?)?.cast<String>() ?? [];
      _pendingTokens = List.from(_appliedTokens);
      _filterRace = j['race'] as String?;
      _filterGender = j['gender'] as String?;
      _filterApplied = j['applied'] as bool?;
      _filterTags = (j['tagIds'] as List?)?.cast<String>() ?? [];
      final ti = (j['tierIndices'] as List?)?.cast<int>() ?? [];
      _filterTiers = ti.map((i) => CharacterTier.values[i]).toSet();
    } catch (_) {}
  }

  // ── Saved presets ────────────────────────────────────────

  void _loadSavedPresets() {
    final raw = _hive.getSavedPresets();
    if (raw == null) { _savedPresets = []; return; }
    try {
      final list = jsonDecode(raw) as List;
      _savedPresets = list
          .map((e) => FilterPreset.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) { _savedPresets = []; }
  }

  Future<void> _persistPresets() async {
    await _hive.saveSavedPresets(
        jsonEncode(_savedPresets.map((p) => p.toJson()).toList()));
  }

  /// Save current active filter as a named preset.
  Future<void> saveCurrentAsPreset(String name, Color color) async {
    final preset = FilterPreset(
      id: const Uuid().v4(),
      name: name,
      colorValue: color.toARGB32(),
      tokens: List.from(_appliedTokens),
      race: _filterRace,
      gender: _filterGender,
      applied: _filterApplied,
      tagIds: List.from(_filterTags),
      tierIndices: _filterTiers.map((t) => t.index).toList(),
    );
    _savedPresets = [..._savedPresets, preset];
    await _persistPresets();
    notifyListeners();
  }

  /// Apply a saved preset as the active filter.
  void applyPreset(FilterPreset preset) {
    _appliedTokens = List.from(preset.tokens);
    _pendingTokens = List.from(preset.tokens);
    _filterRace = preset.race;
    _filterGender = preset.gender;
    _filterApplied = preset.applied;
    _filterTags = List.from(preset.tagIds);
    _filterTiers = preset.tierIndices
        .map((i) => CharacterTier.values[i])
        .toSet();
    notifyListeners();
    if (_persistFilter) _persistCurrentFilter();
  }

  /// Delete a saved preset by id.
  Future<void> deletePreset(String id) async {
    _savedPresets = _savedPresets.where((p) => p.id != id).toList();
    await _persistPresets();
    notifyListeners();
  }

  void setSearch(String query) => notifyListeners();
  String get searchQuery => _appliedTokens.join(' ');
}
