// lib/services/call_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/call_state_model.dart';
import '../utils/constants.dart';

class CallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection for active calls
  static const String activeCallsCollection = 'active_calls';

  // Initiate a call
  Future<CallStateModel> initiateCall({
    required String callerId,
    required String callerName,
    required String receiverId,
    required String receiverName,
    required String channelName,
  }) async {
    try {
      final call = CallStateModel(
        id: channelName,
        callerId: callerId,
        callerName: callerName,
        receiverId: receiverId,
        receiverName: receiverName,
        channelName: channelName,
        status: CallStatus.ringing,
        timestamp: DateTime.now(),
      );

      // Store in Firestore
      await _firestore
          .collection(activeCallsCollection)
          .doc(call.id)
          .set(call.toMap());

      return call;
    } catch (e) {
      throw 'Error initiating call: $e';
    }
  }

  // Listen for incoming calls for a specific user
  Stream<List<CallStateModel>> listenForIncomingCalls(String userId) {
    return _firestore
        .collection(activeCallsCollection)
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CallStateModel.fromMap(doc.data()))
          .toList();
    });
  }

  // Accept a call
  Future<void> acceptCall(String callId) async {
    try {
      await _firestore
          .collection(activeCallsCollection)
          .doc(callId)
          .update({'status': 'accepted'});
    } catch (e) {
      throw 'Error accepting call: $e';
    }
  }

  // Reject a call
  Future<void> rejectCall(String callId) async {
    try {
      await _firestore
          .collection(activeCallsCollection)
          .doc(callId)
          .update({'status': 'rejected'});

      // Delete after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        _firestore.collection(activeCallsCollection).doc(callId).delete();
      });
    } catch (e) {
      throw 'Error rejecting call: $e';
    }
  }

  // End a call
  Future<void> endCall(String callId) async {
    try {
      await _firestore.collection(activeCallsCollection).doc(callId).delete();
    } catch (e) {
      throw 'Error ending call: $e';
    }
  }

  // Listen to call status changes (for caller)
  Stream<CallStateModel?> listenToCallStatus(String callId) {
    return _firestore
        .collection(activeCallsCollection)
        .doc(callId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return CallStateModel.fromMap(snapshot.data()!);
    });
  }

  // Mark call as missed if not answered in 30 seconds
  Future<void> markAsMissed(String callId) async {
    try {
      final doc =
          await _firestore.collection(activeCallsCollection).doc(callId).get();

      if (doc.exists && doc.data()?['status'] == 'ringing') {
        await _firestore
            .collection(activeCallsCollection)
            .doc(callId)
            .update({'status': 'missed'});

        // Delete after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          _firestore.collection(activeCallsCollection).doc(callId).delete();
        });
      }
    } catch (e) {
      print('Error marking as missed: $e');
    }
  }
}
