// GENERATED CODE - DO NOT MODIFY BY HAND
// Manually maintained to support null-safe migration of new fields

part of 'gallery_item.dart';

class GalleryItemAdapter extends TypeAdapter<GalleryItem> {
  @override
  final int typeId = 2;

  @override
  GalleryItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GalleryItem(
      id: fields[0] as String,
      characterId: fields[1] as String,
      filePath: fields[2] as String,
      addedAt: fields[3] == null ? DateTime.now() : fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, GalleryItem obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.characterId)
      ..writeByte(2)
      ..write(obj.filePath)
      ..writeByte(3)
      ..write(obj.addedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GalleryItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
