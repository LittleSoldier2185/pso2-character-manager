import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/character_data.dart';
import '../models/collection_data.dart';
import '../models/gallery_data.dart';
import '../models/tag_data.dart';
import '../services/data_service.dart';
import '../services/share_service.dart';

// ── Filter preset ─────────────────────────────────────────────────

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

// ── Sort options ──────────────────────────────────────────────────

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
      case SortOption.newestFirst: return 'Newest first';
      case SortOption.oldestFirst: return 'Oldest first';
      case SortOption.lastApplied: return 'Last applied';
      case SortOption.tierHighest: return 'Tier (S first)';
    }
  }

  IconData get icon {
    switch (this) {
      case SortOption.nameAZ:      return Icons.sort_by_alpha_rounded;
      case SortOption.nameZA:      return Icons.sort_by_alpha_rounded;
      case SortOption.newestFirst: return Icons.schedule_rounded;
      case SortOption.oldestFirst: return Icons.history_rounded;
      case SortOption.lastApplied: return Icons.check_circle_outline_rounded;
      case SortOption.tierHighest: return Icons.military_tech_rounded;
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────

class CharacterProvider extends ChangeNotifier {
  DataService get _data => DataService.instance;
  final _uuid = const Uuid();

  List<CharacterData>   _characters   = [];
  List<CollectionData>  _collections  = [];
  List<TagData>         _tags         = [];

  // characterId → gallery items (in-memory cache)
  final Map<String, List<GalleryItemData>> _galleryCache = {};

  // Game folder update detection: characterId → { variantFolderName → gameModified }
  final Map<String, Map<String, DateTime>> _pendingUpdates = {};
  Timer? _syncTimer;

  // Filter state
  List<String> _pendingTokens       = [];
  List<String> _appliedTokens       = [];
  String? _filterRace;
  String? _filterGender;
  String? _filterCollectionId;
  bool?   _filterApplied;
  List<String> _filterTags          = [];
  List<String> _filterTagsBlacklist = [];
  Set<CharacterTier> _filterTiers   = {};
  SortOption _sortOption            = SortOption.newestFirst;
  bool _favouritesOnTop             = true;

  List<FilterPreset> _savedPresets = [];
  bool _matchAll       = true;
  bool _persistFilter  = false;

  String? _gameFolderPath;
  String? _saveLocation;

  bool _isLoading = false;

  // ── Getters ───────────────────────────────────────────────────────

  bool get isLoading => _isLoading;

  List<CharacterData>  get allCharacters  => _sortedCharacters(_characters);
  List<CollectionData> get allCollections => _collections;
  List<TagData>        get allTags        => _tags;

  TagData? tagById(String id) {
    try { return _tags.firstWhere((t) => t.id == id); } catch (_) { return null; }
  }

  List<String> get pendingTokens        => _pendingTokens;
  List<String> get appliedTokens        => _appliedTokens;
  String?      get filterRace           => _filterRace;
  String?      get filterGender         => _filterGender;
  String?      get filterCollectionId   => _filterCollectionId;
  bool?        get filterApplied        => _filterApplied;
  List<String> get filterTags           => _filterTags;
  List<String> get filterTagsBlacklist  => _filterTagsBlacklist;
  Set<CharacterTier> get filterTiers    => _filterTiers;
  SortOption   get sortOption           => _sortOption;
  bool         get favouritesOnTop      => _favouritesOnTop;
  List<FilterPreset> get savedPresets   => _savedPresets;
  bool         get persistFilter        => _persistFilter;
  bool         get matchAll             => _matchAll;
  String?      get gameFolderPath       => _gameFolderPath;
  String?      get saveLocation         => _saveLocation;

  Map<String, DateTime> getVariantUpdateTimes(String characterId) =>
      _pendingUpdates[characterId] ?? {};
  bool hasUpdate(String characterId) => _pendingUpdates.containsKey(characterId);
  int get totalUpdatesCount =>
      _pendingUpdates.values.fold(0, (sum, m) => sum + m.length);

  List<CharacterData> get charactersWithUpdates =>
      _characters.where((c) => _pendingUpdates.containsKey(c.id)).toList();

  bool get hasPendingChanges {
    if (_pendingTokens.length != _appliedTokens.length) return true;
    for (int i = 0; i < _pendingTokens.length; i++) {
      if (_pendingTokens[i] != _appliedTokens[i]) return true;
    }
    return false;
  }

  List<CharacterData> get appliedCharacters =>
      _characters.where((c) => c.isApplied).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  int get appliedCount => _characters.where((c) => c.isApplied).length;

  List<CharacterData> get filteredCharacters {
    var list = _characters.where((c) {
      if (_appliedTokens.isNotEmpty) {
        if (_matchAll) {
          if (!_appliedTokens.every((t) =>
              c.name.toLowerCase().contains(t.toLowerCase()))) return false;
        } else {
          if (!_appliedTokens.any((t) =>
              c.name.toLowerCase().contains(t.toLowerCase()))) return false;
        }
      }
      if (_filterRace != null && c.race != _filterRace) return false;
      if (_filterGender != null && c.gender != _filterGender) return false;
      if (_filterCollectionId != null &&
          !c.collectionIds.contains(_filterCollectionId)) return false;
      if (_filterApplied != null && c.isApplied != _filterApplied) return false;
      if (_filterTags.isNotEmpty) {
        if (_matchAll) {
          if (!_filterTags.every((id) => c.tags.contains(id))) return false;
        } else {
          if (!_filterTags.any((id) => c.tags.contains(id))) return false;
        }
      }
      if (_filterTagsBlacklist.isNotEmpty) {
        if (_filterTagsBlacklist.any((id) => c.tags.contains(id))) return false;
      }
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
    if (_appliedTokens.isNotEmpty)       n++;
    if (_filterRace != null)             n++;
    if (_filterGender != null)           n++;
    if (_filterCollectionId != null)     n++;
    if (_filterApplied != null)          n++;
    n += _filterTags.length;
    n += _filterTagsBlacklist.length;
    n += _filterTiers.length;
    return n;
  }

  // ── Sorting ───────────────────────────────────────────────────────

  List<CharacterData> _sortedCharacters(List<CharacterData> list) {
    final sorted = List<CharacterData>.from(list);

    int primaryCompare(CharacterData a, CharacterData b) {
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
            final at = a.lastSyncedAt ?? a.createdAt;
            final bt = b.lastSyncedAt ?? b.createdAt;
            return bt.compareTo(at);
          }
          return b.createdAt.compareTo(a.createdAt);
        case SortOption.tierHighest:
          final at = a.tierIndex ?? 999;
          final bt = b.tierIndex ?? 999;
          if (at != bt) return at.compareTo(bt);
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    }

    sorted.sort((a, b) {
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
    _data.saveSortOption(option.name);
  }

  void setFavouritesOnTop(bool value) {
    _favouritesOnTop = value;
    notifyListeners();
  }

  // ── Init ──────────────────────────────────────────────────────────

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();

    final settings = await _data.getSettings();
    _gameFolderPath = settings.gameFolderPath;
    _saveLocation   = settings.saveLocation;
    _persistFilter  = settings.persistFilter;
    if (settings.sortOption != null) {
      _sortOption = SortOption.values.byName(settings.sortOption!);
    }

    _characters  = await _data.getAllCharacters();
    _collections = await _data.getAllCollections();
    _tags        = await _data.getAllTags();

    // Pre-load gallery cache
    for (final c in _characters) {
      _galleryCache[c.id] = await _data.getGalleryItems(c);
    }

    await _loadSavedPresets();
    if (_persistFilter) await _restorePersistedFilter();

    _isLoading = false;
    notifyListeners();
    _checkForGameFolderUpdates();
    _startSyncTimer();
  }

  // ── Character CRUD ────────────────────────────────────────────────

  Future<String?> checkFileConflict(String sourceFilePath) async {
    final fileName = p.basename(sourceFilePath);
    for (final c in _characters) {
      if (c.originalFileName == fileName || c.gameFileName == fileName) {
        return c.name;
      }
    }
    return null;
  }

  Future<void> addCharacter({
    required String name,
    required String sourceFilePath,
    String? sourceThumbnailPath,
    List<String>? tags,
    List<String>? collectionIds,
    String? description,
    String? customStorageName,
  }) async {
    final id             = _uuid.v4();
    final raceGender     = CharacterData.detectRaceGender(sourceFilePath);
    final originalFileName = p.basename(sourceFilePath);
    final variantName    = _sanitize(customStorageName ?? name);

    final character = await _data.createCharacterFolder(
      id: id,
      name: name,
      race: raceGender['race']!,
      gender: raceGender['gender']!,
      variantFolderName: variantName,
      variantDisplayName: name,
      description: description ?? '',
      tags: tags,
      collectionIds: collectionIds,
      originalFileName: originalFileName,
    );

    // Copy character file into variant folder
    final ext = p.extension(sourceFilePath);
    final targetFileName = customStorageName != null
        ? '$customStorageName$ext'
        : originalFileName;
    await _data.copyFileToVariant(
      characterFolderPath: character.folderPath,
      variantFolderName: variantName,
      sourcePath: sourceFilePath,
      targetFileName: targetFileName,
    );

    // Copy thumbnail
    if (sourceThumbnailPath != null) {
      await _data.copyThumbnailToVariant(
        characterFolderPath: character.folderPath,
        variantFolderName: variantName,
        sourcePath: sourceThumbnailPath,
      );
    }

    character.mainVariantData!.lastSyncedAt = DateTime.now();
    await _data.saveCharacter(character);

    _characters.add(character);
    _galleryCache[character.id] = [];
    notifyListeners();
  }

  Future<void> replaceCharacterFile(
      CharacterData character, String newSourcePath) async {
    // Backup existing file before replacing
    await _data.backupVariant(
      character: character,
      variantFolderName: character.mainVariant,
      source: 'manual_replace',
    );

    final variantFolder =
        p.join(character.folderPath, character.mainVariant);
    final existingFile = character.characterFilePath;
    if (existingFile != null) {
      await File(newSourcePath).copy(existingFile);
    } else {
      // No existing file — copy with original filename
      final fileName = p.basename(newSourcePath);
      await _data.copyFileToVariant(
        characterFolderPath: character.folderPath,
        variantFolderName: character.mainVariant,
        sourcePath: newSourcePath,
        targetFileName: fileName,
      );
    }

    character.mainVariantData!.originalFileName = p.basename(newSourcePath);
    character.mainVariantData!.lastSyncedAt = DateTime.now();
    _pendingUpdates.remove(character.id);
    await _data.saveCharacter(character);
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
    final id = _uuid.v4();
    final raceGender = CharacterData.detectRaceGender(localFilePath);
    final originalFileName = p.basename(localFilePath);
    final variantName = _sanitize(name);

    final character = await _data.createCharacterFolder(
      id: id,
      name: name,
      race: raceGender['race']!,
      gender: raceGender['gender']!,
      variantFolderName: variantName,
      variantDisplayName: name,
      description: description ?? '',
      tags: tags,
      collectionIds: collectionIds,
      originalFileName: originalFileName,
    );

    await _data.copyFileToVariant(
      characterFolderPath: character.folderPath,
      variantFolderName: variantName,
      sourcePath: localFilePath,
      targetFileName: originalFileName,
    );

    if (sourceThumbnailPath != null) {
      await _data.copyThumbnailToVariant(
        characterFolderPath: character.folderPath,
        variantFolderName: variantName,
        sourcePath: sourceThumbnailPath,
      );
    }

    character.appliedVariants = [variantName];
    character.mainVariantData!.lastSyncedAt = DateTime.now();
    await _data.saveCharacter(character);

    _characters.add(character);
    _galleryCache[character.id] = [];
    notifyListeners();
  }

  Future<void> updateCharacter(CharacterData character) async {
    await _data.saveCharacter(character);
    final idx = _characters.indexWhere((c) => c.id == character.id);
    if (idx != -1) _characters[idx] = character;
    notifyListeners();
  }

  Future<void> toggleFavourite(CharacterData character) async {
    character.isFavourite = !character.isFavourite;
    await _data.saveCharacter(character);
    notifyListeners();
  }

  Future<void> setTier(CharacterData character, CharacterTier? tier) async {
    character.tier = tier;
    await _data.saveCharacter(character);
    notifyListeners();
  }

  Future<void> deleteCharacter(CharacterData character) async {
    if (character.isApplied && _gameFolderPath != null) {
      await _removeFromGameFolder(character);
    }
    await _data.deleteCharacter(character);
    _pendingUpdates.remove(character.id);
    _galleryCache.remove(character.id);
    _characters.removeWhere((c) => c.id == character.id);
    notifyListeners();
  }

  // ── Thumbnail ─────────────────────────────────────────────────────

  Future<void> removeCharacterThumbnail(CharacterData character) async {
    final thumbPath = character.thumbnailForVariant(character.mainVariant);
    if (thumbPath != null) {
      final f = File(thumbPath);
      if (await f.exists()) await f.delete();
    }
    character.staticThumbnailFileName = null;
    character.thumbnailMode = thumbnailModeFollow;
    await _data.saveCharacter(character);
    notifyListeners();
  }

  Future<void> updateCharacterThumbnail(
      CharacterData character, String newSourcePath) async {
    // Remove old thumbnail for main variant
    final oldThumb = character.thumbnailForVariant(character.mainVariant);
    if (oldThumb != null) {
      final f = File(oldThumb);
      if (await f.exists()) await f.delete();
    }
    await _data.copyThumbnailToVariant(
      characterFolderPath: character.folderPath,
      variantFolderName: character.mainVariant,
      sourcePath: newSourcePath,
    );
    notifyListeners();
  }

  Future<void> setThumbnailMode(
      CharacterData character, String mode,
      {String? staticSourcePath}) async {
    character.thumbnailMode = mode;
    if (mode == thumbnailModeStatic && staticSourcePath != null) {
      final fileName = await _data.copyStaticThumbnail(
        character: character,
        sourcePath: staticSourcePath,
      );
      character.staticThumbnailFileName = fileName;
    } else if (mode == thumbnailModeFollow) {
      character.staticThumbnailFileName = null;
    }
    await _data.saveCharacter(character);
    notifyListeners();
  }

  // ── Collection thumbnail ──────────────────────────────────────────

  Future<void> removeCollectionThumbnail(CollectionData collection) async {
    if (collection.thumbnailPath != null) {
      final f = File(collection.thumbnailPath!);
      if (await f.exists()) await f.delete();
    }
    collection.thumbnailPath = null;
    _collections = List.from(_collections);
    await _data.saveCollections(_collections);
    notifyListeners();
  }

  Future<void> updateCollectionThumbnail(
      CollectionData collection, String newSourcePath) async {
    if (collection.thumbnailPath != null) {
      final f = File(collection.thumbnailPath!);
      if (await f.exists()) await f.delete();
    }
    final ext = p.extension(newSourcePath);
    final dest = p.join(
        p.dirname(newSourcePath),
        '${DateTime.now().millisecondsSinceEpoch}$ext');
    await File(newSourcePath).copy(dest);
    collection.thumbnailPath = dest;
    await _data.saveCollections(_collections);
    notifyListeners();
  }

  // ── Apply / Unapply ───────────────────────────────────────────────

  Future<String?> toggleApply(CharacterData character) async {
    if (character.isApplied) {
      return _unapplyCharacter(character);
    } else {
      return _applyCharacter(character, character.mainVariant);
    }
  }

  Future<String?> applyVariant(
      CharacterData character, String variantFolderName) async {
    return _applyCharacter(character, variantFolderName);
  }

  Future<String?> _applyCharacter(
      CharacterData character, String variantFolderName) async {
    if (_gameFolderPath != null) {
      try {
        final variant = character.variants
            .firstWhere((v) => v.folderName == variantFolderName);
        final charFile =
            character.charFileForVariant(variantFolderName);
        if (charFile == null) {
          return 'No character file found for variant "$variantFolderName"';
        }
        final gameFileName = variant.originalFileName ??
            p.basename(charFile);
        final dest = p.join(_gameFolderPath!, gameFileName);
        await File(charFile).copy(dest);
      } catch (e) {
        return 'Could not copy to game folder: $e';
      }
    }

    final existing = character.appliedVariants.toSet();
    existing.add(variantFolderName);
    character.appliedVariants = existing.toList();
    character.mainVariantData?.lastSyncedAt = DateTime.now();
    _pendingUpdates.remove(character.id);
    await _data.saveCharacter(character);
    notifyListeners();
    return null;
  }

  Future<String?> _unapplyCharacter(CharacterData character) async {
    if (_gameFolderPath != null) {
      for (final vName in character.appliedVariants) {
        await _removeVariantFromGameFolder(character, vName);
      }
    }
    character.appliedVariants = [];
    await _data.saveCharacter(character);
    notifyListeners();
    return null;
  }

  Future<void> unapplyVariant(
      CharacterData character, String variantFolderName) async {
    await _removeVariantFromGameFolder(character, variantFolderName);
    character.appliedVariants =
        character.appliedVariants.where((v) => v != variantFolderName).toList();
    await _data.saveCharacter(character);
    notifyListeners();
  }

  Future<void> _removeFromGameFolder(CharacterData character) async {
    for (final vName in character.appliedVariants) {
      await _removeVariantFromGameFolder(character, vName);
    }
  }

  Future<void> _removeVariantFromGameFolder(
      CharacterData character, String variantFolderName) async {
    try {
      if (_gameFolderPath == null) return;
      final variant = character.variants
          .where((v) => v.folderName == variantFolderName)
          .firstOrNull;
      if (variant == null) return;
      final charFile = character.charFileForVariant(variantFolderName);
      final gameFileName =
          variant.originalFileName ?? (charFile != null ? p.basename(charFile) : null);
      if (gameFileName == null || gameFileName.isEmpty) return;
      final dest = p.join(_gameFolderPath!, gameFileName);
      final file = File(dest);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  // ── Game folder update detection ──────────────────────────────────

  Future<void> _checkForGameFolderUpdates() async {
    if (_gameFolderPath == null) return;
    _pendingUpdates.clear();
    bool changed = false;

    for (final char in _characters) {
      for (final variant in char.variants) {
        final charFile = char.charFileForVariant(variant.folderName);
        if (charFile == null) continue;
        final gameFileName =
            (variant.originalFileName?.isNotEmpty ?? false)
                ? variant.originalFileName!
                : p.basename(charFile);
        try {
          final gameFile = File(p.join(_gameFolderPath!, gameFileName));
          if (!await gameFile.exists()) continue;
          final storedFile = File(charFile);
          if (!await storedFile.exists()) continue;
          final gameModified   = await gameFile.lastModified();
          final storedModified = await storedFile.lastModified();
          if (gameModified.difference(storedModified).inSeconds > 5) {
            _pendingUpdates.putIfAbsent(char.id, () => {})[variant.folderName] =
                gameModified;
            changed = true;
          }
        } catch (_) {}
      }
    }
    if (changed) notifyListeners();
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30),
        (_) => _checkForGameFolderUpdates());
  }

  Future<void> checkForUpdates() async {
    await _checkForGameFolderUpdates();
    _startSyncTimer();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<String?> syncCharacterFromGameFolder(
      CharacterData character, String variantFolderName) async {
    if (_gameFolderPath == null) return 'Game folder path not set.';
    final variant = character.variants
        .where((v) => v.folderName == variantFolderName)
        .firstOrNull;
    if (variant == null) return 'Variant not found.';
    final charFile = character.charFileForVariant(variantFolderName);
    if (charFile == null) return 'No character file found.';
    final gameFileName =
        (variant.originalFileName?.isNotEmpty ?? false)
            ? variant.originalFileName!
            : p.basename(charFile);
    try {
      final gameFile = File(p.join(_gameFolderPath!, gameFileName));
      if (!await gameFile.exists()) {
        return 'File not found in game folder: $gameFileName';
      }
      await _data.backupVariant(
        character: character,
        variantFolderName: variantFolderName,
        source: 'sync_from_game',
      );
      await gameFile.copy(charFile);
      variant.lastSyncedAt = DateTime.now();
      // File is already in the game folder — mark as applied if not already.
      if (!character.appliedVariants.contains(variantFolderName)) {
        final existing = character.appliedVariants.toSet();
        existing.add(variantFolderName);
        character.appliedVariants = existing.toList();
      }
      _pendingUpdates[character.id]?.remove(variantFolderName);
      if (_pendingUpdates[character.id]?.isEmpty ?? false) {
        _pendingUpdates.remove(character.id);
      }
      await _data.saveCharacter(character);
      notifyListeners();
      return null;
    } catch (e) {
      return 'Sync failed: $e';
    }
  }

  void dismissUpdate(String characterId, {String? variantFolderName}) {
    if (variantFolderName != null) {
      _pendingUpdates[characterId]?.remove(variantFolderName);
      if (_pendingUpdates[characterId]?.isEmpty ?? false) {
        _pendingUpdates.remove(characterId);
      }
    } else {
      _pendingUpdates.remove(characterId);
    }
    notifyListeners();
  }

  Future<String?> addNewFromGameFolder(
      CharacterData existingChar, String variantFolderName) async {
    if (_gameFolderPath == null) return 'Game folder path not set.';
    final variant = existingChar.variants
        .where((v) => v.folderName == variantFolderName)
        .firstOrNull;
    if (variant == null) return 'Variant not found.';
    final charFile = existingChar.charFileForVariant(variantFolderName);
    final gameFileName =
        (variant.originalFileName?.isNotEmpty ?? false)
            ? variant.originalFileName!
            : (charFile != null ? p.basename(charFile) : '');
    if (gameFileName.isEmpty) return 'No game file name known for this variant.';

    final gameFilePath = p.join(_gameFolderPath!, gameFileName);
    final gameFile = File(gameFilePath);
    if (!await gameFile.exists()) {
      return 'File not found in game folder: $gameFileName';
    }

    final id         = _uuid.v4();
    final raceGender = CharacterData.detectRaceGender(gameFilePath);
    final baseName   = variant.displayName.isNotEmpty
        ? variant.displayName
        : existingChar.name;
    final newName    = '$baseName (updated)';
    final newVariant = _sanitize(newName);

    final newChar = await _data.createCharacterFolder(
      id: id,
      name: newName,
      race: raceGender['race']!,
      gender: raceGender['gender']!,
      variantFolderName: newVariant,
      variantDisplayName: newName,
      originalFileName: gameFileName,
    );

    await _data.copyFileToVariant(
      characterFolderPath: newChar.folderPath,
      variantFolderName: newVariant,
      sourcePath: gameFilePath,
      targetFileName: gameFileName,
    );

    newChar.mainVariantData!.lastSyncedAt = DateTime.now();
    await _data.saveCharacter(newChar);

    _characters.add(newChar);
    _galleryCache[newChar.id] = [];
    _pendingUpdates[existingChar.id]?.remove(variantFolderName);
    if (_pendingUpdates[existingChar.id]?.isEmpty ?? false) {
      _pendingUpdates.remove(existingChar.id);
    }
    notifyListeners();
    return null;
  }

  // ── Gallery ───────────────────────────────────────────────────────

  List<GalleryItemData> getGalleryItems(String characterId) =>
      _galleryCache[characterId] ?? [];

  List<GalleryItemData> getAllGalleryItems() {
    final all = <GalleryItemData>[];
    for (final items in _galleryCache.values) {
      all.addAll(items);
    }
    all.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return all;
  }

  CharacterData? characterForGalleryItem(GalleryItemData item) {
    try {
      return _characters.firstWhere((c) => c.id == item.characterId);
    } catch (_) {
      return null;
    }
  }

  Future<GalleryItemData?> addGalleryItem(
      String characterId, String sourcePath) async {
    try {
      final character =
          _characters.firstWhere((c) => c.id == characterId);
      final item =
          await _data.addGalleryItem(character: character, sourcePath: sourcePath);
      _galleryCache[characterId] = await _data.getGalleryItems(character);
      notifyListeners();
      return item;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteGalleryItem(GalleryItemData item) async {
    try {
      final character =
          _characters.firstWhere((c) => c.id == item.characterId);
      await _data.deleteGalleryItem(character: character, item: item);
      _galleryCache[item.characterId] =
          await _data.getGalleryItems(character);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggleGalleryItemBlur(GalleryItemData item) async {
    try {
      final character =
          _characters.firstWhere((c) => c.id == item.characterId);
      item.isBlurred = !item.isBlurred;
      await _data.saveGalleryItems(character, _galleryCache[item.characterId]!);
      notifyListeners();
    } catch (_) {}
  }

  // ── Tags ──────────────────────────────────────────────────────────

  Future<TagData> createTag(String name, Color color) async {
    final tag = TagData(
      id: _uuid.v4(),
      name: name.trim(),
      colorValue: color.toARGB32(),
    );
    _tags.add(tag);
    await _data.saveTags(_tags);
    notifyListeners();
    return tag;
  }

  Future<void> updateTag(TagData tag,
      {String? name, Color? color}) async {
    if (name != null) tag.name = name.trim();
    if (color != null) tag.colorValue = color.toARGB32();
    await _data.saveTags(_tags);
    notifyListeners();
  }

  Future<void> deleteTag(TagData tag) async {
    _tags.removeWhere((t) => t.id == tag.id);
    for (final c in _characters) {
      if (c.tags.contains(tag.id)) {
        c.tags = c.tags.where((t) => t != tag.id).toList();
        await _data.saveCharacter(c);
      }
    }
    await _data.saveTags(_tags);
    notifyListeners();
  }

  int tagUsageCount(String tagId) =>
      _characters.where((c) => c.tags.contains(tagId)).length;

  // ── Share / Export ────────────────────────────────────────────────

  Future<String?> exportCharacterFile(
      CharacterData character, String destPath) async {
    try {
      final charFile = character.characterFilePath;
      if (charFile == null) return 'No character file found';
      await File(charFile).copy(destPath);
      return null;
    } catch (e) {
      return 'Export failed: $e';
    }
  }

  Future<String?> exportBundle({
    required CharacterData character,
    required String destPath,
    required ExportOptions options,
  }) async {
    final galleryItems = getGalleryItems(character.id);
    return ShareService.exportBundle(
      character: character,
      galleryItems: galleryItems,
      destPath: destPath,
      options: options,
    );
  }

  Future<int> estimateBundleSize({
    required CharacterData character,
    required ExportOptions options,
  }) async {
    final galleryItems = getGalleryItems(character.id);
    return ShareService.estimateBundleSize(
      character: character,
      galleryItems: galleryItems,
      options: options,
    );
  }

  Future<String?> importBundle({
    required BundlePreview preview,
    required String characterName,
    String? customFileName,
  }) async {
    try {
      final id          = _uuid.v4();
      final variantName = _sanitize(characterName);

      final character = await _data.createCharacterFolder(
        id: id,
        name: characterName,
        race: preview.race,
        gender: preview.gender,
        variantFolderName: variantName,
        variantDisplayName: characterName,
        originalFileName: preview.originalFileName,
        description: preview.description ?? '',
      );

      final variantFolderPath =
          p.join(character.folderPath, variantName);
      final galleryFolderPath =
          p.join(character.folderPath, 'character_gallery');

      final result = await ShareService.extractBundle(
        bundleBytes: preview.bundleBytes,
        variantFolderPath: variantFolderPath,
        galleryFolderPath: galleryFolderPath,
        variantFolderName: variantName,
        customFileName: customFileName,
      );
      if (result == null) return 'Failed to extract bundle';

      character.mainVariantData!.originalFileName =
          result.originalFileName;
      character.mainVariantData!.lastSyncedAt = DateTime.now();
      await _data.saveCharacter(character);

      // Save gallery items
      final galleryItems = result.galleryFileNames
          .map((fn) => GalleryItemData(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                characterId: character.id,
                fileName: fn,
              ))
          .toList();
      await _data.saveGalleryItems(character, galleryItems);

      _characters.add(character);
      _galleryCache[character.id] = galleryItems;
      notifyListeners();
      return null;
    } catch (e) {
      return 'Import failed: $e';
    }
  }

  // ── Scan game folder ──────────────────────────────────────────────

  Future<List<String>> scanGameFolderForUnregistered() async {
    if (_gameFolderPath == null) return [];
    final registered =
        _characters.map((c) => c.gameFileName).toSet();
    return _data.scanForUnregisteredFiles(_gameFolderPath!, registered);
  }

  // ── Collections ───────────────────────────────────────────────────

  Future<void> addCollection(String name, {
    String? thumbnailPath,
    String description = '',
    int? accentColorValue,
  }) async {
    final collection = CollectionData(
      id: _uuid.v4(),
      name: name,
      thumbnailPath: thumbnailPath,
      description: description,
      accentColorValue: accentColorValue,
    );
    _collections.add(collection);
    await _data.saveCollections(_collections);
    notifyListeners();
  }

  Future<void> updateCollection(CollectionData collection) async {
    await _data.saveCollections(_collections);
    notifyListeners();
  }

  Future<void> deleteCollection(String id) async {
    _collections.removeWhere((c) => c.id == id);
    for (final c in _characters) {
      if (c.collectionIds.contains(id)) {
        c.collectionIds = c.collectionIds.where((cid) => cid != id).toList();
        await _data.saveCharacter(c);
      }
    }
    await _data.saveCollections(_collections);
    notifyListeners();
  }

  int getCharacterCountForCollection(String collectionId) =>
      _characters.where((c) => c.collectionIds.contains(collectionId)).length;

  List<CharacterData> getCharactersForCollection(String collectionId) =>
      _characters
          .where((c) => c.collectionIds.contains(collectionId))
          .toList();

  List<CharacterData> sortedCharactersForCollection(
      String collectionId, SortOption option, bool favouritesOnTop) {
    final list = _characters
        .where((c) => c.collectionIds.contains(collectionId))
        .toList();
    final sorted = List<CharacterData>.from(list);
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
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });
    return sorted;
  }

  // ── Settings ──────────────────────────────────────────────────────

  Future<void> setGameFolderPath(String path) async {
    _gameFolderPath = path;
    final s = await _data.getSettings();
    s.gameFolderPath = path;
    await _data.saveSettings(s);
    notifyListeners();
    _checkForGameFolderUpdates();
  }

  Future<String?> changeSaveLocation(
    String newPath, {
    bool migrateFiles = true,
    void Function(int done, int total)? onProgress,
  }) async {
    try {
      if (migrateFiles && _saveLocation != null) {
        final pathMap = await _data.migrateDataRoot(
          newRootPath: newPath,
          characters: _characters,
          onProgress: onProgress,
        );
        // Update in-memory characters with new folder paths
        for (int i = 0; i < _characters.length; i++) {
          final newFolder = pathMap[_characters[i].folderPath];
          if (newFolder != null) {
            // Reload character from new path
            // (folderPath is final, so we need to reload)
          }
        }
      }
      _saveLocation = newPath;
      _data.setDataRoot(newPath);
      final s = await _data.getSettings();
      s.saveLocation = newPath;
      await _data.saveSettings(s);
      // Reload characters from new location
      _characters = await _data.getAllCharacters();
      _galleryCache.clear();
      for (final c in _characters) {
        _galleryCache[c.id] = await _data.getGalleryItems(c);
      }
      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to change save location: $e';
    }
  }

  // ── Search & Filter ───────────────────────────────────────────────

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
    _pendingTokens      = [];
    _appliedTokens      = [];
    _filterRace         = null;
    _filterGender       = null;
    _filterCollectionId = null;
    _filterApplied      = null;
    _filterTags         = [];
    _filterTagsBlacklist= [];
    _filterTiers        = {};
    notifyListeners();
    if (_persistFilter) _persistCurrentFilter();
  }

  // ── Persist filter ────────────────────────────────────────────────

  Future<void> setPersistFilter(bool value) async {
    _persistFilter = value;
    await _data.savePersistFilter(value);
    if (!value) await _data.savePersistedFilter(null);
    notifyListeners();
  }

  void _persistCurrentFilter() {
    final state = {
      'tokens': _appliedTokens,
      'race': _filterRace,
      'gender': _filterGender,
      'applied': _filterApplied,
      'tagIds': _filterTags,
      'tierIndices': _filterTiers.map((t) => t.index).toList(),
    };
    _data.savePersistedFilter(jsonEncode(state));
  }

  Future<void> _restorePersistedFilter() async {
    final raw = await _data.getPersistedFilter();
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _appliedTokens = (j['tokens'] as List?)?.cast<String>() ?? [];
      _pendingTokens = List.from(_appliedTokens);
      _filterRace    = j['race'] as String?;
      _filterGender  = j['gender'] as String?;
      _filterApplied = j['applied'] as bool?;
      _filterTags    = (j['tagIds'] as List?)?.cast<String>() ?? [];
      final ti       = (j['tierIndices'] as List?)?.cast<int>() ?? [];
      _filterTiers   = ti.map((i) => CharacterTier.values[i]).toSet();
    } catch (_) {}
  }

  // ── Saved presets ─────────────────────────────────────────────────

  Future<void> _loadSavedPresets() async {
    final raw = await _data.getSavedPresets();
    if (raw == null) { _savedPresets = []; return; }
    try {
      final list = jsonDecode(raw) as List;
      _savedPresets = list
          .map((e) => FilterPreset.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _savedPresets = [];
    }
  }

  Future<void> _persistPresets() async {
    await _data.saveSavedPresets(
        jsonEncode(_savedPresets.map((p) => p.toJson()).toList()));
  }

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

  void applyPreset(FilterPreset preset) {
    _appliedTokens = List.from(preset.tokens);
    _pendingTokens = List.from(preset.tokens);
    _filterRace    = preset.race;
    _filterGender  = preset.gender;
    _filterApplied = preset.applied;
    _filterTags    = List.from(preset.tagIds);
    _filterTiers   = preset.tierIndices
        .map((i) => CharacterTier.values[i])
        .toSet();
    notifyListeners();
    if (_persistFilter) _persistCurrentFilter();
  }

  Future<void> deletePreset(String id) async {
    _savedPresets = _savedPresets.where((p) => p.id != id).toList();
    await _persistPresets();
    notifyListeners();
  }

  // ── Variant management ────────────────────────────────────────────

  Future<void> setMainVariant(
      CharacterData character, String variantFolderName) async {
    character.mainVariant = variantFolderName;
    await _data.saveCharacter(character);
    notifyListeners();
  }

  Future<void> renameVariant(
      CharacterData character, VariantData variant, String newName) async {
    variant.displayName = newName;
    await _data.saveCharacter(character);
    notifyListeners();
  }

  /// Returns null on success, error string on failure.
  Future<String?> deleteVariant(
      CharacterData character, VariantData variant) async {
    if (character.variants.length <= 1) {
      return 'Cannot delete the only variant — delete the character instead.';
    }
    if (character.isVariantApplied(variant.folderName)) {
      await _removeVariantFromGameFolder(character, variant.folderName);
      character.appliedVariants = character.appliedVariants
          .where((v) => v != variant.folderName)
          .toList();
    }
    if (character.mainVariant == variant.folderName) {
      final remaining = character.variants
          .where((v) => v.folderName != variant.folderName)
          .toList();
      character.mainVariant = remaining.first.folderName;
    }
    character.variants
        .removeWhere((v) => v.folderName == variant.folderName);
    await _data.deleteVariantFolder(character, variant.folderName);
    await _data.saveCharacter(character);
    notifyListeners();
    return null;
  }

  Future<void> setVariantThumbnail(
      CharacterData character, VariantData variant, String sourcePath) async {
    final variantDir =
        Directory(p.join(character.folderPath, variant.folderName));
    if (await variantDir.exists()) {
      await for (final entity in variantDir.list()) {
        if (entity is File) {
          final name =
              p.basenameWithoutExtension(entity.path).toLowerCase();
          if (name.contains('thumbnail')) await entity.delete();
        }
      }
    }
    await _data.copyThumbnailToVariant(
      characterFolderPath: character.folderPath,
      variantFolderName: variant.folderName,
      sourcePath: sourcePath,
    );
    notifyListeners();
  }

  Future<void> reorderVariants(
      CharacterData character, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = character.variants.removeAt(oldIndex);
    character.variants.insert(newIndex, item);
    await _data.saveCharacter(character);
    notifyListeners();
  }

  Future<void> duplicateVariant(
      CharacterData character, VariantData variant) async {
    final newDisplayName = '${variant.displayName} (Copy)';
    final newFolderName =
        CharacterData.toFolderName(newDisplayName, const Uuid().v4());
    final sourceDir =
        Directory(p.join(character.folderPath, variant.folderName));
    final destDir =
        Directory(p.join(character.folderPath, newFolderName));
    await destDir.create(recursive: true);
    if (await sourceDir.exists()) {
      await for (final entity in sourceDir.list()) {
        if (entity is File) {
          await entity
              .copy(p.join(destDir.path, p.basename(entity.path)));
        }
      }
    }
    character.variants.add(VariantData(
      folderName: newFolderName,
      displayName: newDisplayName,
      originalFileName: variant.originalFileName,
    ));
    await _data.saveCharacter(character);
    notifyListeners();
  }

  Future<String?> exportVariantBundle(
      CharacterData character, VariantData variant, String destPath) =>
      ShareService.exportVariantBundle(
          character: character, variant: variant, destPath: destPath);

  Future<VariantData> addVariant({
    required CharacterData character,
    required String displayName,
    required String sourceFilePath,
    String? sourceThumbnailPath,
    String? originalFileName,
  }) async {
    final folderName = _sanitize(displayName);
    final variant = await _data.addVariant(
      character: character,
      folderName: folderName,
      displayName: displayName,
      originalFileName:
          originalFileName ?? p.basename(sourceFilePath),
    );

    await _data.copyFileToVariant(
      characterFolderPath: character.folderPath,
      variantFolderName: folderName,
      sourcePath: sourceFilePath,
      targetFileName: p.basename(sourceFilePath),
    );

    if (sourceThumbnailPath != null) {
      await _data.copyThumbnailToVariant(
        characterFolderPath: character.folderPath,
        variantFolderName: folderName,
        sourcePath: sourceThumbnailPath,
      );
    }

    notifyListeners();
    return variant;
  }

  // ── Helpers ───────────────────────────────────────────────────────

  static String _sanitize(String name) {
    final result = name
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_{2,}'), '_')
        .trim();
    return result.isEmpty ? 'character' : result;
  }
}
