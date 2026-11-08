import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:bizniz_tracker/core/failure.dart';
import 'package:bizniz_tracker/core/theme/app_theme.dart';
import 'package:bizniz_tracker/features/customer_credit_and_debit_tracking/models/credit_records.dart';
import 'package:bizniz_tracker/features/customer_credit_and_debit_tracking/screens/credit_debit_tracking_screen.dart';
import 'package:bizniz_tracker/features/customer_credit_and_debit_tracking/services/credit_tracking_service.dart';
import 'package:bizniz_tracker/features/products/domain/product.dart';
import 'package:bizniz_tracker/features/products/domain/repositories.dart';
import 'package:bizniz_tracker/features/products/presentation/controllers.dart';
import 'package:bizniz_tracker/features/sales/domain/sale.dart';
import 'package:bizniz_tracker/features/sales/domain/sale_repository.dart';

void main() {
  late Directory directory;
  const service = CreditTrackingService();

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('credit_tracking_');
    Hive.init(directory.path);
  });

  setUp(() async {
    for (final name in [
      CreditTrackingService.customersBoxName,
      CreditTrackingService.creditsBoxName,
      CreditTrackingService.paymentsBoxName,
      CreditTrackingService.correctionsBoxName,
    ]) {
      if (Hive.isBoxOpen(name)) await Hive.box<dynamic>(name).clear();
    }
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('partial payments, settlement, and corrections are audited', () async {
    final customer = await service.addCustomer(
      fullName: 'Jane Cruz',
      phone: '09175551234',
      address: 'Manila',
      notes: 'Regular customer',
    );
    final account = await service.addCredit(
      customer: customer,
      saleId: 'credit-sale-1',
      itemName: 'Sardines',
      quantity: 2,
      unitPrice: 66,
      creditDate: DateTime(2026, 11, 8),
      dueDate: DateTime(2026, 11, 15),
    );

    await service.recordPayment(
      creditId: account.id,
      amount: 30,
      paymentMethod: 'Cash',
      paymentDate: DateTime(2026, 11, 9),
    );
    final partiallyPaid = (await service.loadCredits()).single;
    expect(partiallyPaid.originalAmount, 132);
    expect(partiallyPaid.outstandingBalance, 102);

    await expectLater(
      service.recordPayment(
        creditId: account.id,
        amount: 103,
        paymentMethod: 'GCash',
      ),
      throwsA(isA<ArgumentError>()),
    );

    await service.recordPayment(
      creditId: account.id,
      amount: 102,
      paymentMethod: 'GCash',
      paymentDate: DateTime(2026, 11, 10),
    );
    expect((await service.loadCredits()).single.outstandingBalance, 0);
    expect(await service.loadPayments(creditId: account.id), hasLength(2));

    await service.correctBalance(
      creditId: account.id,
      correctedBalance: 5,
      reason: 'Entry Error',
      details: 'A prior payment was entered against the wrong account.',
      authorizedBy: 'Store Owner',
    );
    final correction = (await service.loadCorrections()).single;
    expect(correction.originalBalance, 0);
    expect(correction.correctedBalance, 5);
    expect(correction.authorizedBy, 'Store Owner');
    expect((await service.loadCredits()).single.outstandingBalance, 5);
  });

  test('rejects invalid customer, due date, and payment inputs', () async {
    await expectLater(
      service.addCustomer(fullName: ' ', phone: '', address: '', notes: ''),
      throwsA(isA<ArgumentError>()),
    );
    final customer = await service.addCustomer(
      fullName: 'Ana Cruz',
      phone: '',
      address: '',
      notes: '',
    );
    await expectLater(
      service.addCredit(
        customer: customer,
        saleId: 'invalid-sale',
        itemName: 'Bread',
        quantity: 1,
        unitPrice: 10,
        creditDate: DateTime(2026, 11, 10),
        dueDate: DateTime(2026, 11, 9),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  testWidgets(
    'credit transaction updates inventory and partial payment reduces balance',
    (tester) async {
      final products = [
        ProductModel(
          id: 'bread',
          name: 'Bread',
          quantity: 5,
          costPrice: 8,
          sellingPrice: 15,
        ),
      ];
      final productRepository = _MemoryProductRepository(products);
      final controller = ProductController(repository: productRepository)
        ..state = ProductState(products: products);
      final sales = _MemorySaleRepository();
      final memoryService = _MemoryCreditService();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildTheme(),
          home: CreditDebitTrackingScreen(
            productController: controller,
            saleRepository: sales,
            service: memoryService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Customer Registration'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Jane Cruz');
      await tester.ensureVisible(find.text('Register Customer'));
      await tester.tap(find.text('Register Customer'));
      await tester.pumpAndSettle();

      expect(find.text('Manage customer credit'), findsOneWidget);
      await tester.tap(find.text('Credit Transaction'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<CreditCustomer>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jane Cruz').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Bread').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), '2');
      await tester.ensureVisible(find.text('Add to Credit'));
      await tester.tap(find.text('Add to Credit'));
      await tester.pumpAndSettle();

      expect(sales.records, hasLength(1));
      expect(sales.records.single.paymentMethod, 'Credit');
      expect(productRepository.products.single.quantity, 3);
      final credit = (await memoryService.loadCredits()).single;
      expect(credit.originalAmount, 30);

      await tester.tap(find.text('Payment Recording'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jane Cruz'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '10');
      await tester.tap(find.text('Record Payment'));
      await tester.pumpAndSettle();

      expect((await memoryService.loadCredits()).single.outstandingBalance, 20);
      expect(
        await memoryService.loadPayments(creditId: credit.id),
        hasLength(1),
      );
    },
  );
}

class _MemoryProductRepository implements ProductRepository {
  final List<ProductModel> products;

  _MemoryProductRepository(this.products);

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

class _MemorySaleRepository implements SaleRepository {
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

class _MemoryCreditService extends CreditTrackingService {
  final customers = <CreditCustomer>[];
  final credits = <CreditAccount>[];
  final payments = <CreditPayment>[];
  var _sequence = 0;

  @override
  Future<List<CreditCustomer>> loadCustomers() async => List.of(customers);

  @override
  Future<CreditCustomer> addCustomer({
    required String fullName,
    required String phone,
    required String address,
    required String notes,
  }) async {
    final customer = CreditCustomer(
      id: 'memory-customer-${_sequence++}',
      fullName: fullName.trim(),
      phone: phone.trim(),
      address: address.trim(),
      notes: notes.trim(),
      createdAt: DateTime.now(),
    );
    customers.add(customer);
    return customer;
  }

  @override
  Future<List<CreditAccount>> loadCredits() async => List.of(credits);

  @override
  Future<CreditAccount> addCredit({
    required CreditCustomer customer,
    required String saleId,
    required String itemName,
    required int quantity,
    required double unitPrice,
    required DateTime creditDate,
    required DateTime dueDate,
  }) async {
    final amount = (quantity * unitPrice * 100).round() / 100;
    final credit = CreditAccount(
      id: 'memory-credit-${_sequence++}',
      customerId: customer.id,
      customerName: customer.fullName,
      saleId: saleId,
      itemName: itemName,
      quantity: quantity,
      unitPrice: unitPrice,
      originalAmount: amount,
      outstandingBalance: amount,
      creditDate: creditDate,
      dueDate: dueDate,
    );
    credits.add(credit);
    return credit;
  }

  @override
  Future<CreditPayment> recordPayment({
    required String creditId,
    required double amount,
    required String paymentMethod,
    DateTime? paymentDate,
  }) async {
    final index = credits.indexWhere((credit) => credit.id == creditId);
    final credit = credits[index];
    final payment = CreditPayment(
      id: 'memory-payment-${_sequence++}',
      creditId: creditId,
      customerId: credit.customerId,
      customerName: credit.customerName,
      amount: amount,
      paymentMethod: paymentMethod,
      paymentDate: paymentDate ?? DateTime.now(),
    );
    credits[index] = credit.copyWith(
      outstandingBalance: credit.outstandingBalance - amount,
    );
    payments.add(payment);
    return payment;
  }

  @override
  Future<List<CreditPayment>> loadPayments({String? creditId}) async => payments
      .where((payment) => creditId == null || payment.creditId == creditId)
      .toList();
}
