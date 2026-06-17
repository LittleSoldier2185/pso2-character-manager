import 'package:flutter/material.dart';

class CollectionData {
  final String id;
  String name;
  String description;
  int? accentColorValue;
  String? thumbnailPath;
  final DateTime createdAt;

  CollectionData({
    required this.id,
    required this.name,
    this.description = '',
    this.accentColorValue,
    this.thumbnailPath,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Color? get accentColor =>
      accentColorValue != null ? Color(accentColorValue!) : null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'accentColorValue': accentColorValue,
    'thumbnailPath': thumbnailPath,
    'createdAt': createdAt.toIso8601String(),
  };

  factory CollectionData.fromJson(Map<String, dynamic> j) => CollectionData(
    id: j['id'] as String,
    name: j['name'] as String,
    description: (j['description'] as String?) ?? '',
    accentColorValue: j['accentColorValue'] as int?,
    thumbnailPath: j['thumbnailPath'] as String?,
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
}
