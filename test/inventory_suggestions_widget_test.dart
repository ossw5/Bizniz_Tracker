import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bizniz_tracker/core/failure.dart';
import 'package:bizniz_tracker/core/reference_inventory.dart';
import 'package:bizniz_tracker/features/inventory_alerts_and_smart_suggestions/screens/inventory_alerts_screen.dart';
import 'package:bizniz_tracker/features/products/domain/product.dart';
import 'package:bizniz_tracker/features/products/domain/repositories.dart';
import 'package:bizniz_tracker/features/products/presentation/controllers.dart';
import 'package:bizniz_tracker/features/sales/domain/sale.dart';
import 'package:bizniz_tracker/features/sales/domain/sale_repository.dart';
import 'package:bizniz_tracker/features/inventory_alerts_and_smart_suggestions/widgets/inventory_alert_product_card.dart';

void main() {
  testWidgets('empty-start reference inventory appears in alert screens', (
    tester,
  ) async {
    final referenceData = referenceInventoryData(now: DateTime(2026, 11, 4));
    final controller = ProductController(repository: _ProductRepository())
      ..state = ProductState(products: referenceData.products);

    await tester.pumpWidget(
      MaterialApp(
        home: InventoryAlertsScreen(
          productController: controller,
          saleRepository: _SaleRepository(referenceData.sales),
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('5 products are running low on stock'), findsOneWidget);
    expect(find.text('Lucky Me Pancit Canton'), findsOneWidget);
    expect(find.text('Netle Fresh Milk 1L'), findsOneWidget);

    await tester.ensureVisible(find.text('SLOW-MOVING'));
    await tester.tap(find.text('SLOW-MOVING'));
    await tester.pumpAndSettle();
    expect(
      find.text('3 products have not been sold for 30 days'),
      findsOneWidget,
    );
    expect(find.text('Yakult'), findsOneWidget);

    await tester.ensureVisible(find.text('SUGGESTIONS'));
    await tester.tap(find.text('SUGGESTIONS'));
    await tester.pumpAndSettle();
    expect(find.text('Yakult'), findsOneWidget);
    expect(find.text('Suggested combo'), findsWidgets);
  });

  testWidgets('known products use the reference product photos', (
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
              .map((name) => InventoryProductThumbnail(productName: name))
              .toList(),
        ),
      ),
    );

    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, hasLength(10));
    expect(images.map((image) => (image.image as AssetImage).assetName), [
      'assets/product_samples/lucky_pancit_canton.png',
      'assets/product_samples/fresh_milk.png',
      'assets/product_samples/gardenia_bread.png',
      'assets/product_samples/coca_cola.png',
      'assets/product_samples/century_tuna.png',
      'assets/product_samples/chips_ahoy.png',
      'assets/product_samples/milo.png',
      'assets/product_samples/yakult.png',
      'assets/product_samples/tide.png',
      'assets/product_samples/nescafe.png',
    ]);
    expect(find.text('C'), findsOneWidget);
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
        Sale(
          id: 'fast-sale',
          productId: 'fast',
          quantitySold: 20,
          sellingPrice: 30,
          saleDate: now.subtract(const Duration(days: 2)),
          totalRevenue: 600,
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
      expect(find.text('Accept combo'), findsWidgets);
      expect(find.byType(InventoryProductThumbnail), findsWidgets);

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
      expect(find.text('Fast product'), findsOneWidget);
      final expirationChip = find.byKey(
        const ValueKey('suggestion-type-expiration'),
      );
      await tester.ensureVisible(expirationChip);
      await tester.tap(expirationChip);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Expiration dates are not recorded'),
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
