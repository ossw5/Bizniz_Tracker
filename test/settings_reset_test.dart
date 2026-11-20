import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:bizniz_tracker/core/app_database.dart';
import 'package:bizniz_tracker/core/reference_inventory.dart';
import 'package:bizniz_tracker/features/customer_credit_and_debit_tracking/services/credit_tracking_service.dart';
import 'package:bizniz_tracker/features/expense_tracking/services/expense_service.dart';
import 'package:bizniz_tracker/features/product_and_inventory_management/services/expiration_service.dart';
import 'package:bizniz_tracker/features/products/domain/product.dart';
import 'package:bizniz_tracker/features/sales/domain/sale.dart';
import 'package:bizniz_tracker/features/settings/models/app_settings.dart';
import 'package:bizniz_tracker/features/settings/services/activity_log_service.dart';
import 'package:bizniz_tracker/features/settings/services/settings_service.dart';

const _businessTables = [
  'products',
  'sales_transactions',
  'sale_items',
  'expiration_batches',
  'stock_movements',
  'customers',
  'credit_accounts',
  'credit_payments',
  'credit_balance_corrections',
  'expenses',
  'expense_corrections',
  'business_activity_log',
];

const _businessBoxes = [
  ActivityLogService.boxName,
  ExpenseService.recordsBoxName,
  ExpenseService.correctionsBoxName,
  ExpirationService.recordsBoxName,
  ExpirationService.historyBoxName,
  CreditTrackingService.customersBoxName,
  CreditTrackingService.creditsBoxName,
  CreditTrackingService.paymentsBoxName,
  CreditTrackingService.correctionsBoxName,
];

