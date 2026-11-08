import 'dart:async';

import 'package:hive/hive.dart';

import '../../products/domain/product.dart';
import '../../settings/services/activity_log_service.dart';
import '../models/expiration_model.dart';

class ExpirationService {
  static const recordsBoxName = 'expiration_records_box';
  static const historyBoxName = 'expiration_history_box';
  static Future<void> _writeQueue = Future<void>.value();
  static int _idSequence = 0;

  const ExpirationService();

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

  List<ExpirationModel> _readRecords(Box<dynamic> box) {
    return box.values
        .map((value) => ExpirationModel.fromMap(value as Map))
        .toList(growable: false);
  }

  Future<List<ExpirationModel>> loadAll({List<ProductModel>? products}) async {
    final records = _readRecords(await _openBox(recordsBoxName));
    final productsById = {
      for (final product in products ?? const <ProductModel>[])
        product.id: product,
    };
    return records
        .map((record) {
          final product = productsById[record.productId];
          return product == null
              ? record
              : record.copyWith(productName: product.name);
        })
        .toList(growable: false);
  }

  Future<List<ExpirationModel>> searchAndFilter({
    String? query,
    ExpirationStatus? status,
    List<ProductModel>? products,
  }) async {
    final records = await loadAll(products: products);
    final normalized = (query ?? '').trim().toLowerCase();
    return records
        .where((record) {
          final matchesQuery =
              normalized.isEmpty ||
              record.productName.toLowerCase().contains(normalized) ||
              record.productId.toLowerCase().contains(normalized) ||
              record.batchIdentifier.toLowerCase().contains(normalized);
          final matchesStatus = status == null || record.status == status;
          return matchesQuery && matchesStatus;
        })
        .toList(growable: false);
  }

  Future<ExpirationModel> addRecord({
    required ProductModel product,
    required DateTime expirationDate,
    required int initialQuantity,
    String batchIdentifier = '',
    String? notes,
  }) {
    return _serializeWrites(() async {
      if (initialQuantity <= 0) {
        throw ArgumentError.value(
          initialQuantity,
          'initialQuantity',
          'Quantity must be greater than zero.',
        );
      }
      if (product.id.trim().isEmpty) {
        throw ArgumentError.value(product.id, 'product', 'Select a product.');
      }

      final box = await _openBox(recordsBoxName);
      final existing = _readRecords(box);
      final requestedBatch = batchIdentifier.trim();
      if (requestedBatch.isNotEmpty &&
          existing.any(
            (record) =>
                record.productId == product.id &&
                record.batchIdentifier.toLowerCase() ==
                    requestedBatch.toLowerCase(),
          )) {
        throw StateError('A batch with that identifier already exists.');
      }

      final id = _newId('expiration', box);
      final batchId = requestedBatch.isEmpty ? 'B-$id' : requestedBatch;
      final record = ExpirationModel.fromProduct(
        id: id,
        product: product,
        expirationDate: expirationDate,
        initialQuantity: initialQuantity,
        batchIdentifier: batchId,
        notes: notes,
      );
      await box.put(record.id, record.toMap());
      const ActivityLogService().recordInBackground(
        description:
            'Added batch ${record.batchIdentifier} for ${record.productName}',
        category: 'Inventory',
        occurredAt: record.createdAt,
      );
      return record;
    });
  }

  Future<ExpirationModel> updateRecord(ExpirationModel updated) {
    return _serializeWrites(() async {
      if (updated.initialQuantity <= 0 ||
          updated.remainingQuantity < 0 ||
          updated.remainingQuantity > updated.initialQuantity) {
        throw StateError(
          'Initial quantity must be positive and remaining quantity must be between zero and the initial quantity.',
        );
      }
      if (updated.productId.trim().isEmpty ||
          updated.batchIdentifier.trim().isEmpty) {
        throw StateError('Product and batch identifier are required.');
      }

      final box = await _openBox(recordsBoxName);
      final oldValue = box.get(updated.id);
      if (oldValue == null) {
        throw StateError('Expiration record not found.');
      }
      final duplicateBatch = _readRecords(box).any(
        (record) =>
            record.id != updated.id &&
            record.productId == updated.productId &&
            record.batchIdentifier.toLowerCase() ==
                updated.batchIdentifier.trim().toLowerCase(),
      );
      if (duplicateBatch) {
        throw StateError('A batch with that identifier already exists.');
      }

      final normalized = updated.copyWith(
        batchIdentifier: updated.batchIdentifier.trim(),
      );
      await box.put(normalized.id, normalized.toMap());
      const ActivityLogService().recordInBackground(
        description:
            'Updated batch ${normalized.batchIdentifier} for ${normalized.productName}',
        category: 'Inventory',
      );
      return normalized;
    });
  }

