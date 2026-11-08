import 'package:flutter/material.dart';

import '../../products/domain/product.dart';
import '../../products/presentation/controllers.dart';
import '../models/expiration_model.dart';
import '../services/expiration_service.dart';
import '../widgets/expiration_status_badge.dart';
import 'add_expiration_screen.dart';

class ProductBatchDetailsScreen extends StatefulWidget {
  final String productId;
  final ProductController? productController;
  final ExpirationService service;

  const ProductBatchDetailsScreen({
    super.key,
    required this.productId,
    this.productController,
    this.service = const ExpirationService(),
  });

  @override
  State<ProductBatchDetailsScreen> createState() =>
      _ProductBatchDetailsScreenState();
}

class _ProductBatchDetailsScreenState extends State<ProductBatchDetailsScreen> {
  List<ExpirationModel> _records = const <ExpirationModel>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final products =
        widget.productController?.state.products ?? const <ProductModel>[];
    final records = await widget.service.getByProduct(
      widget.productId,
      products: products,
    );
    if (!mounted) return;
    setState(() => _records = records);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.productController?.state.products.firstWhere(
      (item) => item.id == widget.productId,
      orElse: () => ProductModel(
        id: widget.productId,
        name: 'Product',
        quantity: 0,
        costPrice: 0,
        sellingPrice: 0,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Product Details & Batches')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product?.name ?? 'Product',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('Product ID: ${product?.id ?? widget.productId}'),
            Text('Category: ${product?.category ?? 'Uncategorized'}'),
            Text(
              'Total Remaining Quantity: ${_records.fold<int>(0, (sum, record) => sum + record.remainingQuantity)}',
            ),
            Text('Number of Batches: ${_records.length}'),
            const SizedBox(height: 16),
            const Text('Batches'),
            const SizedBox(height: 8),
            Expanded(
              child: _records.isEmpty
                  ? const Center(child: Text('No batches recorded yet.'))
                  : ListView.builder(
                      itemCount: _records.length,
                      itemBuilder: (context, index) {
                        final record = _records[index];
                        return Card(
                          child: ListTile(
                            title: Text(record.batchIdentifier),
                            subtitle: Text(
                              'Initial: ${record.initialQuantity} · Remaining: ${record.remainingQuantity}\n'
                              'Expires: ${record.expirationDate.toLocal().toString().split(' ').first}',
                            ),
                            trailing: ExpirationStatusBadge(
                              status: record.status,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (_) => AddExpirationScreen(
                    productController: widget.productController,
                    service: widget.service,
                    initialProductId: widget.productId,
                  ),
                ),
              )
              .then((_) => _load());
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Batch'),
      ),
    );
  }
}
