// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'affirmation.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AffirmationAdapter extends TypeAdapter<Affirmation> {
  @override
  final int typeId = 1;

  @override
  Affirmation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Affirmation(
      id: fields[0] as String,
      message: fields[1] as String,
      category: fields[2] as String,
      createdAt: fields[3] as DateTime,
      audioPath: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Affirmation obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.message)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.audioPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AffirmationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
