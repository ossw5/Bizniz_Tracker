import 'package:bizniz_tracker/features/customer_credit_and_debit_tracking/models/credit_records.dart';
import 'package:bizniz_tracker/features/dashboard/dashboard_data.dart';
import 'package:bizniz_tracker/features/expense_tracking/models/expense_record.dart';
import 'package:bizniz_tracker/features/product_and_inventory_management/models/expiration_model.dart';
import 'package:bizniz_tracker/features/products/domain/product.dart';
import 'package:bizniz_tracker/features/sales/domain/sale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 6, 17, 12);
  final firstProduct = ProductModel(
    id: 'first',
    name: 'First product',
    quantity: 1,
    costPrice: 5,
    sellingPrice: 10,
    minStock: 1,
  );
  final secondProduct = ProductModel(
    id: 'second',
    name: 'Second product',
    quantity: 10,
    costPrice: 8,
    sellingPrice: 15,
    minStock: 2,
  );
  final todaySales = [
    Sale(
      id: 'today-first',
      transactionId: 'today-transaction',
      receiptNumber: 'R-100',
      productId: firstProduct.id,
      productNameAtSale: firstProduct.name,
      productCostAtSale: 5,
      quantitySold: 2,
      sellingPrice: 10,
      saleDate: now.subtract(const Duration(hours: 3)),
      totalRevenue: 20,
      transactionTotal: 35,
      amountPaid: 35,
      paymentMethod: 'Cash',
    ),
    Sale(
      id: 'today-second',
      transactionId: 'today-transaction',
      receiptNumber: 'R-100',
      productId: secondProduct.id,
      productNameAtSale: secondProduct.name,
      productCostAtSale: 8,
      quantitySold: 1,
      sellingPrice: 15,
      saleDate: now.subtract(const Duration(hours: 3)),
      totalRevenue: 15,
      transactionTotal: 35,
      amountPaid: 35,
      paymentMethod: 'Cash',
    ),
  ];

  test('aggregates unique transactions, expenses, cost, and stock counts', () {
    final data = DashboardData.fromRecords(
      now: now,
      products: [
        firstProduct,
        secondProduct,
        ProductModel(
          id: 'reference-seeded',
          name: 'Seeded product',
          quantity: 0,
          costPrice: 1,
          sellingPrice: 2,
        ),
      ],
      sales: [
        ...todaySales,
        Sale(
          id: 'yesterday-sale',
          transactionId: 'yesterday-transaction',
          productId: secondProduct.id,
          quantitySold: 1,
          sellingPrice: 15,
          saleDate: now.subtract(const Duration(days: 1)),
          totalRevenue: 15,
          transactionTotal: 15,
        ),
        Sale(
          id: 'reference-sale-seeded',
          productId: firstProduct.id,
          quantitySold: 100,
          sellingPrice: 10,
          saleDate: now,
          totalRevenue: 1000,
        ),
      ],
      expenses: [
        _expense(
          id: 'today-operating',
          amount: 4,
          date: now,
          type: 'Operating Expense',
        ),
        _expense(
          id: 'today-purchase',
          amount: 10,
          date: now,
          type: 'Inventory Purchase',
        ),
        _expense(
          id: 'yesterday-expense',
          amount: 100,
          date: now.subtract(const Duration(days: 1)),
          type: 'Operating Expense',
        ),
      ],
      expirationRecords: const [],
      creditAccounts: const [],
    );

    expect(data.todaySales, 35);
    expect(data.todayExpenses, 14);
    expect(data.estimatedProfit, 13);
    expect(data.totalProducts, 2);
    expect(data.lowStockProductCount, 1);
    expect(data.recentTransactions.first.receiptNumber, 'R-100');
    expect(data.recentTransactions.first.items, hasLength(2));
  });

  test('buckets actual period totals and counts transactions once', () {
    final data = DashboardData.fromRecords(
      now: now,
      products: [firstProduct, secondProduct],
      sales: [
        ...todaySales,
        Sale(
          id: 'yesterday-sale',
          transactionId: 'yesterday-transaction',
          productId: secondProduct.id,
          quantitySold: 1,
          sellingPrice: 15,
          saleDate: now.subtract(const Duration(days: 1)),
          totalRevenue: 15,
          transactionTotal: 15,
        ),
      ],
      expenses: const [],
      expirationRecords: const [],
      creditAccounts: const [],
    );

    expect(data.transactionsFor(DashboardSalesPeriod.daily), hasLength(1));
    expect(data.transactionsFor(DashboardSalesPeriod.weekly), hasLength(2));
    expect(data.salesBuckets(DashboardSalesPeriod.daily)[3].total, 35);
    expect(data.salesBuckets(DashboardSalesPeriod.weekly)[1].total, 15);
    expect(data.salesBuckets(DashboardSalesPeriod.weekly)[2].total, 35);
    expect(data.salesBuckets(DashboardSalesPeriod.monthly)[2].total, 50);
  });

  test('uses the linked outstanding balance for credit payment status', () {
    final creditSale = Sale(
      id: 'credit-item',
      transactionId: 'credit-transaction',
      productId: firstProduct.id,
      quantitySold: 1,
      sellingPrice: 10,
      saleDate: now,
      totalRevenue: 10,
      transactionTotal: 10,
      amountPaid: 4,
      paymentMethod: 'Credit',
    );
    final account = CreditAccount(
      id: 'credit',
      customerId: 'customer',
      customerName: 'Customer',
      saleId: 'credit-transaction',
      itemName: firstProduct.name,
      quantity: 1,
      unitPrice: 10,
      originalAmount: 10,
      outstandingBalance: 6,
      creditDate: now,
      dueDate: now.add(const Duration(days: 30)),
    );
    final data = DashboardData.fromRecords(
      now: now,
      products: [firstProduct],
      sales: [creditSale],
      expenses: const [],
      expirationRecords: const [],
      creditAccounts: [account],
    );

    expect(data.isTransactionPaid(data.recentTransactions.single), isFalse);
    expect(data.salesBuckets(DashboardSalesPeriod.daily)[4].total, 10);
  });

  test('counts only active nearing and expired inventory batches', () {
    final nearExpiry = ExpirationModel.fromProduct(
      id: 'near',
      product: firstProduct,
      expirationDate: now.add(const Duration(days: 10)),
      initialQuantity: 3,
      batchIdentifier: 'NEAR',
      createdAt: now,
    );
    final expired = ExpirationModel.fromProduct(
      id: 'expired',
      product: secondProduct,
      expirationDate: now.subtract(const Duration(days: 1)),
      initialQuantity: 3,
      batchIdentifier: 'OLD',
      createdAt: now,
    );
    final depleted = nearExpiry.copyWith(id: 'depleted', remainingQuantity: 0);
    final data = DashboardData.fromRecords(
      now: now,
      products: [firstProduct, secondProduct],
      sales: const [],
      expenses: const [],
      expirationRecords: [nearExpiry, expired, depleted],
      creditAccounts: const [],
    );

    expect(data.nearingExpirationCount, 1);
    expect(data.expiredCount, 1);
  });
}

ExpenseRecord _expense({
  required String id,
  required double amount,
  required DateTime date,
  required String type,
}) => ExpenseRecord(
  id: id,
  category: 'Test',
  description: id,
  amount: amount,
  expenseDate: date,
  createdAt: date,
  expenseType: type,
);
