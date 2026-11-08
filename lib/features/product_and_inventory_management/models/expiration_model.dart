import 'package:flutter/material.dart';

import '../../products/domain/product.dart';

enum ExpirationStatus { normal, nearingExpiration, expired, depleted }

extension ExpirationStatusX on ExpirationStatus {
  String get label {
    switch (this) {
      case ExpirationStatus.normal:
        return 'Normal';
      case ExpirationStatus.nearingExpiration:
        return 'Nearing Expiration';
      case ExpirationStatus.expired:
        return 'Expired';
      case ExpirationStatus.depleted:
        return 'Depleted';
    }
  }

  String get shortLabel {
    switch (this) {
      case ExpirationStatus.normal:
        return 'NORMAL';
      case ExpirationStatus.nearingExpiration:
        return 'NEARING';
      case ExpirationStatus.expired:
        return 'EXPIRED';
      case ExpirationStatus.depleted:
        return 'DEPLETED';
    }
  }

  Color get color {
    switch (this) {
      case ExpirationStatus.normal:
        return const Color(0xFF2E7D32);
      case ExpirationStatus.nearingExpiration:
        return const Color(0xFFF9A825);
      case ExpirationStatus.expired:
        return const Color(0xFFD32F2F);
      case ExpirationStatus.depleted:
        return const Color(0xFF616161);
    }
  }
}

class ExpirationModel {
  static const defaultNearExpirationDays = 30;

  final String id;
  final String productId;
  final String productName;
  final String batchIdentifier;
  final int initialQuantity;
  final int remainingQuantity;
  final DateTime expirationDate;
  final DateTime createdAt;
  final String? notes;

  const ExpirationModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.batchIdentifier,
    required this.initialQuantity,
    required this.remainingQuantity,
    required this.expirationDate,
    required this.createdAt,
    this.notes,
  });

  factory ExpirationModel.fromProduct({
    required String id,
    required ProductModel product,
    required DateTime expirationDate,
    required int initialQuantity,
    required String batchIdentifier,
    String? notes,
    DateTime? createdAt,
  }) {
    return ExpirationModel(
      id: id,
      productId: product.id,
      productName: product.name,
      batchIdentifier: batchIdentifier,
      initialQuantity: initialQuantity,
      remainingQuantity: initialQuantity,
      expirationDate: DateTime(
        expirationDate.year,
        expirationDate.month,
        expirationDate.day,
      ),
      createdAt: createdAt ?? DateTime.now(),
      notes: notes,
    );
  }

  ExpirationStatus get status => calculateStatus();

  ExpirationStatus calculateStatus({
    DateTime? now,
    int nearingExpirationDays = defaultNearExpirationDays,
  }) {
    if (remainingQuantity <= 0) return ExpirationStatus.depleted;

    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final expirationDay = DateTime(
      expirationDate.year,
      expirationDate.month,
      expirationDate.day,
    );
    if (expirationDay.isBefore(today)) return ExpirationStatus.expired;
    if (expirationDay.difference(today).inDays <= nearingExpirationDays) {
      return ExpirationStatus.nearingExpiration;
    }
    return ExpirationStatus.normal;
  }

  ExpirationModel copyWith({
    String? id,
    String? productId,
    String? productName,
    String? batchIdentifier,
    int? initialQuantity,
    int? remainingQuantity,
    DateTime? expirationDate,
    DateTime? createdAt,
    String? notes,
    bool clearNotes = false,
  }) {
    return ExpirationModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      batchIdentifier: batchIdentifier ?? this.batchIdentifier,
      initialQuantity: initialQuantity ?? this.initialQuantity,
      remainingQuantity: remainingQuantity ?? this.remainingQuantity,
      expirationDate: expirationDate ?? this.expirationDate,
      createdAt: createdAt ?? this.createdAt,
      notes: clearNotes ? null : notes ?? this.notes,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'productId': productId,
    'productName': productName,
    'batchIdentifier': batchIdentifier,
    'initialQuantity': initialQuantity,
    'remainingQuantity': remainingQuantity,
    'expirationDate': expirationDate,
    'createdAt': createdAt,
    'notes': notes,
  };

  factory ExpirationModel.fromMap(Map<dynamic, dynamic> map) {
    return ExpirationModel(
      id: map['id'] as String,
      productId: map['productId'] as String,
      productName: map['productName'] as String,
      batchIdentifier: map['batchIdentifier'] as String,
      initialQuantity: map['initialQuantity'] as int,
      remainingQuantity: map['remainingQuantity'] as int,
      expirationDate: map['expirationDate'] as DateTime,
      createdAt: map['createdAt'] as DateTime,
      notes: map['notes'] as String?,
    );
  }
}

enum StockMovementType { sold, removed, discarded }

extension StockMovementTypeX on StockMovementType {
  String get label {
    switch (this) {
      case StockMovementType.sold:
        return 'Sold';
      case StockMovementType.removed:
        return 'Removed';
      case StockMovementType.discarded:
        return 'Discarded';
    }
  }
}

class ExpirationHistoryEntry {
  final String id;
  final String productId;
  final String productName;
  final String batchIdentifier;
  final StockMovementType movementType;
  final int previousQuantity;
  final int updatedQuantity;
  final DateTime movementDate;
  final DateTime expirationDate;
  final String? remarks;

  const ExpirationHistoryEntry({
    required this.id,
    required this.productId,
    required this.productName,
    required this.batchIdentifier,
    required this.movementType,
    required this.previousQuantity,
    required this.updatedQuantity,
    required this.movementDate,
    required this.expirationDate,
    this.remarks,
  });

  ExpirationStatus get status {
    if (updatedQuantity <= 0) return ExpirationStatus.depleted;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final expirationDay = DateTime(
      expirationDate.year,
      expirationDate.month,
      expirationDate.day,
    );
    if (expirationDay.isBefore(todayDate)) return ExpirationStatus.expired;
    if (expirationDay.difference(todayDate).inDays <=
        ExpirationModel.defaultNearExpirationDays) {
      return ExpirationStatus.nearingExpiration;
    }
    return ExpirationStatus.normal;
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'productId': productId,
    'productName': productName,
    'batchIdentifier': batchIdentifier,
    'movementType': movementType.name,
    'previousQuantity': previousQuantity,
    'updatedQuantity': updatedQuantity,
    'movementDate': movementDate,
    'expirationDate': expirationDate,
    'remarks': remarks,
  };

  factory ExpirationHistoryEntry.fromMap(Map<dynamic, dynamic> map) {
    return ExpirationHistoryEntry(
      id: map['id'] as String,
      productId: map['productId'] as String,
      productName: map['productName'] as String,
      batchIdentifier: map['batchIdentifier'] as String,
      movementType: StockMovementType.values.byName(
        map['movementType'] as String,
      ),
      previousQuantity: map['previousQuantity'] as int,
      updatedQuantity: map['updatedQuantity'] as int,
      movementDate: map['movementDate'] as DateTime,
      expirationDate: map['expirationDate'] as DateTime,
      remarks: map['remarks'] as String?,
    );
  }
}
