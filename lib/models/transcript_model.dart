// lib/models/transcript_model.dart

import 'package:hive/hive.dart';

part 'transcript_model.g.dart';

@HiveType(typeId: 2) // Make sure typeId is unique
class TranscriptModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String callLogId;

  @HiveField(2)
  final String userId;

  @HiveField(3)
  final String contactUserId;

  @HiveField(4)
  final String contactName;

  @HiveField(5)
  final String transcript;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final Duration duration;

  @HiveField(8)
  final String? callType;

  TranscriptModel({
    required this.id,
    required this.callLogId,
    required this.userId,
    required this.contactUserId,
    required this.contactName,
    required this.transcript,
    required this.createdAt,
    required this.duration,
    this.callType,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'callLogId': callLogId,
      'userId': userId,
      'contactUserId': contactUserId,
      'contactName': contactName,
      'transcript': transcript,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'durationInSeconds': duration.inSeconds,
      'callType': callType,
    };
  }

  factory TranscriptModel.fromMap(Map<String, dynamic> map) {
    return TranscriptModel(
      id: map['id'],
      callLogId: map['callLogId'],
      userId: map['userId'],
      contactUserId: map['contactUserId'],
      contactName: map['contactName'],
      transcript: map['transcript'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      duration: Duration(seconds: map['durationInSeconds'] ?? 0),
      callType: map['callType'],
    );
  }

  String get formattedDate {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  String get formattedTime {
    return '${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
