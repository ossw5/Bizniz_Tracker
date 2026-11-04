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
    return products.where((product) {
      final lastSale = lastSaleByProduct[product.id];
      return lastSale != null && currentDate.difference(lastSale).inDays >= 30;
    }).toList();
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
    ).map((entry) => entry.key).toList();
    final featuredProducts = type == InventorySuggestionType.slowMoving
        ? slowMoving
        : fastMoving;
    final pairingProducts = type == InventorySuggestionType.slowMoving
        ? fastMoving
        : slowMoving;

    return [
      for (var index = 0; index < featuredProducts.length; index++)
        InventoryComboSuggestion(
          featuredProduct: featuredProducts[index],
          pairedProduct: _pairWithDifferentProduct(
            featuredProducts[index],
            pairingProducts,
          ),
          type: type,
        ),
    ];
  }

  ProductModel? _pairWithDifferentProduct(
    ProductModel featured,
    List<ProductModel> candidates,
  ) {
    for (final candidate in candidates) {
      if (candidate.id != featured.id) return candidate;
    }
    return null;
  }
}
