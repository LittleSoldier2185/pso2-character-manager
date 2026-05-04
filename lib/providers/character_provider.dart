import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/character.dart';
import '../models/collection.dart';
import '../services/hive_service.dart';
import '../services/file_service.dart';
import '../services/storage_service.dart';

// Sort options for the character grid
enum SortOption {
  nameAZ,
  nameZA,
  newestFirst,
  oldestFirst,
  lastApplied,
}

extension SortOptionLabel on SortOption {
  String get label {
    switch (this) {
      case SortOption.nameAZ: return 'Name A → Z';
      case SortOption.nameZA: return 'Name Z → A';
      case SortOption.newestFirst: return 'Newest first';
      case SortOption.oldestFirst: return 'Oldest first';
      case SortOption.lastApplied: return 'Last applied';
    }
  }
  IconData get icon {
    switch (this) {
      case SortOption.nameAZ: return Icons.sort_by_alpha_rounded;
      case SortOption.nameZA: return Icons.sort_by_alpha_rounded;
      case SortOption.newestFirst: return Icons.schedule_rounded;
      case SortOption.oldestFirst: return Icons.history_rounded;
      case SortOption.lastApplied: return Icons.check_circle_outline_rounded;
    }
  }
}

class CharacterProvider extends ChangeNotifier {
  final HiveService _hive = HiveService();
  final _uuid = const Uuid();

  List<Character> _characters = [];
  List<Collection> _collections = [];

  // ── Keyword token search ───────────────────────────────────────
  // Pending = what's in the input bar right now (not yet applied)
  // Applied = what's actually filtering the grid
  List<String> _pendingTokens = [];
  List<String> _appliedTokens = [];

  // ── Other filters ──────────────────────────────────────────────
  String? _filterRace;
  String? _filterGender;
  String? _filterCollectionId;
  bool? _filterApplied;

  // ── Sort ───────────────────────────────────────────────────────
  SortOption _sortOption = SortOption.newestFirst;

  // ── Settings ───────────────────────────────────────────────────
  String? _gameFolderPath;
  String? _saveLocation;

  // ── Getters ────────────────────────────────────────────────────

  List<Character> get allCharacters => _sortedCharacters(_characters);
  List<Collection> get allCollections => _collections;

  List<String> get pendingTokens => _pendingTokens;
  List<String> get appliedTokens => _appliedTokens;
  bool get hasPendingChanges {
    if (_pendingTokens.length != _appliedTokens.length) return true;
    for (int i = 0; i < _pendingTokens.length; i++) {
      if (_pendingTokens[i] != _appliedTokens[i]) return true;
    }
    return false;
  }

  String? get filterRace => _filterRace;
  String? get filterGender => _filterGender;
  String? get filterCollectionId => _filterCollectionId;
  bool? get filterApplied => _filterApplied;
  SortOption get sortOption => _sortOption;

  String? get gameFolderPath => _gameFolderPath;
  String? get saveLocation => _saveLocation;

  List<Character> get appliedCharacters =>
      _characters.where((c) => c.isApplied).toList()
        ..sort((a, b) => (a.slotNumber ?? 999).compareTo(b.slotNumber ?? 999));

  int get appliedCount => _characters.where((c) => c.isApplied).length;

  // Filtered + sorted characters (uses _appliedTokens, not _pendingTokens)
  List<Character> get filteredCharacters {
    var list = _characters.where((c) {
      // Keyword tokens — each token must match name, tags, or description
      if (_appliedTokens.isNotEmpty) {
        final matchesAll = _appliedTokens.every((token) {
          final t = token.toLowerCase();
          return c.name.toLowerCase().contains(t) ||
              c.tags.any((tag) => tag.toLowerCase().contains(t)) ||
              c.description.toLowerCase().contains(t) ||
              c.race.toLowerCase().contains(t);
        });
        if (!matchesAll) return false;
      }
      if (_filterRace != null && c.race != _filterRace) return false;
      if (_filterGender != null && c.gender != _filterGender) return false;
      if (_filterCollectionId != null &&
          !c.collectionIds.contains(_filterCollectionId)) return false;
      if (_filterApplied != null && c.isApplied != _filterApplied) return false;
      return true;
    }).toList();
    return _sortedCharacters(list);
  }

  bool get hasActiveFilters =>
      _appliedTokens.isNotEmpty ||
      _filterRace != null ||
      _filterGender != null ||
      _filterCollectionId != null ||
      _filterApplied != null;

  int get activeFilterCount {
    int n = 0;
    if (_appliedTokens.isNotEmpty) n++;
    if (_filterRace != null) n++;
    if (_filterGender != null) n++;
    if (_filterCollectionId != null) n++;
    if (_filterApplied != null) n++;
    return n;
  }

  // All unique tags across all characters
  List<String> get allTags {
    final tags = <String>{};
    for (final c in _characters) tags.addAll(c.tags);
    return tags.toList()..sort();
  }

  // ── Sorting ────────────────────────────────────────────────────

  List<Character> _sortedCharacters(List<Character> list) {
    final sorted = List<Character>.from(list);
    switch (_sortOption) {
      case SortOption.nameAZ:
        sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case SortOption.nameZA:
        sorted.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
      case SortOption.newestFirst:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case SortOption.oldestFirst:
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case SortOption.lastApplied:
        sorted.sort((a, b) {
          // Applied characters first (by slot), then unapplied
          if (a.isApplied && !b.isApplied) return -1;
          if (!a.isApplied && b.isApplied) return 1;
          if (a.isApplied && b.isApplied) {
            return (a.slotNumber ?? 999).compareTo(b.slotNumber ?? 999);
          }
          return b.createdAt.compareTo(a.createdAt);
        });
    }
    return sorted;
  }

