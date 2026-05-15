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
  String? collectionId;

  @HiveField(8)
  late DateTime createdAt;

  @HiveField(9)
  bool isApplied;

  @HiveField(10)
  int? slotNumber;

  @HiveField(11)
  String description;

  @HiveField(12)
  List<String> collectionIds;

  /// The original PSO2 filename (e.g. "3001.fhp").
  /// Used when applying to game folder so PSO2 always gets the correct name
  /// regardless of how the file is stored internally.
  @HiveField(13)
  String? originalFileName;

  /// The last time this character's file was synced from the game folder.
  /// Used to detect if the game folder has a newer version.
  @HiveField(14)
  DateTime? lastSyncedAt;

  /// Whether this character is marked as a favourite.
  /// Favourites are shown at the top of the library grid by default.
  @HiveField(15)
  bool isFavourite;

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
    this.originalFileName,
    this.lastSyncedAt,
    this.isFavourite = false,
  })  : tags = tags ?? [],
        collectionIds =
            collectionIds ?? (collectionId != null ? [collectionId!] : []),
        createdAt = createdAt ?? DateTime.now();

  /// The filename to use when copying to the PSO2 game folder.
  /// Uses originalFileName if set, otherwise falls back to the stored filename.
  String get gameFileName {
    if (originalFileName != null && originalFileName!.isNotEmpty) {
      return originalFileName!;
    }
    return characterFilePath.split(r'\').last.split('/').last;
  }

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
