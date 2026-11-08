import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_theme.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';

class AppSettingsController extends ChangeNotifier {
  final SettingsService service;

  StoreProfile profile = const StoreProfile();
  AppPreferences preferences = const AppPreferences();
  DateTime? lastLocalBackup;
  bool automaticDriveBackup = false;
  bool loaded = false;

  AppSettingsController({this.service = const SettingsService()});

  ThemeMode get themeMode => preferences.themeMode;

  Future<void> load() async {
    profile = await service.loadProfile();
    preferences = await service.loadPreferences();
    lastLocalBackup = await service.loadLastLocalBackup();
    automaticDriveBackup = await service.loadAutomaticDriveBackup();
    loaded = true;
    configureAppFormatting(
      currencyCode: preferences.currencyCode,
      datePattern: preferences.datePattern,
    );
    AppColors.darkMode = preferences.themeMode == ThemeMode.dark;
    notifyListeners();
  }

  Future<void> saveProfile(StoreProfile updated) async {
    await service.saveProfile(updated);
    profile = updated;
    notifyListeners();
  }

  Future<void> updatePreferences(AppPreferences updated) async {
    await service.savePreferences(updated);
    preferences = updated;
    configureAppFormatting(
      currencyCode: updated.currencyCode,
      datePattern: updated.datePattern,
    );
    AppColors.darkMode = updated.themeMode == ThemeMode.dark;
    notifyListeners();
  }

  Future<void> saveAutomaticDriveBackup(bool enabled) async {
    await service.saveAutomaticDriveBackup(enabled);
    automaticDriveBackup = enabled;
    notifyListeners();
  }

  Future<void> markLocalBackup(DateTime dateTime) async {
    await service.saveLastLocalBackup(dateTime);
    lastLocalBackup = dateTime;
    notifyListeners();
  }
}
