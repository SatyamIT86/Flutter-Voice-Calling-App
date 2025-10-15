// lib/utils/migrate_data.dart

import 'package:hive_flutter/hive_flutter.dart';
import 'constants.dart';

Future<void> clearAllHiveData() async {
  try {
    print('🗑️ Clearing all Hive data...');

    // Delete all boxes
    await Hive.deleteBoxFromDisk(AppConstants.contactsBox);
    await Hive.deleteBoxFromDisk(AppConstants.callLogsBox);
    await Hive.deleteBoxFromDisk(AppConstants.transcriptsBox);
    await Hive.deleteBoxFromDisk(AppConstants.settingsBox);

    print('✅ All Hive data cleared');
  } catch (e) {
    print('Error clearing Hive data: $e');
  }
}
