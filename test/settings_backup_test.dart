import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:bizniz_tracker/features/customer_credit_and_debit_tracking/services/credit_tracking_service.dart';
import 'package:bizniz_tracker/features/expense_tracking/services/expense_service.dart';
import 'package:bizniz_tracker/features/product_and_inventory_management/services/expiration_service.dart';
import 'package:bizniz_tracker/features/products/domain/product.dart';
import 'package:bizniz_tracker/features/sales/domain/sale.dart';
import 'package:bizniz_tracker/features/settings/controllers/app_settings_controller.dart';
import 'package:bizniz_tracker/features/settings/models/app_settings.dart';
import 'package:bizniz_tracker/features/settings/services/activity_log_service.dart';
import 'package:bizniz_tracker/features/settings/services/local_backup_service.dart';
import 'package:bizniz_tracker/features/settings/services/settings_service.dart';

void main() {
  late Directory directory;
  const backupService = LocalBackupService();
  const activityLog = ActivityLogService();
  const dynamicBoxNames = [
    SettingsService.boxName,
    ActivityLogService.boxName,
    ExpenseService.recordsBoxName,
    ExpenseService.correctionsBoxName,
    CreditTrackingService.customersBoxName,
    CreditTrackingService.creditsBoxName,
    CreditTrackingService.paymentsBoxName,
    CreditTrackingService.correctionsBoxName,
    ExpirationService.recordsBoxName,
    ExpirationService.historyBoxName,
  ];

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('settings_backup_');
    Hive.init(directory.path);
    Hive.registerAdapter(ProductModelAdapter());
    Hive.registerAdapter(SaleAdapter());
  });

  setUp(() async {
    final products = await Hive.openBox<ProductModel>('products_box');
    final sales = await Hive.openBox<Sale>('sales_box');
    final seeds = await Hive.openBox<bool>('app_settings_box');
    await products.clear();
    await sales.clear();
    await seeds.clear();
    for (final name in dynamicBoxNames) {
      await (Hive.isBoxOpen(name)
              ? Hive.box<dynamic>(name)
              : await Hive.openBox<dynamic>(name))
          .clear();
    }
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('local backup restores typed and dynamic records', () async {
    final product = ProductModel(
      id: 'bread',
      name: 'Bread',
      quantity: 8,
      costPrice: 10,
      sellingPrice: 15,
    );
    final sale = Sale(
      id: 'sale-1',
      productId: 'bread',
      quantitySold: 2,
      sellingPrice: 15,
      saleDate: DateTime(2026, 11, 8),
      totalRevenue: 30,
    );
    await Hive.box<ProductModel>('products_box').put(product.id, product);
    await Hive.box<Sale>('sales_box').put(sale.id, sale);
    await Hive.box<dynamic>(ExpenseService.recordsBoxName).put('expense-1', {
      'description': 'Packaging',
      'occurredAt': DateTime(2026, 11, 7),
    });

    final backup = await backupService.createBackup();
    await Hive.box<ProductModel>('products_box').clear();
    await Hive.box<Sale>('sales_box').clear();
    await Hive.box<dynamic>(
      ExpenseService.recordsBoxName,
    ).put('unbacked-expense', {'description': 'Should be removed'});

    await backupService.restoreBackup(backup);

    expect(Hive.box<ProductModel>('products_box').get('bread')?.name, 'Bread');
    expect(Hive.box<Sale>('sales_box').get('sale-1')?.totalRevenue, 30);
    final restoredExpense =
        Hive.box<dynamic>(ExpenseService.recordsBoxName).get('expense-1')
            as Map;
    expect(restoredExpense['occurredAt'], DateTime(2026, 11, 7));
    expect(
      Hive.box<dynamic>(
        ExpenseService.recordsBoxName,
      ).containsKey('unbacked-expense'),
      isFalse,
    );
  });

  test('backup validation rejects omitted sections before restore', () async {
    final product = ProductModel(
      id: 'bread',
      name: 'Bread',
      quantity: 8,
      costPrice: 10,
      sellingPrice: 15,
    );
    await Hive.box<ProductModel>('products_box').put(product.id, product);
    final backup = await backupService.createBackup();
    (backup['boxes'] as Map<String, dynamic>).remove('sales_box');

    expect(() => backupService.validateBackup(backup), throwsFormatException);
    expect(Hive.box<ProductModel>('products_box').get('bread')?.name, 'Bread');
  });

  test(
    'restore rolls back earlier box writes when a later section is invalid',
    () async {
      final backupProduct = ProductModel(
        id: 'bread',
        name: 'Backup bread',
        quantity: 8,
        costPrice: 10,
        sellingPrice: 15,
      );
      final backupSale = Sale(
        id: 'backup-sale',
        productId: 'bread',
        quantitySold: 1,
        sellingPrice: 15,
        saleDate: DateTime(2026, 11, 8),
        totalRevenue: 15,
      );
      final products = Hive.box<ProductModel>('products_box');
      final sales = Hive.box<Sale>('sales_box');
      await products.put(backupProduct.id, backupProduct);
      await sales.put(backupSale.id, backupSale);
      final backup = await backupService.createBackup();
      final boxes = backup['boxes'] as Map<String, dynamic>;
      final saleRecord = (boxes['sales_box'] as List).single as Map;
      final saleData = Map<String, dynamic>.from(saleRecord['value'] as Map)
        ..['saleDate'] = 'not-a-date';
      saleRecord['value'] = saleData;

      await products.clear();
      await products.put(
        'current',
        ProductModel(
          id: 'current',
          name: 'Current product',
          quantity: 2,
          costPrice: 1,
          sellingPrice: 2,
        ),
      );
      await sales.clear();
      await sales.put(
        'current-sale',
        Sale(
          id: 'current-sale',
          productId: 'current',
          quantitySold: 1,
          sellingPrice: 2,
          saleDate: DateTime(2026, 11, 9),
          totalRevenue: 2,
        ),
      );

      await expectLater(
        backupService.restoreBackup(backup),
        throwsFormatException,
      );
      expect(products.get('current')?.name, 'Current product');
      expect(products.containsKey('bread'), isFalse);
      expect(sales.containsKey('current-sale'), isTrue);
      expect(sales.containsKey('backup-sale'), isFalse);
    },
  );

  test(
    'settings and activity history persist through their services',
    () async {
      final controller = AppSettingsController();
      await controller.load();
      final profile = const StoreProfile(
        storeName: 'Corner Shop',
        ownerName: 'Ana Cruz',
        address: 'Manila',
        contactNumber: '09170000000',
      );
      await controller.saveProfile(profile);
      await controller.updatePreferences(
        const AppPreferences(
          themeMode: ThemeMode.dark,
          currencyCode: 'USD',
          datePattern: 'yyyy-MM-dd',
        ),
      );
      await activityLog.record(
        description: 'Created a backup',
        category: 'Backup',
        occurredAt: DateTime(2026, 11, 8),
      );
      await activityLog.record(
        description: 'Added an expense',
        category: 'Expense',
        occurredAt: DateTime(2026, 11, 9),
      );

      final reloaded = AppSettingsController();
      await reloaded.load();
      expect(reloaded.profile.storeName, 'Corner Shop');
      expect(reloaded.preferences.themeMode, ThemeMode.dark);
      expect(reloaded.preferences.currencyCode, 'USD');
      expect(reloaded.preferences.datePattern, 'yyyy-MM-dd');
      expect(
        (await activityLog.loadRecent(limit: 1)).single.description,
        'Added an expense',
      );
    },
  );
}
