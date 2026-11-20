import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:bizniz_tracker/core/app_database.dart';
import 'package:bizniz_tracker/features/products/data/datasources/product_local_datasource_impl.dart';
import 'package:bizniz_tracker/features/products/data/repositories/product_repository_impl.dart';
import 'package:bizniz_tracker/features/products/presentation/controllers.dart';
import 'package:bizniz_tracker/features/sales/data/sale_repository_impl.dart';
import 'package:bizniz_tracker/features/sales/domain/sale.dart';
import 'package:bizniz_tracker/features/sales/presentation/sales_controller.dart';
import 'package:bizniz_tracker/features/products/domain/product.dart';

final productsBoxProvider = Provider<Box<ProductModel>>((ref) {
  throw UnimplementedError('Open the Hive box before using this provider');
});

final salesBoxProvider = Provider<Box<Sale>>((ref) {
  throw UnimplementedError('Open the Hive box before using this provider');
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Provide the opened app database before use');
});

// local datasource provider
final productLocalDataSourceProvider = Provider<ProductLocalDataSourceImpl>((
  ref,
) {
  final database = ref.watch(appDatabaseProvider);
  return ProductLocalDataSourceImpl(database: database);
});

// sales datasource provider
final saleLocalDataSourceProvider = Provider<SaleLocalDataSource>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return SaleLocalDataSource(database: database);
});

// repository provider
final productRepositoryProvider = Provider((ref) {
  final local = ref.watch(productLocalDataSourceProvider);
  return ProductRepositoryImpl(local: local);
});

// sales repository provider
final saleRepositoryProvider = Provider<SaleRepositoryImpl>((ref) {
  final local = ref.watch(saleLocalDataSourceProvider);
  return SaleRepositoryImpl(local: local);
});

// controller provider
final productControllerProvider = Provider<ProductController>((ref) {
  final repo = ref.watch(productRepositoryProvider);
  return ProductController(repository: repo);
});

// sales controller provider
final salesControllerProvider = Provider<SalesController>((ref) {
  final saleRepo = ref.watch(saleRepositoryProvider);
  final productController = ref.watch(productControllerProvider);
  return SalesController(
    saleRepository: saleRepo,
    productController: productController,
  );
});
