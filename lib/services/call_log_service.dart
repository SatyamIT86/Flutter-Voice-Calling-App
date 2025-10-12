// lib/services/call_log_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/call_log_model.dart';
import '../utils/constants.dart';

class CallLogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get Hive box
  Box<CallLogModel> get _callLogsBox =>
      Hive.box<CallLogModel>(AppConstants.callLogsBox);

  // SAVE TO BOTH LOCAL AND CLOUD
  Future<void> saveCallLog(CallLogModel callLog, String userId) async {
    try {
      print('💾 Saving call log: ${callLog.id}');
      print('   Duration: ${callLog.duration} seconds');
      print('   Type: ${callLog.callType}');

      // Save to LOCAL Hive FIRST (always works)
      await _callLogsBox.put(callLog.id, callLog);
      print('✅ Saved to local Hive');

      // Save to Firestore (might fail if offline)
      try {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(userId)
            .collection(AppConstants.callLogsCollection)
            .doc(callLog.id)
            .set(callLog.toMap(), SetOptions(merge: true));
        print('✅ Saved to Firestore');
      } catch (e) {
        print('⚠️ Firestore save failed (but local saved): $e');
      }
    } catch (e) {
      print('❌ Error saving call log: $e');
      throw 'Error saving call log: $e';
    }
  }

  // GET FROM LOCAL HIVE (always available)
  Future<List<CallLogModel>> getCallLogs(String userId) async {
    try {
      print('📂 Getting call logs from local storage');

      // Get from local Hive
      List<CallLogModel> localCallLogs = _callLogsBox.values.toList();
      print('   Found ${localCallLogs.length} local call logs');

      // Sort by date
      localCallLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Try to sync from Firestore in background (don't wait)
      _syncCallLogsFromCloud(userId);

      return localCallLogs;
    } catch (e) {
      print('❌ Error fetching call logs: $e');
      return [];
    }
  }

  // Background sync from Firestore
  Future<void> _syncCallLogsFromCloud(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.callLogsCollection)
          .get();

      for (var doc in snapshot.docs) {
        try {
          CallLogModel callLog =
              CallLogModel.fromMap(doc.data() as Map<String, dynamic>);

          // Only save if not already in local
          if (_callLogsBox.get(callLog.id) == null) {
            await _callLogsBox.put(callLog.id, callLog);
            print('📥 Synced call log: ${callLog.id}');
          }
        } catch (e) {
          print('⚠️ Error syncing call log: $e');
        }
      }
    } catch (e) {
      print('⚠️ Cloud sync failed: $e');
    }
  }

  // DELETE FROM BOTH
  Future<void> deleteCallLog(String callLogId, String userId) async {
    try {
      // Delete from Hive
      await _callLogsBox.delete(callLogId);

      // Delete from Firestore
      try {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(userId)
            .collection(AppConstants.callLogsCollection)
            .doc(callLogId)
            .delete();
      } catch (e) {
        print('⚠️ Firestore delete failed: $e');
      }
    } catch (e) {
      throw 'Error deleting call log: $e';
    }
  }
}
