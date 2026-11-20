import 'package:flutter/material.dart';

import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';

import 'app.dart';
import 'core/app_database.dart';
import 'core/hive_registry.dart';
import 'core/reference_inventory.dart';
import 'features/products/data/datasources/product_local_datasource_impl.dart';
import 'features/products/data/repositories/product_repository_impl.dart';
import 'features/products/domain/product.dart';
import 'features/products/presentation/controllers.dart';
import 'features/sales/domain/sale.dart';
import 'features/sales/data/sale_repository_impl.dart';
import 'features/settings/controllers/app_settings_controller.dart';
import 'features/settings/services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await registerHiveAdapters();

  final productsBox = await Hive.openBox<ProductModel>('products_box');
  final salesBox = await Hive.openBox<Sale>('sales_box');
  final settingsBox = await Hive.openBox<bool>('app_settings_box');
  final database = AppDatabase();
  await database.customSelect('SELECT 1').get();
  final appSettingsController = AppSettingsController(
    service: SettingsService(database: database),
  );
  await appSettingsController.load();
  await seedReferenceInventoryIfEmpty(
    productsBox: productsBox,
    salesBox: salesBox,
    settingsBox: settingsBox,
  );
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
