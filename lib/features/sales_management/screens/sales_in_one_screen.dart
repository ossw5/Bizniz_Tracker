import 'package:flutter/material.dart';

import '../../products/domain/product.dart';
import '../../products/presentation/controllers.dart';
import '../../sales/domain/sale_repository.dart';
import '../models/sales_transaction_record.dart';
import '../services/sales_in_one_service.dart';
import 'barcode_scanner_screen.dart';
import 'receipt_screen.dart';
import 'sales_history_screen.dart';
import 'sales_summary_screen.dart';

class SalesInOneScreen extends StatefulWidget {
  final ProductController productController;
  final SaleRepository saleRepository;

  const SalesInOneScreen({
    super.key,
    required this.productController,
    required this.saleRepository,
  });

  @override
  State<SalesInOneScreen> createState() => _SalesInOneScreenState();
}

class _SalesInOneScreenState extends State<SalesInOneScreen> {
  final _searchController = TextEditingController();
  final _quantities = <String, int>{};
  String _searchTerm = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ProductModel> get _matchingProducts {
    final query = _searchTerm.trim().toLowerCase();
    final products = widget.productController.state.products.where((product) {
      return query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query) ||
          product.barcode.toLowerCase().contains(query);
    }).toList()..sort((first, second) => first.name.compareTo(second.name));
    return products;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _addProduct(ProductModel product) {
    final selected = _quantities[product.id] ?? 0;
    if (product.quantity <= 0) {
      _showMessage('${product.name} is out of stock.');
      return;
    }
    if (selected >= product.quantity) {
      _showMessage('Only ${product.quantity} units are available.');
      return;
    }
    setState(() => _quantities[product.id] = selected + 1);
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (!mounted || barcode == null) return;

    final matches = widget.productController.state.products
        .where(
          (product) =>
              product.barcode.trim().toLowerCase() ==
                  barcode.trim().toLowerCase() &&
              product.barcode.trim().isNotEmpty,
        )
        .toList();
    if (matches.isEmpty) {
      _showMessage('Barcode "$barcode" is not registered to a product.');
      return;
    }
    if (matches.length > 1) {
      _showMessage(
        'Barcode "$barcode" is assigned to multiple products. '
        'Update inventory barcodes before scanning.',
      );
      return;
    }
    _addProduct(matches.single);
  }

