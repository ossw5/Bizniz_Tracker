import 'package:flutter/material.dart';

import '../../products/domain/product.dart';
import '../../products/presentation/controllers.dart';
import '../../sales/domain/sale_repository.dart';
import '../../settings/services/activity_log_service.dart';
import '../models/sales_transaction_record.dart';
import '../services/sales_in_one_service.dart';
import 'barcode_scanner_screen.dart';
import 'sales_history_screen.dart';
import 'sales_payment_screen.dart';

class SalesInOneScreen extends StatefulWidget {
  final ProductController productController;
  final SaleRepository saleRepository;
  final ActivityLogService? activityLog;
  final int scanRequestVersion;

  const SalesInOneScreen({
    super.key,
    required this.productController,
    required this.saleRepository,
    this.activityLog = const ActivityLogService(),
    this.scanRequestVersion = 0,
  });

  @override
  State<SalesInOneScreen> createState() => _SalesInOneScreenState();
}

class _SalesCartState {
  static final Map<String, int> quantities = <String, int>{};
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

class _SalesInOneScreenState extends State<SalesInOneScreen> {
  final _searchController = TextEditingController();
  final _quantities = _SalesCartState.quantities;
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    if (widget.scanRequestVersion > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scanBarcode());
    }
  }

  @override
  void didUpdateWidget(covariant SalesInOneScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scanRequestVersion != widget.scanRequestVersion &&
        widget.scanRequestVersion > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scanBarcode());
    }
  }

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
          quantities: _quantities,
          saleService: SalesInOneService(
            productController: widget.productController,
            saleRepository: widget.saleRepository,
            activityLog: widget.activityLog,
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (result != true) {
      setState(() {});
      return;
    }
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLowStock = product.isLowStock && !outOfStock;
    final stockColor = outOfStock
        ? colorScheme.error
        : isLowStock
        ? colorScheme.secondary
        : colorScheme.primary;
    final stockLabel = outOfStock
        ? 'Out of stock'
        : isLowStock
        ? 'Low stock'
        : 'In stock';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (product.category.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      product.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Stock: ${product.quantity}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: stockColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: stockColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          stockLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: stockColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (selected > 0)
                        Text(
                          '$selected in cart',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    formatSalesCurrency(product.sellingPrice),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton.filledTonal(
              tooltip: outOfStock ? 'Out of stock' : 'Add ${product.name}',
              onPressed: outOfStock ? null : () => _addProduct(product),
              icon: Icon(
                outOfStock
                    ? Icons.remove_shopping_cart_rounded
                    : Icons.add_rounded,
              ),
            ),
            if (selected > 0) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Remove ${product.name} from cart',
                onPressed: () => setState(() => _quantities.remove(product.id)),
                icon: const Icon(Icons.undo_rounded),
              ),
            ],
          ],
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
    _quantities = widget.quantities;
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
        builder: (_) => SalesPaymentScreen(
          quantities: Map.of(_quantities),
          products: _cartProducts,
          saleService: widget.saleService,
        ),
      ),
    );
    if (!mounted || result != true) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _clearCart() async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear cart?'),
        content: const Text('Remove all selected products from this sale?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Cart'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear Cart'),
          ),
        ],
      ),
    );
    if (clear == true && mounted) setState(_quantities.clear);
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
        actions: [
          IconButton(
            tooltip: 'Clear cart',
            onPressed: _quantities.isEmpty ? null : _clearCart,
            icon: const Icon(Icons.remove_shopping_cart_outlined),
          ),
        ],
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
