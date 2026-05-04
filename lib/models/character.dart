import 'package:hive/hive.dart';

part 'character.g.dart';

@HiveType(typeId: 0)
class Character extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late String race;

  @HiveField(3)
  late String gender;

  @HiveField(4)
  late String characterFilePath;

  @HiveField(5)
  String? thumbnailPath;

  @HiveField(6)
  List<String> tags;

  @HiveField(7)
  String? collectionId; // kept for legacy migration, use collectionIds

  @HiveField(8)
  late DateTime createdAt;

  @HiveField(9)
  bool isApplied;

  @HiveField(10)
  int? slotNumber;

  @HiveField(11)
  String description;

  @HiveField(12)
  List<String> collectionIds; // multi-collection support

  Character({
    required this.id,
    required this.name,
    required this.race,
    required this.gender,
    required this.characterFilePath,
    this.thumbnailPath,
    List<String>? tags,
    this.collectionId,
    DateTime? createdAt,
    this.isApplied = false,
    this.slotNumber,
    this.description = '',
    List<String>? collectionIds,
  })  : tags = tags ?? [],
        collectionIds = collectionIds ?? (collectionId != null ? [collectionId!] : []),
        createdAt = createdAt ?? DateTime.now();

  static Map<String, String> detectRaceGender(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    const map = {
      'fhp': {'race': 'Human', 'gender': 'Female'},
      'mhp': {'race': 'Human', 'gender': 'Male'},
      'fnp': {'race': 'Newman', 'gender': 'Female'},
      'mnp': {'race': 'Newman', 'gender': 'Male'},
      'fdp': {'race': 'Deuman', 'gender': 'Female'},
      'mdp': {'race': 'Deuman', 'gender': 'Male'},
      'fcp': {'race': 'CAST', 'gender': 'Female'},
      'mcp': {'race': 'CAST', 'gender': 'Male'},
    };
    return map[ext] ?? {'race': 'Unknown', 'gender': 'Unknown'};
  }

  static bool isValidExtension(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    return ['fhp', 'mhp', 'fnp', 'mnp', 'fdp', 'mdp', 'fcp', 'mcp']
        .contains(ext);
  }

  static const List<String> validExtensions = [
    'fhp', 'mhp', 'fnp', 'mnp', 'fdp', 'mdp', 'fcp', 'mcp'
  ];
}
