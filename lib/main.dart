import 'package:flutter/material.dart';

import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';

import 'app.dart';
import 'core/app_database.dart';
import 'core/hive_registry.dart';
import 'features/products/data/datasources/product_local_datasource_impl.dart';
import 'features/products/data/repositories/product_repository_impl.dart';
import 'features/products/domain/product.dart';
import 'features/products/presentation/controllers.dart';
import 'features/sales/domain/sale.dart';
import 'features/sales/data/sale_repository_impl.dart';
import 'features/customer_credit_and_debit_tracking/services/credit_tracking_service.dart';
import 'features/expense_tracking/services/expense_service.dart';
import 'features/product_and_inventory_management/services/expiration_service.dart';
import 'features/settings/controllers/app_settings_controller.dart';
import 'features/settings/services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await registerHiveAdapters();

  final productsBox = await Hive.openBox<ProductModel>('products_box');
  final salesBox = await Hive.openBox<Sale>('sales_box');
  await Hive.openBox<dynamic>(ExpenseService.recordsBoxName);
  await Hive.openBox<dynamic>(ExpirationService.recordsBoxName);
  await Hive.openBox<dynamic>(CreditTrackingService.creditsBoxName);
  final database = AppDatabase();
  await database.customSelect('SELECT 1').get();
  final appSettingsController = AppSettingsController(
    service: SettingsService(database: database),
  );
  await appSettingsController.load();
  await database.importHiveInventory(
    products: productsBox.values,
    sales: salesBox.values,
  );
  final productController = ProductController(
    repository: ProductRepositoryImpl(
      local: ProductLocalDataSourceImpl(database: database),
    ),
  );
  await productController.loadProducts();

  runApp(
    BiznizTrackerApp(
      productController: productController,
      saleRepository: SaleRepositoryImpl(
        local: SaleLocalDataSource(database: database),
      ),
      database: database,
      settingsController: appSettingsController,
    ),
  );
}
