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
        return _currentRecordingPath;
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

      // Verify file exists
      if (finalPath != null) {
        final file = File(finalPath);
        if (await file.exists()) {
          final size = await file.length();
          print('   File size: $size bytes');
        } else {
          print('⚠️ File does not exist after stopping!');
        }
      }

      return finalPath;
    } catch (e) {
      print('❌ Error stopping recording: $e');
      _isRecording = false;
      return _currentRecordingPath;
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

  // SAVE - Always add, never replace
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
      print('   Contact: $contactName');

      // Verify file exists
      File file = File(localPath);
      if (!await file.exists()) {
        print('❌ File does not exist: $localPath');
        throw 'Recording file not found at: $localPath';
      }

      int fileSize = await file.length();
      print('   File size: $fileSize bytes');

      if (fileSize == 0) {
        print('⚠️ Warning: File size is 0 bytes!');
      }

      final recordingId = _uuid.v4();

      RecordingModel recording = RecordingModel(
        id: recordingId,
        callLogId: callLogId,
        localPath: localPath,
        contactName: contactName,
        recordedAt: DateTime.now(),
        duration: duration,
        transcript: transcript,
        fileSize: fileSize,
      );

      print('   Recording ID: ${recording.id}');

      // Check if already exists
      final existingLocal = _recordingsBox.get(recording.id);
      if (existingLocal != null) {
        print('⚠️ Recording already exists locally: ${recording.id}');
        return existingLocal;
      }

      // Save to LOCAL Hive FIRST
      await _recordingsBox.put(recording.id, recording);
      print('✅ Saved to local Hive with ID: ${recording.id}');
      print('   Total local recordings: ${_recordingsBox.length}');

      // Verify it was saved
      final savedRecording = _recordingsBox.get(recording.id);
      if (savedRecording != null) {
        print('✅ Verified: Recording is in Hive');
      } else {
        print('❌ ERROR: Recording not found in Hive after saving!');
      }

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

  // GET - Always return local data
  Future<List<RecordingModel>> getRecordings(String userId) async {
    try {
      print('📂 Getting recordings from local storage');

      // Get ALL from local Hive
      List<RecordingModel> localRecordings = _recordingsBox.values.toList();
      print('   Found ${localRecordings.length} local recordings');

      // Verify files still exist
      List<RecordingModel> validRecordings = [];
      for (var recording in localRecordings) {
        final file = File(recording.localPath);
        if (await file.exists()) {
          validRecordings.add(recording);
        } else {
          print('⚠️ File missing for recording: ${recording.id}');
        }
      }

      print('   ${validRecordings.length} recordings have valid files');

      // Sort by date (newest first)
      validRecordings.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

      // Background sync
      _syncRecordingsFromCloud(userId);

      return validRecordings;
    } catch (e) {
      print('❌ Error fetching recordings: $e');
      return [];
    }
  }

  // Background sync - ONLY ADD new ones
  Future<void> _syncRecordingsFromCloud(String userId) async {
    try {
      print('🔄 Background sync recordings...');

      QuerySnapshot snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.recordingsCollection)
          .get();

      print('   Found ${snapshot.docs.length} recordings in Firestore');

      for (var doc in snapshot.docs) {
        try {
          RecordingModel recording =
              RecordingModel.fromMap(doc.data() as Map<String, dynamic>);

          // Only ADD if not already in local
          if (_recordingsBox.get(recording.id) == null) {
            await _recordingsBox.put(recording.id, recording);
            print('📥 Synced new recording: ${recording.id}');
          }
        } catch (e) {
          print('⚠️ Error syncing individual recording: $e');
        }
      }

      print('✅ Sync complete. Total local: ${_recordingsBox.length}');
    } catch (e) {
      print('⚠️ Cloud sync failed: $e');
    }
  }

  // DELETE - only when user manually deletes
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

  // Get count for debugging
  int getRecordingsCount() {
    return _recordingsBox.length;
  }

  // Clear all (for testing only)
  Future<void> clearAllRecordings() async {
    await _recordingsBox.clear();
    print('🗑️ All recordings cleared');
  }

  Future<void> dispose() async {
    if (_isRecording) {
      await stopRecording();
    }
    await _audioRecorder.dispose();
  }
}
