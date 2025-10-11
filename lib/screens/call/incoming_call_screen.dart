// lib/screens/call/incoming_call_screen.dart

import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/call_service.dart';
import '../../utils/constants.dart';
import 'call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String callerName;
  final String callerUserId;
  final String channelName;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerName,
    required this.callerUserId,
    required this.channelName,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final _callService = CallService();
  Timer? _missedCallTimer;

  @override
  void initState() {
    super.initState();
    // Auto-reject after 30 seconds
    _missedCallTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) {
        _rejectCall();
      }
    });
  }

  @override
  void dispose() {
    _missedCallTimer?.cancel();
    super.dispose();
  }

  Future<void> _acceptCall() async {
    _missedCallTimer?.cancel();

    try {
      await _callService.acceptCall(widget.callId);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CallScreen(
              contactName: widget.callerName,
              contactUserId: widget.callerUserId,
              channelName: widget.channelName,
              callId: widget.callId,
              isIncoming: true,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accepting call: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _rejectCall() async {
    _missedCallTimer?.cancel();

    try {
      await _callService.rejectCall(widget.callId);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _rejectCall();
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.primaryColor,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Spacer(),

              // Caller Info
              Column(
                children: [
                  // Animated Ripple Effect
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Animated circles
                      TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: const Duration(seconds: 2),
                        // repeat: true,
                        builder: (context, double value, child) {
                          return Container(
                            width: 140 + (value * 40),
                            height: 140 + (value * 40),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  Colors.white.withOpacity(0.1 * (1 - value)),
                            ),
                          );
                        },
                      ),
                      // Avatar
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        child: Text(
                          widget.callerName[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 48,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.callerName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Incoming voice call...',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.all(40.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Decline Button
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton(
                          onPressed: _rejectCall,
                          backgroundColor: AppColors.dangerColor,
                          heroTag: 'decline',
                          child: const Icon(
                            Icons.call_end,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Decline',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),

                    // Accept Button
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton(
                          onPressed: _acceptCall,
                          backgroundColor: AppColors.successColor,
                          heroTag: 'accept',
                          child: const Icon(
                            Icons.call,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Accept',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
