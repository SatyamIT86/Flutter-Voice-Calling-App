// Free Transcription Service (Integrated directly)
import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:speech_to_text/speech_to_text.dart' as stt;

class FreeTranscriptionService {
  IO.Socket? _socket;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _currentTranscript = '';
  Timer? _transcriptTimer;
  bool _isConnected = false;

  Function(String transcript, String userId, String userName)? onTranscript;

  static const String _serverUrl =
      "http://localhost:3000"; // Change to your server URL
  // bool get isConnected => _socket?.connected == true;
  // Add this getter to fix the error

  Future<bool> initialize() async {
    try {
      print('🎤 Initializing free transcription service...');

      // Initialize socket
      _socket = IO.io(_serverUrl, <String, dynamic>{
        'transports': ['websocket', 'polling'],
        'autoConnect': true,
      });

      _socket!.on('connect', (_) {
        print('✅ Connected to free transcription server');
        _isConnected = true;
      });

      _socket!.on('disconnect', (_) {
        print('🔌 Disconnected from transcription server');
        _isConnected = false;
      });

      _socket!.on('connect_error', (error) {
        print('❌ Socket connection error: $error');
        _isConnected = false;
      });

      _socket!.on('new-transcript', (data) {
        final transcript = data['text'];
        final userId = data['userId'];
        final userName = data['userName'];
        print('📝 Received transcript: $userName - $transcript');
        onTranscript?.call(transcript, userId, userName);
      });

      _socket!.on('call-transcripts', (data) {
        print('📝 Received existing transcripts: ${data.length}');
      });

      _socket!.on('error', (error) {
        print('❌ Socket error: $error');
      });

      // Initialize speech recognition
      bool speechAvailable = await _speech.initialize(
        onError: (error) => print('🎤 Speech error: $error'),
        onStatus: (status) => print('🎤 Speech status: $status'),
      );

      print('🎤 Speech recognition available: $speechAvailable');
      return speechAvailable;
    } catch (e) {
      print('❌ Error initializing transcription: $e');
      _isConnected = false;
      return false;
    }
  }

  void joinCall(String callId, String userId, String userName) {
    if (!_isConnected) {
      print('⚠️ Socket not connected, cannot join call');
      _attemptReconnection(callId, userId, userName);
      return;
    }

    _socket?.emit('join-call', {
      'callId': callId,
      'userId': userId,
      'userName': userName,
    });
    print('🔊 Joined transcription for call: $callId');
  }

  void _attemptReconnection(String callId, String userId, String userName) {
    print('🔄 Attempting to reconnect socket...');
    _socket?.connect();

    // Try to join call after a delay
    Future.delayed(Duration(seconds: 2), () {
      if (_isConnected) {
        joinCall(callId, userId, userName);
      } else {
        print('❌ Failed to reconnect socket');
      }
    });
  }

  Future<void> startListening(
      String callId, String userId, String userName) async {
    if (_isListening) {
      print('⚠️ Already listening');
      return;
    }

    try {
      bool available = await _speech.isAvailable;
      if (!available) {
        print('❌ Speech recognition not available');
        return;
      }

      await _speech.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            _currentTranscript = result.recognizedWords;
            print('🎤 Speech result: $_currentTranscript');

            // Send partial results
            _sendTranscriptUpdate(callId, userId, userName, _currentTranscript,
                result.finalResult);
          }
        },
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        listenFor: Duration(minutes: 30),
        pauseFor: Duration(seconds: 5),
        onSoundLevelChange: (level) {
          // Optional: Handle sound level changes
        },
      );

      _isListening = true;
      print('🎤 Started listening for transcription');
    } catch (e) {
      print('❌ Error starting speech recognition: $e');
    }
  }

  void _sendTranscriptUpdate(String callId, String userId, String userName,
      String transcript, bool isFinal) {
    if (!_isConnected) {
      print('⚠️ Socket not connected, cannot send transcript');
      return;
    }

    _socket?.emit('transcript-update', {
      'callId': callId,
      'userId': userId,
      'userName': userName,
      'transcript': transcript,
      'isFinal': isFinal,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> stopListening(
      String callId, String userId, String userName) async {
    if (!_isListening) return;

    try {
      await _speech.stop();
      _isListening = false;

      // Send final transcript if we have one
      if (_currentTranscript.isNotEmpty) {
        _sendTranscriptUpdate(
            callId, userId, userName, _currentTranscript, true);
        _currentTranscript = '';
      }

      print('🛑 Stopped transcription');
    } catch (e) {
      print('❌ Error stopping transcription: $e');
    }
  }

  void leaveCall(String callId, String userId) {
    if (_isConnected) {
      _socket?.emit('leave-call', {
        'callId': callId,
        'userId': userId,
      });
    }
    print('🚪 Left transcription for call: $callId');
  }

  void dispose() {
    _transcriptTimer?.cancel();
    _speech.stop();
    _socket?.disconnect();
    _socket?.dispose();
    _isConnected = false;
    _isListening = false;
    print('🧹 Transcription service disposed');
  }
}
