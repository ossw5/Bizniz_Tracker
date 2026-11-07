import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:bizniz_tracker/features/products/domain/product.dart';
import 'package:bizniz_tracker/features/sales/domain/sale.dart';
import 'package:bizniz_tracker/features/sales_management/models/sales_transaction_record.dart';

void main() {
  late Directory directory;
  late Box<ProductModel> productsBox;
  late Box<Sale> salesBox;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('sales_in_one_hive_');
    Hive.init(directory.path);
    Hive.registerAdapter(ProductModelAdapter());
    Hive.registerAdapter(SaleAdapter());
    productsBox = await Hive.openBox<ProductModel>('products_box');
    salesBox = await Hive.openBox<Sale>('sales_box');
  });

  tearDownAll(() async {
    await productsBox.close();
    await salesBox.close();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'barcode and completed sale details survive closing and reopening boxes',
    () async {
      final product = ProductModel(
        id: 'bread',
        name: 'Bread',
        quantity: 7,
        costPrice: 10,
        sellingPrice: 15,
        category: 'Bakery',
        barcode: '0123456789',
      );
      final sale = Sale(
        id: 'receipt-1-bread',
        transactionId: 'receipt-1',
        receiptNumber: 'BZT-000001',
        productId: product.id,
        productNameAtSale: product.name,
        quantitySold: 3,
        sellingPrice: 15,
        saleDate: DateTime(2026, 11, 7, 9),
        totalRevenue: 45,
        subtotal: 45,
        discount: 0,
        transactionTotal: 45,
        amountPaid: 50,
        changeDue: 5,
        paymentMethod: 'Cash',
      );
      await productsBox.put(product.id, product);
      await salesBox.put(sale.id, sale);
      await productsBox.close();
      await salesBox.close();

      productsBox = await Hive.openBox<ProductModel>('products_box');
      salesBox = await Hive.openBox<Sale>('sales_box');

      expect(productsBox.get('bread')?.barcode, '0123456789');
      final storedSale = salesBox.get('receipt-1-bread')!;
      expect(storedSale.transactionId, 'receipt-1');
      expect(storedSale.amountPaid, 50);
      expect(storedSale.changeDue, 5);
      expect(
        SalesTransactionRecord.groupSales(salesBox.values).single.total,
        45,
      );
    },
  );
}
