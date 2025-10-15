import 'package:flutter/material.dart';

class AppConstants {
  // Agora Configuration
  static const String agoraAppId = 'df97ce1499c74595b159706922586e50';

  // Collections
  static const String usersCollection = 'users';
  static const String contactsCollection = 'contacts';
  static const String callLogsCollection = 'call_logs';
  static const String recordingsCollection = 'recordings';

  // Storage paths
  static const String recordingsPath = 'recordings';

  // Hive boxes
  static const String contactsBox = 'contacts_box';
  static const String callLogsBox = 'call_logs_box'; // ADD THIS
  static const String transcriptsBox = 'transcripts';
  static const String settingsBox = 'settings_box';

  // Shared preferences keys
  static const String isLoggedInKey = 'is_logged_in';
  static const String userIdKey = 'user_id';
}

class AppColors {
  static const primaryColor = Color(0xFF6366F1);
  static const accentColor = Color(0xFF8B5CF6);
  static const backgroundColor = Color(0xFFF9FAFB);
  static const cardColor = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const successColor = Color(0xFF10B981);
  static const dangerColor = Color(0xFFEF4444);
}
