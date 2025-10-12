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
  final _uuid = const Uuid();

  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isCallConnected = false;
  bool _isRecording = false;
  bool _isSpeechToTextEnabled = false; // Changed to false by default
  bool _recordingEnabled = false; // NEW: Recording toggle

  String _transcript = '';
  String _callDuration = '00:00';
  Timer? _callTimer;
  int _callSeconds = 0;
  DateTime? _callStartTime;
  String? _recordingPath;
  String? _callLogId;
  StreamSubscription? _callStatusSubscription;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _callStatusSubscription?.cancel();
    _agoraService.destroy();
    _speechService.dispose();
    _recordingService.dispose();
    super.dispose();
  }

  Future<void> _initializeCall() async {
    try {
      await _agoraService.initialize();

      _agoraService.onUserJoined = (uid, elapsed) {
        setState(() => _isCallConnected = true);
        _startCallTimer();
        // Recording only starts if enabled
        if (_recordingEnabled) {
          _startRecording();
        }
        // Speech-to-text only starts if enabled
        if (_isSpeechToTextEnabled) {
          _startSpeechToText();
        }
      };

      _agoraService.onUserOffline = (uid, reason) {
        _endCall();
      };

      final currentUserId = _authService.currentUser?.uid ?? '';
      String channelName;
      String callId;

      if (widget.isIncoming) {
        channelName = widget.channelName!;
        callId = widget.callId!;
        _callLogId = callId;
      } else {
        channelName = _generateChannelName(currentUserId, widget.contactUserId);

        final call = await _callService.initiateCall(
          callerId: currentUserId,
          callerName: _authService.currentUser?.displayName ?? 'Unknown',
          receiverId: widget.contactUserId,
          receiverName: widget.contactName,
          channelName: channelName,
        );

        callId = call.id;
        _callLogId = callId;

        _callStatusSubscription =
            _callService.listenToCallStatus(callId).listen((callState) {
          if (callState == null) {
            if (mounted && !_isCallConnected) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Call ended')),
              );
              Navigator.pop(context);
            }
          } else if (callState.status == CallStatus.rejected) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Call rejected')),
              );
              Navigator.pop(context);
            }
          }
        });

        Future.delayed(const Duration(seconds: 30), () {
          if (!_isCallConnected && mounted) {
            _callService.markAsMissed(callId);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No answer')),
            );
            Navigator.pop(context);
          }
        });
      }

      await _agoraService.joinChannel(
        channelName: channelName,
        token: '',
        uid: 0,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing call: $e')),
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
    _callStartTime = DateTime.now();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _callSeconds++;
        final minutes = _callSeconds ~/ 60;
        final seconds = _callSeconds % 60;
        _callDuration =
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      });
    });
  }

  Future<void> _startRecording() async {
    try {
      _recordingPath = await _recordingService.startRecording(
        fileName: 'call_${_callLogId}.m4a',
      );

      if (_recordingPath != null) {
        setState(() => _isRecording = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording started'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recording failed: $e')),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _recordingService.stopRecording();
      setState(() => _isRecording = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recording stopped'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  Future<void> _startSpeechToText() async {
    try {
      _speechService.onResult = (text) {
        setState(() {
          _transcript = text;
        });
      };

      _speechService.onError = (error) {
        print('Speech error: $error');
      };

      await _speechService.startListening();
    } catch (e) {
      print('Error starting speech-to-text: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speech-to-text failed: $e')),
      );
    }
  }

  Future<void> _toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    await _agoraService.muteLocalAudio(_isMuted);
  }

  Future<void> _toggleSpeaker() async {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    await _agoraService.setSpeakerphone(_isSpeakerOn);
  }

  void _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
      setState(() => _recordingEnabled = false);
    } else {
      if (_isCallConnected) {
        await _startRecording();
      }
      setState(() => _recordingEnabled = true);
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
// Replace _endCall method in call_screen.dart

  Future<void> _endCall() async {
    try {
      print('Ending call...');

      // Stop call timer
      _callTimer?.cancel();

      // Stop recording
      if (_isRecording) {
        print('Stopping recording...');
        final path = await _recordingService.stopRecording();
        if (path != null) {
          _recordingPath = path;
          print('Recording stopped, path: $path');
        }
      }

      // Stop speech-to-text
      await _speechService.stopListening();

      // Leave Agora channel
      await _agoraService.leaveChannel();

      // End call in Firestore
      if (_callLogId != null) {
        await _callService.endCall(_callLogId!);
      }

      // Save recording metadata FIRST
      if (_recordingPath != null && _callLogId != null && _isRecording) {
        final currentUserId = _authService.currentUser?.uid;
        if (currentUserId != null) {
          print('Saving recording metadata...');
          try {
            await _recordingService.saveRecordingMetadata(
              userId: currentUserId,
              callLogId: _callLogId!,
              localPath: _recordingPath!,
              contactName: widget.contactName,
              duration: _callSeconds,
              transcript: _transcript.isEmpty ? null : _transcript,
            );
            print('Recording metadata saved successfully!');
          } catch (e) {
            print('Error saving recording metadata: $e');
          }
        }
      } else {
        print(
            'No recording to save - Path: $_recordingPath, CallLogId: $_callLogId, IsRecording: $_isRecording');
      }

      // Save call log AFTER recording
      await _saveCallLog();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error ending call: $e');
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _saveCallLog() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        print('No current user, cannot save call log');
        return;
      }

      if (_callLogId == null) {
        print('No call log ID, cannot save');
        return;
      }

      // Determine caller and receiver info
      final isIncoming = widget.isIncoming;
      final currentUserId = currentUser.uid;
      final currentUserName = currentUser.displayName ?? 'Unknown';
      final contactUserId = widget.contactUserId;
      final contactName = widget.contactName;

      print(
          'Saving call log - Current User: $currentUserId, Contact: $contactUserId');

      // Create call log for current user
      final callLog = CallLogModel(
        id: _callLogId!,
        callerId: isIncoming ? contactUserId : currentUserId,
        callerName: isIncoming ? contactName : currentUserName,
        receiverId: isIncoming ? currentUserId : contactUserId,
        receiverName: isIncoming ? currentUserName : contactName,
        callType: isIncoming ? CallType.incoming : CallType.outgoing,
        timestamp: _callStartTime ?? DateTime.now(),
        duration: _callSeconds,
        recordingUrl: _recordingPath,
        transcript: _transcript.isEmpty ? null : _transcript,
      );

      print('Saving call log to current user: ${callLog.toMap()}');

      // Save to current user's call logs
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(currentUserId)
          .collection(AppConstants.callLogsCollection)
          .doc(_callLogId)
          .set(callLog.toMap());

      print('Call log saved for current user');

      // Create opposite call log for contact
      final otherCallLog = CallLogModel(
        id: _callLogId!,
        callerId: isIncoming ? contactUserId : currentUserId,
        callerName: isIncoming ? contactName : currentUserName,
        receiverId: isIncoming ? currentUserId : contactUserId,
        receiverName: isIncoming ? currentUserName : contactName,
        callType: isIncoming ? CallType.outgoing : CallType.incoming,
        timestamp: _callStartTime ?? DateTime.now(),
        duration: _callSeconds,
        recordingUrl: _recordingPath,
        transcript: _transcript.isEmpty ? null : _transcript,
      );

      print('Saving call log to contact user: ${otherCallLog.toMap()}');

      // Save to contact's call logs
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(contactUserId)
          .collection(AppConstants.callLogsCollection)
          .doc(_callLogId)
          .set(otherCallLog.toMap());

      print('Call log saved for contact user');
      print('Call logs saved successfully!');
    } catch (e) {
      print('Error saving call log: $e');
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
                  _isCallConnected ? _callDuration : 'Calling...',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 32),

                // Transcript Display
                if (_isSpeechToTextEnabled && _transcript.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: SingleChildScrollView(
                      child: Text(
                        _transcript,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
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

                // Call Controls Row 2
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

                // Recording Indicator
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
