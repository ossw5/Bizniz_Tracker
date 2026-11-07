import 'package:hive/hive.dart';

part 'sale.g.dart';

@HiveType(typeId: 1)
class Sale extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String productId;

  @HiveField(2)
  final int quantitySold;

  @HiveField(3)
  final double sellingPrice; // price at time of sale

  @HiveField(4)
  final DateTime saleDate;

  @HiveField(5)
  final double totalRevenue; // quantitySold * sellingPrice
  @HiveField(6)
  final String? transactionId;
  @HiveField(7)
  final String? receiptNumber;
  @HiveField(8)
  final String? productNameAtSale;
  @HiveField(9)
  final double? subtotal;
  @HiveField(10)
  final double? discount;
  @HiveField(11)
  final double? transactionTotal;
  @HiveField(12)
  final double? amountPaid;
  @HiveField(13)
  final double? changeDue;
  @HiveField(14)
  final String? paymentMethod;

  Sale({
    required this.id,
    required this.productId,
    required this.quantitySold,
    required this.sellingPrice,
    required this.saleDate,
    required this.totalRevenue,
    this.transactionId,
    this.receiptNumber,
    this.productNameAtSale,
    this.subtotal,
    this.discount,
    this.transactionTotal,
    this.amountPaid,
    this.changeDue,
    this.paymentMethod,
  });

  // Helper to calculate total revenue
  static double calculateRevenue(int quantity, double price) {
    return quantity * price;
  }

  Sale copyWith({
    String? id,
    String? productId,
    int? quantitySold,
    double? sellingPrice,
    DateTime? saleDate,
    double? totalRevenue,
    String? transactionId,
    String? receiptNumber,
    String? productNameAtSale,
    double? subtotal,
    double? discount,
    double? transactionTotal,
    double? amountPaid,
    double? changeDue,
    String? paymentMethod,
  }) {
    return Sale(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      quantitySold: quantitySold ?? this.quantitySold,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      saleDate: saleDate ?? this.saleDate,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      transactionId: transactionId ?? this.transactionId,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      productNameAtSale: productNameAtSale ?? this.productNameAtSale,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      transactionTotal: transactionTotal ?? this.transactionTotal,
      amountPaid: amountPaid ?? this.amountPaid,
      changeDue: changeDue ?? this.changeDue,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Sale &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          productId == other.productId &&
          quantitySold == other.quantitySold &&
          sellingPrice == other.sellingPrice &&
          saleDate == other.saleDate &&
          totalRevenue == other.totalRevenue &&
          transactionId == other.transactionId &&
          receiptNumber == other.receiptNumber &&
          productNameAtSale == other.productNameAtSale &&
          subtotal == other.subtotal &&
          discount == other.discount &&
          transactionTotal == other.transactionTotal &&
          amountPaid == other.amountPaid &&
          changeDue == other.changeDue &&
          paymentMethod == other.paymentMethod;

  @override
  int get hashCode =>
      id.hashCode ^
      productId.hashCode ^
      quantitySold.hashCode ^
      sellingPrice.hashCode ^
      saleDate.hashCode ^
      totalRevenue.hashCode ^
      transactionId.hashCode ^
      receiptNumber.hashCode ^
      productNameAtSale.hashCode ^
      subtotal.hashCode ^
      discount.hashCode ^
      transactionTotal.hashCode ^
      amountPaid.hashCode ^
      changeDue.hashCode ^
      paymentMethod.hashCode;
}