  void setSortOption(SortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  // ── Init ───────────────────────────────────────────────────────

  void loadAll() {
    _characters = _hive.getAllCharacters();
    _collections = _hive.getAllCollections();
    _gameFolderPath = _hive.getGameFolderPath();
    _saveLocation = _hive.getSaveLocation();
    StorageService.init(_saveLocation);
    notifyListeners();
  }

  // ── Character CRUD ─────────────────────────────────────────────

  Future<void> addCharacter({
    required String name,
    required String sourceFilePath,
    String? sourceThumbnailPath,
    List<String>? tags,
    List<String>? collectionIds,
    String? description,
  }) async {
    final charFilePath = await FileService.copyCharacterFile(sourceFilePath);
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
      collectionId: collectionIds?.isNotEmpty == true ? collectionIds!.first : null,
      description: description ?? '',
    );
    await _hive.addCharacter(character);
    _characters = _hive.getAllCharacters();
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
      characterFilePath: localFilePath,
      thumbnailPath: thumbPath,
      tags: tags ?? [],
      collectionIds: collectionIds ?? [],
      collectionId: collectionIds?.isNotEmpty == true ? collectionIds!.first : null,
      description: description ?? '',
      isApplied: true,
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

  Future<void> deleteCharacter(Character character) async {
    if (character.isApplied && _gameFolderPath != null) {
      await _removeFromGameFolder(character);
    }
    await FileService.deleteFile(character.characterFilePath);
    if (character.thumbnailPath != null) {
      await FileService.deleteFile(character.thumbnailPath!);
    }
    await _hive.deleteCharacter(character.id);
    _characters = _hive.getAllCharacters();
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
    final usedSlots = appliedCharacters.map((c) => c.slotNumber ?? 0).toSet();
    int slot = 1;
    while (usedSlots.contains(slot)) slot++;

    if (_gameFolderPath != null) {
      try {
        final fileName = p.basename(character.characterFilePath);
        final dest = p.join(_gameFolderPath!, fileName);
        await File(character.characterFilePath).copy(dest);
      } catch (e) {
        return 'Could not copy to game folder: $e';
      }
    }

    character.isApplied = true;
    character.slotNumber = slot;
    await character.save();
    _characters = _hive.getAllCharacters();
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
      final fileName = p.basename(character.characterFilePath);
      final dest = p.join(_gameFolderPath!, fileName);
      final file = File(dest);
      if (await file.exists()) await file.delete();
    } catch (_) {}
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

  // ── Scan game folder ───────────────────────────────────────────

  Future<List<String>> scanGameFolderForUnregistered() async {
    if (_gameFolderPath == null) return [];
    final registered =
        _characters.map((c) => p.basename(c.characterFilePath)).toSet();
    return FileService.scanForUnregisteredFiles(_gameFolderPath!, registered);
  }

  // ── Collection CRUD ────────────────────────────────────────────

  Future<void> addCollection(String name, {String? thumbnailPath}) async {
    final collection =
        Collection(id: _uuid.v4(), name: name, thumbnailPath: thumbnailPath);
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
      _sortedCharacters(_characters
          .where((c) => c.collectionIds.contains(collectionId))
          .toList());

  // ── Save location ──────────────────────────────────────────────

  Future<void> setGameFolderPath(String path) async {
    _gameFolderPath = path;
    await _hive.saveGameFolderPath(path);
    notifyListeners();
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

  // ── Keyword token search ───────────────────────────────────────

  /// Add a token to the pending list (not yet applied to grid)
  void addPendingToken(String token) {
    final t = token.trim();
    if (t.isEmpty || _pendingTokens.contains(t)) return;
    _pendingTokens = [..._pendingTokens, t];
    notifyListeners();
  }

  /// Remove a token from the pending list
  void removePendingToken(String token) {
    _pendingTokens = _pendingTokens.where((t) => t != token).toList();
    notifyListeners();
  }

  /// Apply pending tokens to actually filter the grid
  void applySearch() {
    _appliedTokens = List.from(_pendingTokens);
    notifyListeners();
  }

  /// Clear all tokens (both pending and applied)
  void clearTokens() {
    _pendingTokens = [];
    _appliedTokens = [];
    notifyListeners();
  }

  // ── Other filters ──────────────────────────────────────────────

  void setFilterRace(String? race) {
    _filterRace = (_filterRace == race) ? null : race;
    notifyListeners();
  }

  void setFilterGender(String? gender) {
    _filterGender = (_filterGender == gender) ? null : gender;
    notifyListeners();
  }

  void setFilterCollection(String? collectionId) {
    _filterCollectionId = collectionId;
    notifyListeners();
  }

  void setFilterApplied(bool? value) {
    _filterApplied = (_filterApplied == value) ? null : value;
    notifyListeners();
  }

  void clearAllFilters() {
    _pendingTokens = [];
    _appliedTokens = [];
    _filterRace = null;
    _filterGender = null;
    _filterCollectionId = null;
    _filterApplied = null;
    notifyListeners();
  }

  // Legacy single-string search kept for collection detail search
  // (collection search is local, doesn't need token system)
  void setSearch(String query) {
    // Not used by main grid anymore — kept for compatibility
    notifyListeners();
  }

  String get searchQuery => _appliedTokens.join(' ');

  // Old tag filter methods kept for the filter panel chips
  List<String> _filterTags = [];
  List<String> get filterTags => _filterTags;

  void toggleFilterTag(String tag) {
    if (_filterTags.contains(tag)) {
      _filterTags = _filterTags.where((t) => t != tag).toList();
    } else {
      _filterTags = [..._filterTags, tag];
    }
    notifyListeners();
  }

  void setFilterTags(List<String> tags) {
    _filterTags = tags;
    notifyListeners();
  }
}
