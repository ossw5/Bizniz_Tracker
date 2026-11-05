import 'dart:io';

import 'package:bizniz_tracker/features/product_and_inventory_management/models/expiration_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  final today = DateTime(2026, 11, 5);

  ExpirationBatch batch({
    int remainingQuantity = 5,
    int daysUntilExpiration = 31,
  }) {
    return ExpirationBatch(
      id: 'batch-1',
      productId: 'product-1',
      initialQuantity: 5,
      remainingQuantity: remainingQuantity,
      expirationDate: today.add(Duration(days: daysUntilExpiration)),
    );
  }

  group('ExpirationBatch status', () {
    test('treats a batch beyond the threshold as normal', () {
      expect(
        batch().statusAt(now: today),
        ExpirationBatchStatus.normal,
      );
    });

    test('includes today and the 30th day in nearing expiration', () {
      expect(
        batch(daysUntilExpiration: 30).statusAt(now: today),
        ExpirationBatchStatus.nearingExpiration,
      );
      expect(
        batch(daysUntilExpiration: 0).statusAt(now: today),
        ExpirationBatchStatus.nearingExpiration,
      );
    });

    test('treats an earlier expiration date as expired', () {
      expect(
        batch(daysUntilExpiration: -1).statusAt(now: today),
        ExpirationBatchStatus.expired,
      );
    });

    test('depleted status takes priority over expiration', () {
      expect(
        batch(remainingQuantity: 0, daysUntilExpiration: -1).statusAt(
          now: today,
        ),
        ExpirationBatchStatus.depleted,
      );
    });

    test('allows a caller to configure the nearing threshold', () {
      expect(
        batch(daysUntilExpiration: 31).statusAt(
          now: today,
          nearingExpirationDays: 45,
        ),
        ExpirationBatchStatus.nearingExpiration,
      );
    });

    test('ignores time-of-day when comparing calendar dates', () {
      final lateToday = DateTime(2026, 11, 5, 23, 59);
      expect(
        batch(daysUntilExpiration: 0).statusAt(now: lateToday),
        ExpirationBatchStatus.nearingExpiration,
      );
    });
  });

  group('ExpirationBatch validation', () {
    test('rejects invalid quantities and missing references', () {
      expect(
        () => ExpirationBatch(
          id: 'batch',
          productId: 'product',
          initialQuantity: 0,
          remainingQuantity: 0,
          expirationDate: today,
        ),
        throwsArgumentError,
      );
      expect(
        () => ExpirationBatch(
          id: 'batch',
          productId: 'product',
          initialQuantity: 2,
          remainingQuantity: 3,
          expirationDate: today,
        ),
        throwsArgumentError,
      );
      expect(
        () => ExpirationBatch(
          id: 'batch',
          productId: ' ',
          initialQuantity: 1,
          remainingQuantity: 1,
          expirationDate: today,
        ),
        throwsArgumentError,
      );
    });

    test('normalizes an empty batch identifier and can clear it', () {
      final withEmptyIdentifier = ExpirationBatch(
        id: 'batch',
        productId: 'product',
        initialQuantity: 1,
        remainingQuantity: 1,
        expirationDate: today,
        batchIdentifier: '  ',
      );
      expect(withEmptyIdentifier.batchIdentifier, isNull);

      final withIdentifier = withEmptyIdentifier.copyWith(
        batchIdentifier: '  Batch A  ',
      );
      expect(withIdentifier.batchIdentifier, 'Batch A');
      expect(
        withIdentifier.copyWith(clearBatchIdentifier: true).batchIdentifier,
        isNull,
      );
    });
  });

  test('Hive adapter persists and restores expiration batches', () async {
    final directory = await Directory.systemTemp.createTemp(
      'bizniz_expiration_model_test_',
    );
    final boxName = 'expiration_batches_${DateTime.now().microsecondsSinceEpoch}';
    Hive.init(directory.path);
    Hive.registerAdapter(ExpirationBatchAdapter());

    try {
      final box = await Hive.openBox<ExpirationBatch>(boxName);
      final original = ExpirationBatch(
        id: 'batch-1',
        productId: 'product-1',
        initialQuantity: 10,
        remainingQuantity: 7,
        expirationDate: today,
        batchIdentifier: 'Batch 001',
      );
      await box.put(original.id, original);

      final restored = box.get(original.id)!;
      expect(restored.id, original.id);
      expect(restored.productId, original.productId);
      expect(restored.initialQuantity, original.initialQuantity);
      expect(restored.remainingQuantity, original.remainingQuantity);
      expect(restored.expirationDate, original.expirationDate);
      expect(restored.batchIdentifier, original.batchIdentifier);

      await box.close();
    } finally {
      await Hive.close();
      await directory.delete(recursive: true);
    }
  });
}
