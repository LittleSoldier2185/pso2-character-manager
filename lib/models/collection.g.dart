// GENERATED CODE - DO NOT MODIFY BY HAND
// Manually maintained to support null-safe migration of new fields

part of 'collection.dart';

class CollectionAdapter extends TypeAdapter<Collection> {
  @override
  final int typeId = 1;

  @override
  Collection read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Collection(
      id: fields[0] as String,
      name: fields[1] as String,
      createdAt: fields[2] as DateTime?,
      thumbnailPath: fields[3] == null ? null : fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Collection obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.thumbnailPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollectionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
