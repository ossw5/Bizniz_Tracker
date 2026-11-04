import 'package:flutter/material.dart';

import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';

import 'app.dart';
import 'core/hive_registry.dart';
import 'core/reference_inventory.dart';
import 'features/products/data/datasources/product_local_datasource_impl.dart';
import 'features/products/data/repositories/product_repository_impl.dart';
import 'features/products/domain/product.dart';
import 'features/products/presentation/controllers.dart';
import 'features/sales/data/sale_repository_impl.dart';
import 'features/sales/domain/sale.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await registerHiveAdapters();

  final productsBox = await Hive.openBox<ProductModel>('products_box');
  final salesBox = await Hive.openBox<Sale>('sales_box');
  final settingsBox = await Hive.openBox<bool>('app_settings_box');
  await seedReferenceInventoryIfEmpty(
    productsBox: productsBox,
    salesBox: salesBox,
    settingsBox: settingsBox,
  );
  final productController = ProductController(
    repository: ProductRepositoryImpl(
      local: ProductLocalDataSourceImpl(productsBox: productsBox),
    ),
  );
  await productController.loadProducts();

  runApp(
    BiznizTrackerApp(
      productController: productController,
      saleRepository: SaleRepositoryImpl(
        local: SaleLocalDataSource(salesBox: salesBox),
      ),
    ),
  );
}