  Future<void> _openCart() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ShoppingCartScreen(
          products: widget.productController.state.products,
          quantities: Map.of(_quantities),
          saleService: SalesInOneService(
            productController: widget.productController,
            saleRepository: widget.saleRepository,
          ),
        ),
      ),
    );
    if (!mounted || result != true) return;
    setState(_quantities.clear);
    await widget.productController.loadProducts();
    if (mounted && widget.productController.state.error != null) {
      _showMessage(
        'Sale was saved, but inventory refresh failed: '
        '${widget.productController.state.error}',
      );
    }
  }

  Future<void> _refreshProducts() async {
    await widget.productController.loadProducts();
    if (!mounted) return;
    setState(() {});
    if (widget.productController.state.error != null) {
      _showMessage(
        'Could not refresh inventory: ${widget.productController.state.error}',
      );
    }
  }

  int get _cartCount => _quantities.values.fold(0, (sum, qty) => sum + qty);

  double get _cartTotal {
    final products = {
      for (final product in widget.productController.state.products)
        product.id: product,
    };
    final cents = _quantities.entries.fold<int>(0, (sum, entry) {
      final product = products[entry.key];
      return sum +
          (product == null
              ? 0
              : (product.sellingPrice * 100).round() * entry.value);
    });
    return cents / 100;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.productController.state;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales in One'),
        actions: [
          IconButton(
            tooltip: 'Scan barcode',
            onPressed: _scanBarcode,
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
          IconButton(
            tooltip: 'Sales history',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => SalesHistoryScreen(
                  saleRepository: widget.saleRepository,
                  products: widget.productController.state.products,
                ),
              ),
            ),
            icon: const Icon(Icons.history_rounded),
          ),
          IconButton(
            tooltip: 'Sales summary',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) =>
                    SalesSummaryScreen(saleRepository: widget.saleRepository),
              ),
            ),
            icon: const Icon(Icons.bar_chart_rounded),
          ),
        ],
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load inventory: ${state.error}'),
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshProducts,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search name, category, or barcode',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchTerm = '');
                        },
                        icon: const Icon(Icons.clear),
                      ),
                      filled: true,
                    ),
                    onChanged: (value) => setState(() => _searchTerm = value),
                  ),
                  const SizedBox(height: 12),
                  if (_matchingProducts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        state.products.isEmpty
                            ? 'No inventory products are available. Add products in Inventory to start a sale.'
                            : 'No products match your search.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ..._matchingProducts.map(_productCard),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _cartCount == 0 ? null : _openCart,
            icon: const Icon(Icons.shopping_cart_outlined),
            label: Text(
              _cartCount == 0
                  ? 'Cart is empty'
                  : 'Cart ($_cartCount) · ${formatSalesCurrency(_cartTotal)}',
            ),
          ),
        ),
      ),
    );
  }

  Widget _productCard(ProductModel product) {
    final selected = _quantities[product.id] ?? 0;
    final outOfStock = product.quantity <= 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(product.name),
        subtitle: Text(
          [
            if (product.category.isNotEmpty) product.category,
            '${formatSalesCurrency(product.sellingPrice)} · '
                '${product.quantity} in stock',
            if (selected > 0) '$selected in cart',
          ].join(' · '),
        ),
        trailing: IconButton(
          tooltip: outOfStock ? 'Out of stock' : 'Add ${product.name}',
          onPressed: outOfStock ? null : () => _addProduct(product),
          icon: Icon(
            outOfStock ? Icons.remove_shopping_cart : Icons.add_circle_outline,
          ),
        ),
      ),
    );
  }
}

class ShoppingCartScreen extends StatefulWidget {
  final List<ProductModel> products;
  final Map<String, int> quantities;
  final SalesInOneService saleService;

  const ShoppingCartScreen({
    super.key,
    required this.products,
    required this.quantities,
    required this.saleService,
  });

  @override
  State<ShoppingCartScreen> createState() => _ShoppingCartScreenState();
}

class _ShoppingCartScreenState extends State<ShoppingCartScreen> {
  late final Map<String, int> _quantities;

  @override
  void initState() {
    super.initState();
    _quantities = Map.of(widget.quantities);
  }

  List<ProductModel> get _cartProducts {
    final products = {
      for (final product in widget.products) product.id: product,
    };
    return _quantities.keys
        .map((id) => products[id])
        .whereType<ProductModel>()
        .toList();
  }

  double get _subtotal {
    final products = {
      for (final product in widget.products) product.id: product,
    };
    final cents = _quantities.entries.fold<int>(0, (sum, entry) {
      final product = products[entry.key];
      return sum +
          (product == null
              ? 0
              : (product.sellingPrice * 100).round() * entry.value);
    });
    return cents / 100;
  }

  void _setQuantity(ProductModel product, int quantity) {
    setState(() {
      if (quantity <= 0) {
        _quantities.remove(product.id);
      } else {
        _quantities[product.id] = quantity;
      }
    });
  }