  Future<ExpirationModel> updateStock({
    required String recordId,
    required StockMovementType movementType,
    required int quantity,
    String? remarks,
  }) {
    return _serializeWrites(() async {
      if (quantity <= 0) {
        throw ArgumentError.value(
          quantity,
          'quantity',
          'Quantity must be greater than zero.',
        );
      }

      final recordsBox = await _openBox(recordsBoxName);
      final historyBox = await _openBox(historyBoxName);
      final oldValue = recordsBox.get(recordId);
      if (oldValue == null) {
        throw StateError('Expiration record not found.');
      }
      final record = ExpirationModel.fromMap(oldValue as Map);
      final nextQuantity = record.remainingQuantity - quantity;
      if (nextQuantity < 0) {
        throw StateError(
          'The stock movement exceeds the available batch stock.',
        );
      }

      final updated = record.copyWith(remainingQuantity: nextQuantity);
      final movement = ExpirationHistoryEntry(
        id: _newId('movement', historyBox),
        productId: record.productId,
        productName: record.productName,
        batchIdentifier: record.batchIdentifier,
        movementType: movementType,
        previousQuantity: record.remainingQuantity,
        updatedQuantity: updated.remainingQuantity,
        movementDate: DateTime.now(),
        expirationDate: record.expirationDate,
        remarks: remarks,
      );
      await recordsBox.put(record.id, updated.toMap());
      try {
        await historyBox.put(movement.id, movement.toMap());
      } catch (error) {
        try {
          await recordsBox.put(record.id, record.toMap());
        } catch (rollbackError) {
          throw StateError(
            'Could not save stock movement ($error) or restore batch quantity ($rollbackError).',
          );
        }
        rethrow;
      }
      const ActivityLogService().recordInBackground(
        description:
            '${movement.movementType.label} ${movement.updatedQuantity - movement.previousQuantity} units from batch ${record.batchIdentifier}',
        category: 'Inventory',
        occurredAt: movement.movementDate,
      );
      return updated;
    });
  }

  Future<List<ExpirationHistoryEntry>> getHistory({
    DateTime? start,
    DateTime? end,
  }) async {
    final lower = start == null
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : DateTime(start.year, start.month, start.day);
    final upperExclusive = end == null
        ? DateTime.now().add(const Duration(days: 3651))
        : DateTime(end.year, end.month, end.day).add(const Duration(days: 1));
    final box = await _openBox(historyBoxName);
    return box.values
        .map((value) => ExpirationHistoryEntry.fromMap(value as Map))
        .where(
          (entry) =>
              !entry.movementDate.isBefore(lower) &&
              entry.movementDate.isBefore(upperExclusive),
        )
        .toList(growable: false);
  }

  Future<Map<String, int>> getSummary({List<ProductModel>? products}) async {
    final records = await loadAll(products: products);
    return {
      'total': records.length,
      'normal': records
          .where((record) => record.status == ExpirationStatus.normal)
          .length,
      'nearing': records
          .where(
            (record) => record.status == ExpirationStatus.nearingExpiration,
          )
          .length,
      'expired': records
          .where((record) => record.status == ExpirationStatus.expired)
          .length,
      'depleted': records
          .where((record) => record.status == ExpirationStatus.depleted)
          .length,
    };
  }

  Future<List<ExpirationModel>> getByProduct(
    String productId, {
    List<ProductModel>? products,
  }) async {
    final records = await loadAll(products: products);
    return records
        .where((record) => record.productId == productId)
        .toList(growable: false);
  }
}
