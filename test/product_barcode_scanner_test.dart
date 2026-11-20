import 'package:bizniz_tracker/core/failure.dart';
import 'package:bizniz_tracker/features/products/domain/product.dart';
import 'package:bizniz_tracker/features/products/domain/repositories.dart';
import 'package:bizniz_tracker/features/products/presentation/controllers.dart';
import 'package:bizniz_tracker/legacy_main.dart' as legacy;
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'cancelling a scan preserves the form and manual entry returns a barcode',
    (tester) async {
      final controller = ProductController(
        repository: _MemoryProductRepository(),
        activityLog: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: legacy.InventoryAlertsScreen(
            productController: controller,
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Add product'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(2), 'Preserved product');
      await tester.ensureVisible(find.byTooltip('Scan barcode'));
      await tester.tap(find.byTooltip('Scan barcode'));
      await tester.pumpAndSettle();

      expect(find.text('Scan Barcode'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Add Product'), findsOneWidget);
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .any((field) => field.controller?.text == 'Preserved product'),
        isTrue,
      );
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .last
            .controller
            ?.text,
        isEmpty,
      );

      await tester.ensureVisible(find.byTooltip('Scan barcode'));
      await tester.tap(find.byTooltip('Scan barcode'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '9876543210123');
      await tester.tap(find.byTooltip('Add barcode'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .last
            .controller
            ?.text,
        '9876543210123',
      );
    },
  );

  testWidgets('inventory alert product form rejects duplicate barcodes', (
    tester,
  ) async {
    final existingProduct = ProductModel(
      id: 'existing',
      name: 'Existing product',
      quantity: 1,
      costPrice: 1,
      sellingPrice: 2,
      category: 'General',
      minStock: 0,
      barcode: '1234567890123',
    );
    final controller = ProductController(
      repository: _MemoryProductRepository(products: [existingProduct]),
      activityLog: null,
    )..state = ProductState(products: [existingProduct]);

    await tester.pumpWidget(
      MaterialApp(
        home: legacy.InventoryAlertsScreen(
          productController: controller,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add product'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(2), 'Duplicate product');
    await tester.enterText(
      find.byType(TextField).last,
      existingProduct.barcode,
    );
    final enteredValues = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((field) => field.controller?.text)
        .toList();
    expect(enteredValues, contains('Duplicate product'));
    expect(enteredValues, contains(existingProduct.barcode));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(controller.state.products, hasLength(1));
    expect(
      find.text('That barcode is already assigned to another product.'),
      findsOneWidget,
    );
  });
}

class _MemoryProductRepository implements ProductRepository {
  final List<ProductModel> _products;

  _MemoryProductRepository({List<ProductModel> products = const []})
    : _products = List.of(products);

  @override
  Future<Either<Failure, List<ProductModel>>> getAllProducts() async =>
      Right(List.of(_products));

  @override
  Future<Either<Failure, ProductModel>> addProduct(ProductModel product) async {
    _products.add(product);
    return Right(product);
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

  @override
  Future<Either<Failure, bool>> deleteProduct(String id) async {
    _products.removeWhere((product) => product.id == id);
    return const Right(true);
  }
}
