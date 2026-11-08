import 'dart:async';

import 'package:hive/hive.dart';

import '../../settings/services/activity_log_service.dart';
import '../models/credit_records.dart';

class CreditTrackingService {
  static const customersBoxName = 'credit_customers_box';
  static const creditsBoxName = 'customer_credits_box';
  static const paymentsBoxName = 'credit_payments_box';
  static const correctionsBoxName = 'credit_balance_corrections_box';
  static Future<void> _writeQueue = Future<void>.value();
  static int _idSequence = 0;

  const CreditTrackingService();

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

  Future<List<CreditCustomer>> loadCustomers() async {
    final box = await _openBox(customersBoxName);
    final customers =
        box.values.map((value) => CreditCustomer.fromMap(value as Map)).toList()
          ..sort(
            (first, second) => first.fullName.toLowerCase().compareTo(
              second.fullName.toLowerCase(),
            ),
          );
    return customers;
  }

  Future<CreditCustomer> addCustomer({
    required String fullName,
    required String phone,
    required String address,
    required String notes,
  }) {
    return _serializeWrites(() async {
      final name = fullName.trim();
      if (name.isEmpty) {
        throw ArgumentError.value(
          fullName,
          'fullName',
          'Customer name is required.',
        );
      }
      final box = await _openBox(customersBoxName);
      final customer = CreditCustomer(
        id: _newId('customer', box),
        fullName: name,
        phone: phone.trim(),
        address: address.trim(),
        notes: notes.trim(),
        createdAt: DateTime.now(),
      );
      await box.put(customer.id, customer.toMap());
      const ActivityLogService().recordInBackground(
        description: 'Registered customer: ${customer.fullName}',
        category: 'Customer',
        occurredAt: customer.createdAt,
      );
      return customer;
    });
  }

  Future<CreditAccount> addCredit({
    required CreditCustomer customer,
    required String saleId,
    required String itemName,
    required int quantity,
    required double unitPrice,
    required DateTime creditDate,
    required DateTime dueDate,
  }) {
    return _serializeWrites(() async {
      if (saleId.trim().isEmpty || itemName.trim().isEmpty) {
        throw ArgumentError('A linked sale and item are required.');
      }
      if (quantity <= 0 ||
          !unitPrice.isFinite ||
          unitPrice <= 0 ||
          _dateOnly(dueDate).isBefore(_dateOnly(creditDate))) {
        throw ArgumentError(
          'Enter a valid credit amount, quantity, and due date.',
        );
      }
      final customersBox = await _openBox(customersBoxName);
      if (!customersBox.containsKey(customer.id)) {
        throw StateError('The selected customer is no longer registered.');
      }
      final box = await _openBox(creditsBoxName);
      if (box.values
          .map((value) => CreditAccount.fromMap(value as Map))
          .any((credit) => credit.saleId == saleId)) {
        throw StateError('A credit record already exists for this sale.');
      }
      final total = _toCurrency(quantity * unitPrice);
      final account = CreditAccount(
        id: _newId('credit', box),
        customerId: customer.id,
        customerName: customer.fullName,
        saleId: saleId,
        itemName: itemName.trim(),
        quantity: quantity,
        unitPrice: unitPrice,
        originalAmount: total,
        outstandingBalance: total,
        creditDate: _dateOnly(creditDate),
        dueDate: _dateOnly(dueDate),
      );
      await box.put(account.id, account.toMap());
      const ActivityLogService().recordInBackground(
        description:
            'Recorded ${account.itemName} credit for ${account.customerName}',
        category: 'Credit',
        occurredAt: account.creditDate,
      );
      return account;
    });
  }

  Future<void> rollbackCredit(String creditId) {
    return _serializeWrites(() async {
      final box = await _openBox(creditsBoxName);
      await box.delete(creditId);
    });
  }

  Future<List<CreditAccount>> loadCredits() async {
    final box = await _openBox(creditsBoxName);
    final credits =
        box.values.map((value) => CreditAccount.fromMap(value as Map)).toList()
          ..sort(
            (first, second) => second.creditDate.compareTo(first.creditDate),
          );
    return credits;
  }

