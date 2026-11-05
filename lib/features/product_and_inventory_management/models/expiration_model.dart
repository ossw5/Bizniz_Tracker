import 'package:hive/hive.dart';

enum ExpirationBatchStatus { normal, nearingExpiration, expired, depleted }

class ExpirationBatch extends HiveObject {
  static const int defaultNearingExpirationDays = 30;

  final String id;
  final String productId;
  final int initialQuantity;
  final int remainingQuantity;
  final DateTime expirationDate;
  final String? batchIdentifier;

  ExpirationBatch({
    required this.id,
    required this.productId,
    required this.initialQuantity,
    required this.remainingQuantity,
    required this.expirationDate,
    String? batchIdentifier,
  }) : batchIdentifier = _normalizeBatchIdentifier(batchIdentifier) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Batch ID cannot be empty.');
    }
    if (productId.trim().isEmpty) {
      throw ArgumentError.value(
        productId,
        'productId',
        'Product ID cannot be empty.',
      );
    }
    if (initialQuantity <= 0) {
      throw ArgumentError.value(
        initialQuantity,
        'initialQuantity',
        'Initial quantity must be greater than zero.',
      );
    }
    if (remainingQuantity < 0 || remainingQuantity > initialQuantity) {
      throw ArgumentError.value(
        remainingQuantity,
        'remainingQuantity',
        'Remaining quantity must be between zero and the initial quantity.',
      );
    }
  }

  ExpirationBatchStatus statusAt({
    DateTime? now,
    int nearingExpirationDays = defaultNearingExpirationDays,
  }) {
    if (nearingExpirationDays < 0) {
      throw ArgumentError.value(
        nearingExpirationDays,
        'nearingExpirationDays',
        'Expiration threshold cannot be negative.',
      );
    }
    if (remainingQuantity == 0) return ExpirationBatchStatus.depleted;

    final currentDate = now ?? DateTime.now();
    final today = DateTime.utc(
      currentDate.year,
      currentDate.month,
      currentDate.day,
    );
    final expirationDay = DateTime.utc(
      expirationDate.year,
      expirationDate.month,
      expirationDate.day,
    );
    final daysUntilExpiration = expirationDay.difference(today).inDays;

    if (daysUntilExpiration < 0) return ExpirationBatchStatus.expired;
    if (daysUntilExpiration <= nearingExpirationDays) {
      return ExpirationBatchStatus.nearingExpiration;
    }
    return ExpirationBatchStatus.normal;
  }

  ExpirationBatch copyWith({
    String? id,
    String? productId,
    int? initialQuantity,
    int? remainingQuantity,
    DateTime? expirationDate,
    String? batchIdentifier,
    bool clearBatchIdentifier = false,
  }) {
    return ExpirationBatch(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      initialQuantity: initialQuantity ?? this.initialQuantity,
      remainingQuantity: remainingQuantity ?? this.remainingQuantity,
      expirationDate: expirationDate ?? this.expirationDate,
      batchIdentifier: clearBatchIdentifier
          ? null
          : batchIdentifier ?? this.batchIdentifier,
    );
  }

  static String? _normalizeBatchIdentifier(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class ExpirationBatchAdapter extends TypeAdapter<ExpirationBatch> {
  @override
  final int typeId = 2;

  @override
  ExpirationBatch read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var index = 0; index < numOfFields; index++)
        reader.readByte(): reader.read(),
    };
    return ExpirationBatch(
      id: fields[0] as String,
      productId: fields[1] as String,
      initialQuantity: fields[2] as int,
      remainingQuantity: fields[3] as int,
      expirationDate: fields[4] as DateTime,
      batchIdentifier: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ExpirationBatch obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.productId)
      ..writeByte(2)
      ..write(obj.initialQuantity)
      ..writeByte(3)
      ..write(obj.remainingQuantity)
      ..writeByte(4)
      ..write(obj.expirationDate)
      ..writeByte(5)
      ..write(obj.batchIdentifier);
  }
}
