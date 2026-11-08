import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:bizniz_tracker/core/failure.dart';
import 'package:bizniz_tracker/features/product_and_inventory_management/screens/expiration_list_screen.dart';
import 'package:bizniz_tracker/features/product_and_inventory_management/screens/product_batch_details_screen.dart';
import 'package:bizniz_tracker/features/products/domain/product.dart';
import 'package:bizniz_tracker/features/products/domain/repositories.dart';
import 'package:bizniz_tracker/features/products/presentation/controllers.dart';
import 'package:bizniz_tracker/legacy_main.dart' as legacy;

void main() {
  late Directory directory;
  late ProductController controller;
  final product = ProductModel(
    id: 'bread',
    name: 'Bread',
    quantity: 5,
    costPrice: 10,
    sellingPrice: 15,
  );

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('expiration_navigation_');
    Hive.init(directory.path);
  });

  setUp(() async {
    controller = ProductController(repository: _FakeProductRepository())
      ..state = ProductState(products: [product]);
    if (Hive.isBoxOpen('expiration_records_box')) {
      await Hive.box<dynamic>('expiration_records_box').clear();
    }
    if (Hive.isBoxOpen('expiration_history_box')) {
      await Hive.box<dynamic>('expiration_history_box').clear();
    }
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  testWidgets('expiration screen loads without inventing batches', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ExpirationListScreen(productController: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('PRODUCT EXPIRATION MANAGEMENT'), findsOneWidget);
    expect(find.text('No expiration records found.'), findsOneWidget);
    expect(find.text('B-1'), findsNothing);
  });

  testWidgets('inventory expiration shortcut opens on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: legacy.InventoryManagementScreen(
          productController: controller,
          onRefresh: () {},
          onOpenInventoryAlerts: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Product Expiration'), findsOneWidget);

    await tester.tap(find.byTooltip('Product Expiration'));
    await tester.pumpAndSettle();
    expect(find.text('PRODUCT EXPIRATION MANAGEMENT'), findsOneWidget);
  });

  testWidgets('Add Batch opens expiration form with the product selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProductBatchDetailsScreen(
          productController: controller,
          productId: product.id,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Batch'));
    await tester.pumpAndSettle();

    expect(find.text('Add Product Expiration'), findsOneWidget);
    expect(find.text('Product'), findsOneWidget);
    expect(find.text('Bread (bread)'), findsOneWidget);
  });
}

class _FakeProductRepository implements ProductRepository {
  @override
  Future<Either<Failure, List<ProductModel>>> getAllProducts() async => Right([
    ProductModel(
      id: 'bread',
      name: 'Bread',
      quantity: 5,
      costPrice: 10,
      sellingPrice: 15,
    ),
  ]);

  @override
  Future<Either<Failure, ProductModel>> addProduct(
    ProductModel product,
  ) async => Right(product);

  @override
  Future<Either<Failure, ProductModel>> updateProduct(
    ProductModel product,
  ) async => Right(product);

  @override
  Future<Either<Failure, bool>> deleteProduct(String id) async =>
      const Right(true);

  @override
  Future<Either<Failure, ProductModel>> getProductById(String id) async =>
      Left(Failure('Product not found'));
}
