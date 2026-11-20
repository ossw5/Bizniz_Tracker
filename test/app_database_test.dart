import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bizniz_tracker/core/app_database.dart';
import 'package:bizniz_tracker/features/products/domain/product.dart';
import 'package:bizniz_tracker/features/sales/domain/sale.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('creates documented tables and persists products and sales', () async {
    final tables = await database
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final tableNames = tables.map((row) => row.read<String>('name')).toSet();

    expect(
      tableNames,
      containsAll({
        'products',
        'sales_transactions',
        'sale_items',
        'expiration_batches',
        'stock_movements',
        'customers',
        'credit_accounts',
        'credit_payments',
        'credit_balance_corrections',
        'expenses',
        'expense_corrections',
        'business_activity_log',
        'store_profile',
        'app_preferences',
      }),
    );

    final product = ProductModel(
      id: 'bread',
      name: 'Bread',
      quantity: 8,
      costPrice: 10.25,
      sellingPrice: 15.5,
      category: 'Bakery',
      minStock: 2,
      barcode: '0123',
    );
    await database.putProduct(product);
    expect(await database.getProduct('bread'), product);

    final sale = Sale(
      id: 'sale-1-bread',
      transactionId: 'sale-1',
      receiptNumber: 'BZT-000001',
      productId: 'bread',
      productNameAtSale: 'Bread',
      productCostAtSale: 10.25,
      quantitySold: 2,
      sellingPrice: 15.5,
      saleDate: DateTime(2026, 11, 9, 10),
      totalRevenue: 31,
      subtotal: 31,
      discount: 0,
      transactionTotal: 31,
      amountPaid: 35,
      changeDue: 4,
      paymentMethod: 'Cash',
    );
    await database.putSale(sale);

    final storedSale = (await database.getSales()).single;
    expect(storedSale.id, sale.id);
    expect(storedSale.transactionId, sale.transactionId);
    expect(storedSale.receiptNumber, sale.receiptNumber);
    expect(storedSale.productCostAtSale, sale.productCostAtSale);
    expect(storedSale.transactionTotal, sale.transactionTotal);
    expect(storedSale.amountPaid, sale.amountPaid);
    expect(storedSale.changeDue, sale.changeDue);

    await database.deleteProduct('bread');
    expect((await database.getSales()).single.productNameAtSale, 'Bread');
    expect((await database.getSales()).single.productId, 'bread');
  });

  test(
    'Hive inventory import is idempotent and preserves legacy sales',
    () async {
      final oldProduct = ProductModel(
        id: 'bread',
        name: 'Old bread',
        quantity: 3,
        costPrice: 10,
        sellingPrice: 15,
      );
      final oldSale = Sale(
        id: 'legacy-sale',
        productId: 'removed-product',
        quantitySold: 1,
        sellingPrice: 15,
        saleDate: DateTime(2026, 11, 8),
        totalRevenue: 15,
      );
      await database.importHiveInventory(
        products: [oldProduct],
        sales: [oldSale],
      );
      await database.putProduct(oldProduct.copyWith(quantity: 2));
      await database.importHiveInventory(
        products: [oldProduct],
        sales: [oldSale],
      );

      expect((await database.getProduct('bread'))?.quantity, 2);
      final importedSale = (await database.getSales()).single;
      expect(importedSale.transactionId, oldSale.id);
      expect(importedSale.receiptNumber, oldSale.id);
      expect(importedSale.productNameAtSale, '');
      expect(importedSale.productId, 'removed-product');
    },
  );

  test(
    'failed Hive inventory import can be retried without partial rows',
    () async {
      final invalidProduct = ProductModel(
        id: 'invalid',
        name: 'Invalid price',
        quantity: 1,
        costPrice: double.nan,
        sellingPrice: 15,
      );
      await expectLater(
        database.importHiveInventory(
          products: [invalidProduct],
          sales: const [],
        ),
        throwsArgumentError,
      );
      expect(await database.getProducts(), isEmpty);

      await database.importHiveInventory(
        products: [
          ProductModel(
            id: 'bread',
            name: 'Bread',
            quantity: 2,
            costPrice: 10,
            sellingPrice: 15,
          ),
        ],
        sales: const [],
      );
      expect((await database.getProducts()).single.id, 'bread');
    },
  );
}
