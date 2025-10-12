// lib/services/recording_service.dart

import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/recording_model.dart';
import '../utils/constants.dart';

class RecordingService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  bool _isRecording = false;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;

  // Get Hive box
  Box<RecordingModel> get _recordingsBox =>
      Hive.box<RecordingModel>(AppConstants.recordingsBox);

  bool get isRecording => _isRecording;

  Future<bool> requestPermissions() async {
    try {
      PermissionStatus status = await Permission.microphone.request();

      if (Platform.isAndroid) {
        PermissionStatus storageStatus = await Permission.storage.request();
        if (!status.isGranted || !storageStatus.isGranted) {
          print('❌ Permissions denied');
          return false;
        }
      }

      print('✅ All permissions granted');
      return true;
    } catch (e) {
      print('❌ Error requesting permissions: $e');
      return false;
    }
  }

  Future<String?> startRecording({String? fileName}) async {
    try {
      bool hasPermission = await requestPermissions();
      if (!hasPermission) {
        throw 'Recording permissions not granted';
      }

      if (_isRecording) {
        print('⚠️ Already recording');
        return null;
      }

      Directory appDir = await getApplicationDocumentsDirectory();
      String recordingsDir = '${appDir.path}/recordings';

      Directory(recordingsDir).createSync(recursive: true);

      fileName ??= 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentRecordingPath = '$recordingsDir/$fileName';

      print('📁 Recording path: $_currentRecordingPath');

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

        print('✅ Recording started: $_currentRecordingPath');
        return _currentRecordingPath;
      } else {
        throw 'Recording permission not granted';
      }
    } catch (e) {
      print('❌ Error starting recording: $e');
      return null;
    }
  }

  Future<String?> stopRecording() async {
    try {
      print('🛑 stopRecording called');
      print('   isRecording: $_isRecording');
      print('   currentPath: $_currentRecordingPath');

      if (!_isRecording) {
        print('⚠️ Not currently recording');
        return _currentRecordingPath;
      }

      String? path = await _audioRecorder.stop();
      _isRecording = false;

      final finalPath = path ?? _currentRecordingPath;
      print('✅ Recording stopped: $finalPath');

      return finalPath;
    } catch (e) {
      print('❌ Error stopping recording: $e');
      return null;
    }
  }

  Future<void> pauseRecording() async {
    if (_isRecording) {
      await _audioRecorder.pause();
    }
  }

  Future<void> resumeRecording() async {
    if (_isRecording) {
      await _audioRecorder.resume();
    }
  }

  int getRecordingDuration() {
    if (_recordingStartTime == null) return 0;
    return DateTime.now().difference(_recordingStartTime!).inSeconds;
  }

  // SAVE TO BOTH LOCAL AND CLOUD
  Future<RecordingModel> saveRecordingMetadata({
    required String userId,
    required String callLogId,
    required String localPath,
    required String contactName,
    required int duration,
    String? transcript,
  }) async {
    try {
      print('💾 saveRecordingMetadata called');
      print('   Path: $localPath');
      print('   Duration: $duration');

      // Check if file exists
      File file = File(localPath);
      if (!await file.exists()) {
        print('❌ File does not exist: $localPath');
        throw 'Recording file not found';
      }

      int fileSize = await file.length();
      print('   File size: $fileSize bytes');

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

      print('   Recording ID: ${recording.id}');

      // Save to LOCAL Hive FIRST
      await _recordingsBox.put(recording.id, recording);
      print('✅ Saved to local Hive');

      // Save to Firestore
      try {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(userId)
            .collection(AppConstants.recordingsCollection)
            .doc(recording.id)
            .set(recording.toMap());
        print('✅ Saved to Firestore');
      } catch (e) {
        print('⚠️ Firestore save failed (but local saved): $e');
      }

      return recording;
    } catch (e) {
      print('❌ Error saving recording metadata: $e');
      throw 'Error saving recording metadata: $e';
    }
  }

  // GET FROM LOCAL HIVE (always available)
  Future<List<RecordingModel>> getRecordings(String userId) async {
    try {
      print('📂 Getting recordings from local storage');

      // Get from local Hive
      List<RecordingModel> localRecordings = _recordingsBox.values.toList();
      print('   Found ${localRecordings.length} local recordings');

      // Sort by date
      localRecordings.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

      // Try to sync from Firestore in background (don't wait)
      _syncRecordingsFromCloud(userId);

      return localRecordings;
    } catch (e) {
      print('❌ Error fetching recordings: $e');
      return [];
    }
  }

  // Background sync from Firestore
  Future<void> _syncRecordingsFromCloud(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.recordingsCollection)
          .get();

      for (var doc in snapshot.docs) {
        try {
          RecordingModel recording =
              RecordingModel.fromMap(doc.data() as Map<String, dynamic>);

          // Only save if not already in local
          if (_recordingsBox.get(recording.id) == null) {
            await _recordingsBox.put(recording.id, recording);
            print('📥 Synced recording: ${recording.id}');
          }
        } catch (e) {
          print('⚠️ Error syncing recording: $e');
        }
      }
    } catch (e) {
      print('⚠️ Cloud sync failed: $e');
    }
  }

  // DELETE FROM BOTH
  Future<void> deleteRecording({
    required String userId,
    required String recordingId,
    required String localPath,
  }) async {
    try {
      print('🗑️ Deleting recording: $recordingId');

      // Delete local file
      File file = File(localPath);
      if (await file.exists()) {
        await file.delete();
        print('✅ Local file deleted');
      }

      // Delete from Hive
      await _recordingsBox.delete(recordingId);
      print('✅ Deleted from Hive');

      // Delete from Firestore
      try {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(userId)
            .collection(AppConstants.recordingsCollection)
            .doc(recordingId)
            .delete();
        print('✅ Deleted from Firestore');
      } catch (e) {
        print('⚠️ Firestore delete failed: $e');
      }
    } catch (e) {
      throw 'Error deleting recording: $e';
    }
  }

  Future<void> dispose() async {
    if (_isRecording) {
      await stopRecording();
    }
    await _audioRecorder.dispose();
  }
}
