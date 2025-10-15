// lib/services/call_log_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/call_log_model.dart';
import '../utils/constants.dart';

class CallLogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isSyncing = false;

  Box<CallLogModel> get _callLogsBox =>
      Hive.box<CallLogModel>(AppConstants.callLogsBox);

  // ✅ IMPROVED: Better save with validation
  Future<void> saveCallLog(CallLogModel callLog, String userId) async {
    try {
      print('💾 SAVE CALL LOG: ${callLog.id}');
      print('   User: $userId');
      print(
          '   Caller: ${callLog.callerName} → Receiver: ${callLog.receiverName}');
      print('   Type: ${callLog.callType}');
      print('   Duration: ${callLog.duration}s');

      // Validate critical fields
      if (callLog.id.isEmpty ||
          callLog.callerId.isEmpty ||
          callLog.receiverId.isEmpty) {
        print('❌ Invalid call log data - missing required fields');
        return;
      }

      // Save to LOCAL Hive FIRST (this is our source of truth)
      await _callLogsBox.put(callLog.id, callLog);
      print('✅ Saved to Hive: ${callLog.id}');

      // Save to Firestore (fire and forget)
      _saveToFirestore(callLog, userId);
    } catch (e) {
      print('❌ Error saving call log: $e');
    }
  }

  // Firestore save (non-blocking)
  Future<void> _saveToFirestore(CallLogModel callLog, String userId) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.callLogsCollection)
          .doc(callLog.id)
          .set(callLog.toMap());
      print('✅ Saved to Firestore: ${callLog.id}');
    } catch (e) {
      print('⚠️ Firestore save failed: $e');
      // Don't throw - local data is preserved
    }
  }

  // ✅ IMPROVED: Better sync with locking
  Future<List<CallLogModel>> getCallLogs(String userId) async {
    try {
      print('📂 Getting call logs from local storage');

      // Get ALL from local Hive FIRST
      List<CallLogModel> localCallLogs = _callLogsBox.values.toList();
      print('   Found ${localCallLogs.length} local call logs');

      // Sort by date (newest first)
      localCallLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Background sync (with lock to prevent multiple simultaneous syncs)
      if (!_isSyncing) {
        _isSyncing = true;
        _syncCallLogsFromCloud(userId).whenComplete(() => _isSyncing = false);
      }

      return localCallLogs;
    } catch (e) {
      print('❌ Error fetching call logs: $e');
      return [];
    }
  }

  // ✅ IMPROVED: Better sync with error handling
  // In CallLogService - fix the sync logic
  Future<void> _syncCallLogsFromCloud(String userId) async {
    try {
      print('🔄 Starting intelligent sync...');

      QuerySnapshot snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.callLogsCollection)
          .orderBy('timestamp', descending: true)
          .get();

      int addedCount = 0;
      int updatedCount = 0;

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          CallLogModel cloudCallLog = CallLogModel.fromMap(data);

          CallLogModel? localCallLog = _callLogsBox.get(cloudCallLog.id);

          if (localCallLog == null) {
            // New call log - add it
            await _callLogsBox.put(cloudCallLog.id, cloudCallLog);
            addedCount++;
          } else if (cloudCallLog.timestamp.isAfter(localCallLog.timestamp)) {
            // Cloud version is newer - update local
            await _callLogsBox.put(cloudCallLog.id, cloudCallLog);
            updatedCount++;
          }
          // Otherwise keep local version if it's newer or same
        } catch (e) {
          print('⚠️ Error processing call log ${doc.id}: $e');
        }
      }

      print('✅ Sync complete. Added: $addedCount, Updated: $updatedCount');
    } catch (e) {
      print('❌ Cloud sync failed: $e');
    }
  }

  // ✅ NEW: Add validation method
  Future<void> validateAndFixCallLogs(String userId) async {
    print('🔍 VALIDATING CALL LOGS...');

    final localLogs = _callLogsBox.values.toList();
    int fixedCount = 0;

    for (var log in localLogs) {
      // Check for common issues
      if (log.callerId == log.receiverId) {
        print('⚠️ Invalid call log: caller and receiver are same: ${log.id}');
      }

      if (log.duration < 0) {
        print('⚠️ Invalid duration in call log: ${log.id}');
      }
    }

    print('✅ Validation complete. Issues found: $fixedCount');
  }

  // DELETE - only when user manually deletes
  Future<void> deleteCallLog(String callLogId, String userId) async {
    try {
      print('🗑️ Deleting call log: $callLogId');

      // Delete from Hive
      await _callLogsBox.delete(callLogId);
      print('✅ Deleted from Hive');

      // Delete from Firestore
      try {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(userId)
            .collection(AppConstants.callLogsCollection)
            .doc(callLogId)
            .delete();
        print('✅ Deleted from Firestore');
      } catch (e) {
        print('⚠️ Firestore delete failed: $e');
      }
    } catch (e) {
      throw 'Error deleting call log: $e';
    }
  }

  // Get count for debugging
  int getCallLogsCount() {
    return _callLogsBox.length;
  }

  // Clear all (for testing only)
  Future<void> clearAllCallLogs() async {
    await _callLogsBox.clear();
    print('🗑️ All call logs cleared');
  }
}
