import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:bizniz_tracker/app.dart';
import 'package:bizniz_tracker/core/failure.dart';
import 'package:bizniz_tracker/core/theme/app_theme.dart';
import 'package:bizniz_tracker/features/dashboard/dashboard_screen.dart';
import 'package:bizniz_tracker/features/products/domain/product.dart';
import 'package:bizniz_tracker/features/products/domain/repositories.dart';
import 'package:bizniz_tracker/features/products/presentation/controllers.dart';
import 'package:bizniz_tracker/features/sales/domain/sale.dart';
import 'package:bizniz_tracker/features/sales/domain/sale_repository.dart';
import 'package:dartz/dartz.dart';
import 'package:bizniz_tracker/legacy_main.dart' as legacy;

void main() {
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('widget_test_');
    Hive.init(directory.path);
    await Hive.openBox<dynamic>('business_activity_log_box');
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  testWidgets('dashboard fits a narrow mobile viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = ProductController(
      repository: _FakeProductRepository(),
      activityLog: null,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(),
        home: DashboardScreen(productController: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Bizniz Tracker'), findsOneWidget);
  });

  testWidgets('inventory overview and product cards fit narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller =
        ProductController(
            repository: _FakeProductRepository(),
            activityLog: null,
          )
          ..state = ProductState(
            products: [
              ProductModel(
                id: 'mineral-water',
                name: 'Mineral Water Long Bottle Name',
                quantity: 5,
                costPrice: 12,
                sellingPrice: 20,
                category: 'Beverages',
                minStock: 10,
              ),
            ],
          );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(),
        home: legacy.InventoryManagementScreen(
          productController: controller,
          onRefresh: () {},
          onOpenInventoryAlerts: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Inventory Overview'), findsOneWidget);
    expect(find.text('Mineral Water Long Bottle Name'), findsOneWidget);
    expect(find.text('Low stock'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard View All opens the inventory alert screen', (
    tester,
  ) async {
    final controller = ProductController(
      repository: _FakeProductRepository(),
      activityLog: null,
    );
    await tester.pumpWidget(
      MaterialApp(home: DashboardScreen(productController: controller)),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('View All'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('View All'));
    await tester.pumpAndSettle();

    expect(find.text('LOW STOCK'), findsOneWidget);
    expect(find.textContaining('No low-stock products found.'), findsOneWidget);
  });

  testWidgets('dashboard suggestions shortcut opens smart suggestions', (
    tester,
  ) async {
    final controller = ProductController(
      repository: _FakeProductRepository(),
      activityLog: null,
    );
    await tester.pumpWidget(
      MaterialApp(home: DashboardScreen(productController: controller)),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('View Suggestions'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('View Suggestions'));
    await tester.pumpAndSettle();

    expect(find.text('SUGGESTIONS'), findsOneWidget);
    expect(
      find.text('Pair slow-moving products with popular items'),
      findsOneWidget,
    );
  });

  testWidgets('inventory navigation opens inventory alerts', (tester) async {
    final controller = ProductController(
      repository: _FakeProductRepository(),
      activityLog: null,
    );
    await tester.pumpWidget(BiznizTrackerApp(productController: controller));
    await tester.pumpAndSettle();

    expect(find.text('Business Overview'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.inventory_2_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Inventory Management'), findsOneWidget);
    expect(find.text('Inventory Alerts'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.notifications_active_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Inventory Alerts'), findsOneWidget);
    expect(find.text('LOW STOCK'), findsOneWidget);
    expect(find.textContaining('No low-stock products found.'), findsOneWidget);
  });

  testWidgets('out-of-stock products appear in inventory alerts', (
    tester,
  ) async {
    final controller =
        ProductController(
            repository: _FakeProductRepository(),
            activityLog: null,
          )
          ..state = ProductState(
            products: [
              ProductModel(
                id: 'zero-stock',
                name: 'Out of stock item',
                quantity: 0,
                costPrice: 1,
                sellingPrice: 2,
                minStock: 5,
              ),
            ],
          );

    await tester.pumpWidget(BiznizTrackerApp(productController: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.inventory_2_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Out of stock item'), findsOneWidget);
    await tester.tap(find.text('Inventory Alerts'));
    await tester.pumpAndSettle();

    expect(find.text('Out of stock item'), findsOneWidget);
    expect(find.text('OUT OF STOCK'), findsOneWidget);
  });

  testWidgets('adding a product makes it available to inventory alerts', (
    tester,
  ) async {
    final controller = ProductController(
      repository: _FakeProductRepository(),
      activityLog: null,
    );
    await tester.pumpWidget(BiznizTrackerApp(productController: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.inventory_2_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Product'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), 'Test product');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(controller.state.products, hasLength(1));
    expect(find.text('Test product'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.notifications_active_outlined));
    await tester.pumpAndSettle();
    expect(find.text('OUT OF STOCK'), findsOneWidget);
  });

  testWidgets('record sale quick action opens Sales in One', (tester) async {
    await tester.pumpWidget(
      BiznizTrackerApp(
        productController: ProductController(
          repository: _FakeProductRepository(),
          activityLog: null,
        ),
        saleRepository: _FakeSaleRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Record Sale'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Record Sale'));
    await tester.pumpAndSettle();

    expect(find.text('Sales in One'), findsOneWidget);
    expect(
      find.textContaining('No inventory products are available.'),
      findsOneWidget,
    );
  });

  testWidgets('reports navigation shows saved sales totals', (tester) async {
    final now = DateTime.now();
    final saleRepository = _FakeSaleRepository(
      sales: [
        Sale(
          id: 'line-1',
          transactionId: 'receipt-1',
          productId: 'bread',
          productNameAtSale: 'Bread',
          quantitySold: 2,
          sellingPrice: 15,
          saleDate: now,
          totalRevenue: 30,
        ),
        Sale(
          id: 'line-2',
          transactionId: 'receipt-1',
          productId: 'milk',
          productNameAtSale: 'Milk',
          quantitySold: 1,
          sellingPrice: 10,
          saleDate: now,
          totalRevenue: 10,
        ),
      ],
    );
    await tester.pumpWidget(
      BiznizTrackerApp(
        productController: ProductController(
          repository: _FakeProductRepository(),
          activityLog: null,
        ),
        saleRepository: saleRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Sales Summary'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('Expense Tracking'), findsOneWidget);
    expect(find.text('Credit and Debit Tracking'), findsOneWidget);
    await tester.tap(find.text('View all sales summary'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Completed sales'), findsOneWidget);
    expect(find.textContaining('1 transaction'), findsOneWidget);
    expect(find.textContaining('3 items'), findsOneWidget);
    expect(find.textContaining('40.00'), findsOneWidget);
    expect(find.text('Bread'), findsOneWidget);
    expect(find.textContaining('2 sold'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.textContaining('1 sold'), findsOneWidget);

  });
}

class _FakeSaleRepository implements SaleRepository {
  final List<Sale> sales;

  _FakeSaleRepository({this.sales = const []});

  @override
  Future<Sale> addSale(Sale sale) async => sale;

  @override
  Future<List<Sale>> getAllSales() async => sales;

  @override
  Future<List<Sale>> getSalesByDate(DateTime date) async => [];

  @override
  Future<List<Sale>> getSalesByDateRange(DateTime start, DateTime end) async =>
      [];

  @override
  Future<List<Sale>> getSalesByProductId(String productId) async => [];

  @override
  Future<bool> deleteSale(String id) async => true;
}

class _FakeProductRepository implements ProductRepository {
  final List<ProductModel> _products = [];

  @override
  Future<Either<Failure, List<ProductModel>>> getAllProducts() async =>
      Right(List.of(_products));

  @override
  Future<Either<Failure, ProductModel>> addProduct(ProductModel product) async {
    _products.add(product);
    return Right(product);
  }

  @override
  Future<Either<Failure, bool>> deleteProduct(String id) async {
    _products.removeWhere((product) => product.id == id);
    return const Right(true);
  }

  @override
  Future<Either<Failure, ProductModel>> getProductById(String id) async {
    for (final product in _products) {
      if (product.id == id) return Right(product);
    }
    return Left(Failure('Product not found'));
  }

  @override
  Future<Either<Failure, ProductModel>> updateProduct(
    ProductModel product,
  ) async {
    final index = _products.indexWhere((item) => item.id == product.id);
    if (index == -1) return Left(Failure('Product not found'));
    _products[index] = product;
    return Right(product);
  }
}
