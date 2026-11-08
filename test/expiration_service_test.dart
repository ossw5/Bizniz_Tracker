import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:bizniz_tracker/features/product_and_inventory_management/models/expiration_model.dart';
import 'package:bizniz_tracker/features/product_and_inventory_management/services/expiration_service.dart';
import 'package:bizniz_tracker/features/products/domain/product.dart';
import 'package:bizniz_tracker/features/settings/services/activity_log_service.dart';

void main() {
  late Directory directory;
  final service = const ExpirationService();
  final product = ProductModel(
    id: 'bread',
    name: 'Bread',
    quantity: 20,
    costPrice: 10,
    sellingPrice: 15,
    category: 'Bakery',
  );

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('expiration_service_');
    Hive.init(directory.path);
  });

  setUp(() async {
    if (Hive.isBoxOpen(ExpirationService.recordsBoxName)) {
      await Hive.box<dynamic>(ExpirationService.recordsBoxName).clear();
    }
    if (Hive.isBoxOpen(ExpirationService.historyBoxName)) {
      await Hive.box<dynamic>(ExpirationService.historyBoxName).clear();
    }
  });

  tearDownAll(() async {
    await const ActivityLogService().loadRecent();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'does not fabricate expiration batches from product inventory',
    () async {
      expect(await service.loadAll(products: [product]), isEmpty);
    },
  );

  test(
    'expiration status uses local date and depleted has highest priority',
    () {
      final today = DateTime(2026, 11, 8);
      final record = ExpirationModel.fromProduct(
        id: 'record',
        product: product,
        expirationDate: DateTime(2026, 12, 9),
        initialQuantity: 3,
        batchIdentifier: 'B-1',
      );

      expect(record.calculateStatus(now: today), ExpirationStatus.normal);
      expect(
        record
            .copyWith(expirationDate: DateTime(2026, 12, 8))
            .calculateStatus(now: today),
        ExpirationStatus.nearingExpiration,
      );
      expect(
        record
            .copyWith(expirationDate: DateTime(2026, 11, 7))
            .calculateStatus(now: today),
        ExpirationStatus.expired,
      );
      expect(
        record
            .copyWith(
              expirationDate: DateTime(2026, 11, 7),
              remainingQuantity: 0,
            )
            .calculateStatus(now: today),
        ExpirationStatus.depleted,
      );
    },
  );

  test(
    'batch edits preserve remaining stock and movements persist in Hive',
    () async {
      final created = await service.addRecord(
        product: product,
        expirationDate: DateTime(2026, 12, 10),
        initialQuantity: 10,
        batchIdentifier: 'LOT-1',
      );
      final edited = await service.updateRecord(
        created.copyWith(
          initialQuantity: 12,
          expirationDate: DateTime(2027, 1, 10),
        ),
      );
      expect(edited.remainingQuantity, 10);

      final moved = await service.updateStock(
        recordId: edited.id,
        movementType: StockMovementType.removed,
        quantity: 3,
        remarks: 'Damaged packaging',
      );
      expect(moved.remainingQuantity, 7);
      expect((await service.getHistory()).single.updatedQuantity, 7);

      await Hive.close();
      final stored = await service.loadAll();
      expect(stored.single.remainingQuantity, 7);
      expect(stored.single.initialQuantity, 12);
      expect((await service.getHistory()).single.remarks, 'Damaged packaging');
    },
  );

  test('rejects duplicate batch identifiers and stock below zero', () async {
    final record = await service.addRecord(
      product: product,
      expirationDate: DateTime(2026, 12, 10),
      initialQuantity: 2,
      batchIdentifier: 'LOT-2',
    );

    await expectLater(
      service.addRecord(
        product: product,
        expirationDate: DateTime(2027, 1, 10),
        initialQuantity: 1,
        batchIdentifier: 'lot-2',
      ),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      service.updateStock(
        recordId: record.id,
        movementType: StockMovementType.sold,
        quantity: 3,
      ),
      throwsA(isA<StateError>()),
    );
    expect((await service.loadAll()).single.remainingQuantity, 2);
  });
}
