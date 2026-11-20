import 'package:flutter_test/flutter_test.dart';

import 'package:bizniz_tracker/features/expense_tracking/models/expense_record.dart';
import 'package:bizniz_tracker/features/reports/services/expense_report_summary.dart';

void main() {
  test('summarizes the matching expense records and their breakdowns', () {
    final summary = ExpenseReportSummary.fromRecords([
      _expense(
        id: 'expense-1',
        category: 'Utilities',
        amount: 25,
        paymentMethod: 'Cash',
      ),
      _expense(
        id: 'expense-2',
        category: 'Supplies',
        amount: 75,
        paymentMethod: 'Bank Transfer',
      ),
      _expense(
        id: 'expense-3',
        category: 'Utilities',
        amount: 50,
        paymentMethod: 'Cash',
      ),
    ]);

    expect(summary.transactionCount, 3);
    expect(summary.records.map((record) => record.id), [
      'expense-1',
      'expense-2',
      'expense-3',
    ]);
    expect(summary.total, 150);
    expect(summary.highest?.id, 'expense-2');
    expect(summary.average, 50);
    expect(summary.categoryTotals, {'Utilities': 75, 'Supplies': 75});
    expect(summary.paymentMethodTotals, {'Cash': 75, 'Bank Transfer': 75});
    expect(summary.percentageOfTotal(75), 50);
  });

  test('empty reports have zero statistics and no breakdowns', () {
    final summary = ExpenseReportSummary.fromRecords(const []);

    expect(summary.transactionCount, 0);
    expect(summary.total, 0);
    expect(summary.highest, isNull);
    expect(summary.average, 0);
    expect(summary.categoryTotals, isEmpty);
    expect(summary.paymentMethodTotals, isEmpty);
    expect(summary.percentageOfTotal(10), 0);
  });
}

ExpenseRecord _expense({
  required String id,
  required String category,
  required double amount,
  required String paymentMethod,
}) => ExpenseRecord(
  id: id,
  category: category,
  description: 'Test expense',
  amount: amount,
  expenseDate: DateTime(2026, 11, 8),
  createdAt: DateTime(2026, 11, 8),
  paymentMethod: paymentMethod,
);
