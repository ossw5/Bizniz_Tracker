import 'package:hive/hive.dart';

part 'product.g.dart';

@HiveType(typeId: 0)
class ProductModel extends HiveObject {
  @HiveField(0)
  final String id; // use uuid or timestamp string
  @HiveField(1)
  final String name;
  @HiveField(2)
  int quantity;
  @HiveField(3)
  final double costPrice;
  @HiveField(4)
  double sellingPrice;
  @HiveField(5)
  final String category;
  @HiveField(6)
  final int minStock; // minimum stock threshold
  @HiveField(7, defaultValue: '')
  final String barcode;

  bool get isLowStock =>
      quantity <= 0 || (minStock > 0 && quantity <= minStock);

  ProductModel({
    required this.id,
    required this.name,
    required this.quantity,
    required this.costPrice,
    required this.sellingPrice,
    this.category = '',
    this.minStock = 0,
    this.barcode = '',
  });

  // copyWith for updates
  ProductModel copyWith({
    String? id,
    String? name,
    int? quantity,
    double? costPrice,
    double? sellingPrice,
    String? category,
    int? minStock,
    String? barcode,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      category: category ?? this.category,
      minStock: minStock ?? this.minStock,
      barcode: barcode ?? this.barcode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          quantity == other.quantity &&
          costPrice == other.costPrice &&
          sellingPrice == other.sellingPrice &&
          category == other.category &&
          minStock == other.minStock &&
          barcode == other.barcode;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      quantity.hashCode ^
      costPrice.hashCode ^
      sellingPrice.hashCode ^
      category.hashCode ^
      minStock.hashCode ^
      barcode.hashCode;
}
