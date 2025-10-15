import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../services/agora_service.dart';
import '../../services/speech_service.dart';
// import '../../services/recording_service.dart';
import '../../services/auth_service.dart';
import '../../services/call_service.dart';
import '../../utils/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/call_log_model.dart';
import '../../models/call_state_model.dart';
import 'package:uuid/uuid.dart';
import '../../services/call_log_service.dart';

// Free Transcription Service (Integrated directly)
class FreeTranscriptionService {
  IO.Socket? _socket;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _currentTranscript = '';
  Timer? _transcriptTimer;

  Function(String transcript, String userId, String userName)? onTranscript;

  static const String _serverUrl =
      "http://localhost:3000"; // Change to your server URL

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

      _socket!.on('disconnect', (_) {
        print('🔌 Disconnected from transcription server');
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
      return false;
    }
  }

  void joinCall(String callId, String userId, String userName) {
    if (_socket?.connected != true) {
      print('⚠️ Socket not connected, cannot join call');
      return;
    }

    _socket?.emit('join-call', {
      'callId': callId,
      'userId': userId,
      'userName': userName,
    });
    print('🔊 Joined transcription for call: $callId');
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
    if (_socket?.connected != true) {
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
    _socket?.emit('leave-call', {
      'callId': callId,
      'userId': userId,
    });
    print('🚪 Left transcription for call: $callId');
  }

  void dispose() {
    _transcriptTimer?.cancel();
    _speech.stop();
    _socket?.disconnect();
    _socket?.dispose();
    print('🧹 Transcription service disposed');
  }
}

class CallScreen extends StatefulWidget {
  final String contactName;
  final String contactUserId;
  final String? channelName;
  final String? callId;
  final bool isIncoming;

