// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recording_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecordingModelAdapter extends TypeAdapter<RecordingModel> {
  @override
  final int typeId = 2;

  @override
  RecordingModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecordingModel(
      id: fields[0] as String,
      callLogId: fields[1] as String,
      localPath: fields[2] as String,
      cloudUrl: fields[3] as String?,
      contactName: fields[4] as String,
      recordedAt: fields[5] as DateTime,
      duration: fields[6] as int,
      transcript: fields[7] as String?,
      fileSize: fields[8] as int,
    );
  }

  @override
  void write(BinaryWriter writer, RecordingModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.callLogId)
      ..writeByte(2)
      ..write(obj.localPath)
      ..writeByte(3)
      ..write(obj.cloudUrl)
      ..writeByte(4)
      ..write(obj.contactName)
      ..writeByte(5)
      ..write(obj.recordedAt)
      ..writeByte(6)
      ..write(obj.duration)
      ..writeByte(7)
      ..write(obj.transcript)
      ..writeByte(8)
      ..write(obj.fileSize);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecordingModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
