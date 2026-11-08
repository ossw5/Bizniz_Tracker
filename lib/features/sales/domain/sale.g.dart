// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SaleAdapter extends TypeAdapter<Sale> {
  @override
  final int typeId = 1;

  @override
  Sale read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Sale(
      id: fields[0] as String,
      productId: fields[1] as String,
      quantitySold: fields[2] as int,
      sellingPrice: fields[3] as double,
      saleDate: fields[4] as DateTime,
      totalRevenue: fields[5] as double,
      transactionId: fields[6] as String?,
      receiptNumber: fields[7] as String?,
      productNameAtSale: fields[8] as String?,
      subtotal: fields[9] as double?,
      discount: fields[10] as double?,
      transactionTotal: fields[11] as double?,
      amountPaid: fields[12] as double?,
      changeDue: fields[13] as double?,
      paymentMethod: fields[14] as String?,
      productCostAtSale: fields[15] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, Sale obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.productId)
      ..writeByte(2)
      ..write(obj.quantitySold)
      ..writeByte(3)
      ..write(obj.sellingPrice)
      ..writeByte(4)
      ..write(obj.saleDate)
      ..writeByte(5)
      ..write(obj.totalRevenue)
      ..writeByte(6)
      ..write(obj.transactionId)
      ..writeByte(7)
      ..write(obj.receiptNumber)
      ..writeByte(8)
      ..write(obj.productNameAtSale)
      ..writeByte(9)
      ..write(obj.subtotal)
      ..writeByte(10)
      ..write(obj.discount)
      ..writeByte(11)
      ..write(obj.transactionTotal)
      ..writeByte(12)
      ..write(obj.amountPaid)
      ..writeByte(13)
      ..write(obj.changeDue)
      ..writeByte(14)
      ..write(obj.paymentMethod)
      ..writeByte(15)
      ..write(obj.productCostAtSale);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
