// lib/models/recording_model.dart

import 'package:hive/hive.dart';

part 'recording_model.g.dart';

@HiveType(typeId: 2) // ADD HIVE ANNOTATION
class RecordingModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String callLogId;

  @HiveField(2)
  final String localPath;

  @HiveField(3)
  final String? cloudUrl;

  @HiveField(4)
  final String contactName;

  @HiveField(5)
  final DateTime recordedAt;

  @HiveField(6)
  final int duration;

  @HiveField(7)
  final String? transcript;

  @HiveField(8)
  final int fileSize;

  RecordingModel({
    required this.id,
    required this.callLogId,
    required this.localPath,
    this.cloudUrl,
    required this.contactName,
    required this.recordedAt,
    required this.duration,
    this.transcript,
    required this.fileSize,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'callLogId': callLogId,
      'localPath': localPath,
      'cloudUrl': cloudUrl,
      'contactName': contactName,
      'recordedAt': recordedAt.toIso8601String(),
      'duration': duration,
      'transcript': transcript,
      'fileSize': fileSize,
    };
  }

  factory RecordingModel.fromMap(Map<String, dynamic> map) {
    return RecordingModel(
      id: map['id'] ?? '',
      callLogId: map['callLogId'] ?? '',
      localPath: map['localPath'] ?? '',
      cloudUrl: map['cloudUrl'],
      contactName: map['contactName'] ?? '',
      recordedAt:
          DateTime.parse(map['recordedAt'] ?? DateTime.now().toIso8601String()),
      duration: map['duration'] ?? 0,
      transcript: map['transcript'],
      fileSize: map['fileSize'] ?? 0,
    );
  }

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024)
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDuration {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
