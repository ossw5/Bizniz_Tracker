import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:bizniz_tracker/features/expense_tracking/models/expense_record.dart';
import 'package:bizniz_tracker/features/expense_tracking/screens/expense_tracking_screen.dart';
import 'package:bizniz_tracker/features/expense_tracking/services/expense_service.dart';

void main() {
  late Directory directory;
  const service = ExpenseService();

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('expense_tracking_');
    Hive.init(directory.path);
  });

  setUp(() async {
    if (Hive.isBoxOpen(ExpenseService.recordsBoxName)) {
      await Hive.box<dynamic>(ExpenseService.recordsBoxName).clear();
    }
    if (Hive.isBoxOpen(ExpenseService.correctionsBoxName)) {
      await Hive.box<dynamic>(ExpenseService.correctionsBoxName).clear();
    }
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'expense edits and deletions keep reasoned correction history',
    () async {
      final created = await service.addExpense(
        category: 'Utilities',
        description: 'Electricity',
        amount: 1250,
        expenseDate: DateTime(2026, 11, 8, 15),
      );
      final updated = await service.updateExpense(
        updated: created.copyWith(amount: 1400),
        reason: 'Corrected the bill amount',
      );
      expect(updated.amount, 1400);

      await service.deleteExpense(
        expenseId: created.id,
        reason: 'Duplicate entry',
      );

      expect(await service.loadAll(), isEmpty);
      final history = await service.loadCorrections();
      expect(history.map((entry) => entry.action), [
        'Deleted',
        'Edited',
        'Added',
      ]);
      expect(history[0].reason, 'Duplicate entry');
      expect(history[1].reason, 'Corrected the bill amount');
      expect(history[1].previousRecord?['amount'], 1250);
      expect(history[1].updatedRecord?['amount'], 1400);
    },
  );

  testWidgets('expense screen records and displays an expense', (tester) async {
    final memoryService = _MemoryExpenseService();
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseTrackingScreen(
          saleRepository: null,
          products: const [],
          service: memoryService,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Add Expense'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byType(TextFormField).at(0), '125.50');
    await tester.enterText(find.byType(TextFormField).at(1), 'Shop supplies');
    tester.testTextInput.hide();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.text('Save Expense'));
    await tester.tap(find.text('Save Expense'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Shop supplies'), findsOneWidget);
    expect(find.text('Utilities'), findsOneWidget);
    expect(find.textContaining('₱125.50'), findsWidgets);
  });

  test('rejects invalid expenses and changes without reasons', () async {
    await expectLater(
      service.addExpense(
        category: 'Utilities',
        description: 'Bill',
        amount: 0,
        expenseDate: DateTime(2026, 11, 8),
      ),
      throwsA(isA<ArgumentError>()),
    );
    final created = await service.addExpense(
      category: 'Utilities',
      description: 'Bill',
      amount: 50,
      expenseDate: DateTime(2026, 11, 8),
    );
    await expectLater(
      service.updateExpense(updated: created.copyWith(amount: 75), reason: ' '),
      throwsA(isA<ArgumentError>()),
    );
  });
}

class _MemoryExpenseService extends ExpenseService {
  final List<ExpenseRecord> records = [];

  @override
  Future<List<ExpenseRecord>> loadAll() async => List.of(records);

  @override
  Future<ExpenseRecord> addExpense({
    required String category,
    required String description,
    required double amount,
    required DateTime expenseDate,
  }) async {
    final record = ExpenseRecord(
      id: 'memory-${records.length}',
      category: category,
      description: description,
      amount: amount,
      expenseDate: DateTime(
        expenseDate.year,
        expenseDate.month,
        expenseDate.day,
      ),
      createdAt: DateTime.now(),
    );
    records.add(record);
    return record;
  }
}
