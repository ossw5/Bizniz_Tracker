import '../../products/domain/product.dart';
import '../../sales/domain/sale.dart';
import '../models/inventory_alerts_data.dart';

class InventoryAlertService {
  const InventoryAlertService();

  List<ProductModel> lowStockProducts(Iterable<ProductModel> products) =>
      products.where((product) => product.isLowStock).toList();

  List<ProductModel> slowMovingProducts(
    Iterable<ProductModel> products,
    Iterable<Sale> sales, {
    DateTime? now,
  }) {
    final lastSaleByProduct = <String, DateTime>{};
    for (final sale in sales) {
      final previous = lastSaleByProduct[sale.productId];
      if (previous == null || sale.saleDate.isAfter(previous)) {
        lastSaleByProduct[sale.productId] = sale.saleDate;
      }
    }

    final currentDate = now ?? DateTime.now();
    final slowMoving = products.where((product) {
      final lastSale = lastSaleByProduct[product.id];
      return lastSale != null && currentDate.difference(lastSale).inDays >= 30;
    }).toList();
    slowMoving.sort((first, second) {
      final lastSaleOrder = lastSaleByProduct[first.id]!.compareTo(
        lastSaleByProduct[second.id]!,
      );
      return lastSaleOrder != 0
          ? lastSaleOrder
          : first.name.compareTo(second.name);
    });
    return slowMoving;
  }

  List<MapEntry<ProductModel, int>> topSellingProducts(
    Iterable<ProductModel> products,
    Iterable<Sale> sales, {
    required Duration period,
    DateTime? now,
  }) {
    final threshold = (now ?? DateTime.now()).subtract(period);
    final quantitiesByProduct = <String, int>{};
    for (final sale in sales) {
      if (!sale.saleDate.isBefore(threshold)) {
        quantitiesByProduct.update(
          sale.productId,
          (quantity) => quantity + sale.quantitySold,
          ifAbsent: () => sale.quantitySold,
        );
      }
    }

    final productsById = {for (final product in products) product.id: product};
    final results = <MapEntry<ProductModel, int>>[];
    for (final entry in quantitiesByProduct.entries) {
      final product = productsById[entry.key];
      if (product != null) results.add(MapEntry(product, entry.value));
    }
    results.sort((a, b) => b.value.compareTo(a.value));
    return results;
  }

  List<InventoryRestockSuggestion> restockSuggestions(
    Iterable<ProductModel> products,
  ) {
    final lowStock = lowStockProducts(products)
      ..sort((a, b) => a.quantity.compareTo(b.quantity));
    return lowStock
        .map(
          (product) => InventoryRestockSuggestion(
            product: product,
            recommendedQuantity: (product.minStock * 2 - product.quantity)
                .clamp(1, 1 << 31)
                .toInt(),
          ),
        )
        .toList();
  }

  List<InventoryComboSuggestion> comboSuggestions({
    required Iterable<ProductModel> products,
    required Iterable<Sale> sales,
    required InventorySuggestionType type,
    DateTime? now,
  }) {
    if (type == InventorySuggestionType.expiration) return [];

    final productList = products.toList();
    final currentDate = now ?? DateTime.now();
    final slowMoving = slowMovingProducts(productList, sales, now: currentDate);
    final fastMoving = topSellingProducts(
      productList,
      sales,
      period: const Duration(days: 30),
      now: currentDate,
    ).map((entry) => entry.key).toSet();
    final featuredProducts = type == InventorySuggestionType.slowMoving
        ? slowMoving.toSet()
        : fastMoving;

    return [
      for (final pair in frequentProductPairs(productList, sales))
        if (featuredProducts.contains(pair.first) ||
            featuredProducts.contains(pair.second))
          InventoryComboSuggestion(
            featuredProduct: featuredProducts.contains(pair.first)
                ? pair.first
                : pair.second,
            pairedProduct: featuredProducts.contains(pair.first)
                ? pair.second
                : pair.first,
            type: type,
            transactionsTogether: pair.transactionsTogether,
          ),
    ];
  }

  List<InventoryProductPair> frequentProductPairs(
    Iterable<ProductModel> products,
    Iterable<Sale> sales, {
    int minimumTransactions = 2,
  }) {
    final productsById = {for (final product in products) product.id: product};
    final productsByPair = <String, (String, String)>{};
    final transactionProducts = <String, Set<String>>{};
    for (final sale in sales) {
      transactionProducts
          .putIfAbsent(sale.transactionId ?? sale.id, () => <String>{})
          .add(sale.productId);
    }
    final pairCounts = <String, int>{};
    for (final productIds in transactionProducts.values) {
      final sortedIds = productIds.toList()..sort();
      for (var first = 0; first < sortedIds.length; first++) {
        for (var second = first + 1; second < sortedIds.length; second++) {
          final firstId = sortedIds[first];
          final secondId = sortedIds[second];
          if (!productsById.containsKey(firstId) ||
              !productsById.containsKey(secondId)) {
            continue;
          }
          final pairKey = '$firstId\u0000$secondId';
          productsByPair[pairKey] = (firstId, secondId);
          pairCounts.update(pairKey, (count) => count + 1, ifAbsent: () => 1);
        }
      }
    }

    final pairs =
        <InventoryProductPair>[
          for (final entry in pairCounts.entries)
            if (entry.value >= minimumTransactions)
              InventoryProductPair(
                first: productsById[productsByPair[entry.key]!.$1]!,
                second: productsById[productsByPair[entry.key]!.$2]!,
                transactionsTogether: entry.value,
              ),
        ]..sort((first, second) {
          final frequency = second.transactionsTogether.compareTo(
            first.transactionsTogether,
          );
          if (frequency != 0) return frequency;
          final firstName = first.first.name.compareTo(second.first.name);
          return firstName != 0
              ? firstName
              : first.second.name.compareTo(second.second.name);
        });
    return pairs;
  }
}
