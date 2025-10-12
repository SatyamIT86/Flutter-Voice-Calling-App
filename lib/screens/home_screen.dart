// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_voicecall_app/models/contact_model.dart';
import 'package:hive/hive.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/call_service.dart';
import '../models/call_state_model.dart';
import '../utils/constants.dart';
import 'contacts/contact_screen.dart';
import 'recordings/recordings_screen.dart';
import 'call_logs/call_logs_screen.dart';
import 'call/incoming_call_screen.dart';
import 'auth/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _authService = AuthService();
  final _callService = CallService();
  StreamSubscription? _callSubscription;

  final List<Widget> _screens = [
    const ContactsScreen(),
    const CallLogsScreen(),
    const RecordingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _listenForIncomingCalls();
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    super.dispose();
  }

  void _listenForIncomingCalls() {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    _callSubscription =
        _callService.listenForIncomingCalls(userId).listen((calls) {
      if (calls.isNotEmpty && mounted) {
        final incomingCall = calls.first;
        _showIncomingCallScreen(incomingCall);
      }
    });
  }

  void _showIncomingCallScreen(CallStateModel call) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IncomingCallScreen(
          callId: call.id,
          callerName: call.callerName,
          callerUserId: call.callerId,
          channelName: call.channelName,
        ),
      ),
    );
  }

  void _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Clear Hive cache
              await Hive.box<ContactModel>(AppConstants.contactsBox).clear();
              await Hive.box(AppConstants.settingsBox).clear();

              // Logout from Firebase
              await _authService.logout();

              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: Text(
              'Logout',
              style: TextStyle(color: AppColors.dangerColor),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text(
          _currentIndex == 0
              ? 'Contacts'
              : _currentIndex == 1
                  ? 'Call Logs'
                  : 'Recordings',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        selectedItemColor: AppColors.primaryColor,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts_outlined),
            activeIcon: Icon(Icons.contacts),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Call Logs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mic_outlined),
            activeIcon: Icon(Icons.mic),
            label: 'Recordings',
          ),
        ],
      ),
    );
  }
}
