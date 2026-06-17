import 'package:flutter/material.dart';

class TagData {
  final String id;
  String name;
  int colorValue;
  final DateTime createdAt;

  TagData({
    required this.id,
    required this.name,
    int? colorValue,
    DateTime? createdAt,
  })  : colorValue = colorValue ?? const Color(0xFF00B4D8).toARGB32(),
        createdAt = createdAt ?? DateTime.now();

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
    'createdAt': createdAt.toIso8601String(),
  };

  factory TagData.fromJson(Map<String, dynamic> j) => TagData(
    id: j['id'] as String,
    name: j['name'] as String,
    colorValue: j['colorValue'] as int?,
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
}
