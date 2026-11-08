import 'dart:async';

import 'package:hive/hive.dart';

import '../../settings/services/activity_log_service.dart';
import '../models/expense_record.dart';

class ExpenseService {
  static const recordsBoxName = 'business_expenses_box';
  static const correctionsBoxName = 'expense_corrections_box';
  static Future<void> _writeQueue = Future<void>.value();
  static int _idSequence = 0;

  const ExpenseService();

  Future<Box<dynamic>> _openBox(String name) async {
    if (Hive.isBoxOpen(name)) return Hive.box<dynamic>(name);
    return Hive.openBox<dynamic>(name);
  }

  Future<T> _serializeWrites<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _writeQueue = _writeQueue.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  String _newId(String prefix, Box<dynamic> box) {
    String id;
    do {
      id = '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_idSequence++}';
    } while (box.containsKey(id));
    return id;
  }

  List<ExpenseRecord> _readRecords(Box<dynamic> box) => box.values
      .map((value) => ExpenseRecord.fromMap(value as Map))
      .toList(growable: false);

  void _validate(ExpenseRecord record) {
    if (record.category.trim().isEmpty) {
      throw ArgumentError.value(
        record.category,
        'category',
        'Choose a category.',
      );
    }
    if (record.description.trim().isEmpty) {
      throw ArgumentError.value(
        record.description,
        'description',
        'Description is required.',
      );
    }
    if (!record.amount.isFinite || record.amount <= 0) {
      throw ArgumentError.value(
        record.amount,
        'amount',
        'Amount must be greater than zero.',
      );
    }
  }

  Future<List<ExpenseRecord>> loadAll() async {
    final box = await _openBox(recordsBoxName);
    final records = _readRecords(box).toList()
      ..sort(
        (first, second) => second.expenseDate.compareTo(first.expenseDate),
      );
    return records;
  }

  Future<ExpenseRecord> addExpense({
    required String category,
    required String description,
    required double amount,
    required DateTime expenseDate,
  }) {
    return _serializeWrites(() async {
      final box = await _openBox(recordsBoxName);
      final historyBox = await _openBox(correctionsBoxName);
      final id = _newId('expense', box);
      final record = ExpenseRecord(
        id: id,
        category: category.trim(),
        description: description.trim(),
        amount: amount,
        expenseDate: _dateOnly(expenseDate),
        createdAt: DateTime.now(),
      );
      _validate(record);
      final correction = ExpenseCorrection(
        id: _newId('expense-history', historyBox),
        expenseId: id,
        action: 'Added',
        reason: 'Expense recorded',
        changedAt: DateTime.now(),
        updatedRecord: record.toMap(),
      );
      await box.put(record.id, record.toMap());
      try {
        await historyBox.put(correction.id, correction.toMap());
      } catch (error) {
        try {
          await box.delete(record.id);
        } catch (rollbackError) {
          throw StateError(
            'Could not save expense history ($error) or remove the unsaved expense ($rollbackError).',
          );
        }
        rethrow;
      }
      const ActivityLogService().recordInBackground(
        description:
            'Recorded ${record.category} expense: ${record.description}',
        category: 'Expense',
        occurredAt: record.createdAt,
      );
      return record;
    });
  }

  Future<ExpenseRecord> updateExpense({
    required ExpenseRecord updated,
    required String reason,
  }) {
    return _serializeWrites(() async {
      final normalizedReason = reason.trim();
      if (normalizedReason.isEmpty) {
        throw ArgumentError.value(
          reason,
          'reason',
          'A reason for the change is required.',
        );
      }
      final box = await _openBox(recordsBoxName);
      final historyBox = await _openBox(correctionsBoxName);
      final stored = box.get(updated.id);
      if (stored == null) throw StateError('Expense record not found.');
      final previous = ExpenseRecord.fromMap(stored as Map);
      final normalized = updated.copyWith(
        category: updated.category.trim(),
        description: updated.description.trim(),
        expenseDate: _dateOnly(updated.expenseDate),
      );
      _validate(normalized);
      final correction = ExpenseCorrection(
        id: _newId('expense-history', historyBox),
        expenseId: normalized.id,
        action: 'Edited',
        reason: normalizedReason,
        changedAt: DateTime.now(),
        previousRecord: previous.toMap(),
        updatedRecord: normalized.toMap(),
      );
      await box.put(normalized.id, normalized.toMap());
      try {
        await historyBox.put(correction.id, correction.toMap());
      } catch (error) {
        try {
          await box.put(previous.id, previous.toMap());
        } catch (rollbackError) {
          throw StateError(
            'Could not save the correction history ($error) or restore the expense ($rollbackError).',
          );
        }
        rethrow;
      }
      const ActivityLogService().recordInBackground(
        description: 'Updated expense: ${normalized.description}',
        category: 'Expense',
      );
      return normalized;
    });
  }

  Future<void> deleteExpense({
    required String expenseId,
    required String reason,
  }) {
    return _serializeWrites(() async {
      final normalizedReason = reason.trim();
      if (normalizedReason.isEmpty) {
        throw ArgumentError.value(
          reason,
          'reason',
          'A reason for the change is required.',
        );
      }
      final box = await _openBox(recordsBoxName);
      final historyBox = await _openBox(correctionsBoxName);
      final stored = box.get(expenseId);
      if (stored == null) throw StateError('Expense record not found.');
      final previous = ExpenseRecord.fromMap(stored as Map);
      final correction = ExpenseCorrection(
        id: _newId('expense-history', historyBox),
        expenseId: expenseId,
        action: 'Deleted',
        reason: normalizedReason,
        changedAt: DateTime.now(),
        previousRecord: previous.toMap(),
      );
      await historyBox.put(correction.id, correction.toMap());
      try {
        await box.delete(expenseId);
      } catch (error) {
        try {
          await historyBox.delete(correction.id);
        } catch (rollbackError) {
          throw StateError(
            'Could not delete the expense ($error) or remove its incomplete history entry ($rollbackError).',
          );
        }
        rethrow;
      }
      const ActivityLogService().recordInBackground(
        description: 'Deleted expense: ${previous.description}',
        category: 'Expense',
      );
    });
  }

  Future<List<ExpenseCorrection>> loadCorrections() async {
    final box = await _openBox(correctionsBoxName);
    final corrections =
        box.values
            .map((value) => ExpenseCorrection.fromMap(value as Map))
            .toList()
          ..sort(
            (first, second) => second.changedAt.compareTo(first.changedAt),
          );
    return corrections;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
