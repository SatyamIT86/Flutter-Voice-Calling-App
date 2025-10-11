// lib/models/call_log_model.dart

enum CallType { incoming, outgoing, missed }

class CallLogModel {
  final String id;
  final String callerId;
  final String callerName;
  final String receiverId;
  final String receiverName;
  final CallType callType;
  final DateTime timestamp;
  final int duration; // in seconds
  final String? recordingUrl;
  final String? transcript;

  CallLogModel({
    required this.id,
    required this.callerId,
    required this.callerName,
    required this.receiverId,
    required this.receiverName,
    required this.callType,
    required this.timestamp,
    required this.duration,
    this.recordingUrl,
    this.transcript,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'callerId': callerId,
      'callerName': callerName,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'callType': callType.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
      'duration': duration,
      'recordingUrl': recordingUrl,
      'transcript': transcript,
    };
  }

  factory CallLogModel.fromMap(Map<String, dynamic> map) {
    return CallLogModel(
      id: map['id'] ?? '',
      callerId: map['callerId'] ?? '',
      callerName: map['callerName'] ?? '',
      receiverId: map['receiverId'] ?? '',
      receiverName: map['receiverName'] ?? '',
      callType: CallType.values.firstWhere(
        (e) => e.toString().split('.').last == map['callType'],
        orElse: () => CallType.outgoing,
      ),
      timestamp: DateTime.parse(
        map['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
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
    CallType? callType,
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
      callType: callType ?? this.callType,
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
      recordingUrl: recordingUrl ?? this.recordingUrl,
      transcript: transcript ?? this.transcript,
    );
  }
}
