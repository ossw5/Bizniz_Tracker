import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bizniz_tracker/app.dart';
import 'package:bizniz_tracker/core/failure.dart';
import 'package:bizniz_tracker/features/dashboard/dashboard_screen.dart';
import 'package:bizniz_tracker/features/products/domain/product.dart';
import 'package:bizniz_tracker/features/products/domain/repositories.dart';
import 'package:bizniz_tracker/features/products/presentation/controllers.dart';
import 'package:bizniz_tracker/features/sales/domain/sale.dart';
import 'package:bizniz_tracker/features/sales/domain/sale_repository.dart';
import 'package:dartz/dartz.dart';

void main() {
  testWidgets('dashboard View All opens the inventory alert screen', (
    tester,
  ) async {
    final controller = ProductController(repository: _FakeProductRepository());
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
    final controller = ProductController(repository: _FakeProductRepository());
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
    final controller = ProductController(repository: _FakeProductRepository());
    await tester.pumpWidget(BiznizTrackerApp(productController: controller));
    await tester.pumpAndSettle();

    expect(find.text('Business Overview'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.inventory_2_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Inventory Management'), findsOneWidget);
    expect(find.text('Inventory Alerts'), findsOneWidget);
    await tester.tap(find.text('Inventory Alerts'));
    await tester.pumpAndSettle();

    expect(find.text('Inventory Alerts'), findsOneWidget);
    expect(find.text('LOW STOCK'), findsOneWidget);
    expect(find.textContaining('No low-stock products found.'), findsOneWidget);
  });

  testWidgets('out-of-stock products appear in inventory alerts', (
    tester,
  ) async {
    final controller = ProductController(repository: _FakeProductRepository())
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
    final controller = ProductController(repository: _FakeProductRepository());
    await tester.pumpWidget(BiznizTrackerApp(productController: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.inventory_2_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Product'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), 'Test product');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Test product'), findsOneWidget);
    await tester.tap(find.text('Inventory Alerts'));
    await tester.pumpAndSettle();
    expect(find.text('OUT OF STOCK'), findsOneWidget);
  });

  testWidgets('record sale quick action opens Sales in One', (tester) async {
    await tester.pumpWidget(
      BiznizTrackerApp(
        productController: ProductController(
          repository: _FakeProductRepository(),
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
}

class _FakeSaleRepository implements SaleRepository {
  @override
  Future<Sale> addSale(Sale sale) async => sale;

  @override
  Future<List<Sale>> getAllSales() async => [];

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
