import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:bizniz_tracker/core/reference_inventory.dart';
import 'package:bizniz_tracker/features/inventory_alerts_and_smart_suggestions/services/inventory_alert_service.dart';
import 'package:bizniz_tracker/features/products/domain/product.dart';
import 'package:bizniz_tracker/features/sales/domain/sale.dart';

void main() {
  late Directory hiveDirectory;
  late Box<ProductModel> productsBox;
  late Box<Sale> salesBox;
  late Box<bool> settingsBox;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'bizniz_reference_inventory_test_',
    );
    Hive.init(hiveDirectory.path);
    Hive.registerAdapter(ProductModelAdapter());
    Hive.registerAdapter(SaleAdapter());
    productsBox = await Hive.openBox<ProductModel>('products_box');
    salesBox = await Hive.openBox<Sale>('sales_box');
    settingsBox = await Hive.openBox<bool>('app_settings_box');
  });

  tearDownAll(() async {
    await productsBox.close();
    await salesBox.close();
    await settingsBox.close();
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test(
    'seeds reference products and sales only for an empty inventory',
    () async {
      final now = DateTime(2026, 11, 4);

      await seedReferenceInventoryIfEmpty(
        productsBox: productsBox,
        salesBox: salesBox,
        settingsBox: settingsBox,
        now: now,
      );

      final products = productsBox.values.toList();
      final sales = salesBox.values.toList();
      const alertService = InventoryAlertService();
      expect(products, hasLength(10));
      expect(sales, hasLength(10));
      expect(alertService.lowStockProducts(products), hasLength(5));
      expect(
        alertService
            .slowMovingProducts(products, sales, now: now)
            .map((product) => product.name),
        containsAll(['Yakult', 'Tide', 'Nescafe']),
      );
      expect(
        alertService
            .topSellingProducts(
              products,
              sales,
              period: const Duration(days: 30),
              now: now,
            )
            .map((entry) => entry.key.name),
        contains('Lucky Me Pancit Canton'),
      );

      await seedReferenceInventoryIfEmpty(
        productsBox: productsBox,
        salesBox: salesBox,
        settingsBox: settingsBox,
        now: now,
      );
      expect(productsBox.length, 10);
      expect(salesBox.length, 10);

      await productsBox.clear();
      await salesBox.clear();
      await seedReferenceInventoryIfEmpty(
        productsBox: productsBox,
        salesBox: salesBox,
        settingsBox: settingsBox,
        now: now,
      );
      expect(productsBox, isEmpty);
      expect(salesBox, isEmpty);
    },
  );
}