void main() {
  late Directory directory;
  late AppDatabase database;
  late Box<ProductModel> products;
  late Box<Sale> sales;
  late Box<bool> appSettings;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('settings_reset_');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(ProductModelAdapter().typeId)) {
      Hive.registerAdapter(ProductModelAdapter());
    }
    if (!Hive.isAdapterRegistered(SaleAdapter().typeId)) {
      Hive.registerAdapter(SaleAdapter());
    }
    products = await Hive.openBox<ProductModel>('products_box');
    sales = await Hive.openBox<Sale>('sales_box');
    appSettings = await Hive.openBox<bool>('app_settings_box');
    for (final name in [
      SettingsService.boxName,
      ..._businessBoxes,
      ExpenseService.customCategoriesBoxName,
    ]) {
      await Hive.openBox<dynamic>(name);
    }
    database = AppDatabase(executor: NativeDatabase.memory());
    await _seedHive();
    await _seedDatabase(database);
  });

  tearDown(() async {
    await database.close();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('reset app preferences deletes all local business data', () async {
    await SettingsService(database: database).resetPreferences();

    for (final table in _businessTables) {
      expect(await _rowCount(database, table), 0, reason: table);
    }
    expect(await _rowCount(database, 'migration_state'), 0);
    expect(await _rowCount(database, 'store_profile'), 1);
    expect(await _rowCount(database, 'app_preferences'), 1);
    expect((await database.getStoreProfile())?.storeName, '');
    expect((await database.getAppPreferences())?.currencyCode, 'PHP');

    expect(products, isEmpty);
    expect(sales, isEmpty);
    for (final name in [
      ..._businessBoxes,
      ExpenseService.customCategoriesBoxName,
    ]) {
      expect(Hive.box<dynamic>(name), isEmpty, reason: name);
    }
    expect(appSettings.get('reference_inventory_seeded'), isTrue);
    expect(Hive.box<dynamic>(SettingsService.boxName), isEmpty);
    await seedReferenceInventoryIfEmpty(
      productsBox: products,
      salesBox: sales,
      settingsBox: appSettings,
    );
    expect(products.isEmpty, isTrue);
    expect(sales.isEmpty, isTrue);
  });

  test('reset entire application preserves all business records', () async {
    await SettingsService(database: database).resetEntireApplication();

    for (final table in _businessTables) {
      expect(await _rowCount(database, table), 1, reason: table);
    }
    expect(await _rowCount(database, 'migration_state'), 1);
    expect(await _rowCount(database, 'store_profile'), 1);
    expect(await _rowCount(database, 'app_preferences'), 1);
    expect((await database.getStoreProfile())?.storeName, '');
    expect((await database.getAppPreferences())?.currencyCode, 'PHP');

    expect(products, hasLength(1));
    expect(sales, hasLength(1));
    for (final name in _businessBoxes) {
      expect(Hive.box<dynamic>(name), hasLength(1), reason: name);
    }
    expect(
      Hive.box<dynamic>(ExpenseService.customCategoriesBoxName),
      hasLength(1),
    );
    expect(appSettings.get('reference_inventory_seeded'), isTrue);
    expect(Hive.box<dynamic>(SettingsService.boxName), isEmpty);
  });
}

Future<void> _seedHive() async {
  await Hive.box<ProductModel>('products_box').put(
    'product-1',
    ProductModel(
      id: 'product-1',
      name: 'Test product',
      quantity: 5,
      costPrice: 1,
      sellingPrice: 2,
    ),
  );
  await Hive.box<Sale>('sales_box').put(
    'sale-1',
    Sale(
      id: 'sale-1',
      productId: 'product-1',
      quantitySold: 1,
      sellingPrice: 2,
      saleDate: DateTime(2026, 11, 1),
      totalRevenue: 2,
    ),
  );
  await Hive.box<bool>(
    'app_settings_box',
  ).put('reference_inventory_seeded', true);
  for (final name in _businessBoxes) {
    await Hive.box<dynamic>(name).put('record-1', {'value': 'preserve'});
  }
  await Hive.box<dynamic>(
    ExpenseService.customCategoriesBoxName,
  ).put('category-1', 'Custom');
  final preferences = Hive.box<dynamic>(SettingsService.boxName);
  await preferences.put(SettingsService.profileKey, {'storeName': 'Old store'});
  await preferences.put(SettingsService.preferencesKey, {
    'currencyCode': 'USD',
  });
  await preferences.put(SettingsService.localBackupTimeKey, '2026-11-01');
  await preferences.put(SettingsService.driveBackupTimeKey, '2026-11-01');
  await preferences.put(SettingsService.autoDriveBackupKey, true);
}

Future<void> _seedDatabase(AppDatabase database) async {
  await database.customStatement(
    "INSERT INTO products VALUES "
    "('product-1', 'Test product', 5, 100, 200, 'Food', 1, '')",
  );
  await database.customStatement(
    "INSERT INTO sales_transactions VALUES "
    "('sale-1', 'receipt-1', '2026-11-01T10:00:00.000', 200, 0, 200, 200, 0, 'Cash')",
  );
  await database.customStatement(
    "INSERT INTO sale_items VALUES "
    "('item-1', 'sale-1', 'product-1', 'product-1', 'Test product', 1, 200, 100, 200)",
  );
  await database.customStatement(
    "INSERT INTO expiration_batches VALUES "
    "('batch-1', 'product-1', 'batch', 5, 4, '2027-01-01', '2026-11-01', NULL)",
  );
  await database.customStatement(
    "INSERT INTO stock_movements VALUES "
    "('movement-1', 'batch-1', 'product-1', 'Test product', 'batch', "
    "'adjustment', 5, 4, '2026-11-01', '2027-01-01', NULL)",
  );
  await database.customStatement(
    "INSERT INTO customers VALUES "
    "('customer-1', 'Test customer', '', '', '', '2026-11-01')",
  );
  await database.customStatement(
    "INSERT INTO credit_accounts VALUES "
    "('credit-1', 'customer-1', 'sale-1', 'Test product', 1, 200, 200, 100, "
    "'2026-11-01', '2026-12-01', 'Test customer')",
  );
  await database.customStatement(
    "INSERT INTO credit_payments VALUES "
    "('payment-1', 'credit-1', 'customer-1', 100, 'Cash', '2026-11-01', 'Test customer')",
  );
  await database.customStatement(
    "INSERT INTO credit_balance_corrections VALUES "
    "('correction-1', 'credit-1', 200, 100, 'Correction', '', '', "
    "'2026-11-01', 'Test customer')",
  );
  await database.customStatement(
    "INSERT INTO expenses VALUES "
    "('expense-1', 'Supplies', 'Test expense', 100, '2026-11-01', '2026-11-01')",
  );
  await database.customStatement(
    "INSERT INTO expense_corrections VALUES "
    "('expense-correction-1', 'expense-1', 'edited', 'Correction', "
    "'2026-11-01', NULL, NULL)",
  );
  await database.customStatement(
    "INSERT INTO business_activity_log VALUES "
    "('activity-1', 'Test activity', 'Test', '2026-11-01')",
  );
  await database.saveStoreProfile(const StoreProfile(storeName: 'Old store'));
  await database.saveAppPreferences(
    const AppPreferences(currencyCode: 'USD', themeMode: ThemeMode.dark),
  );
  await database.customStatement(
    "INSERT INTO migration_state VALUES ('legacy-import', 'completed')",
  );
}

Future<int> _rowCount(AppDatabase database, String table) async {
  final row = await database
      .customSelect('SELECT COUNT(*) AS count FROM "$table"')
      .getSingle();
  return row.read<int>('count');
}
