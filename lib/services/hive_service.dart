import 'package:hive_flutter/hive_flutter.dart';
import '../models/character.dart';
import '../models/collection.dart';

class HiveService {
  static const String _charactersBox = 'characters';
  static const String _collectionsBox = 'collections';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(CharacterAdapter());
    Hive.registerAdapter(CollectionAdapter());
    await Hive.openBox<Character>(_charactersBox);
    await Hive.openBox<Collection>(_collectionsBox);
  }

  Box<Character> get _chars => Hive.box<Character>(_charactersBox);
  Box<Collection> get _colls => Hive.box<Collection>(_collectionsBox);

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

  List<Collection> getAllCollections() {
    return _colls.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> addCollection(Collection collection) async {
    await _colls.put(collection.id, collection);
  }

  Future<void> deleteCollection(String id) async {
    final chars =
        getAllCharacters().where((c) => c.collectionId == id).toList();
    for (final c in chars) {
      c.collectionId = null;
      await c.save();
    }
    await _colls.delete(id);
  }

  Collection? getCollection(String id) => _colls.get(id);
}
