class CreditCustomer {
  final String id;
  final String fullName;
  final String phone;
  final String address;
  final String notes;
  final DateTime createdAt;

  const CreditCustomer({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.address,
    required this.notes,
    required this.createdAt,
  });

  factory CreditCustomer.fromMap(Map map) => CreditCustomer(
    id: map['id'] as String,
    fullName: map['fullName'] as String,
    phone: map['phone'] as String? ?? '',
    address: map['address'] as String? ?? '',
    notes: map['notes'] as String? ?? '',
    createdAt: DateTime.parse(map['createdAt'] as String),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'fullName': fullName,
    'phone': phone,
    'address': address,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
  };
}

class CreditAccount {
  final String id;
  final String customerId;
  final String customerName;
  final String saleId;
  final String itemName;
  final int quantity;
  final double unitPrice;
  final double originalAmount;
  final double outstandingBalance;
  final DateTime creditDate;
  final DateTime dueDate;

  const CreditAccount({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.saleId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.originalAmount,
    required this.outstandingBalance,
    required this.creditDate,
    required this.dueDate,
  });

  bool get isSettled => outstandingBalance <= 0;

  factory CreditAccount.fromMap(Map map) => CreditAccount(
    id: map['id'] as String,
    customerId: map['customerId'] as String,
    customerName: map['customerName'] as String,
    saleId: map['saleId'] as String,
    itemName: map['itemName'] as String,
    quantity: map['quantity'] as int,
    unitPrice: (map['unitPrice'] as num).toDouble(),
    originalAmount: (map['originalAmount'] as num).toDouble(),
    outstandingBalance: (map['outstandingBalance'] as num).toDouble(),
    creditDate: DateTime.parse(map['creditDate'] as String),
    dueDate: DateTime.parse(map['dueDate'] as String),
  );

  CreditAccount copyWith({double? outstandingBalance}) => CreditAccount(
    id: id,
    customerId: customerId,
    customerName: customerName,
    saleId: saleId,
    itemName: itemName,
    quantity: quantity,
    unitPrice: unitPrice,
    originalAmount: originalAmount,
    outstandingBalance: outstandingBalance ?? this.outstandingBalance,
    creditDate: creditDate,
    dueDate: dueDate,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'customerId': customerId,
    'customerName': customerName,
    'saleId': saleId,
    'itemName': itemName,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'originalAmount': originalAmount,
    'outstandingBalance': outstandingBalance,
    'creditDate': creditDate.toIso8601String(),
    'dueDate': dueDate.toIso8601String(),
  };
}

class CreditPayment {
  final String id;
  final String creditId;
  final String customerId;
  final String customerName;
  final double amount;
  final String paymentMethod;
  final DateTime paymentDate;

  const CreditPayment({
    required this.id,
    required this.creditId,
    required this.customerId,
    required this.customerName,
    required this.amount,
    required this.paymentMethod,
    required this.paymentDate,
  });

  factory CreditPayment.fromMap(Map map) => CreditPayment(
    id: map['id'] as String,
    creditId: map['creditId'] as String,
    customerId: map['customerId'] as String,
    customerName: map['customerName'] as String,
    amount: (map['amount'] as num).toDouble(),
    paymentMethod: map['paymentMethod'] as String,
    paymentDate: DateTime.parse(map['paymentDate'] as String),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'creditId': creditId,
    'customerId': customerId,
    'customerName': customerName,
    'amount': amount,
    'paymentMethod': paymentMethod,
    'paymentDate': paymentDate.toIso8601String(),
  };
}

class BalanceCorrection {
  final String id;
  final String creditId;
  final String customerName;
  final double originalBalance;
  final double correctedBalance;
  final String reason;
  final String details;
  final String authorizedBy;
  final DateTime changedAt;

  const BalanceCorrection({
    required this.id,
    required this.creditId,
    required this.customerName,
    required this.originalBalance,
    required this.correctedBalance,
    required this.reason,
    required this.details,
    required this.authorizedBy,
    required this.changedAt,
  });

  factory BalanceCorrection.fromMap(Map map) => BalanceCorrection(
    id: map['id'] as String,
    creditId: map['creditId'] as String,
    customerName: map['customerName'] as String,
    originalBalance: (map['originalBalance'] as num).toDouble(),
    correctedBalance: (map['correctedBalance'] as num).toDouble(),
    reason: map['reason'] as String,
    details: map['details'] as String,
    authorizedBy: map['authorizedBy'] as String,
    changedAt: DateTime.parse(map['changedAt'] as String),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'creditId': creditId,
    'customerName': customerName,
    'originalBalance': originalBalance,
    'correctedBalance': correctedBalance,
    'reason': reason,
    'details': details,
    'authorizedBy': authorizedBy,
    'changedAt': changedAt.toIso8601String(),
  };
}
