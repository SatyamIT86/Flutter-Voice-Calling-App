// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'call_log_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CallLogModelAdapter extends TypeAdapter<CallLogModel> {
  @override
  final int typeId = 1;

  @override
  CallLogModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    // Parse callType safely inline
    CallType parseCallType(String type) {
      switch (type.toLowerCase()) {
        case 'incoming':
          return CallType.incoming;
        case 'outgoing':
          return CallType.outgoing;
        case 'missed':
          return CallType.missed;
        default:
          return CallType.outgoing;
      }
    }

    return CallLogModel(
      id: fields[0] as String,
      callerId: fields[1] as String,
      callerName: fields[2] as String,
      receiverId: fields[3] as String,
      receiverName: fields[4] as String,
      timestamp: fields[6] as DateTime,
      duration: fields[7] as int,
      recordingUrl: fields[8] as String?,
      transcript: fields[9] as String?,
      callTypeEnum: parseCallType(fields[5] as String? ?? 'outgoing'),
      hasTranscript: fields[10] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, CallLogModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.callerId)
      ..writeByte(2)
      ..write(obj.callerName)
      ..writeByte(3)
      ..write(obj.receiverId)
      ..writeByte(4)
      ..write(obj.receiverName)
      ..writeByte(5)
      ..write(obj.callType)
      ..writeByte(6)
      ..write(obj.timestamp)
      ..writeByte(7)
      ..write(obj.duration)
      ..writeByte(8)
      ..write(obj.recordingUrl)
      ..writeByte(9)
      ..write(obj.transcript);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CallLogModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
