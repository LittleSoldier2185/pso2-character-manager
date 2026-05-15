import 'package:hive/hive.dart';

part 'gallery_item.g.dart';

@HiveType(typeId: 2)
class GalleryItem extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String characterId;

  @HiveField(2)
  late String filePath;

  @HiveField(3)
  late DateTime addedAt;

  GalleryItem({
    required this.id,
    required this.characterId,
    required this.filePath,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();
}
