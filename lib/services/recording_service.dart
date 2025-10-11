// lib/services/recording_service.dart

import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/recording_model.dart';
import '../utils/constants.dart';

class RecordingService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  bool _isRecording = false;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;

  // Getters
  bool get isRecording => _isRecording;

  // Request permissions
  Future<bool> requestPermissions() async {
    PermissionStatus status = await Permission.microphone.request();

    if (Platform.isAndroid) {
      PermissionStatus storageStatus = await Permission.storage.request();
      return status.isGranted && storageStatus.isGranted;
    }

    return status.isGranted;
  }

  // Start recording
  Future<String?> startRecording({String? fileName}) async {
    try {
      // Check permissions
      bool hasPermission = await requestPermissions();
      if (!hasPermission) {
        throw 'Recording permissions not granted';
      }

      // Check if already recording
      if (_isRecording) {
        print('Already recording');
        return null;
      }

      // Get directory
      Directory appDir = await getApplicationDocumentsDirectory();
      String recordingsDir = '${appDir.path}/recordings';

      // Create recordings directory if it doesn't exist
      Directory(recordingsDir).createSync(recursive: true);

      // Generate file path
      fileName ??= 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentRecordingPath = '$recordingsDir/$fileName';

      // Start recording
      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: _currentRecordingPath!,
        );

        _isRecording = true;
        _recordingStartTime = DateTime.now();

        print('Recording started: $_currentRecordingPath');
        return _currentRecordingPath;
      } else {
        throw 'Recording permission not granted';
      }
    } catch (e) {
      print('Error starting recording: $e');
      return null;
    }
  }

  // Stop recording
  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) {
        print('Not currently recording');
        return null;
      }

      String? path = await _audioRecorder.stop();
      _isRecording = false;

      print('Recording stopped: $path');
      return path ?? _currentRecordingPath;
    } catch (e) {
      print('Error stopping recording: $e');
      return null;
    }
  }

  // Pause recording
  Future<void> pauseRecording() async {
    if (_isRecording) {
      await _audioRecorder.pause();
    }
  }

  // Resume recording
  Future<void> resumeRecording() async {
    if (_isRecording) {
      await _audioRecorder.resume();
    }
  }

  // Get recording duration
  int getRecordingDuration() {
    if (_recordingStartTime == null) return 0;
    return DateTime.now().difference(_recordingStartTime!).inSeconds;
  }

  // Save recording metadata (LOCAL ONLY - NO FIREBASE STORAGE)
  Future<RecordingModel> saveRecordingMetadata({
    required String userId,
    required String callLogId,
    required String localPath,
    required String contactName,
    required int duration,
    String? transcript,
  }) async {
    try {
      // Get file size
      File file = File(localPath);
      int fileSize = await file.length();

      RecordingModel recording = RecordingModel(
        id: _uuid.v4(),
        callLogId: callLogId,
        localPath: localPath,
        contactName: contactName,
        recordedAt: DateTime.now(),
        duration: duration,
        transcript: transcript,
        fileSize: fileSize,
      );

      // Save to Firestore (metadata only, not the file)
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.recordingsCollection)
          .doc(recording.id)
          .set(recording.toMap());

      return recording;
    } catch (e) {
      throw 'Error saving recording metadata: $e';
    }
  }

  // Get all recordings for a user
  Future<List<RecordingModel>> getRecordings(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.recordingsCollection)
          .orderBy('recordedAt', descending: true)
          .get();

      return snapshot.docs
          .map(
            (doc) => RecordingModel.fromMap(doc.data() as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw 'Error fetching recordings: $e';
    }
  }

  // Delete recording
  Future<void> deleteRecording({
    required String userId,
    required String recordingId,
    required String localPath,
    String? cloudUrl,
  }) async {
    try {
      // Delete local file
      File file = File(localPath);
      if (await file.exists()) {
        await file.delete();
      }

      // Delete from Firestore
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.recordingsCollection)
          .doc(recordingId)
          .delete();
    } catch (e) {
      throw 'Error deleting recording: $e';
    }
  }

  // Dispose
  Future<void> dispose() async {
    if (_isRecording) {
      await stopRecording();
    }
    await _audioRecorder.dispose();
  }
}
