import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/character.dart';
import '../models/collection.dart';
import '../services/hive_service.dart';
import '../services/file_service.dart';

class CharacterProvider extends ChangeNotifier {
  final HiveService _hive = HiveService();
  final _uuid = const Uuid();

  List<Character> _characters = [];
  List<Collection> _collections = [];

  String _searchQuery = '';
  String? _filterRace;
  String? _filterGender;
  String? _filterCollectionId;
  List<String> _filterTags = [];

  List<Character> get allCharacters => _characters;
  List<Collection> get allCollections => _collections;
  String get searchQuery => _searchQuery;
  String? get filterRace => _filterRace;
  String? get filterGender => _filterGender;
  String? get filterCollectionId => _filterCollectionId;
  List<String> get filterTags => _filterTags;

  List<Character> get filteredCharacters {
    return _characters.where((c) {
      if (_searchQuery.isNotEmpty &&
          !c.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      if (_filterRace != null && c.race != _filterRace) return false;
      if (_filterGender != null && c.gender != _filterGender) return false;
      if (_filterCollectionId != null &&
          c.collectionId != _filterCollectionId) {
        return false;
      }
      if (_filterTags.isNotEmpty &&
          !_filterTags.every((tag) => c.tags.contains(tag))) {
        return false;
      }
      return true;
    }).toList();
  }

  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _filterRace != null ||
      _filterGender != null ||
      _filterCollectionId != null ||
      _filterTags.isNotEmpty;

  void loadAll() {
    _characters = _hive.getAllCharacters();
    _collections = _hive.getAllCollections();
    notifyListeners();
  }

  Future<void> addCharacter({
    required String name,
    required String sourceFilePath,
    String? sourceThumbnailPath,
    List<String>? tags,
    String? collectionId,
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
      collectionId: collectionId,
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
    await FileService.deleteFile(character.characterFilePath);
    if (character.thumbnailPath != null) {
      await FileService.deleteFile(character.thumbnailPath!);
    }
    await _hive.deleteCharacter(character.id);
    _characters = _hive.getAllCharacters();
    notifyListeners();
  }

  Future<void> addCollection(String name) async {
    final collection = Collection(id: _uuid.v4(), name: name);
    await _hive.addCollection(collection);
    _collections = _hive.getAllCollections();
    notifyListeners();
  }

  Future<void> deleteCollection(String id) async {
    await _hive.deleteCollection(id);
    _characters = _hive.getAllCharacters();
    _collections = _hive.getAllCollections();
    notifyListeners();
  }

  int getCharacterCountForCollection(String collectionId) {
    return _characters.where((c) => c.collectionId == collectionId).length;
  }

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilterRace(String? race) {
    _filterRace = race;
    notifyListeners();
  }

  void setFilterGender(String? gender) {
    _filterGender = gender;
    notifyListeners();
  }

  void setFilterCollection(String? collectionId) {
    _filterCollectionId = collectionId;
    notifyListeners();
  }

  void setFilterTags(List<String> tags) {
    _filterTags = tags;
    notifyListeners();
  }

  void clearAllFilters() {
    _searchQuery = '';
    _filterRace = null;
    _filterGender = null;
    _filterCollectionId = null;
    _filterTags = [];
    notifyListeners();
  }

  List<String> get allTags {
    final tags = <String>{};
    for (final c in _characters) tags.addAll(c.tags);
    return tags.toList()..sort();
  }
}
