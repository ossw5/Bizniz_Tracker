import '../../products/domain/product.dart';
import '../../products/presentation/controllers.dart';
import '../../sales/domain/sale.dart';
import '../../sales/domain/sale_repository.dart';
import '../models/sales_transaction_record.dart';
import '../../settings/services/activity_log_service.dart';
import '../../customer_credit_and_debit_tracking/models/credit_records.dart';
import '../../customer_credit_and_debit_tracking/services/credit_tracking_service.dart';

class SalesInOneException implements Exception {
  final String message;

  const SalesInOneException(this.message);

  @override
  String toString() => message;
}

class SalesInOneService {
  static const paymentMethods = ['Cash', 'GCash', 'Card', 'Credit'];

  final ProductController productController;
  final SaleRepository saleRepository;
  final ActivityLogService? activityLog;
  final CreditTrackingService creditService;
  final Map<String, Future<SalesTransactionRecord>> _inFlightTransactions = {};

  SalesInOneService({
    required this.productController,
    required this.saleRepository,
    this.activityLog = const ActivityLogService(),
    this.creditService = const CreditTrackingService(),
  });

  Future<SalesTransactionRecord> completeSale({
    required Map<String, int> quantities,
    required double amountPaid,
    required String paymentMethod,
    String? transactionId,
    DateTime? now,
    CreditCustomer? creditCustomer,
    double initialCreditPayment = 0,
  }) async {
    final date = now ?? DateTime.now();
    final requestId = transactionId ?? _newTransactionId(date);
    final inFlight = _inFlightTransactions[requestId];
    if (inFlight != null) return inFlight;

    final completion = _completeSale(
      quantities: quantities,
      amountPaid: amountPaid,
      paymentMethod: paymentMethod,
      requestId: requestId,
      date: date,
      creditCustomer: creditCustomer,
      initialCreditPayment: initialCreditPayment,
    );
    _inFlightTransactions[requestId] = completion;
    try {
      return await completion;
    } finally {
      _inFlightTransactions.remove(requestId);
    }
  }

