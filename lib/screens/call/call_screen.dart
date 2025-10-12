// lib/screens/call/call_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/agora_service.dart';
import '../../services/speech_service.dart';
import '../../services/recording_service.dart';
import '../../services/auth_service.dart';
import '../../services/call_service.dart';
import '../../utils/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/call_log_model.dart';
import '../../models/call_state_model.dart';
import 'package:uuid/uuid.dart';
import '../../services/call_log_service.dart';

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
  final _recordingService = RecordingService();
  final _authService = AuthService();
  final _callService = CallService();
  final _firestore = FirebaseFirestore.instance;
  final _callLogService = CallLogService();
  final _uuid = const Uuid();

  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isCallConnected = false;
  bool _isRecording = false;
  bool _isSpeechToTextEnabled = false;
  bool _recordingEnabled = false;
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

  @override
  void initState() {
    super.initState();
    _initializeUserInfo();
    _initializeCall();
  }

  @override
  void dispose() {
    print('🔴 Disposing CallScreen');
    _callTimer?.cancel();
    _callStatusSubscription?.cancel();

    // Don't dispose services here - let endCall handle it
    super.dispose();
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

        // Start recording if enabled
        if (_recordingEnabled) {
          await _startRecording();
        }

        // Start speech-to-text if enabled
        if (_isSpeechToTextEnabled) {
          await _startSpeechToText();
        }
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

  Future<void> _startSpeechToText() async {
    try {
      print('🎤 Starting speech-to-text...');

      _speechService.onResult = (text) {
        if (mounted) {
          setState(() {
            _transcript = text;
          });
        }
      };

      _speechService.onError = (error) {
        print('❌ Speech error: $error');
      };

      await _speechService.startListening();
      print('✅ Speech-to-text started');
    } catch (e) {
      print('❌ Error starting speech-to-text: $e');
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

  void _toggleSpeechToText() async {
    setState(() => _isSpeechToTextEnabled = !_isSpeechToTextEnabled);

    if (_isSpeechToTextEnabled) {
      if (_isCallConnected) {
        await _startSpeechToText();
      }
    } else {
      await _speechService.stopListening();
      setState(() => _transcript = '');
    }
  }

  Future<void> _endCall() async {
    print('📴 Ending call...');
    print('   Call connected: $_isCallConnected');
    print('   Call duration: $_callSeconds seconds');
    print('   Recording: $_isRecording, Path: $_recordingPath');

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

      // Stop recording
      if (_isRecording) {
        await _stopRecording();
      }

      // Stop speech-to-text
      await _speechService.stopListening();

      // Leave Agora
      await _agoraService.leaveChannel();

      // End call in Firestore
      if (_callLogId != null) {
        await _callService.endCall(_callLogId!);
      }

      // Save recording metadata FIRST (if we have a recording)
      // Save recording metadata FIRST (if we have a recording)
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

      // Save call log AFTER recording
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
      await _recordingService.dispose();
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

      final isIncoming = widget.isIncoming;

      // Create UNIQUE ID for current user's call log
      final currentUserCallLogId = '${_callLogId}_${_currentUserId}';

      // Create call log for current user
      final callLog = CallLogModel(
        id: currentUserCallLogId, // UNIQUE ID
        callerId: isIncoming ? widget.contactUserId : _currentUserId!,
        callerName: isIncoming ? widget.contactName : _currentUserName!,
        receiverId: isIncoming ? _currentUserId! : widget.contactUserId,
        receiverName: isIncoming ? _currentUserName! : widget.contactName,
        callTypeEnum: isIncoming ? CallType.incoming : CallType.outgoing,
        timestamp: callTime,
        duration: duration,
        recordingUrl: _recordingPath,
        transcript: _transcript.isEmpty ? null : _transcript,
      );

      print('   Saving for current user with ID: $currentUserCallLogId');

      // Save for current user
      await _callLogService.saveCallLog(callLog, _currentUserId!);

      // Create UNIQUE ID for contact's call log
      final contactCallLogId = '${_callLogId}_${widget.contactUserId}';

      // Create opposite call log for contact
      final otherCallLog = CallLogModel(
        id: contactCallLogId, // UNIQUE ID
        callerId: isIncoming ? widget.contactUserId : _currentUserId!,
        callerName: isIncoming ? widget.contactName : _currentUserName!,
        receiverId: isIncoming ? _currentUserId! : widget.contactUserId,
        receiverName: isIncoming ? _currentUserName! : widget.contactName,
        callTypeEnum: isIncoming ? CallType.outgoing : CallType.incoming,
        timestamp: callTime,
        duration: duration,
        recordingUrl: _recordingPath,
        transcript: _transcript.isEmpty ? null : _transcript,
      );

      print('   Saving for contact user with ID: $contactCallLogId');

      // Save for contact user
      await _callLogService.saveCallLog(otherCallLog, widget.contactUserId);

      print('✅✅ Both call logs saved with UNIQUE IDs!');
    } catch (e) {
      print('❌ Error saving call log: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: AppColors.primaryColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Spacer(),

                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    widget.contactName[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 48,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  widget.contactName,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  _isCallConnected
                      ? _callDuration
                      : _isInitializing
                          ? 'Connecting...'
                          : 'Calling...',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 32),

                if (_isSpeechToTextEnabled && _transcript.isNotEmpty)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SingleChildScrollView(
                        reverse: true, // scrolls to bottom as new text is added
                        child: Text(
                          _transcript.isNotEmpty ? _transcript : 'Listening...',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),

                const Spacer(),

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
                    _buildCallButton(
                      icon: _recordingEnabled
                          ? Icons.fiber_manual_record
                          : Icons.radio_button_unchecked,
                      label: 'Record',
                      onPressed: _toggleRecording,
                      backgroundColor: _recordingEnabled
                          ? Colors.red.withOpacity(0.3)
                          : Colors.white.withOpacity(0.2),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

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
                const SizedBox(height: 32),

                if (_isRecording)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Recording',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 32),

                FloatingActionButton(
                  onPressed: _endCall,
                  backgroundColor: AppColors.dangerColor,
                  child: const Icon(
                    Icons.call_end,
                    size: 32,
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
