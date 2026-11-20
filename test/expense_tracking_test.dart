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
    await tester.ensureVisible(find.text('Save Expense'));
    await tester.tap(find.text('Save Expense'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.drag(find.byType(ListView).last, const Offset(0, -900));
    await tester.pumpAndSettle();
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

  test(
    'expense report details persist and older records retain defaults',
    () async {
      final created = await service.addExpense(
        category: 'Stock',
        description: 'Wholesale goods',
        amount: 350,
        expenseDate: DateTime(2026, 11, 12),
        paymentMethod: 'Bank Transfer',
        referenceNumber: 'TRX-12',
        recordedBy: 'Owner',
        remarks: 'For resale',
        expenseType: 'Inventory Purchase',
      );
      final loaded = (await service.loadAll()).single;
      expect(loaded.paymentMethod, 'Bank Transfer');
      expect(loaded.referenceNumber, 'TRX-12');
      expect(loaded.recordedBy, 'Owner');
      expect(loaded.remarks, 'For resale');
      expect(loaded.expenseType, 'Inventory Purchase');
      expect(
        ExpenseRecord.fromMap({
          'id': created.id,
          'category': 'Utilities',
          'description': 'Legacy record',
          'amount': 10,
          'expenseDate': DateTime(2026, 11, 12),
          'createdAt': DateTime(2026, 11, 12),
        }).paymentMethod,
        'Cash',
      );
    },
  );

  test(
    'expense records remain available after reopening their Hive box',
    () async {
      final saved = await service.addExpense(
        category: 'Utilities',
        description: 'Electricity',
        amount: 1250,
        expenseDate: DateTime(2026, 11, 8, 15),
        paymentMethod: 'Bank Transfer',
        referenceNumber: 'BILL-8',
        remarks: 'November bill',
      );
      await Hive.box<dynamic>(ExpenseService.recordsBoxName).close();

      final loaded = await service.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.single.id, saved.id);
      expect(loaded.single.expenseDate, DateTime(2026, 11, 8));
      expect(loaded.single.amount, 1250);
      expect(loaded.single.paymentMethod, 'Bank Transfer');
      expect(loaded.single.referenceNumber, 'BILL-8');
      expect(loaded.single.remarks, 'November bill');
    },
  );

  test('expense records accept ISO date strings from older saved formats', () {
    final record = ExpenseRecord.fromMap({
      'id': 'legacy-expense',
      'category': 'Utilities',
      'description': 'Legacy bill',
      'amount': 10,
      'expenseDate': '2026-11-08T00:00:00.000',
      'createdAt': '2026-11-08T09:30:00.000',
    });

    expect(record.expenseDate, DateTime(2026, 11, 8));
    expect(record.createdAt, DateTime(2026, 11, 8, 9, 30));
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
    String paymentMethod = 'Cash',
    String? referenceNumber,
    String? recordedBy,
    String remarks = '',
    String expenseType = 'Operating Expense',
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
      paymentMethod: paymentMethod,
      referenceNumber: referenceNumber,
      recordedBy: recordedBy,
      remarks: remarks,
      expenseType: expenseType,
    );
    records.add(record);
    return record;
  }
}
