import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/character.dart';
import '../models/collection.dart';
import '../models/gallery_item.dart';
import '../models/tag.dart';

class HiveService {
  static const String _charactersBox  = 'characters';
  static const String _collectionsBox = 'collections';
  static const String _galleryBox     = 'gallery';
  static const String _tagsBox        = 'tags';
  static const String _settingsBox    = 'settings';

  static const String _keyGameFolder     = 'gameFolderPath';
  static const String _keySaveLocation   = 'saveLocation';
  static const String _keyAccentColor    = 'accentColor';
  static const String _keyGalleryColumns = 'galleryColumns';
  static const String _keyBlurredItems   = 'blurredGalleryItems';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(CharacterAdapter());
    Hive.registerAdapter(CollectionAdapter());
    Hive.registerAdapter(GalleryItemAdapter());
    Hive.registerAdapter(TagAdapter());
    await Hive.openBox<Character>(_charactersBox);
    await Hive.openBox<Collection>(_collectionsBox);
    await Hive.openBox<GalleryItem>(_galleryBox);
    await Hive.openBox<Tag>(_tagsBox);
    await Hive.openBox(_settingsBox);
  }

  Box<Character>   get _chars    => Hive.box<Character>(_charactersBox);
  Box<Collection>  get _colls    => Hive.box<Collection>(_collectionsBox);
  Box<GalleryItem> get _gallery  => Hive.box<GalleryItem>(_galleryBox);
  Box<Tag>         get _tags     => Hive.box<Tag>(_tagsBox);
  Box              get _settings => Hive.box(_settingsBox);

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
        c.collectionIds =
            c.collectionIds.where((cid) => cid != id).toList();
        c.collectionId =
            c.collectionIds.isNotEmpty ? c.collectionIds.first : null;
        await c.save();
      }
    }
    await _colls.delete(id);
  }

  Collection? getCollection(String id) => _colls.get(id);

  // ── Gallery ────────────────────────────────────────────────────

  List<GalleryItem> getGalleryItemsForCharacter(String characterId) {
    return _gallery.values
        .where((g) => g.characterId == characterId)
        .toList()
      ..sort((a, b) => a.addedAt.compareTo(b.addedAt));
  }

  List<GalleryItem> getAllGalleryItems() {
    return _gallery.values.toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  }

  Future<void> addGalleryItem(GalleryItem item) async {
    await _gallery.put(item.id, item);
  }

  Future<void> deleteGalleryItem(String id) async {
    await _gallery.delete(id);
  }

  Future<void> deleteAllGalleryItemsForCharacter(String characterId) async {
    final keys = _gallery.values
        .where((g) => g.characterId == characterId)
        .map((g) => g.id)
        .toList();
    for (final key in keys) {
      await _gallery.delete(key);
    }
  }

  // ── Tags ───────────────────────────────────────────────────────

  List<Tag> getAllTags() =>
      _tags.values.toList()..sort((a, b) => a.name.compareTo(b.name));

  Tag? getTag(String id) => _tags.get(id);

  Future<void> addTag(Tag tag) async => _tags.put(tag.id, tag);

  Future<void> updateTag(Tag tag) async => tag.save();

  Future<void> deleteTag(String id) async {
    // Remove this tag id from every character that uses it
    for (final c in _chars.values) {
      if (c.tags.contains(id)) {
        c.tags = c.tags.where((t) => t != id).toList();
        await c.save();
      }
    }
    await _tags.delete(id);
  }

  /// One-time migration: characters currently store plain tag name strings.
  /// Replace each name with the UUID of the matching Tag, creating Tags as needed.
  Future<void> migrateStringTagsToIds() async {
    final uuidRe = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false);
    final cache = <String, Tag>{};  // name.lower → Tag

    // Pre-populate cache with existing tags
    for (final t in _tags.values) {
      cache[t.name.toLowerCase()] = t;
    }

    for (final c in _chars.values) {
      if (c.tags.isEmpty) continue;
      final alreadyMigrated = c.tags.every((t) => uuidRe.hasMatch(t));
      if (alreadyMigrated) continue;

      final newIds = <String>[];
      for (final t in c.tags) {
        if (uuidRe.hasMatch(t)) {
          newIds.add(t);
        } else {
          final key = t.toLowerCase();
          if (!cache.containsKey(key)) {
            final tag = Tag(id: const Uuid().v4(), name: t);
            await addTag(tag);
            cache[key] = tag;
          }
          newIds.add(cache[key]!.id);
        }
      }
      c.tags = newIds;
      await c.save();
    }
  }

  // ── Settings ───────────────────────────────────────────────────

  String? getGameFolderPath() =>
      _settings.get(_keyGameFolder) as String?;
  Future<void> saveGameFolderPath(String path) async =>
      _settings.put(_keyGameFolder, path);

  String? getSaveLocation() =>
      _settings.get(_keySaveLocation) as String?;
  Future<void> saveSaveLocation(String path) async =>
      _settings.put(_keySaveLocation, path);

  Color? getAccentColor() {
    final val = _settings.get(_keyAccentColor) as int?;
    return val != null ? Color(val) : null;
  }

  Future<void> saveAccentColor(Color color) async =>
      _settings.put(_keyAccentColor, color.toARGB32());

  int getGalleryColumns() =>
      (_settings.get(_keyGalleryColumns) as int?) ?? 3;
  Future<void> saveGalleryColumns(int columns) async =>
      _settings.put(_keyGalleryColumns, columns);

  /// Returns the set of gallery item IDs that are blurred.
  Set<String> getBlurredItems() {
    final raw = _settings.get(_keyBlurredItems);
    if (raw == null) return {};
    return Set<String>.from((raw as List).cast<String>());
  }

  Future<void> saveBlurredItems(Set<String> ids) async =>
      _settings.put(_keyBlurredItems, ids.toList());

  Future<void> toggleBlurredItem(String id) async {
    final set = getBlurredItems();
    if (set.contains(id)) {
      set.remove(id);
    } else {
      set.add(id);
    }
    await saveBlurredItems(set);
  }
}
