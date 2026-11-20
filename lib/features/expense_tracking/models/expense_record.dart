class ExpenseRecord {
  final String id;
  final String category;
  final String description;
  final double amount;
  final DateTime expenseDate;
  final DateTime createdAt;
  final String paymentMethod;
  final String? referenceNumber;
  final String? recordedBy;
  final String remarks;
  final String expenseType;

  const ExpenseRecord({
    required this.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.expenseDate,
    required this.createdAt,
    this.paymentMethod = 'Cash',
    this.referenceNumber,
    this.recordedBy,
    this.remarks = '',
    this.expenseType = 'Operating Expense',
  });

  ExpenseRecord copyWith({
    String? category,
    String? description,
    double? amount,
    DateTime? expenseDate,
    String? paymentMethod,
    String? referenceNumber,
    String? recordedBy,
    String? remarks,
    String? expenseType,
  }) {
    return ExpenseRecord(
      id: id,
      category: category ?? this.category,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      expenseDate: expenseDate ?? this.expenseDate,
      createdAt: createdAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      recordedBy: recordedBy ?? this.recordedBy,
      remarks: remarks ?? this.remarks,
      expenseType: expenseType ?? this.expenseType,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'category': category,
    'description': description,
    'amount': amount,
    'expenseDate': expenseDate,
    'createdAt': createdAt,
    'paymentMethod': paymentMethod,
    'referenceNumber': referenceNumber,
    'recordedBy': recordedBy,
    'remarks': remarks,
    'expenseType': expenseType,
  };

  factory ExpenseRecord.fromMap(Map<dynamic, dynamic> map) => ExpenseRecord(
    id: map['id'] as String,
    category: map['category'] as String,
    description: map['description'] as String,
    amount: (map['amount'] as num).toDouble(),
    expenseDate: _dateFrom(map['expenseDate'], 'expenseDate'),
    createdAt: _dateFrom(map['createdAt'], 'createdAt'),
    paymentMethod: map['paymentMethod'] as String? ?? 'Cash',
    referenceNumber: map['referenceNumber'] as String?,
    recordedBy: map['recordedBy'] as String?,
    remarks: map['remarks'] as String? ?? '',
    expenseType: map['expenseType'] as String? ?? 'Operating Expense',
  );

  static DateTime _dateFrom(Object? value, String field) {
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw FormatException('Invalid expense $field.');
  }
}

class ExpenseCorrection {
  final String id;
  final String expenseId;
  final String action;
  final String reason;
  final DateTime changedAt;
  final Map<String, Object?>? previousRecord;
  final Map<String, Object?>? updatedRecord;

  const ExpenseCorrection({
    required this.id,
    required this.expenseId,
    required this.action,
    required this.reason,
    required this.changedAt,
    this.previousRecord,
    this.updatedRecord,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'expenseId': expenseId,
    'action': action,
    'reason': reason,
    'changedAt': changedAt,
    'previousRecord': previousRecord,
    'updatedRecord': updatedRecord,
  };

  factory ExpenseCorrection.fromMap(Map<dynamic, dynamic> map) =>
      ExpenseCorrection(
        id: map['id'] as String,
        expenseId: map['expenseId'] as String,
        action: map['action'] as String,
        reason: map['reason'] as String,
        changedAt: map['changedAt'] as DateTime,
        previousRecord: map['previousRecord'] == null
            ? null
            : Map<String, Object?>.from(map['previousRecord'] as Map),
        updatedRecord: map['updatedRecord'] == null
            ? null
            : Map<String, Object?>.from(map['updatedRecord'] as Map),
      );
}
