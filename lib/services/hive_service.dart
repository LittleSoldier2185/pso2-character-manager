import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/character.dart';
import '../models/collection.dart';

class HiveService {
  static const String _charactersBox = 'characters';
  static const String _collectionsBox = 'collections';
  static const String _settingsBox = 'settings';

  static const String _keyGameFolder   = 'gameFolderPath';
  static const String _keySaveLocation = 'saveLocation';
  static const String _keyAccentColor  = 'accentColor';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(CharacterAdapter());
    Hive.registerAdapter(CollectionAdapter());
    await Hive.openBox<Character>(_charactersBox);
    await Hive.openBox<Collection>(_collectionsBox);
    await Hive.openBox(_settingsBox);
  }

  Box<Character> get _chars => Hive.box<Character>(_charactersBox);
  Box<Collection> get _colls => Hive.box<Collection>(_collectionsBox);
  Box get _settings => Hive.box(_settingsBox);

  // Static accessor for accent color — needed before provider is ready
  static Color? staticGetAccentColor() {
    try {
      final box = Hive.box(_settingsBox);
      final val = box.get(_keyAccentColor) as int?;
      return val != null ? Color(val) : null;
    } catch (_) {
      return null;
    }
  }

  // ── Characters ─────────────────────────────────────────────────

  List<Character> getAllCharacters() {
    return _chars.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> addCharacter(Character character) async {
    await _chars.put(character.id, character);
  }

  Future<void> updateCharacter(Character character) async {
    await character.save();
  }

  Future<void> deleteCharacter(String id) async {
    await _chars.delete(id);
  }

  Character? getCharacter(String id) => _chars.get(id);

  Future<void> migrateCharacterPaths(Map<String, String> pathMap) async {
    for (final c in _chars.values) {
      bool changed = false;
      if (pathMap.containsKey(c.characterFilePath)) {
        c.characterFilePath = pathMap[c.characterFilePath]!;
        changed = true;
      }
      if (c.thumbnailPath != null && pathMap.containsKey(c.thumbnailPath)) {
        c.thumbnailPath = pathMap[c.thumbnailPath!];
        changed = true;
      }
      if (changed) await c.save();
    }
  }

  // ── Collections ────────────────────────────────────────────────

  List<Collection> getAllCollections() {
    return _colls.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> addCollection(Collection collection) async {
    await _colls.put(collection.id, collection);
  }

  Future<void> updateCollection(Collection collection) async {
    await collection.save();
  }

  Future<void> deleteCollection(String id) async {
    for (final c in _chars.values) {
      if (c.collectionIds.contains(id)) {
        c.collectionIds = c.collectionIds.where((cid) => cid != id).toList();
        c.collectionId =
            c.collectionIds.isNotEmpty ? c.collectionIds.first : null;
        await c.save();
      }
    }
    await _colls.delete(id);
  }

  Collection? getCollection(String id) => _colls.get(id);

  // ── Settings ───────────────────────────────────────────────────

  String? getGameFolderPath() => _settings.get(_keyGameFolder) as String?;
  Future<void> saveGameFolderPath(String path) async =>
      _settings.put(_keyGameFolder, path);

  String? getSaveLocation() => _settings.get(_keySaveLocation) as String?;
  Future<void> saveSaveLocation(String path) async =>
      _settings.put(_keySaveLocation, path);

  Color? getAccentColor() {
    final val = _settings.get(_keyAccentColor) as int?;
    return val != null ? Color(val) : null;
  }

  Future<void> saveAccentColor(Color color) async =>
      _settings.put(_keyAccentColor, color.toARGB32());
}
