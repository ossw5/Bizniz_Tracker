import 'package:flutter/material.dart';

import '../models/expiration_model.dart';
import 'expiration_status_badge.dart';

class ExpirationListItem extends StatelessWidget {
  final ExpirationModel record;
  final VoidCallback? onViewDetails;
  final VoidCallback? onEdit;
  final VoidCallback? onUpdateStock;
  final VoidCallback? onViewHistory;

  const ExpirationListItem({
    super.key,
    required this.record,
    this.onViewDetails,
    this.onEdit,
    this.onUpdateStock,
    this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.productName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ExpirationStatusBadge(status: record.status),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Text('ID: ${record.productId}'),
                Text('Batch: ${record.batchIdentifier}'),
                Text('Qty: ${record.remainingQuantity}'),
                Text(
                  'Expires: ${record.expirationDate.toLocal().toString().split(' ').first}',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                PopupMenuButton<String>(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'details',
                      child: Text('View Details'),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit Details'),
                    ),
                    const PopupMenuItem(
                      value: 'stock',
                      child: Text('Update Stock'),
                    ),
                    const PopupMenuItem(
                      value: 'history',
                      child: Text('View History'),
                    ),
                  ],
                  onSelected: (value) {
                    switch (value) {
                      case 'details':
                        onViewDetails?.call();
                        break;
                      case 'edit':
                        onEdit?.call();
                        break;
                      case 'stock':
                        onUpdateStock?.call();
                        break;
                      case 'history':
                        onViewHistory?.call();
                        break;
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
