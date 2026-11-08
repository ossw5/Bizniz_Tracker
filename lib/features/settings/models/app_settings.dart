import 'package:flutter/material.dart';

class StoreProfile {
  final String storeName;
  final String ownerName;
  final String address;
  final String contactNumber;

  const StoreProfile({
    this.storeName = '',
    this.ownerName = '',
    this.address = '',
    this.contactNumber = '',
  });

  factory StoreProfile.fromMap(Map<dynamic, dynamic>? map) => StoreProfile(
    storeName: map?['storeName'] as String? ?? '',
    ownerName: map?['ownerName'] as String? ?? '',
    address: map?['address'] as String? ?? '',
    contactNumber: map?['contactNumber'] as String? ?? '',
  );

  Map<String, Object?> toMap() => {
    'storeName': storeName,
    'ownerName': ownerName,
    'address': address,
    'contactNumber': contactNumber,
  };
}

class NotificationPreferences {
  final bool lowStock;
  final bool expiration;
  final bool sales;
  final bool expenseReminders;

  const NotificationPreferences({
    this.lowStock = true,
    this.expiration = true,
    this.sales = true,
    this.expenseReminders = true,
  });

  factory NotificationPreferences.fromMap(Map<dynamic, dynamic>? map) =>
      NotificationPreferences(
        lowStock: map?['lowStock'] as bool? ?? true,
        expiration: map?['expiration'] as bool? ?? true,
        sales: map?['sales'] as bool? ?? true,
        expenseReminders: map?['expenseReminders'] as bool? ?? true,
      );

  NotificationPreferences copyWith({
    bool? lowStock,
    bool? expiration,
    bool? sales,
    bool? expenseReminders,
  }) => NotificationPreferences(
    lowStock: lowStock ?? this.lowStock,
    expiration: expiration ?? this.expiration,
    sales: sales ?? this.sales,
    expenseReminders: expenseReminders ?? this.expenseReminders,
  );

  Map<String, Object?> toMap() => {
    'lowStock': lowStock,
    'expiration': expiration,
    'sales': sales,
    'expenseReminders': expenseReminders,
  };
}

class AppPreferences {
  final ThemeMode themeMode;
  final String currencyCode;
  final String datePattern;
  final NotificationPreferences notifications;

  const AppPreferences({
    this.themeMode = ThemeMode.light,
    this.currencyCode = 'PHP',
    this.datePattern = 'MMM d, yyyy',
    this.notifications = const NotificationPreferences(),
  });

  factory AppPreferences.fromMap(Map<dynamic, dynamic>? map) {
    final theme = map?['themeMode'] as String?;
    return AppPreferences(
      themeMode: ThemeMode.values.firstWhere(
        (value) => value.name == theme,
        orElse: () => ThemeMode.light,
      ),
      currencyCode: map?['currencyCode'] as String? ?? 'PHP',
      datePattern: map?['datePattern'] as String? ?? 'MMM d, yyyy',
      notifications: NotificationPreferences.fromMap(
        map?['notifications'] as Map?,
      ),
    );
  }

  AppPreferences copyWith({
    ThemeMode? themeMode,
    String? currencyCode,
    String? datePattern,
    NotificationPreferences? notifications,
  }) => AppPreferences(
    themeMode: themeMode ?? this.themeMode,
    currencyCode: currencyCode ?? this.currencyCode,
    datePattern: datePattern ?? this.datePattern,
    notifications: notifications ?? this.notifications,
  );

  Map<String, Object?> toMap() => {
    'themeMode': themeMode.name,
    'currencyCode': currencyCode,
    'datePattern': datePattern,
    'notifications': notifications.toMap(),
  };
}
