import 'package:path/path.dart' as p;

class GalleryItemData {
  final String id;
  final String characterId;
  final String fileName; // relative to character_gallery/ folder
  final DateTime addedAt;
  bool isBlurred;

  GalleryItemData({
    required this.id,
    required this.characterId,
    required this.fileName,
    DateTime? addedAt,
    this.isBlurred = false,
  }) : addedAt = addedAt ?? DateTime.now();

  /// Absolute path, given the character's folder path.
  String filePath(String characterFolderPath) =>
      p.join(characterFolderPath, 'character_gallery', fileName);

  Map<String, dynamic> toJson() => {
    'id': id,
    'characterId': characterId,
    'fileName': fileName,
    'addedAt': addedAt.toIso8601String(),
    'isBlurred': isBlurred,
  };

  factory GalleryItemData.fromJson(Map<String, dynamic> j) => GalleryItemData(
    id: j['id'] as String,
    characterId: j['characterId'] as String,
    fileName: j['fileName'] as String,
    addedAt: DateTime.parse(j['addedAt'] as String),
    isBlurred: (j['isBlurred'] as bool?) ?? false,
  );
}
