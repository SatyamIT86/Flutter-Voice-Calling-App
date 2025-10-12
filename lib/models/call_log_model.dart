// lib/models/call_log_model.dart

import 'package:hive/hive.dart';

part 'call_log_model.g.dart';

enum CallType { incoming, outgoing, missed }

@HiveType(typeId: 1)
class CallLogModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String callerId;

  @HiveField(2)
  final String callerName;

  @HiveField(3)
  final String receiverId;

  @HiveField(4)
  final String receiverName;

  @HiveField(5)
  final String callType;

  @HiveField(6)
  final DateTime timestamp;

  @HiveField(7)
  final int duration;

  @HiveField(8)
  final String? recordingUrl;

  @HiveField(9)
  final String? transcript;

  CallLogModel({
    required this.id,
    required this.callerId,
    required this.callerName,
    required this.receiverId,
    required this.receiverName,
    required CallType callTypeEnum,
    required this.timestamp,
    required this.duration,
    this.recordingUrl,
    this.transcript,
  }) : callType = callTypeEnum.name;

  CallType get callTypeEnum {
    switch (callType.toLowerCase()) {
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'callerId': callerId,
      'callerName': callerName,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'callType': callType,
      'timestamp': timestamp.toIso8601String(),
      'duration': duration,
      'recordingUrl': recordingUrl,
      'transcript': transcript,
    };
  }

  factory CallLogModel.fromMap(Map<String, dynamic> map) {
    CallType type;
    try {
      final callTypeStr =
          (map['callType'] ?? 'outgoing').toString().toLowerCase();
      switch (callTypeStr) {
        case 'incoming':
          type = CallType.incoming;
          break;
        case 'outgoing':
          type = CallType.outgoing;
          break;
        case 'missed':
          type = CallType.missed;
          break;
        default:
          type = CallType.outgoing;
      }
    } catch (e) {
      type = CallType.outgoing;
    }

    return CallLogModel(
      id: map['id'] ?? '',
      callerId: map['callerId'] ?? '',
      callerName: map['callerName'] ?? '',
      receiverId: map['receiverId'] ?? '',
      receiverName: map['receiverName'] ?? '',
      callTypeEnum: type,
      timestamp:
          DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      duration: map['duration'] ?? 0,
      recordingUrl: map['recordingUrl'],
      transcript: map['transcript'],
    );
  }

  String get formattedDuration {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  CallLogModel copyWith({
    String? id,
    String? callerId,
    String? callerName,
    String? receiverId,
    String? receiverName,
    CallType? callTypeEnum,
    DateTime? timestamp,
    int? duration,
    String? recordingUrl,
    String? transcript,
  }) {
    return CallLogModel(
      id: id ?? this.id,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      callTypeEnum: callTypeEnum ?? this.callTypeEnum,
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
      recordingUrl: recordingUrl ?? this.recordingUrl,
      transcript: transcript ?? this.transcript,
    );
  }
}
