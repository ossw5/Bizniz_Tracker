import 'package:hive/hive.dart';

import '../../../core/app_database.dart';
import '../../products/domain/product.dart';
import '../../sales/domain/sale.dart';
import '../models/app_settings.dart';

class SettingsService {
  static const boxName = 'bizniz_preferences_box';
  static const profileKey = 'store_profile';
  static const preferencesKey = 'app_preferences';
  static const localBackupTimeKey = 'last_local_backup_at';
  static const driveBackupTimeKey = 'last_drive_backup_at';
  static const autoDriveBackupKey = 'automatic_drive_backup';
  static const _businessBoxNames = [
    'business_activity_log_box',
    'business_expenses_box',
    'expense_corrections_box',
    'expense_custom_categories_box',
    'expiration_records_box',
    'expiration_history_box',
    'credit_customers_box',
    'customer_credits_box',
    'credit_payments_box',
    'credit_balance_corrections_box',
  ];

  final AppDatabase? database;

  const SettingsService({this.database});

  Future<Box<dynamic>> _openBox() async {
    if (Hive.isBoxOpen(boxName)) return Hive.box<dynamic>(boxName);
    return Hive.openBox<dynamic>(boxName);
  }

  Future<StoreProfile> loadProfile() async {
    if (database != null) {
      final profile = await database!.getStoreProfile();
      if (profile != null) return profile;
      final legacyValue = (await _openBox()).get(profileKey);
      if (legacyValue is Map) {
        final legacy = StoreProfile.fromMap(legacyValue);
        await database!.saveStoreProfile(legacy);
        return legacy;
      }
      return const StoreProfile();
    }
    final value = (await _openBox()).get(profileKey);
    return StoreProfile.fromMap(value is Map ? value : null);
  }

  Future<void> saveProfile(StoreProfile profile) async {
    if (database != null) {
      await database!.saveStoreProfile(profile);
    } else {
      await (await _openBox()).put(profileKey, profile.toMap());
    }
  }

  Future<AppPreferences> loadPreferences() async {
    if (database != null) {
      final preferences = await database!.getAppPreferences();
      if (preferences != null) return preferences;
      final legacyValue = (await _openBox()).get(preferencesKey);
      if (legacyValue is Map) {
        final legacy = AppPreferences.fromMap(legacyValue);
        await database!.saveAppPreferences(legacy);
        return legacy;
      }
      return const AppPreferences();
    }
    final value = (await _openBox()).get(preferencesKey);
    return AppPreferences.fromMap(value is Map ? value : null);
  }

  Future<void> savePreferences(AppPreferences preferences) async {
    if (database != null) {
      await database!.saveAppPreferences(preferences);
    } else {
      await (await _openBox()).put(preferencesKey, preferences.toMap());
    }
  }

  Future<void> resetPreferences() async {
    await _clearApplicationData();
  }

  Future<void> resetEntireApplication() async {
    await database?.clearApplicationConfiguration();
    await _clearSettings();
    await saveProfile(const StoreProfile());
    await savePreferences(const AppPreferences());
  }

  Future<void> _clearApplicationData() async {
    await database?.clearAllData();

    final products = Hive.isBoxOpen('products_box')
        ? Hive.box<ProductModel>('products_box')
        : await Hive.openBox<ProductModel>('products_box');
    final sales = Hive.isBoxOpen('sales_box')
        ? Hive.box<Sale>('sales_box')
        : await Hive.openBox<Sale>('sales_box');
    final appSettings = Hive.isBoxOpen('app_settings_box')
        ? Hive.box<bool>('app_settings_box')
        : await Hive.openBox<bool>('app_settings_box');
    await products.clear();
    await sales.clear();
    await appSettings.clear();
    for (final name in _businessBoxNames) {
      await (await _openDynamicBox(name)).clear();
    }

    await _clearSettings();
    // Keep an empty fresh install from being repopulated with demo inventory
    // by the first-launch seeding step on the next app start.
    await appSettings.put('reference_inventory_seeded', true);
    await saveProfile(const StoreProfile());
    await savePreferences(const AppPreferences());
  }

  Future<void> _clearSettings() async {
    await (await _openBox()).clear();
  }

  Future<Box<dynamic>> _openDynamicBox(String name) async {
    if (Hive.isBoxOpen(name)) return Hive.box<dynamic>(name);
    return Hive.openBox<dynamic>(name);
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
