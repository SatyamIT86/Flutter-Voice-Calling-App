// lib/services/call_log_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/call_log_model.dart';
import '../utils/constants.dart';

class CallLogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Box<CallLogModel> get _callLogsBox =>
      Hive.box<CallLogModel>(AppConstants.callLogsBox);

  // SAVE - Always add, never replace
  Future<void> saveCallLog(CallLogModel callLog, String userId) async {
    try {
      print('💾 Saving call log: ${callLog.id}');
      print('   Duration: ${callLog.duration} seconds');
      print('   Type: ${callLog.callType}');
      print('   User ID: $userId');

      // Check if already exists locally
      final existingLocal = _callLogsBox.get(callLog.id);
      if (existingLocal != null) {
        print('⚠️ Call log already exists locally, skipping: ${callLog.id}');
        return;
      }

      // Save to LOCAL Hive FIRST
      await _callLogsBox.put(callLog.id, callLog);
      print('✅ Saved to local Hive with ID: ${callLog.id}');
      print('   Total local call logs: ${_callLogsBox.length}');

      // Save to Firestore
      try {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(userId)
            .collection(AppConstants.callLogsCollection)
            .doc(callLog.id)
            .set(callLog.toMap());
        print('✅ Saved to Firestore');
      } catch (e) {
        print('⚠️ Firestore save failed (but local saved): $e');
      }
    } catch (e) {
      print('❌ Error saving call log: $e');
      throw 'Error saving call log: $e';
    }
  }

  // GET - Always return local data (never delete)
  Future<List<CallLogModel>> getCallLogs(String userId) async {
    try {
      print('📂 Getting call logs from local storage');

      // Get ALL from local Hive
      List<CallLogModel> localCallLogs = _callLogsBox.values.toList();
      print('   Found ${localCallLogs.length} local call logs');

      // Sort by date (newest first)
      localCallLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Background sync (don't wait, don't delete)
      _syncCallLogsFromCloud(userId);

      return localCallLogs;
    } catch (e) {
      print('❌ Error fetching call logs: $e');
      return [];
    }
  }

  // Background sync - ONLY ADD new ones, NEVER delete
  Future<void> _syncCallLogsFromCloud(String userId) async {
    try {
      print('🔄 Background sync starting...');

      QuerySnapshot snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.callLogsCollection)
          .get();

      print('   Found ${snapshot.docs.length} call logs in Firestore');

      for (var doc in snapshot.docs) {
        try {
          CallLogModel callLog =
              CallLogModel.fromMap(doc.data() as Map<String, dynamic>);

          // Only ADD if not already in local
          if (_callLogsBox.get(callLog.id) == null) {
            await _callLogsBox.put(callLog.id, callLog);
            print('📥 Synced new call log: ${callLog.id}');
          }
        } catch (e) {
          print('⚠️ Error syncing individual call log: $e');
        }
      }

      print('✅ Sync complete. Total local: ${_callLogsBox.length}');
    } catch (e) {
      print('⚠️ Cloud sync failed: $e');
    }
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
