import '../../expense_tracking/models/expense_record.dart';

class ExpenseReportSummary {
  final List<ExpenseRecord> records;
  final double total;
  final ExpenseRecord? highest;
  final Map<String, double> categoryTotals;
  final Map<String, double> paymentMethodTotals;

  ExpenseReportSummary._({
    required this.records,
    required this.total,
    required this.highest,
    required this.categoryTotals,
    required this.paymentMethodTotals,
  });

  factory ExpenseReportSummary.fromRecords(Iterable<ExpenseRecord> source) {
    final records = List<ExpenseRecord>.unmodifiable(source);
    var total = 0.0;
    ExpenseRecord? highest;
    final categoryTotals = <String, double>{};
    final paymentMethodTotals = <String, double>{};
    for (final record in records) {
      total += record.amount;
      if (highest == null || record.amount > highest.amount) {
        highest = record;
      }
      categoryTotals.update(
        record.category,
        (value) => value + record.amount,
        ifAbsent: () => record.amount,
      );
      paymentMethodTotals.update(
        record.paymentMethod,
        (value) => value + record.amount,
        ifAbsent: () => record.amount,
      );
    }

    return ExpenseReportSummary._(
      records: records,
      total: total,
      highest: highest,
      categoryTotals: Map.unmodifiable(categoryTotals),
      paymentMethodTotals: Map.unmodifiable(paymentMethodTotals),
    );
  }

  int get transactionCount => records.length;

  double get average => records.isEmpty ? 0 : total / records.length;

  double percentageOfTotal(double amount) =>
      total == 0 ? 0 : amount / total * 100;
}
