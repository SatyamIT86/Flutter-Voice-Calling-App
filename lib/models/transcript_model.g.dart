// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcript_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TranscriptModelAdapter extends TypeAdapter<TranscriptModel> {
  @override
  final int typeId = 2;

  @override
  TranscriptModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TranscriptModel(
      id: fields[0] as String,
      callLogId: fields[1] as String,
      userId: fields[2] as String,
      contactUserId: fields[3] as String,
      contactName: fields[4] as String,
      transcript: fields[5] as String,
      createdAt: fields[6] as DateTime,
      duration: fields[7] as Duration,
      callType: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TranscriptModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.callLogId)
      ..writeByte(2)
      ..write(obj.userId)
      ..writeByte(3)
      ..write(obj.contactUserId)
      ..writeByte(4)
      ..write(obj.contactName)
      ..writeByte(5)
      ..write(obj.transcript)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.duration)
      ..writeByte(8)
      ..write(obj.callType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranscriptModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
