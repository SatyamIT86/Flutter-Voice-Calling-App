import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/transcript_model.dart';

class TranscriptService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;
  String _currentTranscript = '';
  Function(String)? _onTranscriptUpdate;
  String? _currentCallId;

  Future<bool> initializeSpeech() async {
    try {
      bool available = await _speech.initialize(
        onError: (error) => print('Speech error: $error'),
        onStatus: (status) => print('Speech status: $status'),
      );
      return available;
    } catch (e) {
      print('Error initializing speech: $e');
      return false;
    }
  }

  void startListening({
    required String callId,
    required Function(String) onTranscriptUpdate,
  }) {
    _currentCallId = callId;
    _onTranscriptUpdate = onTranscriptUpdate;
    _currentTranscript = '';

    _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          _currentTranscript += ' ${result.recognizedWords}';
          _onTranscriptUpdate?.call(_currentTranscript.trim());
        } else {
          String partialText = result.recognizedWords;
          _onTranscriptUpdate
              ?.call('${_currentTranscript.trim()} $partialText');
        }
      },
      listenFor: Duration(minutes: 30),
      pauseFor: Duration(seconds: 3),
      partialResults: true,
      localeId: 'en_US',
    );

    _isListening = true;
  }

  void stopListening() {
    _speech.stop();
    _isListening = false;
    _currentCallId = null;
  }

  bool get isListening => _isListening;

  Future<void> saveTranscript({
    required String userId,
    required String callLogId,
    required String contactUserId,
    required String contactName,
    required String transcript,
    required Duration duration,
    String? callType,
  }) async {
    try {
      final transcriptId = '${callLogId}_transcript';

      final transcriptModel = TranscriptModel(
        id: transcriptId,
        callLogId: callLogId,
        userId: userId,
        contactUserId: contactUserId,
        contactName: contactName,
        transcript: transcript,
        createdAt: DateTime.now(),
        duration: duration,
        callType: callType,
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('transcripts')
          .doc(transcriptId)
          .set(transcriptModel.toMap());

      print('✅ Transcript saved: $transcriptId');
    } catch (e) {
      print('❌ Error saving transcript: $e');
      throw e;
    }
  }

  Future<List<TranscriptModel>> getTranscripts(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('transcripts')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => TranscriptModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting transcripts: $e');
      return [];
    }
  }

  Future<void> deleteTranscript(String userId, String transcriptId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('transcripts')
          .doc(transcriptId)
          .delete();
    } catch (e) {
      print('Error deleting transcript: $e');
      throw e;
    }
  }

  void dispose() {
    if (_isListening) {
      _speech.stop();
    }
    _isListening = false;
  }
}
