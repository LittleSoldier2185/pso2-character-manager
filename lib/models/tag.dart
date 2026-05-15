import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'tag.g.dart';

@HiveType(typeId: 3)
class Tag extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  /// Colour stored as ARGB int. Defaults to accent cyan if null.
  @HiveField(2)
  int colorValue;

  @HiveField(3)
  DateTime createdAt;

  Tag({
    required this.id,
    required this.name,
    int? colorValue,
    DateTime? createdAt,
  })  : colorValue = colorValue ?? const Color(0xFF00B4D8).toARGB32(),
        createdAt = createdAt ?? DateTime.now();

  Color get color => Color(colorValue);
}