  Future<SalesTransactionRecord> _completeSale({
    required Map<String, int> quantities,
    required double amountPaid,
    required String paymentMethod,
    required String requestId,
    required DateTime date,
    required CreditCustomer? creditCustomer,
    required double initialCreditPayment,
  }) async {
    if (requestId.trim().isEmpty) {
      throw const SalesInOneException('A transaction ID is required.');
    }
    if (quantities.isEmpty) {
      throw const SalesInOneException('Add at least one product to the sale.');
    }
    if (!paymentMethods.contains(paymentMethod)) {
      throw const SalesInOneException('Select a supported payment method.');
    }
    if (!amountPaid.isFinite || amountPaid < 0) {
      throw const SalesInOneException('Enter a valid payment amount.');
    }
    final existingSales = await saleRepository.getAllSales();
    final existingItems = existingSales
        .where((sale) => sale.transactionId == requestId)
        .toList();
    if (existingItems.isNotEmpty) {
      final existing = SalesTransactionRecord.fromSales(existingItems);
      final previousQuantities = {
        for (final item in existing.items) item.productId: item.quantitySold,
      };
      final normalizedQuantities = Map<String, int>.from(quantities)
        ..removeWhere((_, quantity) => quantity == 0);
      final sameQuantities =
          previousQuantities.length == normalizedQuantities.length &&
          normalizedQuantities.entries.every(
            (entry) => previousQuantities[entry.key] == entry.value,
          );
      if (sameQuantities &&
          _toCents(existing.amountPaid) == _toCents(amountPaid) &&
          existing.paymentMethod == paymentMethod) {
        if (paymentMethod == 'Credit') {
          final credits = await creditService.loadCredits();
          final matchingCredits = credits
              .where((account) => account.saleId == requestId)
              .toList();
          final credit = matchingCredits.isEmpty ? null : matchingCredits.first;
          if (credit != null) {
            return existing.copyWith(
              customerName: credit.customerName,
              remainingCredit: credit.outstandingBalance,
            );
          }
        }
        return existing;
      }
      throw const SalesInOneException(
        'This transaction ID has already been used for a different sale.',
      );
    }

    final productsById = {
      for (final product in productController.state.products)
        product.id: product,
    };
    final selectedProducts = <ProductModel>[];
    var subtotalCents = 0;
    for (final entry in quantities.entries) {
      final quantity = entry.value;
      final product = productsById[entry.key];
      if (quantity <= 0 || product == null) {
        throw const SalesInOneException(
          'A selected product is no longer available. Refresh inventory and try again.',
        );
      }
      if (product.quantity < quantity) {
        throw SalesInOneException(
          'Only ${product.quantity} units of ${product.name} are available.',
        );
      }
      selectedProducts.add(product);
      subtotalCents += _toCents(product.sellingPrice) * quantity;
    }

    final paidCents = _toCents(amountPaid);
    if (paymentMethod == 'Credit') {
      if (creditCustomer == null) {
        throw const SalesInOneException(
          'Select a customer account for credit payment.',
        );
      }
      if (initialCreditPayment.isFinite == false ||
          _toCents(initialCreditPayment) < 0 ||
          _toCents(initialCreditPayment) > subtotalCents) {
        throw const SalesInOneException(
          'Enter a valid initial credit payment.',
        );
      }
    } else if (paidCents < subtotalCents) {
      throw const SalesInOneException(
        'The amount received must cover the total amount due.',
      );
    }
    if (paymentMethod == 'Credit') {
      // Initial credit payments are recorded against one transaction-level credit.
    } else if (paymentMethod != 'Cash' && paidCents != subtotalCents) {
      throw const SalesInOneException(
        'For GCash or card, enter the exact amount due.',
      );
    }

    final originalProducts = productController.state.products;
    final receiptNumber = _nextReceiptNumber(date, requestId, existingSales);
    final subtotal = subtotalCents / 100;
    final total = subtotal;
    final amount = paymentMethod == 'Credit'
        ? _toCents(initialCreditPayment) / 100
        : paidCents / 100;
    final changeDue = paymentMethod == 'Cash'
        ? (paidCents - subtotalCents) / 100
        : 0.0;
    final sales = <Sale>[
      for (final product in selectedProducts)
        Sale(
          id: '$requestId-${product.id}',
          transactionId: requestId,
          receiptNumber: receiptNumber,
          productId: product.id,
          productNameAtSale: product.name,
          productCostAtSale: product.costPrice,
          quantitySold: quantities[product.id]!,
          sellingPrice: product.sellingPrice,
          saleDate: date,
          totalRevenue:
              _toCents(product.sellingPrice) * quantities[product.id]! / 100,
          subtotal: subtotal,
          discount: 0,
          transactionTotal: total,
          amountPaid: amount,
          changeDue: changeDue,
          paymentMethod: paymentMethod,
        ),
    ];

    final attemptedProducts = <ProductModel>[];
    final savedSales = <Sale>[];
    CreditAccount? savedCredit;
    try {
      for (final product in selectedProducts) {
        attemptedProducts.add(product);
        final updated = product.copyWith(
          quantity: product.quantity - quantities[product.id]!,
        );
        final result = await productController.repository.updateProduct(
          updated,
        );
        result.fold<void>(
          (failure) => throw SalesInOneException(failure.message),
          (_) {},
        );
      }
      for (final sale in sales) {
        await saleRepository.addSale(sale);
        savedSales.add(sale);
      }
      if (paymentMethod == 'Credit') {
        savedCredit = await creditService.addTransactionCredit(
          customer: creditCustomer!,
          saleId: requestId,
          itemName: selectedProducts.map((product) => product.name).join(', '),
          quantity: quantities.values.fold<int>(
            0,
            (sum, quantity) => sum + quantity,
          ),
          originalAmount: total,
          initialPayment: initialCreditPayment,
          creditDate: date,
          dueDate: date.add(const Duration(days: 30)),
        );
      }
    } catch (error) {
      final rollbackErrors = <String>[];
      if (savedCredit != null) {
        try {
          await creditService.rollbackCredit(savedCredit.id);
        } catch (rollbackError) {
          rollbackErrors.add('credit record: $rollbackError');
        }
      }
      for (final sale in savedSales.reversed) {
        try {
          final deleted = await saleRepository.deleteSale(sale.id);
          if (!deleted) rollbackErrors.add('Could not remove ${sale.id}.');
        } catch (rollbackError) {
          rollbackErrors.add(rollbackError.toString());
        }
      }
      for (final product in attemptedProducts.reversed) {
        try {
          final result = await productController.repository.updateProduct(
            product,
          );
          result.fold<void>(
            (failure) => rollbackErrors.add(failure.message),
            (_) {},
          );
        } catch (rollbackError) {
          rollbackErrors.add(rollbackError.toString());
        }
      }
      if (rollbackErrors.isNotEmpty) {
        throw SalesInOneException(
          'Sale could not be completed: $error. Inventory rollback also reported: ${rollbackErrors.join('; ')}',
        );
      }
      if (error is SalesInOneException) rethrow;
      throw SalesInOneException('Sale could not be completed: $error');
    }

    final updatedById = {
      for (final product in selectedProducts)
        product.id: product.copyWith(
          quantity: product.quantity - quantities[product.id]!,
        ),
    };
    productController.state = productController.state.copyWith(
      products: [
        for (final product in originalProducts)
          updatedById[product.id] ?? product,
      ],
    );
    activityLog?.recordInBackground(
      description:
          'Completed sale $receiptNumber for ${formatSalesCurrency(total)}',
      category: 'Sales',
      occurredAt: date,
    );
    final transaction = SalesTransactionRecord.fromSales(sales);
    if (paymentMethod == 'Credit') {
      return transaction.copyWith(
        customerName: creditCustomer!.fullName,
        remainingCredit: savedCredit!.outstandingBalance,
      );
    }
    return transaction;
  }

  String _nextReceiptNumber(
    DateTime date,
    String requestedId,
    List<Sale> existing,
  ) {
    final base = requestedId;
    final usedNumbers = {
      for (final sale in existing) sale.receiptNumber ?? sale.id,
    };
    if (!usedNumbers.contains(base)) return base;
    final generated =
        'BZT-${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}-'
        '${date.millisecondsSinceEpoch}';
    var candidate = generated;
    var suffix = 1;
    while (usedNumbers.contains(candidate)) {
      candidate = '$generated-$suffix';
      suffix++;
    }
    return candidate;
  }

  String _newTransactionId(DateTime date) =>
      'BZT-${date.year.toString().padLeft(4, '0')}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}-${date.microsecondsSinceEpoch}';

  static int _toCents(double amount) => (amount * 100).round();
}
