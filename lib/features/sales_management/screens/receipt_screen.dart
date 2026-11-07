import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/sales_transaction_record.dart';

class ReceiptScreen extends StatelessWidget {
  final SalesTransactionRecord transaction;

  const ReceiptScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final date = MaterialLocalizations.of(
      context,
    ).formatFullDate(transaction.date);
    final time = TimeOfDay.fromDateTime(transaction.date).format(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Receipt'),
        actions: [
          IconButton(
            tooltip: 'Copy receipt',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _receiptText()));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Receipt copied to clipboard.')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.storefront_rounded, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    'Sales in One',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Text('Receipt: ${transaction.receiptNumber}'),
                  Text('Date: $date, $time'),
                  const Divider(height: 28),
                  for (final item in transaction.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.productNameAtSale ?? item.productId}\n'
                              '${item.quantitySold} × ${formatSalesCurrency(item.sellingPrice)}',
                            ),
                          ),
                          Text(formatSalesCurrency(item.totalRevenue)),
                        ],
                      ),
                    ),
                  const Divider(height: 28),
                  _ReceiptAmount(
                    label: 'Subtotal',
                    value: transaction.subtotal,
                  ),
                  _ReceiptAmount(
                    label: 'Discount',
                    value: transaction.discount,
                  ),
                  _ReceiptAmount(label: 'Total', value: transaction.total),
                  _ReceiptAmount(
                    label: 'Paid (${transaction.paymentMethod})',
                    value: transaction.amountPaid,
                  ),
                  _ReceiptAmount(label: 'Change', value: transaction.changeDue),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _receiptText() {
    final lines = [
      'Sales in One',
      'Receipt: ${transaction.receiptNumber}',
      'Date: ${transaction.date}',
      for (final item in transaction.items)
        '${item.productNameAtSale ?? item.productId}  '
            '${item.quantitySold} x ${formatSalesCurrency(item.sellingPrice)}  '
            '${formatSalesCurrency(item.totalRevenue)}',
      'Subtotal: ${formatSalesCurrency(transaction.subtotal)}',
      'Discount: ${formatSalesCurrency(transaction.discount)}',
      'Total: ${formatSalesCurrency(transaction.total)}',
      'Paid: ${formatSalesCurrency(transaction.amountPaid)}',
      'Change: ${formatSalesCurrency(transaction.changeDue)}',
      'Payment: ${transaction.paymentMethod}',
    ];
    return lines.join('\n');
  }
}

class _ReceiptAmount extends StatelessWidget {
  final String label;
  final double value;

  const _ReceiptAmount({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label), Text(formatSalesCurrency(value))],
    ),
  );
}
