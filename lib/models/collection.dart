import 'package:hive/hive.dart';

part 'collection.g.dart';

@HiveType(typeId: 1)
class Collection extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late DateTime createdAt;

  @HiveField(3)
  String? thumbnailPath; // optional custom thumbnail for the collection

  Collection({
    required this.id,
    required this.name,
    DateTime? createdAt,
    this.thumbnailPath,
  }) : createdAt = createdAt ?? DateTime.now();
}
