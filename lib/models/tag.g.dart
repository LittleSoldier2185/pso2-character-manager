// GENERATED CODE - DO NOT MODIFY BY HAND
// Manually maintained to support null-safe migration of new fields

part of 'tag.dart';

class TagAdapter extends TypeAdapter<Tag> {
  @override
  final int typeId = 3;

  @override
  Tag read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Tag(
      id: fields[0] as String,
      name: fields[1] as String,
      colorValue: fields[2] == null ? const Color(0xFF00B4D8).toARGB32() : fields[2] as int,
      createdAt: fields[3] == null ? DateTime.now() : fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Tag obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.colorValue)
      ..writeByte(3)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TagAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