  Future<CreditPayment> recordPayment({
    required String creditId,
    required double amount,
    required String paymentMethod,
    DateTime? paymentDate,
  }) {
    return _serializeWrites(() async {
      if (!amount.isFinite || amount <= 0) {
        throw ArgumentError.value(
          amount,
          'amount',
          'Payment must be greater than zero.',
        );
      }
      const methods = ['Cash', 'GCash'];
      if (!methods.contains(paymentMethod)) {
        throw ArgumentError.value(
          paymentMethod,
          'paymentMethod',
          'Choose Cash or GCash.',
        );
      }
      final creditsBox = await _openBox(creditsBoxName);
      final paymentsBox = await _openBox(paymentsBoxName);
      final stored = creditsBox.get(creditId);
      if (stored == null) throw StateError('Credit record not found.');
      final account = CreditAccount.fromMap(stored as Map);
      final amountToCents = _toCents(amount);
      final balanceCents = _toCents(account.outstandingBalance);
      if (amountToCents > balanceCents) {
        throw ArgumentError.value(
          amount,
          'amount',
          'Payment cannot exceed the outstanding balance.',
        );
      }
      final payment = CreditPayment(
        id: _newId('payment', paymentsBox),
        creditId: creditId,
        customerId: account.customerId,
        customerName: account.customerName,
        amount: amountToCents / 100,
        paymentMethod: paymentMethod,
        paymentDate: paymentDate ?? DateTime.now(),
      );
      final updated = account.copyWith(
        outstandingBalance: (balanceCents - amountToCents) / 100,
      );
      await paymentsBox.put(payment.id, payment.toMap());
      try {
        await creditsBox.put(updated.id, updated.toMap());
      } catch (error) {
        try {
          await paymentsBox.delete(payment.id);
        } catch (rollbackError) {
          throw StateError(
            'Could not update the balance ($error) or remove the unsaved payment ($rollbackError).',
          );
        }
        rethrow;
      }
      const ActivityLogService().recordInBackground(
        description:
            'Recorded ${payment.paymentMethod} payment from ${payment.customerName}',
        category: 'Credit',
        occurredAt: payment.paymentDate,
      );
      return payment;
    });
  }

  Future<List<CreditPayment>> loadPayments({String? creditId}) async {
    final box = await _openBox(paymentsBoxName);
    final payments =
        box.values
            .map((value) => CreditPayment.fromMap(value as Map))
            .where(
              (payment) => creditId == null || payment.creditId == creditId,
            )
            .toList()
          ..sort(
            (first, second) => second.paymentDate.compareTo(first.paymentDate),
          );
    return payments;
  }

  Future<CreditAccount> correctBalance({
    required String creditId,
    required double correctedBalance,
    required String reason,
    required String details,
    required String authorizedBy,
  }) {
    return _serializeWrites(() async {
      final normalizedReason = reason.trim();
      final normalizedDetails = details.trim();
      final normalizedAuthorizedBy = authorizedBy.trim();
      if (normalizedReason.isEmpty ||
          normalizedDetails.isEmpty ||
          normalizedAuthorizedBy.isEmpty) {
        throw ArgumentError('Reason, details, and authorizer are required.');
      }
      if (!correctedBalance.isFinite || correctedBalance < 0) {
        throw ArgumentError.value(
          correctedBalance,
          'correctedBalance',
          'Balance cannot be negative.',
        );
      }
      final creditsBox = await _openBox(creditsBoxName);
      final correctionsBox = await _openBox(correctionsBoxName);
      final stored = creditsBox.get(creditId);
      if (stored == null) throw StateError('Credit record not found.');
      final account = CreditAccount.fromMap(stored as Map);
      final correction = BalanceCorrection(
        id: _newId('balance-correction', correctionsBox),
        creditId: creditId,
        customerName: account.customerName,
        originalBalance: account.outstandingBalance,
        correctedBalance: _toCurrency(correctedBalance),
        reason: normalizedReason,
        details: normalizedDetails,
        authorizedBy: normalizedAuthorizedBy,
        changedAt: DateTime.now(),
      );
      final updated = account.copyWith(
        outstandingBalance: correction.correctedBalance,
      );
      await correctionsBox.put(correction.id, correction.toMap());
      try {
        await creditsBox.put(updated.id, updated.toMap());
      } catch (error) {
        try {
          await correctionsBox.delete(correction.id);
        } catch (rollbackError) {
          throw StateError(
            'Could not update the balance ($error) or remove the incomplete correction ($rollbackError).',
          );
        }
        rethrow;
      }
      const ActivityLogService().recordInBackground(
        description: 'Corrected credit balance for ${account.customerName}',
        category: 'Credit',
        occurredAt: correction.changedAt,
      );
      return updated;
    });
  }

  Future<List<BalanceCorrection>> loadCorrections() async {
    final box = await _openBox(correctionsBoxName);
    final corrections =
        box.values
            .map((value) => BalanceCorrection.fromMap(value as Map))
            .toList()
          ..sort(
            (first, second) => second.changedAt.compareTo(first.changedAt),
          );
    return corrections;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static int _toCents(double amount) => (amount * 100).round();

  static double _toCurrency(double amount) => _toCents(amount) / 100;
}
