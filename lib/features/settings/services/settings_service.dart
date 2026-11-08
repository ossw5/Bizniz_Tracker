import 'package:hive/hive.dart';

import '../models/app_settings.dart';

class SettingsService {
  static const boxName = 'bizniz_preferences_box';
  static const profileKey = 'store_profile';
  static const preferencesKey = 'app_preferences';
  static const localBackupTimeKey = 'last_local_backup_at';
  static const driveBackupTimeKey = 'last_drive_backup_at';
  static const autoDriveBackupKey = 'automatic_drive_backup';

  const SettingsService();

  Future<Box<dynamic>> _openBox() async {
    if (Hive.isBoxOpen(boxName)) return Hive.box<dynamic>(boxName);
    return Hive.openBox<dynamic>(boxName);
  }

  Future<StoreProfile> loadProfile() async {
    final value = (await _openBox()).get(profileKey);
    return StoreProfile.fromMap(value is Map ? value : null);
  }

  Future<void> saveProfile(StoreProfile profile) async {
    await (await _openBox()).put(profileKey, profile.toMap());
  }

  Future<AppPreferences> loadPreferences() async {
    final value = (await _openBox()).get(preferencesKey);
    return AppPreferences.fromMap(value is Map ? value : null);
  }

  Future<void> savePreferences(AppPreferences preferences) async {
    await (await _openBox()).put(preferencesKey, preferences.toMap());
  }

  Future<DateTime?> loadLastLocalBackup() => _loadDateTime(localBackupTimeKey);

  Future<void> saveLastLocalBackup(DateTime dateTime) async {
    await (await _openBox()).put(
      localBackupTimeKey,
      dateTime.toIso8601String(),
    );
  }

  Future<DateTime?> _loadDateTime(String key) async {
    final value = (await _openBox()).get(key);
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }

  Future<bool> loadAutomaticDriveBackup() async =>
      (await _openBox()).get(autoDriveBackupKey, defaultValue: false) as bool;

  Future<void> saveAutomaticDriveBackup(bool enabled) async {
    await (await _openBox()).put(autoDriveBackupKey, enabled);
  }
}
