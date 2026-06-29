import 'package:uuid/uuid.dart';

class AlbumData {
  final String id;
  String name;
  String description;
  final List<String> itemIds; // ordered; itemIds[0] is the cover
  List<String>? _tagIds;
  final DateTime createdAt;
  DateTime? updatedAt;
  DateTime? lastViewedAt;
  bool isFavourite;

  // Null-safe getter: guards against hot-reload stale instances and missing JSON key.
  List<String> get tagIds => _tagIds ?? const [];

  AlbumData({
    String? id,
    required this.name,
    this.description = '',
    List<String>? itemIds,
    List<String>? tagIds,
    DateTime? createdAt,
    this.updatedAt,
    this.lastViewedAt,
    this.isFavourite = false,
  })  : id = id ?? const Uuid().v4(),
        itemIds = itemIds ?? [],
        _tagIds = tagIds ?? [],
        createdAt = createdAt ?? DateTime.now();

  String? get coverId => itemIds.isNotEmpty ? itemIds.first : null;

  void setTagIds(List<String> ids) => _tagIds = ids;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'itemIds': List<String>.from(itemIds),
        'tagIds': List<String>.from(tagIds),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': (updatedAt ?? createdAt).toIso8601String(),
        'lastViewedAt': lastViewedAt?.toIso8601String(),
        'isFavourite': isFavourite,
      };

  factory AlbumData.fromJson(Map<String, dynamic> j) => AlbumData(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String? ?? '',
        itemIds: (j['itemIds'] as List?)?.cast<String>() ?? [],
        tagIds: (j['tagIds'] as List?)?.cast<String>().toList() ?? [],
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: j['updatedAt'] != null
            ? DateTime.parse(j['updatedAt'] as String)
            : null,
        lastViewedAt: j['lastViewedAt'] != null
            ? DateTime.parse(j['lastViewedAt'] as String)
            : null,
        isFavourite: (j['isFavourite'] as bool?) ?? false,
      );
}
