import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:bizniz_tracker/core/failure.dart';
import 'package:bizniz_tracker/features/inventory_alerts_and_smart_suggestions/screens/inventory_alerts_screen.dart';
import 'package:bizniz_tracker/features/settings/services/activity_log_service.dart';
import 'package:bizniz_tracker/features/products/domain/product.dart';
import 'package:bizniz_tracker/features/products/domain/repositories.dart';
import 'package:bizniz_tracker/features/products/presentation/controllers.dart';
import 'package:bizniz_tracker/features/product_and_inventory_management/services/expiration_service.dart';
import 'package:bizniz_tracker/features/sales/domain/sale.dart';
import 'package:bizniz_tracker/features/sales/domain/sale_repository.dart';
import 'package:bizniz_tracker/features/inventory_alerts_and_smart_suggestions/widgets/inventory_alert_product_card.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'inventory_alert_widget_test_',
    );
    Hive.init(hiveDirectory.path);
    await Hive.openBox<dynamic>(ExpirationService.recordsBoxName);
    await Hive.openBox<dynamic>(ActivityLogService.boxName);
  });

  setUp(() async {
    if (Hive.isBoxOpen(ExpirationService.recordsBoxName)) {
      await Hive.box<dynamic>(ExpirationService.recordsBoxName).clear();
    }
  });

  tearDownAll(() async {
    await const ActivityLogService().loadRecent();
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  testWidgets('alerts and combos reflect recorded inventory and sales', (
    tester,
  ) async {
    final now = DateTime(2026, 11, 4);
    final products = [
      ProductModel(
        id: 'store-rice',
        name: 'Store rice',
        quantity: 2,
        costPrice: 10,
        sellingPrice: 15,
        minStock: 5,
      ),
      ProductModel(
        id: 'store-tuna',
        name: 'Store tuna',
        quantity: 1,
        costPrice: 20,
        sellingPrice: 30,
        minStock: 4,
      ),
    ];
    final sales = [
      for (var index = 0; index < 2; index++) ...[
        Sale(
          id: 'rice-$index',
          transactionId: 'basket-$index',
          productId: 'store-rice',
          quantitySold: 1,
          sellingPrice: 15,
          saleDate: now.subtract(const Duration(days: 40)),
          totalRevenue: 15,
        ),
        Sale(
          id: 'tuna-$index',
          transactionId: 'basket-$index',
          productId: 'store-tuna',
          quantitySold: 1,
          sellingPrice: 30,
          saleDate: now.subtract(const Duration(days: 40)),
          totalRevenue: 30,
        ),
      ],
    ];
    final controller = ProductController(repository: _ProductRepository())
      ..state = ProductState(products: products);

    await tester.pumpWidget(
      MaterialApp(
        home: InventoryAlertsScreen(
          productController: controller,
          saleRepository: _SaleRepository(sales),
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 products are running low on stock'), findsOneWidget);
    expect(find.text('Store rice'), findsOneWidget);
    expect(find.text('Store tuna'), findsOneWidget);

    await tester.ensureVisible(find.text('SLOW-MOVING'));
    await tester.tap(find.text('SLOW-MOVING'));
    await tester.pumpAndSettle();
    expect(
      find.text('2 products have not been sold for 30 days'),
      findsOneWidget,
    );
    expect(find.text('Store rice'), findsOneWidget);

    await tester.ensureVisible(find.text('SUGGESTIONS'));
    await tester.tap(find.text('SUGGESTIONS'));
    await tester.pumpAndSettle();
    expect(find.text('Store rice'), findsOneWidget);
    expect(find.text('Suggested combo'), findsWidgets);
    expect(find.text('Purchased together in 2 transactions'), findsOneWidget);
  });

  testWidgets('expiration alerts show active batches from local records', (
    tester,
  ) async {
    final service = const ExpirationService();
    final nearProduct = ProductModel(
      id: 'near-product',
      name: 'Near expiry product',
      quantity: 5,
      costPrice: 1,
      sellingPrice: 2,
    );
    final expiredProduct = ProductModel(
      id: 'expired-product',
      name: 'Expired product',
      quantity: 4,
      costPrice: 1,
      sellingPrice: 2,
    );
    final now = DateTime.now();
    await tester.runAsync(() async {
      await service.addRecord(
        product: nearProduct,
        expirationDate: now.add(const Duration(days: 10)),
        initialQuantity: 3,
        batchIdentifier: 'NEAR-1',
      );
      await service.addRecord(
        product: expiredProduct,
        expirationDate: now.subtract(const Duration(days: 1)),
        initialQuantity: 2,
        batchIdentifier: 'OLD-1',
      );
    });

    final controller = ProductController(repository: _ProductRepository())
      ..state = ProductState(products: [nearProduct, expiredProduct]);
    await tester.pumpWidget(
      MaterialApp(
        home: InventoryAlertsScreen(
          productController: controller,
          saleRepository: _SaleRepository(const []),
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final expirationTab = find.descendant(
      of: find.byType(TabBar),
      matching: find.text('EXPIRATION'),
    );
    await tester.tap(expirationTab);
    await tester.pumpAndSettle();

    expect(find.text('1 expired · 1 nearing expiration'), findsOneWidget);
    expect(find.text('Near expiry product'), findsOneWidget);
    expect(find.text('Expired product'), findsOneWidget);
  });

  testWidgets('products use colorful monograms instead of photos', (
    tester,
  ) async {
    const productNames = [
      'Lucky Me Pancit Canton',
      'Netle Fresh Milk 1L',
      'Gardenia Classic White Bread',
      'Coca Cola 330ML',
      'Century Tuna',
      'Chips Ahoy',
      'Milo 400G',
      'Yakult',
      'Tide',
      'Nescafe',
      'Custom product',
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: productNames
              .map((name) => InventoryProductMonogram(productName: name))
              .toList(),
        ),
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.text('L'), findsOneWidget);
    expect(find.text('C'), findsNWidgets(4));
  });

  testWidgets('inventory alert cards fit a narrow phone without photos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              InventoryAlertProductCard(
                product: ProductModel(
                  id: 'narrow',
                  name: 'Extra Long Product Name for Small Screens',
                  quantity: 0,
                  costPrice: 12,
                  sellingPrice: 18,
                  category: 'Packaged Household Goods',
                  minStock: 8,
                ),
                status: 'OUT OF STOCK',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
    expect(
      find.text('Extra Long Product Name for Small Screens'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'suggestions are categorized, editable, and vertically scrollable',
    (tester) async {
      final products = [
        for (var index = 0; index < 8; index++)
          ProductModel(
            id: 'slow-$index',
            name: 'Slow product $index',
            quantity: 5,
            costPrice: 10,
            sellingPrice: 15,
          ),
        ProductModel(
          id: 'fast',
          name: 'Fast product',
          quantity: 30,
          costPrice: 20,
          sellingPrice: 30,
        ),
        ProductModel(
          id: 'fast-pair',
          name: 'Fast pair product',
          quantity: 20,
          costPrice: 10,
          sellingPrice: 18,
        ),
      ];
      final now = DateTime.now();
      final sales = [
        for (var index = 0; index < 8; index++)
          Sale(
            id: 'slow-sale-$index',
            productId: 'slow-$index',
            quantitySold: 1,
            sellingPrice: 15,
            saleDate: now.subtract(const Duration(days: 40)),
            totalRevenue: 15,
          ),
        for (var index = 0; index < 8; index++)
          for (var repeat = 0; repeat < 2; repeat++) ...[
            Sale(
              id: 'slow-basket-$index-$repeat-slow',
              transactionId: 'slow-basket-$index-$repeat',
              productId: 'slow-$index',
              quantitySold: 1,
              sellingPrice: 15,
              saleDate: now.subtract(const Duration(days: 40)),
              totalRevenue: 15,
            ),
            Sale(
              id: 'slow-basket-$index-$repeat-fast',
              transactionId: 'slow-basket-$index-$repeat',
              productId: 'fast',
              quantitySold: 1,
              sellingPrice: 30,
              saleDate: now.subtract(const Duration(days: 40)),
              totalRevenue: 30,
            ),
          ],
        Sale(
          id: 'fast-sale-1',
          transactionId: 'fast-basket-1',
          productId: 'fast',
          quantitySold: 20,
          sellingPrice: 30,
          saleDate: now.subtract(const Duration(days: 2)),
          totalRevenue: 600,
        ),
        Sale(
          id: 'fast-pair-sale-1',
          transactionId: 'fast-basket-1',
          productId: 'fast-pair',
          quantitySold: 1,
          sellingPrice: 18,
          saleDate: now.subtract(const Duration(days: 2)),
          totalRevenue: 18,
        ),
        Sale(
          id: 'fast-sale-2',
          transactionId: 'fast-basket-2',
          productId: 'fast',
          quantitySold: 20,
          sellingPrice: 30,
          saleDate: now.subtract(const Duration(days: 1)),
          totalRevenue: 600,
        ),
        Sale(
          id: 'fast-pair-sale-2',
          transactionId: 'fast-basket-2',
          productId: 'fast-pair',
          quantitySold: 1,
          sellingPrice: 18,
          saleDate: now.subtract(const Duration(days: 1)),
          totalRevenue: 18,
        ),
      ];
      final controller = ProductController(repository: _ProductRepository())
        ..state = ProductState(products: products);

      await tester.pumpWidget(
        MaterialApp(
          home: InventoryAlertsScreen(
            productController: controller,
            saleRepository: _SaleRepository(sales),
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('SUGGESTIONS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SUGGESTIONS'));
      await tester.pumpAndSettle();

      expect(find.text('SLOW-MOVING'), findsWidgets);
      expect(find.text('FAST MOVING'), findsOneWidget);
      expect(find.text('EXPIRATION'), findsWidgets);
      expect(find.text('Slow product 0'), findsOneWidget);
      expect(find.text('+ Fast product'), findsWidgets);
      expect(find.text('Purchased together in 2 transactions'), findsWidgets);
      expect(find.text('Accept combo'), findsWidgets);
      expect(find.byType(InventoryProductMonogram), findsWidgets);

      await tester.tap(find.text('Edit combo').first);
      await tester.pumpAndSettle();
      expect(find.text('Edit combo'), findsWidgets);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Accept combo').first);
      await tester.pumpAndSettle();
      expect(find.text('Accepted'), findsOneWidget);

      final suggestionScrollView = find.descendant(
        of: find.byType(TabBarView),
        matching: find.byType(SingleChildScrollView),
      );
      final suggestionScrollable = find.descendant(
        of: suggestionScrollView,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Slow product 7'),
        300,
        scrollable: suggestionScrollable,
      );
      expect(find.text('Slow product 7'), findsOneWidget);

      final fastMovingChip = find.byKey(
        const ValueKey('suggestion-type-fastMoving'),
      );
      await tester.ensureVisible(fastMovingChip);
      await tester.tap(fastMovingChip);
      await tester.pumpAndSettle();
      expect(find.text('Fast product'), findsWidgets);
      expect(find.text('+ Fast pair product'), findsOneWidget);
      final expirationChip = find.byKey(
        const ValueKey('suggestion-type-expiration'),
      );
      await tester.ensureVisible(expirationChip);
      await tester.tap(expirationChip);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Expiration alerts are available'),
        findsOneWidget,
      );
    },
  );
}

class _ProductRepository implements ProductRepository {
  @override
  Future<Either<Failure, List<ProductModel>>> getAllProducts() async =>
      const Right([]);

  @override
  Future<Either<Failure, ProductModel>> addProduct(ProductModel product) =>
      Future.value(Right(product));

  @override
  Future<Either<Failure, bool>> deleteProduct(String id) =>
      Future.value(const Right(true));

  @override
  Future<Either<Failure, ProductModel>> getProductById(String id) =>
      Future.value(Left(Failure('Product not found')));

  @override
  Future<Either<Failure, ProductModel>> updateProduct(ProductModel product) =>
      Future.value(Right(product));
}

class _SaleRepository implements SaleRepository {
  final List<Sale> _sales;

  _SaleRepository(this._sales);

  @override
  Future<Sale> addSale(Sale sale) async => sale;

  @override
  Future<bool> deleteSale(String id) async => true;

  @override
  Future<List<Sale>> getAllSales() async => _sales;

  @override
  Future<List<Sale>> getSalesByDate(DateTime date) async => _sales;

  @override
  Future<List<Sale>> getSalesByDateRange(DateTime start, DateTime end) async =>
      _sales;

  @override
  Future<List<Sale>> getSalesByProductId(String productId) async =>
      _sales.where((sale) => sale.productId == productId).toList();
}
