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
  @HiveField(10) // new field
  final bool hasTranscript;

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
    required this.hasTranscript, // new required field
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
    try {
      CallType type;
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
          print('⚠️ Unknown call type: $callTypeStr, defaulting to outgoing');
          type = CallType.outgoing;
      }

      DateTime timestamp;
      try {
        timestamp = DateTime.parse(
            map['timestamp'] ?? DateTime.now().toIso8601String());
      } catch (e) {
        print('⚠️ Invalid timestamp, using current time');
        timestamp = DateTime.now();
      }

      int duration;
      try {
        duration = (map['duration'] ?? 0) is int
            ? map['duration']
            : int.tryParse(map['duration'].toString()) ?? 0;
        if (duration < 0) duration = 0;
      } catch (e) {
        print('⚠️ Invalid duration, defaulting to 0');
        duration = 0;
      }

      return CallLogModel(
        id: map['id']?.toString() ?? '',
        callerId: map['callerId']?.toString() ?? '',
        callerName: map['callerName']?.toString() ?? 'Unknown',
        receiverId: map['receiverId']?.toString() ?? '',
        receiverName: map['receiverName']?.toString() ?? 'Unknown',
        callTypeEnum: type,
        timestamp: timestamp,
        duration: duration,
        recordingUrl: map['recordingUrl']?.toString(),
        transcript: map['transcript']?.toString(),
        hasTranscript: map['hasTranscript'] ?? false, // new field
      );
    } catch (e) {
      print('❌ Critical error creating CallLogModel: $e');
      return CallLogModel(
        id: 'error_${DateTime.now().millisecondsSinceEpoch}',
        callerId: 'unknown',
        callerName: 'Unknown',
        receiverId: 'unknown',
        receiverName: 'Unknown',
        callTypeEnum: CallType.outgoing,
        timestamp: DateTime.now(),
        duration: 0,
        hasTranscript: false, // new field
      );
    }
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
      hasTranscript: hasTranscript ?? this.hasTranscript, // new field
    );
  }
}
