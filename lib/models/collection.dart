import 'package:flutter/material.dart';
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

  /// Optional short description for this collection.
  @HiveField(4)
  String description;

  /// Accent colour stored as ARGB int (Color.toARGB32()).
  /// Null means use the app's global accent.
  @HiveField(5)
  int? accentColorValue;

  Collection({
    required this.id,
    required this.name,
    DateTime? createdAt,
    this.thumbnailPath,
    this.description = '',
    this.accentColorValue,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Returns the collection's custom accent colour, or null to use app default.
  Color? get accentColor =>
      accentColorValue != null ? Color(accentColorValue!) : null;
}
