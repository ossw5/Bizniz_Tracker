import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:bizniz_tracker/core/failure.dart';
import 'package:bizniz_tracker/features/products/domain/product.dart';
import 'package:bizniz_tracker/features/products/domain/repositories.dart';
import 'package:bizniz_tracker/features/products/presentation/controllers.dart';
import 'package:bizniz_tracker/features/sales/domain/sale.dart';
import 'package:bizniz_tracker/features/sales/domain/sale_repository.dart';
import 'package:bizniz_tracker/features/sales_management/services/sales_in_one_service.dart';

void main() {
  late Directory directory;
  late _ProductRepository productRepository;
  late ProductController productController;
  late _SaleRepository saleRepository;
  late SalesInOneService service;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('sales_service_');
    Hive.init(directory.path);
  });

  setUp(() async {
    final activityBox = Hive.isBoxOpen('business_activity_log_box')
        ? Hive.box<dynamic>('business_activity_log_box')
        : await Hive.openBox<dynamic>('business_activity_log_box');
    await activityBox.clear();
    productRepository = _ProductRepository([
      _product('bread', 'Bread', 10, 12.5),
      _product('milk', 'Milk', 4, 25),
    ]);
    productController = ProductController(repository: productRepository)
      ..state = ProductState(products: productRepository.products);
    saleRepository = _SaleRepository();
    service = SalesInOneService(
      productController: productController,
      saleRepository: saleRepository,
    );
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'complete sale saves receipt details and deducts inventory once',
    () async {
      final result = await service.completeSale(
        quantities: {'bread': 2, 'milk': 1},
        amountPaid: 60,
        paymentMethod: 'Cash',
        now: DateTime(2026, 11, 7, 10),
      );

      expect(result.subtotal, 50);
      expect(result.total, 50);
      expect(result.amountPaid, 60);
      expect(result.changeDue, 10);
      expect(result.items, hasLength(2));
      expect(productRepository.products.first.quantity, 8);
      expect(productRepository.products.last.quantity, 3);
      expect(saleRepository.sales, hasLength(2));
      expect(saleRepository.sales.map((sale) => sale.receiptNumber).toSet(), {
        result.receiptNumber,
      });
      expect(saleRepository.sales.first.productNameAtSale, isNotEmpty);
      expect(
        productController.state.products.map((product) => product.quantity),
        [8, 3],
      );
    },
  );

  test(
    'retrying the same completed transaction does not deduct stock again',
    () async {
      final first = await service.completeSale(
        quantities: {'bread': 1},
        amountPaid: 20,
        paymentMethod: 'Cash',
        transactionId: 'payment-attempt-1',
      );
      final retry = await service.completeSale(
        quantities: {'bread': 1},
        amountPaid: 20,
        paymentMethod: 'Cash',
        transactionId: 'payment-attempt-1',
      );

      expect(retry.receiptNumber, first.receiptNumber);
      expect(productRepository.products.first.quantity, 9);
      expect(saleRepository.sales, hasLength(1));
    },
  );

  test(
    'concurrent retries of one transaction only save and deduct once',
    () async {
      final results = await Future.wait([
        service.completeSale(
          quantities: {'bread': 1},
          amountPaid: 20,
          paymentMethod: 'Cash',
          transactionId: 'concurrent-payment',
        ),
        service.completeSale(
          quantities: {'bread': 1},
          amountPaid: 20,
          paymentMethod: 'Cash',
          transactionId: 'concurrent-payment',
        ),
      ]);

      expect(
        results.map((result) => result.receiptNumber).toSet(),
        hasLength(1),
      );
      expect(productRepository.products.first.quantity, 9);
      expect(saleRepository.sales, hasLength(1));
    },
  );

  test(
    'insufficient payment or stock does not save or deduct inventory',
    () async {
      await expectLater(
        service.completeSale(
          quantities: {'bread': 1},
          amountPaid: 1,
          paymentMethod: 'Cash',
        ),
        throwsA(isA<SalesInOneException>()),
      );
      await expectLater(
        service.completeSale(
          quantities: {'milk': 5},
          amountPaid: 125,
          paymentMethod: 'Cash',
        ),
        throwsA(isA<SalesInOneException>()),
      );

      expect(saleRepository.sales, isEmpty);
      expect(productRepository.products.map((product) => product.quantity), [
        10,
        4,
      ]);
    },
  );

  test(
    'failed transaction persistence rolls back all inventory changes',
    () async {
      saleRepository.failOnAdd = 2;

      await expectLater(
        service.completeSale(
          quantities: {'bread': 1, 'milk': 1},
          amountPaid: 37.5,
          paymentMethod: 'Cash',
        ),
        throwsA(isA<SalesInOneException>()),
      );

      expect(saleRepository.sales, isEmpty);
      expect(productRepository.products.map((product) => product.quantity), [
        10,
        4,
      ]);
    },
  );

  test(
    'cashless payment requires exact amount and stores zero change',
    () async {
      await expectLater(
        service.completeSale(
          quantities: {'bread': 1},
          amountPaid: 20,
          paymentMethod: 'GCash',
        ),
        throwsA(isA<SalesInOneException>()),
      );
      final result = await service.completeSale(
        quantities: {'bread': 1},
        amountPaid: 12.5,
        paymentMethod: 'GCash',
      );
      expect(result.changeDue, 0);
      expect(result.paymentMethod, 'GCash');
    },
  );
}

ProductModel _product(String id, String name, int quantity, double price) =>
    ProductModel(
      id: id,
      name: name,
      quantity: quantity,
      costPrice: price / 2,
      sellingPrice: price,
      barcode: id,
    );

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
  final List<Sale> sales = [];
  int? failOnAdd;
  int _addCount = 0;

  @override
  Future<Sale> addSale(Sale sale) async {
    _addCount++;
    if (_addCount == failOnAdd) throw StateError('Storage write failed');
    sales.add(sale);
    return sale;
  }

  @override
  Future<List<Sale>> getAllSales() async => List.of(sales);

  @override
  Future<List<Sale>> getSalesByDate(DateTime date) async => sales;

  @override
  Future<List<Sale>> getSalesByDateRange(DateTime start, DateTime end) async =>
      sales;

  @override
  Future<List<Sale>> getSalesByProductId(String productId) async =>
      sales.where((sale) => sale.productId == productId).toList();

  @override
  Future<bool> deleteSale(String id) async {
    sales.removeWhere((sale) => sale.id == id);
    return true;
  }
}
