// GENERATED CODE - DO NOT MODIFY BY HAND
// Manually maintained to support null-safe migration of new fields

part of 'character.dart';

class CharacterAdapter extends TypeAdapter<Character> {
  @override
  final int typeId = 0;

  @override
  Character read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    // Migrate legacy single collectionId → collectionIds list
    final legacyColId = fields[7] as String?;
    List<String> collectionIds;
    if (fields[12] != null) {
      collectionIds = (fields[12] as List).cast<String>();
    } else if (legacyColId != null) {
      collectionIds = [legacyColId];
    } else {
      collectionIds = [];
    }
    return Character(
      id: fields[0] as String,
      name: fields[1] as String,
      race: fields[2] as String,
      gender: fields[3] as String,
      characterFilePath: fields[4] as String,
      thumbnailPath: fields[5] as String?,
      tags: (fields[6] as List?)?.cast<String>(),
      collectionId: fields[7] as String?,
      createdAt: fields[8] as DateTime?,
      isApplied: fields[9] == null ? false : fields[9] as bool,
      slotNumber: fields[10] as int?,
      description: fields[11] == null ? '' : fields[11] as String,
      collectionIds: collectionIds,
    );
  }

  @override
  void write(BinaryWriter writer, Character obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.race)
      ..writeByte(3)
      ..write(obj.gender)
      ..writeByte(4)
      ..write(obj.characterFilePath)
      ..writeByte(5)
      ..write(obj.thumbnailPath)
      ..writeByte(6)
      ..write(obj.tags)
      ..writeByte(7)
      ..write(obj.collectionId)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.isApplied)
      ..writeByte(10)
      ..write(obj.slotNumber)
      ..writeByte(11)
      ..write(obj.description)
      ..writeByte(12)
      ..write(obj.collectionIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharacterAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
