// lib/models/call_state_model.dart

enum CallStatus { ringing, accepted, rejected, ended, missed }

class CallStateModel {
  final String id;
  final String callerId;
  final String callerName;
  final String receiverId;
  final String receiverName;
  final String channelName;
  final CallStatus status;
  final DateTime timestamp;

  CallStateModel({
    required this.id,
    required this.callerId,
    required this.callerName,
    required this.receiverId,
    required this.receiverName,
    required this.channelName,
    required this.status,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'callerId': callerId,
      'callerName': callerName,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'channelName': channelName,
      'status': status.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory CallStateModel.fromMap(Map<String, dynamic> map) {
    return CallStateModel(
      id: map['id'] ?? '',
      callerId: map['callerId'] ?? '',
      callerName: map['callerName'] ?? '',
      receiverId: map['receiverId'] ?? '',
      receiverName: map['receiverName'] ?? '',
      channelName: map['channelName'] ?? '',
      status: CallStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => CallStatus.ringing,
      ),
      timestamp:
          DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}
