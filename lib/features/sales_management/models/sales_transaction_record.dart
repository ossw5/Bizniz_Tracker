import '../../../core/formatters.dart';
import '../../sales/domain/sale.dart';

String formatSalesCurrency(num amount) => formatAppCurrency(amount);

class SalesTransactionRecord {
  final String id;
  final String receiptNumber;
  final DateTime date;
  final List<Sale> items;
  final double subtotal;
  final double discount;
  final double total;
  final double amountPaid;
  final double changeDue;
  final String paymentMethod;

  const SalesTransactionRecord({
    required this.id,
    required this.receiptNumber,
    required this.date,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.amountPaid,
    required this.changeDue,
    required this.paymentMethod,
  });

  factory SalesTransactionRecord.fromSales(Iterable<Sale> sales) {
    final items = sales.toList()
      ..sort((first, second) => first.productId.compareTo(second.productId));
    if (items.isEmpty) {
      throw ArgumentError.value(sales, 'sales', 'Must contain sale items.');
    }

    final first = items.first;
    final itemTotal = items.fold<double>(
      0,
      (total, sale) => total + sale.totalRevenue,
    );
    final id = first.transactionId ?? first.id;

    return SalesTransactionRecord(
      id: id,
      receiptNumber: first.receiptNumber ?? id,
      date: first.saleDate,
      items: List.unmodifiable(items),
      subtotal: first.subtotal ?? itemTotal,
      discount: first.discount ?? 0,
      total: first.transactionTotal ?? itemTotal,
      amountPaid: first.amountPaid ?? itemTotal,
      changeDue: first.changeDue ?? 0,
      paymentMethod: first.paymentMethod ?? 'Recorded sale',
    );
  }

  static List<SalesTransactionRecord> groupSales(Iterable<Sale> sales) {
    final grouped = <String, List<Sale>>{};
    for (final sale in sales) {
      grouped.putIfAbsent(sale.transactionId ?? sale.id, () => []).add(sale);
    }
    final transactions =
        grouped.values.map(SalesTransactionRecord.fromSales).toList()
          ..sort((first, second) => second.date.compareTo(first.date));
    return transactions;
  }
}
