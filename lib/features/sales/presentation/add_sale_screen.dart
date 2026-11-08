import 'package:flutter/material.dart';
import 'package:bizniz_tracker/features/products/presentation/controllers.dart';
import 'package:bizniz_tracker/features/products/domain/product.dart';
import 'package:bizniz_tracker/features/sales/presentation/sales_controller.dart';
import 'package:bizniz_tracker/core/formatters.dart';
import 'package:bizniz_tracker/features/sales/domain/sale.dart';
import 'package:bizniz_tracker/features/sales/data/sale_repository_impl.dart';

// Product search dialog widget (top-level)
class _ProductSearchDialog extends StatefulWidget {
  final List<ProductModel> products;

  const _ProductSearchDialog({required this.products});

  @override
  State<_ProductSearchDialog> createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends State<_ProductSearchDialog> {
  late List<ProductModel> _filtered;
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _filtered = widget.products;
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    final s = q.trim().toLowerCase();
    setState(() {
      if (s.isEmpty) {
        _filtered = widget.products;
      } else {
        _filtered = widget.products
            .where(
              (p) =>
                  p.name.toLowerCase().contains(s) ||
                  p.id.contains(s) ||
                  p.category.toLowerCase().contains(s),
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Product'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search by name, id, or category',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: _onSearch,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.maxFinite,
            height: 300,
            child: _filtered.isEmpty
                ? const Center(child: Text('No products found'))
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final p = _filtered[index];
                      return ListTile(
                        title: Text(p.name),
                        subtitle: Text('ID: ${p.id} • ${p.quantity} in stock'),
                        trailing: Text(p.category),
                        onTap: () => Navigator.of(context).pop(p),
                      );
                    },
                  ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class AddSaleScreen extends StatefulWidget {
  final Function(int) onNavigate;
  final ProductController productController;
  final SalesController salesController;
  final SaleRepositoryImpl saleRepository;

  const AddSaleScreen({
    required this.onNavigate,
    required this.productController,
    required this.salesController,
    required this.saleRepository,
    super.key,
  });

  @override
  State<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends State<AddSaleScreen> {
  ProductModel? _selectedProduct;
  int _quantityInput = 1;
  late TextEditingController _quantityController;
  late TextEditingController _priceController;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: '1');
    _priceController = TextEditingController();
    _loadDefaultPrice();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _loadDefaultPrice() {
    if (_selectedProduct != null) {
      _priceController.text = _selectedProduct!.sellingPrice.toString();
    } else {
      _priceController.clear();
    }
  }

  void _onProductSelected(ProductModel? product) {
    setState(() {
      _selectedProduct = product;
      _error = null;
      _loadDefaultPrice();
    });
  }

  void _onQuantityChanged(String value) {
    final parsed = int.tryParse(value);
    if (parsed != null && parsed > 0) {
      setState(() {
        _quantityInput = parsed;
        _error = null;
      });
    }
  }

  Future<void> _recordSale() async {
    // Validation
    if (_selectedProduct == null) {
      setState(() => _error = 'Please select a product');
      return;
    }

    if (_quantityInput <= 0) {
      setState(() => _error = 'Quantity must be greater than 0');
      return;
    }

    if (_quantityInput > _selectedProduct!.quantity) {
      setState(
        () => _error =
            'Cannot sell more than available stock (${_selectedProduct!.quantity} available)',
      );
      return;
    }

    final priceStr = _priceController.text.trim();
    final price = double.tryParse(priceStr);
    if (price == null || price <= 0) {
      setState(() => _error = 'Please enter a valid selling price');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Create Sale record
      final sale = Sale(
        id: '${DateTime.now().millisecondsSinceEpoch}_${_selectedProduct!.id}',
        productId: _selectedProduct!.id,
        productCostAtSale: _selectedProduct!.costPrice,
        quantitySold: _quantityInput,
        sellingPrice: price,
        saleDate: DateTime.now(),
        totalRevenue: Sale.calculateRevenue(_quantityInput, price),
      );

      // Save to repository
      await widget.saleRepository.addSale(sale);

      // Reduce inventory
      final updatedProduct = _selectedProduct!.copyWith(
        quantity: _selectedProduct!.quantity - _quantityInput,
      );
      await widget.productController.updateProduct(updatedProduct);

      if (mounted) {
        // Reset form
        setState(() {
          _selectedProduct = null;
          _quantityInput = 1;
          _quantityController.text = '1';
          _priceController.clear();
          _error = null;
          _isSubmitting = false;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sale recorded successfully!')),
        );

        // Navigate back to Home
        widget.onNavigate(0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error recording sale: ${e.toString()}';
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.productController.state.products;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Sale'), centerTitle: true),
      body: products.isEmpty
          ? const Center(
              child: Text('No products available. Add products first.'),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Search / Selector
                  Text(
                    'Select Product',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final selected = await showDialog<ProductModel?>(
                        context: context,
                        builder: (context) =>
                            _ProductSearchDialog(products: products),
                      );
                      if (selected != null) _onProductSelected(selected);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _selectedProduct == null
                                  ? 'Tap to search products'
                                  : '${_selectedProduct!.name} (${_selectedProduct!.quantity} in stock)',
                              style: TextStyle(
                                color: _selectedProduct == null
                                    ? Theme.of(context).hintColor
                                    : Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Product search dialog widget will be defined below
                          const Icon(Icons.search),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Quantity Input
                  if (_selectedProduct != null) ...[
                    Text(
                      'Quantity to Sell',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      onChanged: _onQuantityChanged,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintText: 'Enter quantity',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        helperText:
                            'Available: ${_selectedProduct!.quantity} units',
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Selling Price Input
                    Text(
                      'Selling Price per Unit',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixText: '₱ ',
                        hintText: 'Enter price',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total Revenue: ${formatCurrency(_quantityInput * (double.tryParse(_priceController.text) ?? 0))}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Error Display
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.error.withValues(alpha: 0.08),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.error.withValues(alpha: 0.2),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting || _selectedProduct == null
                              ? null
                              : _recordSale,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: Text(
                            _isSubmitting ? 'Processing...' : 'Confirm Sale',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : () => widget.onNavigate(0),
                          icon: const Icon(Icons.close),
                          label: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
