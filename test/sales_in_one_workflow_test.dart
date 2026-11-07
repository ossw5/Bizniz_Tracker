import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bizniz_tracker/core/failure.dart';
import 'package:bizniz_tracker/core/theme/app_theme.dart';
import 'package:bizniz_tracker/features/products/domain/product.dart';
import 'package:bizniz_tracker/features/products/domain/repositories.dart';
import 'package:bizniz_tracker/features/products/presentation/controllers.dart';
import 'package:bizniz_tracker/features/sales/domain/sale.dart';
import 'package:bizniz_tracker/features/sales/domain/sale_repository.dart';
import 'package:bizniz_tracker/features/sales_management/screens/sales_in_one_screen.dart';

void main() {
  testWidgets(
    'barcode to checkout, receipt, stock refresh, history, and summaries',
    (tester) async {
      final products = [
        ProductModel(
          id: 'milk-1',
          name: 'Fresh Milk',
          quantity: 4,
          costPrice: 15,
          sellingPrice: 25,
          category: 'Dairy',
          barcode: 'MILK-123',
        ),
        ProductModel(
          id: 'empty',
          name: 'Out of Stock Product',
          quantity: 0,
          costPrice: 5,
          sellingPrice: 10,
          barcode: 'EMPTY-000',
        ),
      ];
      final productRepository = _ProductRepository(products);
      final controller = ProductController(repository: productRepository)
        ..state = ProductState(products: products);
      final sales = _SaleRepository();
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildTheme(),
          home: SalesInOneScreen(
            productController: controller,
            saleRepository: sales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fresh Milk'), findsOneWidget);
      expect(find.textContaining('₱25.00'), findsOneWidget);
      expect(find.byTooltip('Out of stock'), findsOneWidget);

      await _scan(tester, 'UNKNOWN');
      expect(
        find.text('Barcode "UNKNOWN" is not registered to a product.'),
        findsOneWidget,
      );
      await _scan(tester, 'MILK-123');
      expect(find.textContaining('1 in cart'), findsOneWidget);

      await tester.tap(find.textContaining('Cart (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Shopping Cart'), findsOneWidget);
      await tester.tap(find.byTooltip('Increase quantity'));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsWidgets);

      await tester.tap(find.textContaining('Proceed to Payment'));
      await tester.pumpAndSettle();
      expect(find.text('Payment'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('amount-paid')), '10');
      await tester.ensureVisible(find.text('Complete Sale'));
      await tester.tap(find.text('Complete Sale'));
      await tester.pumpAndSettle();
      expect(sales.records, isEmpty);
      expect(productRepository.products.first.quantity, 4);

      await tester.enterText(find.byKey(const ValueKey('amount-paid')), '50');
      await tester.ensureVisible(find.text('Complete Sale'));
      await tester.tap(find.text('Complete Sale'));
      await tester.pumpAndSettle();
      expect(find.text('Receipt'), findsOneWidget);
      expect(
        find.text('Receipt: ${sales.records.first.receiptNumber}'),
        findsOneWidget,
      );
      expect(find.textContaining('2 × ₱25.00'), findsOneWidget);
      expect(find.text('₱50.00'), findsWidgets);
      expect(find.text('₱0.00'), findsWidgets);
      expect(sales.records, hasLength(1));
      expect(productRepository.products.first.quantity, 2);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 in stock'), findsOneWidget);
      expect(find.textContaining('Cart (0)'), findsNothing);

      await tester.tap(find.byTooltip('Sales history'));
      await tester.pumpAndSettle();
      expect(find.text('Sales History'), findsOneWidget);
      expect(find.text(sales.records.first.receiptNumber!), findsOneWidget);
      await tester.tap(find.text(sales.records.first.receiptNumber!));
      await tester.pumpAndSettle();
      expect(find.textContaining('Fresh Milk'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back to sales'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Sales summary'));
      await tester.pumpAndSettle();
      expect(find.text('Sales Summary'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('summary-transaction-count')),
            )
            .data,
        '1',
      );
      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('summary-transaction-count')),
            )
            .data,
        '1',
      );
      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('summary-transaction-count')),
            )
            .data,
        '1',
      );
      debugDefaultTargetPlatformOverride = null;
    },
  );
}

Future<void> _scan(WidgetTester tester, String barcode) async {
  await tester.tap(find.byTooltip('Scan barcode'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, barcode);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

class _ProductRepository implements ProductRepository {
  final List<ProductModel> products;

  _ProductRepository(this.products);

  @override
  Future<Either<Failure, List<ProductModel>>> getAllProducts() async =>
      Right(products);

  @override
  Future<Either<Failure, ProductModel>> addProduct(ProductModel product) =>
      Future.value(Right(product));

  @override
  Future<Either<Failure, ProductModel>> updateProduct(
    ProductModel product,
  ) async {
    final index = products.indexWhere((item) => item.id == product.id);
    if (index < 0) return Left(Failure('Product not found'));
    products[index] = product;
    return Right(product);
  }

  @override
  Future<Either<Failure, bool>> deleteProduct(String id) =>
      Future.value(const Right(true));

  @override
  Future<Either<Failure, ProductModel>> getProductById(String id) async {
    final matches = products.where((product) => product.id == id);
    return matches.isEmpty ? Left(Failure('Not found')) : Right(matches.first);
  }
}

class _SaleRepository implements SaleRepository {
  final records = <Sale>[];

  @override
  Future<Sale> addSale(Sale sale) async {
    records.add(sale);
    return sale;
  }

  @override
  Future<List<Sale>> getAllSales() async => List.of(records);

  @override
  Future<List<Sale>> getSalesByDate(DateTime date) async => records;

  @override
  Future<List<Sale>> getSalesByDateRange(DateTime start, DateTime end) async =>
      records;

  @override
  Future<List<Sale>> getSalesByProductId(String productId) async =>
      records.where((sale) => sale.productId == productId).toList();

  @override
  Future<bool> deleteSale(String id) async {
    records.removeWhere((sale) => sale.id == id);
    return true;
  }
}
