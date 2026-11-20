import 'package:flutter_test/flutter_test.dart';

import 'package:bizniz_tracker/features/inventory_alerts_and_smart_suggestions/services/inventory_alert_service.dart';
import 'package:bizniz_tracker/features/inventory_alerts_and_smart_suggestions/models/inventory_alerts_data.dart';
import 'package:bizniz_tracker/features/products/domain/product.dart';
import 'package:bizniz_tracker/features/sales/domain/sale.dart';

void main() {
  const service = InventoryAlertService();
  final now = DateTime(2026, 11, 4);
  final lowStock = ProductModel(
    id: 'low',
    name: 'Low stock',
    quantity: 2,
    costPrice: 1,
    sellingPrice: 2,
    minStock: 5,
  );
  final outOfStock = ProductModel(
    id: 'out',
    name: 'Out of stock',
    quantity: 0,
    costPrice: 1,
    sellingPrice: 2,
  );
  final healthy = ProductModel(
    id: 'healthy',
    name: 'Healthy',
    quantity: 20,
    costPrice: 1,
    sellingPrice: 2,
    minStock: 5,
  );

  test('finds low and out-of-stock products and suggests restock amounts', () {
    final products = [lowStock, outOfStock, healthy];

    expect(service.lowStockProducts(products), [lowStock, outOfStock]);
    final suggestions = service.restockSuggestions(products);
    expect(suggestions.first.product, outOfStock);
    expect(suggestions.last.recommendedQuantity, 8);
  });

  test('finds slow-moving products using the last recorded sale', () {
    final products = [lowStock, healthy];
    final sales = [
      Sale(
        id: 'old-sale',
        productId: lowStock.id,
        quantitySold: 1,
        sellingPrice: 2,
        saleDate: now.subtract(const Duration(days: 35)),
        totalRevenue: 2,
      ),
      Sale(
        id: 'recent-sale',
        productId: healthy.id,
        quantitySold: 1,
        sellingPrice: 2,
        saleDate: now.subtract(const Duration(days: 4)),
        totalRevenue: 2,
      ),
    ];

    expect(service.slowMovingProducts(products, sales, now: now), [lowStock]);
  });

  test('ranks products by sales within the selected period', () {
    final products = [lowStock, healthy];
    final sales = [
      Sale(
        id: 'low-sale',
        productId: lowStock.id,
        quantitySold: 2,
        sellingPrice: 2,
        saleDate: now.subtract(const Duration(days: 2)),
        totalRevenue: 4,
      ),
      Sale(
        id: 'healthy-sale',
        productId: healthy.id,
        quantitySold: 5,
        sellingPrice: 2,
        saleDate: now.subtract(const Duration(days: 1)),
        totalRevenue: 10,
      ),
      Sale(
        id: 'outside-period',
        productId: lowStock.id,
        quantitySold: 10,
        sellingPrice: 2,
        saleDate: now.subtract(const Duration(days: 40)),
        totalRevenue: 20,
      ),
    ];

    final results = service.topSellingProducts(
      products,
      sales,
      period: const Duration(days: 7),
      now: now,
    );

    expect(results.map((entry) => entry.key), [healthy, lowStock]);
    expect(results.map((entry) => entry.value), [5, 2]);
  });

  test('builds product combos from repeated shared transactions', () {
    final fastMoving = ProductModel(
      id: 'fast',
      name: 'Fast product',
      quantity: 20,
      costPrice: 1,
      sellingPrice: 2,
    );
    final products = [lowStock, healthy, outOfStock, fastMoving];
    final sales = [
      Sale(
        id: 'old-low',
        transactionId: 'old-transaction-1',
        productId: lowStock.id,
        quantitySold: 1,
        sellingPrice: 2,
        saleDate: now.subtract(const Duration(days: 35)),
        totalRevenue: 2,
      ),
      Sale(
        id: 'old-healthy',
        transactionId: 'old-transaction-1',
        productId: healthy.id,
        quantitySold: 1,
        sellingPrice: 2,
        saleDate: now.subtract(const Duration(days: 35)),
        totalRevenue: 2,
      ),
      Sale(
        id: 'old-low-repeat',
        transactionId: 'old-transaction-2',
        productId: lowStock.id,
        quantitySold: 1,
        sellingPrice: 2,
        saleDate: now.subtract(const Duration(days: 34)),
        totalRevenue: 2,
      ),
      Sale(
        id: 'old-healthy-repeat',
        transactionId: 'old-transaction-2',
        productId: healthy.id,
        quantitySold: 1,
        sellingPrice: 2,
        saleDate: now.subtract(const Duration(days: 34)),
        totalRevenue: 2,
      ),
      Sale(
        id: 'recent-healthy',
        transactionId: 'recent-transaction-1',
        productId: fastMoving.id,
        quantitySold: 5,
        sellingPrice: 2,
        saleDate: now.subtract(const Duration(days: 2)),
        totalRevenue: 10,
      ),
      Sale(
        id: 'recent-out',
        transactionId: 'recent-transaction-1',
        productId: outOfStock.id,
        quantitySold: 2,
        sellingPrice: 2,
        saleDate: now.subtract(const Duration(days: 2)),
        totalRevenue: 4,
      ),
      Sale(
        id: 'recent-healthy-repeat',
        transactionId: 'recent-transaction-2',
        productId: fastMoving.id,
        quantitySold: 5,
        sellingPrice: 2,
        saleDate: now.subtract(const Duration(days: 1)),
        totalRevenue: 10,
      ),
      Sale(
        id: 'recent-out-repeat',
        transactionId: 'recent-transaction-2',
        productId: outOfStock.id,
        quantitySold: 2,
        sellingPrice: 2,
        saleDate: now.subtract(const Duration(days: 1)),
        totalRevenue: 4,
      ),
    ];

    final slowSuggestions = service.comboSuggestions(
      products: products,
      sales: sales,
      type: InventorySuggestionType.slowMoving,
      now: now,
    );
    final fastSuggestions = service.comboSuggestions(
      products: products,
      sales: sales,
      type: InventorySuggestionType.fastMoving,
      now: now,
    );

    expect(
      {
        slowSuggestions.single.featuredProduct,
        slowSuggestions.single.pairedProduct,
      },
      {lowStock, healthy},
    );
    expect(slowSuggestions.single.comboPrice, 3.6);
    expect(fastSuggestions.single.transactionsTogether, 2);
    expect(
      {
        fastSuggestions.single.featuredProduct,
        fastSuggestions.single.pairedProduct,
      },
      {fastMoving, outOfStock},
    );
    expect(
      service.comboSuggestions(
        products: products,
        sales: sales,
        type: InventorySuggestionType.expiration,
        now: now,
      ),
      isEmpty,
    );
  });
}
