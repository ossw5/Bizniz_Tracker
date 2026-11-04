import 'package:hive/hive.dart';

import '../features/products/domain/product.dart';
import '../features/sales/domain/sale.dart';

class ReferenceInventoryData {
  final List<ProductModel> products;
  final List<Sale> sales;

  const ReferenceInventoryData({required this.products, required this.sales});
}

ReferenceInventoryData referenceInventoryData({DateTime? now}) {
  final products = [
    ProductModel(
      id: 'reference-lucky-pancit-canton',
      name: 'Lucky Me Pancit Canton',
      quantity: 3,
      costPrice: 10,
      sellingPrice: 15,
      category: 'Instant noodles',
      minStock: 5,
    ),
    ProductModel(
      id: 'reference-fresh-milk',
      name: 'Netle Fresh Milk 1L',
      quantity: 1,
      costPrice: 85,
      sellingPrice: 105,
      category: 'Milk',
      minStock: 3,
    ),
    ProductModel(
      id: 'reference-gardenia-bread',
      name: 'Gardenia Classic White Bread',
      quantity: 4,
      costPrice: 52,
      sellingPrice: 65,
      category: 'Bread',
      minStock: 6,
    ),
    ProductModel(
      id: 'reference-coca-cola',
      name: 'Coca Cola 330ML',
      quantity: 5,
      costPrice: 18,
      sellingPrice: 25,
      category: 'Beverages',
      minStock: 7,
    ),
    ProductModel(
      id: 'reference-century-tuna',
      name: 'Century Tuna',
      quantity: 3,
      costPrice: 30,
      sellingPrice: 40,
      category: 'Canned goods',
      minStock: 5,
    ),
    ProductModel(
      id: 'reference-chips-ahoy',
      name: 'Chips Ahoy',
      quantity: 12,
      costPrice: 35,
      sellingPrice: 45,
      category: 'Snacks',
      minStock: 5,
    ),
    ProductModel(
      id: 'reference-milo',
      name: 'Milo 400G',
      quantity: 8,
      costPrice: 90,
      sellingPrice: 110,
      category: 'Beverages',
      minStock: 4,
    ),
    ProductModel(
      id: 'reference-yakult',
      name: 'Yakult',
      quantity: 4,
      costPrice: 45,
      sellingPrice: 55,
      category: 'Beverages',
      minStock: 2,
    ),
    ProductModel(
      id: 'reference-tide',
      name: 'Tide',
      quantity: 4,
      costPrice: 35,
      sellingPrice: 45,
      category: 'Household',
      minStock: 2,
    ),
    ProductModel(
      id: 'reference-nescafe',
      name: 'Nescafe',
      quantity: 4,
      costPrice: 80,
      sellingPrice: 100,
      category: 'Beverages',
      minStock: 2,
    ),
  ];

  final productById = {for (final product in products) product.id: product};
  final currentTime = now ?? DateTime.now();
  final sales = [
    _referenceSale(
      productById['reference-lucky-pancit-canton']!,
      quantity: 244,
      daysAgo: 1,
      now: currentTime,
    ),
    _referenceSale(
      productById['reference-fresh-milk']!,
      quantity: 254,
      daysAgo: 2,
      now: currentTime,
    ),
    _referenceSale(
      productById['reference-gardenia-bread']!,
      quantity: 274,
      daysAgo: 3,
      now: currentTime,
    ),
    _referenceSale(
      productById['reference-coca-cola']!,
      quantity: 246,
      daysAgo: 4,
      now: currentTime,
    ),
    _referenceSale(
      productById['reference-century-tuna']!,
      quantity: 25,
      daysAgo: 5,
      now: currentTime,
    ),
    _referenceSale(
      productById['reference-chips-ahoy']!,
      quantity: 80,
      daysAgo: 6,
      now: currentTime,
    ),
    _referenceSale(
      productById['reference-milo']!,
      quantity: 55,
      daysAgo: 7,
      now: currentTime,
    ),
    _referenceSale(
      productById['reference-yakult']!,
      quantity: 30,
      daysAgo: 92,
      now: currentTime,
    ),
    _referenceSale(
      productById['reference-tide']!,
      quantity: 40,
      daysAgo: 106,
      now: currentTime,
    ),
    _referenceSale(
      productById['reference-nescafe']!,
      quantity: 35,
      daysAgo: 111,
      now: currentTime,
    ),
  ];

  return ReferenceInventoryData(products: products, sales: sales);
}

Future<void> seedReferenceInventoryIfEmpty({
  required Box<ProductModel> productsBox,
  required Box<Sale> salesBox,
  required Box<bool> settingsBox,
  DateTime? now,
}) async {
  const seedMarker = 'reference_inventory_seeded';
  if (settingsBox.get(seedMarker, defaultValue: false) ?? false) return;

  if (productsBox.isEmpty && salesBox.isEmpty) {
    final data = referenceInventoryData(now: now);
    await productsBox.putAll({
      for (final product in data.products) product.id: product,
    });
    await salesBox.putAll({for (final sale in data.sales) sale.id: sale});
  }
  await settingsBox.put(seedMarker, true);
}

Sale _referenceSale(
  ProductModel product, {
  required int quantity,
  required int daysAgo,
  required DateTime now,
}) {
  final saleId = 'reference-sale-${product.id}';
  return Sale(
    id: saleId,
    productId: product.id,
    quantitySold: quantity,
    sellingPrice: product.sellingPrice,
    saleDate: now.subtract(Duration(days: daysAgo)),
    totalRevenue: Sale.calculateRevenue(quantity, product.sellingPrice),
  );
}
