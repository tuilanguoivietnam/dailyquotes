// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite_affirmation.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FavoriteAffirmationAdapter extends TypeAdapter<FavoriteAffirmation> {
  @override
  final int typeId = 2;

  @override
  FavoriteAffirmation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FavoriteAffirmation(
      id: fields[0] as String,
      message: fields[1] as String,
      category: fields[2] as String,
      createdAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, FavoriteAffirmation obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.message)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoriteAffirmationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