  const CallScreen({
    super.key,
    required this.contactName,
    required this.contactUserId,
    this.channelName,
    this.callId,
    this.isIncoming = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _agoraService = AgoraService();
  final _speechService = SpeechService();
  // final _recordingService = RecordingService();
  final _authService = AuthService();
  final _callService = CallService();
  final _firestore = FirebaseFirestore.instance;
  final _callLogService = CallLogService();
  final _uuid = const Uuid();
  final _transcriptionService = FreeTranscriptionService();

  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isCallConnected = false;
  // bool _isRecording = false;
  bool _isSpeechToTextEnabled = false;
  // bool _recordingEnabled = false;
  bool _isInitializing = true;

  String _transcript = '';
  String _callDuration = '00:00';
  Timer? _callTimer;
  int _callSeconds = 0;
  DateTime? _callStartTime;
  String? _recordingPath;
  String? _callLogId;
  StreamSubscription? _callStatusSubscription;

  // Store user info immediately
  String? _currentUserId;
  String? _currentUserName;

  // Transcription variables
  List<Map<String, dynamic>> _transcripts = [];
  String _liveTranscript = '';

  @override
  void initState() {
    super.initState();
    _initializeUserInfo();
    _initializeCall();
    _initializeTranscription();
  }

  @override
  void dispose() {
    print('🔴 Disposing CallScreen');
    _callTimer?.cancel();
    _callStatusSubscription?.cancel();
    _transcriptionService.dispose();

    super.dispose();
  }

  Future<void> _initializeTranscription() async {
    _transcriptionService.onTranscript = (transcript, userId, userName) {
      if (mounted) {
        setState(() {
          _transcripts.add({
            'text': transcript,
            'userId': userId,
            'userName': userName,
            'timestamp': DateTime.now(),
          });
          // Keep only last 20 transcripts to avoid memory issues
          if (_transcripts.length > 20) {
            _transcripts.removeAt(0);
          }
          print('📝 ADDED TRANSCRIPT: $userName - $transcript');
        });
      }
    };

    bool initialized = await _transcriptionService.initialize();
    if (initialized) {
      print('✅ Free transcription service initialized');

      // Test socket connection with better error handling
      await Future.delayed(Duration(seconds: 3));
      if (_transcriptionService._socket?.connected == true) {
        print('🔗 Socket connection verified');
      } else {
        print(
            '⚠️ Socket connection failed - check server URL: ${FreeTranscriptionService._serverUrl}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Transcription server connection failed. Check if server is running.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } else {
      print('❌ Failed to initialize transcription service');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Speech recognition initialization failed'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _updateLiveTranscript() {
    // Show last 5 messages for better readability
    final recentTranscripts =
        _transcripts.reversed.take(5).toList().reversed.toList();
    _liveTranscript = recentTranscripts
        .map((entry) => '${entry['userName']}: ${entry['text']}')
        .join('\n');
  }

  void _initializeUserInfo() {
    final currentUser = _authService.currentUser;
    _currentUserId = currentUser?.uid;
    _currentUserName = currentUser?.displayName ?? 'Unknown';
    print('👤 User Info: ID=$_currentUserId, Name=$_currentUserName');
  }

  Future<void> _initializeCall() async {
    try {
      print('📞 Initializing call...');

      if (_currentUserId == null) {
        throw 'User not logged in';
      }

      await _agoraService.initialize();
      print('✅ Agora initialized');

      // Setup callbacks BEFORE joining
      _agoraService.onUserJoined = (uid, elapsed) async {
        print('👥 User joined: $uid');
        if (!mounted) return;

        setState(() {
          _isCallConnected = true;
          _isInitializing = false;
        });

        _startCallTimer();

        // Start transcription if enabled
        if (_isSpeechToTextEnabled) {
          final callId = widget.callId ?? _callLogId!;
          _transcriptionService.joinCall(
              callId, _currentUserId!, _currentUserName!);
          await _transcriptionService.startListening(
              callId, _currentUserId!, _currentUserName!);
          print('🎤 Transcription started for call: $callId');
        }

        // Start recording if enabled - COMMENTED OUT
        // if (_recordingEnabled) {
        //   await _startRecording();
        // }
      };

      _agoraService.onUserOffline = (uid, reason) {
        print('👋 User left: $uid, reason: $reason');
        _endCall();
      };

      String channelName;
      String callId;

      if (widget.isIncoming) {
        channelName = widget.channelName!;
        callId = widget.callId!;
        _callLogId = callId;
        print('📥 Incoming call - Channel: $channelName, ID: $callId');
      } else {
        channelName =
            _generateChannelName(_currentUserId!, widget.contactUserId);

        final call = await _callService.initiateCall(
          callerId: _currentUserId!,
          callerName: _currentUserName!,
          receiverId: widget.contactUserId,
          receiverName: widget.contactName,
          channelName: channelName,
        );

        callId = call.id;
        _callLogId = callId;
        print('📤 Outgoing call - Channel: $channelName, ID: $callId');

        _callStatusSubscription =
            _callService.listenToCallStatus(callId).listen((callState) {
          if (callState == null) {
            if (mounted && !_isCallConnected) {
              print('❌ Call ended remotely');
              Navigator.pop(context);
            }
          } else if (callState.status == CallStatus.rejected) {
            if (mounted) {
              print('🚫 Call rejected');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Call rejected')),
              );
              Navigator.pop(context);
            }
          }
        });

        // Auto-timeout for outgoing calls
        Future.delayed(const Duration(seconds: 45), () {
          if (!_isCallConnected && mounted) {
            print('⏰ Call timeout - no answer');
            _callService.markAsMissed(callId);
            Navigator.pop(context);
          }
        });
      }

      // Join Agora channel
      await _agoraService.joinChannel(
        channelName: channelName,
        token: '',
        uid: 0,
      );

      print('✅ Joined Agora channel: $channelName');

      setState(() {
        _isInitializing = false;
      });
    } catch (e) {
      print('❌ Error initializing call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  String _generateChannelName(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  void _startCallTimer() {
    if (_callTimer != null && _callTimer!.isActive) {
      print('⚠️ Timer already running');
      return;
    }

    _callStartTime = DateTime.now();
    print('⏱️ Call timer started at ${_callStartTime}');

    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _callSeconds++;
        final minutes = _callSeconds ~/ 60;
        final seconds = _callSeconds % 60;
        _callDuration =
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      });

      // Log every 10 seconds
      if (_callSeconds % 10 == 0) {
        print('⏱️ Call duration: $_callDuration ($_callSeconds seconds)');
      }
    });
  }

  // COMMENTED OUT RECORDING METHODS
  /*
  Future<void> _startRecording() async {
    if (_isRecording) {
      print('⚠️ Already recording');
      return;
    }

    try {
      print('🎙️ Starting recording...');

      _recordingPath = await _recordingService.startRecording(
        fileName:
            'call_${_callLogId}_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );

      if (_recordingPath != null) {
        setState(() => _isRecording = true);
        print('✅ Recording started: $_recordingPath');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recording started'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        print('❌ Recording failed to start - no path returned');
      }
    } catch (e) {
      print('❌ Error starting recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording failed: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) {
      print('⚠️ Not recording');
      return;
    }

    try {
      print('🛑 Stopping recording...');
      final path = await _recordingService.stopRecording();

      setState(() => _isRecording = false);

      if (path != null) {
        print('✅ Recording stopped: $path');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording stopped'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error stopping recording: $e');
    }
  }

  void _toggleRecording() async {
    if (!_isCallConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot record - call not connected')),
        );
      }
      return;
    }

    if (_isRecording) {
      await _stopRecording();
      setState(() => _recordingEnabled = false);
    } else {
      setState(() => _recordingEnabled = true);
      if (_isCallConnected) {
        await _startRecording();
      }
    }
  }
  */

  void _toggleSpeechToText() async {
    if (_isSpeechToTextEnabled) {
      // Turning off
      setState(() {
        _isSpeechToTextEnabled = false;
      });

      final callId = widget.callId ?? _callLogId!;
      await _transcriptionService.stopListening(
          callId, _currentUserId!, _currentUserName!);
      _transcriptionService.leaveCall(callId, _currentUserId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transcription stopped')),
        );
      }
    } else {
      // Turning on
      setState(() {
        _isSpeechToTextEnabled = true;
      });

      if (_isCallConnected) {
        final callId = widget.callId ?? _callLogId!;
        _transcriptionService.joinCall(
            callId, _currentUserId!, _currentUserName!);
        await _transcriptionService.startListening(
            callId, _currentUserId!, _currentUserName!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transcription started')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Wait for call to connect')),
          );
        }
      }
    }
  }

  Future<void> _toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    await _agoraService.muteLocalAudio(_isMuted);
    print('🔇 Mute: $_isMuted');
  }

  Future<void> _toggleSpeaker() async {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    await _agoraService.setSpeakerphone(_isSpeakerOn);
    print('🔊 Speaker: $_isSpeakerOn');
  }

  Widget _buildTranscriptWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.transcribe, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text(
                'Live Transcript',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(width: 8),
              if (_transcripts.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_transcripts.length}',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.all(8),
              child: _transcripts.isEmpty
                  ? Center(
                      child: Text(
                        'Speak to see transcript here...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.builder(
                      reverse: true, // Newest at bottom
                      itemCount: _transcripts.length,
                      itemBuilder: (context, index) {
                        final transcript =
                            _transcripts.reversed.toList()[index];
                        final isCurrentUser =
                            transcript['userId'] == _currentUserId;

                        return Container(
                          margin: EdgeInsets.only(bottom: 8),
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isCurrentUser
                                ? Colors.blue.withOpacity(0.3)
                                : Colors.green.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCurrentUser ? 'You' : transcript['userName'],
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                transcript['text'],
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _endCall() async {
    print('📴 Ending call...');
    print('   Call connected: $_isCallConnected');
    print('   Call duration: $_callSeconds seconds');
    // print('   Recording: $_isRecording, Path: $_recordingPath'); // COMMENTED

    try {
      // Prevent multiple calls
      if (_callTimer == null && _callSeconds == 0 && !_isCallConnected) {
        print('⚠️ Call never connected, skipping save');
        await _cleanup();
        if (mounted) Navigator.pop(context);
        return;
      }

      // Stop timer first
      _callTimer?.cancel();

      // Stop transcription
      if (_isSpeechToTextEnabled) {
        final callId = widget.callId ?? _callLogId!;
        await _transcriptionService.stopListening(
            callId, _currentUserId!, _currentUserName!);
        _transcriptionService.leaveCall(callId, _currentUserId!);
      }

      // Stop recording - COMMENTED
      // if (_isRecording) {
      //   await _stopRecording();
      // }

      // Stop old speech-to-text
      await _speechService.stopListening();

      // Leave Agora
      await _agoraService.leaveChannel();

      // End call in Firestore
      if (_callLogId != null) {
        await _callService.endCall(_callLogId!);
      }

      // Save recording metadata - COMMENTED
      /*
      if (_recordingPath != null &&
          _callLogId != null &&
          _currentUserId != null) {
        print('💾 Saving recording metadata...');
        try {
          final recordingModel = await _recordingService.saveRecordingMetadata(
            userId: _currentUserId!,
            callLogId: _callLogId!,
            localPath: _recordingPath!,
            contactName: widget.contactName,
            duration: _callSeconds,
            transcript: _transcript.isEmpty ? null : _transcript,
          );
          print('✅ Recording metadata saved: ${recordingModel.id}');
        } catch (e) {
          print('❌ Error saving recording: $e');
        }
      }
      */

      // Save call log
      await _saveCallLog();

      await _cleanup();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('❌ Error ending call: $e');
      await _cleanup();
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _cleanup() async {
    try {
      await _agoraService.destroy();
      await _speechService.dispose();
      // await _recordingService.dispose(); // COMMENTED
      _transcriptionService.dispose();
    } catch (e) {
      print('Error during cleanup: $e');
    }
  }

  Future<void> _saveCallLog() async {
    try {
      if (_currentUserId == null || _callLogId == null) {
        print('❌ Cannot save call log - missing user ID or call ID');
        return;
      }

      final callTime = _callStartTime ?? DateTime.now();
      final duration = _callSeconds;

      print('💾 Saving call logs...');
      print('   Base Call ID: $_callLogId');
      print('   Duration: $duration seconds');
      print('   Transcripts collected: ${_transcripts.length}');

      // Combine all transcripts into one string
      String combinedTranscript = _transcripts
          .map((entry) => '${entry['userName']}: ${entry['text']}')
          .join('\n\n');

      final isOutgoingCall = !widget.isIncoming;

      // For CURRENT USER
      final currentUserCallLogId = '${_callLogId}_${_currentUserId}';

      final currentUserCallLog = CallLogModel(
        id: currentUserCallLogId,
        callerId: isOutgoingCall ? _currentUserId! : widget.contactUserId,
        callerName: isOutgoingCall ? _currentUserName! : widget.contactName,
        receiverId: isOutgoingCall ? widget.contactUserId : _currentUserId!,
        receiverName: isOutgoingCall ? widget.contactName : _currentUserName!,
        callTypeEnum: isOutgoingCall ? CallType.outgoing : CallType.incoming,
        timestamp: callTime,
        duration: duration,
        recordingUrl: _recordingPath,
        transcript: combinedTranscript.isEmpty ? null : combinedTranscript,
        hasTranscript:
            combinedTranscript.isNotEmpty, // This should fix your error
      );

      print('💾 Saving CURRENT user call log: $currentUserCallLogId');
      print('   Type: ${isOutgoingCall ? 'OUTGOING' : 'INCOMING'}');
      print('   Has Transcript: ${combinedTranscript.isNotEmpty}');

      await _callLogService.saveCallLog(currentUserCallLog, _currentUserId!);

      // For CONTACT USER
      final contactCallLogId = '${_callLogId}_${widget.contactUserId}';

      final contactCallLog = CallLogModel(
        id: contactCallLogId,
        callerId: isOutgoingCall ? _currentUserId! : widget.contactUserId,
        callerName: isOutgoingCall ? _currentUserName! : widget.contactName,
        receiverId: isOutgoingCall ? widget.contactUserId : _currentUserId!,
        receiverName: isOutgoingCall ? widget.contactName : _currentUserName!,
        callTypeEnum: isOutgoingCall ? CallType.incoming : CallType.outgoing,
        timestamp: callTime,
        duration: duration,
        recordingUrl: _recordingPath,
        transcript: combinedTranscript.isEmpty ? null : combinedTranscript,
        hasTranscript:
            combinedTranscript.isNotEmpty, // This should fix your error
      );

      print('💾 Saving CONTACT user call log: $contactCallLogId');
      print('   Type: ${isOutgoingCall ? 'INCOMING' : 'OUTGOING'}');
      print('   Has Transcript: ${combinedTranscript.isNotEmpty}');

      await _callLogService.saveCallLog(contactCallLog, widget.contactUserId);

      print('✅✅ Both call logs saved with transcripts!');
    } catch (e) {
      print('❌ Error saving call log: $e');
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: AppColors.primaryColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0), // Reduced padding
            child: Column(
              children: [
                const Spacer(flex: 1),

                // Contact Avatar
                CircleAvatar(
                  radius: 50, // Reduced size
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    widget.contactName[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 36, // Reduced font size
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Contact Name
                Text(
                  widget.contactName,
                  style: const TextStyle(
                    fontSize: 24, // Reduced size
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),

                // Call Duration/Status
                Text(
                  _isCallConnected
                      ? _callDuration
                      : _isInitializing
                          ? 'Connecting...'
                          : 'Calling...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 20),

                // Transcript Widget - FIXED WITH FLEXIBLE
                if (_isSpeechToTextEnabled)
                  Flexible(
                    flex: 2,
                    child: _buildTranscriptWidget(),
                  ),

                const Spacer(flex: 1),

                // Call Controls Row 1
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCallButton(
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      label: _isMuted ? 'Unmute' : 'Mute',
                      onPressed: _toggleMute,
                      backgroundColor: _isMuted
                          ? Colors.white.withOpacity(0.3)
                          : Colors.white.withOpacity(0.2),
                    ),
                    _buildCallButton(
                      icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                      label: 'Speaker',
                      onPressed: _toggleSpeaker,
                      backgroundColor: _isSpeakerOn
                          ? Colors.white.withOpacity(0.3)
                          : Colors.white.withOpacity(0.2),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Transcript Toggle Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildCallButton(
                      icon: _isSpeechToTextEnabled
                          ? Icons.subtitles
                          : Icons.subtitles_off,
                      label: 'Transcript',
                      onPressed: _toggleSpeechToText,
                      backgroundColor: _isSpeechToTextEnabled
                          ? Colors.white.withOpacity(0.3)
                          : Colors.white.withOpacity(0.2),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // End Call Button
                FloatingActionButton(
                  onPressed: _endCall,
                  backgroundColor: AppColors.dangerColor,
                  child: const Icon(
                    Icons.call_end,
                    size: 28, // Reduced size
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? backgroundColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon),
            color: Colors.white,
            iconSize: 28,
            padding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