  Future<void> _proceedToPayment() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          quantities: Map.of(_quantities),
          products: _cartProducts,
          saleService: widget.saleService,
        ),
      ),
    );
    if (!mounted || result != true) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to products',
          onPressed: () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Shopping Cart'),
      ),
      body: _cartProducts.isEmpty
          ? const Center(child: Text('Your cart is empty.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final product in _cartProducts)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(product.name)),
                              IconButton(
                                tooltip: 'Remove ${product.name}',
                                onPressed: () => _setQuantity(product, 0),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          Text(
                            '${formatSalesCurrency(product.sellingPrice)} each · '
                            '${formatSalesCurrency(product.sellingPrice * _quantities[product.id]!)} subtotal',
                          ),
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Decrease quantity',
                                onPressed: () => _setQuantity(
                                  product,
                                  _quantities[product.id]! - 1,
                                ),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text('${_quantities[product.id]}'),
                              IconButton(
                                tooltip: 'Increase quantity',
                                onPressed:
                                    _quantities[product.id]! >= product.quantity
                                    ? null
                                    : () => _setQuantity(
                                        product,
                                        _quantities[product.id]! + 1,
                                      ),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                              Text('Available: ${product.quantity}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                const Divider(height: 24),
                _CartAmount(label: 'Subtotal', amount: _subtotal),
                const _CartAmount(label: 'Discount', amount: 0),
                _CartAmount(label: 'Total', amount: _subtotal, bold: true),
              ],
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _quantities.isEmpty ? null : _proceedToPayment,
            child: Text(
              'Proceed to Payment · ${formatSalesCurrency(_subtotal)}',
            ),
          ),
        ),
      ),
    );
  }
}

class _CartAmount extends StatelessWidget {
  final String label;
  final double amount;
  final bool bold;

  const _CartAmount({
    required this.label,
    required this.amount,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.w700) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(formatSalesCurrency(amount), style: style),
        ],
      ),
    );
  }
}

class PaymentScreen extends StatefulWidget {
  final Map<String, int> quantities;
  final List<ProductModel> products;
  final SalesInOneService saleService;

  const PaymentScreen({
    super.key,
    required this.quantities,
    required this.products,
    required this.saleService,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final TextEditingController _amountController;
  final String _transactionId = 'BZT-${DateTime.now().microsecondsSinceEpoch}';
  String _paymentMethod = 'Cash';
  bool _submitting = false;

  int get _totalCents {
    final prices = {
      for (final product in widget.products)
        product.id: (product.sellingPrice * 100).round(),
    };
    return widget.quantities.entries.fold(
      0,
      (sum, entry) => sum + (prices[entry.key] ?? 0) * entry.value,
    );
  }

  double get _total => _totalCents / 100;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: _total.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _completeSale() async {
    if (_submitting) return;
    final amountPaid = double.tryParse(_amountController.text.trim());
    if (amountPaid == null || !amountPaid.isFinite) {
      _showError('Enter a valid payment amount.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final transaction = await widget.saleService.completeSale(
        quantities: widget.quantities,
        amountPaid: amountPaid,
        paymentMethod: _paymentMethod,
        transactionId: _transactionId,
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ReceiptScreen(transaction: transaction),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final amountPaid = double.tryParse(_amountController.text) ?? 0;
    final visibleChange = _paymentMethod == 'Cash'
        ? (amountPaid - _total).clamp(0, double.infinity)
        : 0.0;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to cart',
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Payment'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Amount',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatSalesCurrency(_total),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _paymentMethod,
            decoration: const InputDecoration(labelText: 'Payment Method'),
            items: SalesInOneService.paymentMethods
                .map(
                  (method) =>
                      DropdownMenuItem(value: method, child: Text(method)),
                )
                .toList(),
            onChanged: _submitting
                ? null
                : (method) {
                    if (method == null) return;
                    setState(() {
                      _paymentMethod = method;
                      if (method != 'Cash') {
                        _amountController.text = _total.toStringAsFixed(2);
                      }
                    });
                  },
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('amount-paid'),
            controller: _amountController,
            enabled: !_submitting,
            decoration: const InputDecoration(
              labelText: 'Amount Received',
              prefixText: '₱ ',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: ListTile(
              title: const Text('Change'),
              trailing: Text(
                formatSalesCurrency(visibleChange),
                key: const ValueKey('change-due'),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _submitting ? null : _completeSale,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(_submitting ? 'Saving Sale' : 'Complete Sale'),
          ),
        ],
      ),
    );
  }
}
