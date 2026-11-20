import '../customer_credit_and_debit_tracking/models/credit_records.dart';
import '../expense_tracking/models/expense_record.dart';
import '../product_and_inventory_management/models/expiration_model.dart';
import '../products/domain/product.dart';
import '../sales/domain/sale.dart';
import '../sales_management/models/sales_transaction_record.dart';

enum DashboardSalesPeriod { daily, weekly, monthly }

class DashboardSalesBucket {
  final String label;
  final double total;

  const DashboardSalesBucket({required this.label, required this.total});
}

class DashboardData {
  final DateTime calculatedAt;
  final List<ProductModel> products;
  final List<Sale> sales;
  final List<ExpenseRecord> expenses;
  final List<ExpirationModel> expirationRecords;
  final List<CreditAccount> creditAccounts;
  final List<SalesTransactionRecord> transactions;

  DashboardData._({
    required this.calculatedAt,
    required this.products,
    required this.sales,
    required this.expenses,
    required this.expirationRecords,
    required this.creditAccounts,
    required this.transactions,
  });

  factory DashboardData.fromRecords({
    required Iterable<ProductModel> products,
    required Iterable<Sale> sales,
    required Iterable<ExpenseRecord> expenses,
    required Iterable<ExpirationModel> expirationRecords,
    required Iterable<CreditAccount> creditAccounts,
    DateTime? now,
  }) {
    final currentProducts = products
        .where((product) => !product.id.startsWith('reference-'))
        .toList(growable: false);
    final currentSales = sales
        .where((sale) => !sale.id.startsWith('reference-sale-'))
        .toList(growable: false);
    final transactions = SalesTransactionRecord.groupSales(currentSales);
    return DashboardData._(
      calculatedAt: now ?? DateTime.now(),
      products: currentProducts,
      sales: currentSales,
      expenses: expenses.toList(growable: false),
      expirationRecords: expirationRecords.toList(growable: false),
      creditAccounts: creditAccounts.toList(growable: false),
      transactions: transactions,
    );
  }

  int get totalProducts => products.length;

  int get lowStockProductCount =>
      products.where((product) => product.isLowStock).length;

  double get todaySales => transactions
      .where((transaction) => _isSameDate(transaction.date, calculatedAt))
      .fold(0, (total, transaction) => total + transaction.total);

  double get todayExpenses => expenses
      .where((expense) => _isSameDate(expense.expenseDate, calculatedAt))
      .fold(0, (total, expense) => total + expense.amount);

  double? get estimatedProfit {
    final todayTransactions = transactions
        .where((transaction) => _isSameDate(transaction.date, calculatedAt))
        .toList(growable: false);
    final productsById = {for (final product in products) product.id: product};
    var costOfGoods = 0.0;
    for (final transaction in todayTransactions) {
      for (final item in transaction.items) {
        final unitCost =
            item.productCostAtSale ?? productsById[item.productId]?.costPrice;
        if (unitCost == null) return null;
        costOfGoods += unitCost * item.quantitySold;
      }
    }
    final operatingExpenses = expenses
        .where(
          (expense) =>
              _isSameDate(expense.expenseDate, calculatedAt) &&
              expense.expenseType.trim().toLowerCase() != 'inventory purchase',
        )
        .fold<double>(0, (total, expense) => total + expense.amount);
    return todaySales - costOfGoods - operatingExpenses;
  }

  List<SalesTransactionRecord> get recentTransactions =>
      transactions.take(3).toList(growable: false);

  int get nearingExpirationCount => expirationRecords
      .where(
        (record) =>
            record.calculateStatus(now: calculatedAt) ==
            ExpirationStatus.nearingExpiration,
      )
      .length;

  int get expiredCount => expirationRecords
      .where(
        (record) =>
            record.calculateStatus(now: calculatedAt) ==
            ExpirationStatus.expired,
      )
      .length;

  Map<String, double> get outstandingBalancesBySale => {
    for (final account in creditAccounts)
      account.saleId: account.outstandingBalance,
  };

  bool isTransactionPaid(SalesTransactionRecord transaction) {
    final outstanding = outstandingBalancesBySale[transaction.id];
    if (outstanding != null) return outstanding <= 0;
    return transaction.amountPaid >= transaction.total;
  }

  List<SalesTransactionRecord> transactionsFor(DashboardSalesPeriod period) {
    final range = _periodRange(period, calculatedAt);
    return transactions
        .where(
          (transaction) =>
              !transaction.date.isBefore(range.$1) &&
              transaction.date.isBefore(range.$2),
        )
        .toList(growable: false);
  }

  List<DashboardSalesBucket> salesBuckets(DashboardSalesPeriod period) {
    final values = switch (period) {
      DashboardSalesPeriod.daily => List<double>.filled(8, 0),
      DashboardSalesPeriod.weekly => List<double>.filled(7, 0),
      DashboardSalesPeriod.monthly => List<double>.filled(5, 0),
    };
    final labels = switch (period) {
      DashboardSalesPeriod.daily => const [
        '12a',
        '3a',
        '6a',
        '9a',
        '12p',
        '3p',
        '6p',
        '9p',
      ],
      DashboardSalesPeriod.weekly => const [
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun',
      ],
      DashboardSalesPeriod.monthly => const [
        '1-7',
        '8-14',
        '15-21',
        '22-28',
        '29+',
      ],
    };
    for (final transaction in transactionsFor(period)) {
      final index = switch (period) {
        DashboardSalesPeriod.daily => transaction.date.hour ~/ 3,
        DashboardSalesPeriod.weekly => transaction.date.weekday - 1,
        DashboardSalesPeriod.monthly => (transaction.date.day - 1) ~/ 7,
      };
      values[index] += transaction.total;
    }
    return [
      for (var index = 0; index < values.length; index++)
        DashboardSalesBucket(label: labels[index], total: values[index]),
    ];
  }

  (DateTime, DateTime) _periodRange(DashboardSalesPeriod period, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (period) {
      DashboardSalesPeriod.daily => (today, today.add(const Duration(days: 1))),
      DashboardSalesPeriod.weekly => (
        today.subtract(Duration(days: today.weekday - 1)),
        today
            .subtract(Duration(days: today.weekday - 1))
            .add(const Duration(days: 7)),
      ),
      DashboardSalesPeriod.monthly => (
        DateTime(now.year, now.month),
        DateTime(now.year, now.month + 1),
      ),
    };
  }

  static bool _isSameDate(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
