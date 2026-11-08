class ExpenseRecord {
  final String id;
  final String category;
  final String description;
  final double amount;
  final DateTime expenseDate;
  final DateTime createdAt;

  const ExpenseRecord({
    required this.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.expenseDate,
    required this.createdAt,
  });

  ExpenseRecord copyWith({
    String? category,
    String? description,
    double? amount,
    DateTime? expenseDate,
  }) {
    return ExpenseRecord(
      id: id,
      category: category ?? this.category,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      expenseDate: expenseDate ?? this.expenseDate,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'category': category,
    'description': description,
    'amount': amount,
    'expenseDate': expenseDate,
    'createdAt': createdAt,
  };

  factory ExpenseRecord.fromMap(Map<dynamic, dynamic> map) => ExpenseRecord(
    id: map['id'] as String,
    category: map['category'] as String,
    description: map['description'] as String,
    amount: (map['amount'] as num).toDouble(),
    expenseDate: map['expenseDate'] as DateTime,
    createdAt: map['createdAt'] as DateTime,
  );
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
