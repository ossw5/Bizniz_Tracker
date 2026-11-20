import '../../products/domain/product.dart';

enum InventorySuggestionType { slowMoving, fastMoving, expiration }

class InventoryRestockSuggestion {
  final ProductModel product;
  final int recommendedQuantity;

  const InventoryRestockSuggestion({
    required this.product,
    required this.recommendedQuantity,
  });
}

class InventoryComboSuggestion {
  final ProductModel featuredProduct;
  final ProductModel? pairedProduct;
  final InventorySuggestionType type;
  final int discountPercent;
  final int transactionsTogether;

  const InventoryComboSuggestion({
    required this.featuredProduct,
    required this.pairedProduct,
    required this.type,
    this.discountPercent = 10,
    this.transactionsTogether = 0,
  });

  double get originalPrice =>
      featuredProduct.sellingPrice + (pairedProduct?.sellingPrice ?? 0);

  double get comboPrice => originalPrice * (1 - discountPercent / 100);

  String get id =>
      '${type.name}:${featuredProduct.id}:${pairedProduct?.id ?? ''}';

  InventoryComboSuggestion copyWith({int? discountPercent}) =>
      InventoryComboSuggestion(
        featuredProduct: featuredProduct,
        pairedProduct: pairedProduct,
        type: type,
        discountPercent: discountPercent ?? this.discountPercent,
        transactionsTogether: transactionsTogether,
      );
}

class InventoryProductPair {
  final ProductModel first;
  final ProductModel second;
  final int transactionsTogether;

  const InventoryProductPair({
    required this.first,
    required this.second,
    required this.transactionsTogether,
  });
}
