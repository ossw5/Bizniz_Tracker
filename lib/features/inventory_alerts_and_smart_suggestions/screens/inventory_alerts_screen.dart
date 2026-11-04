import 'package:flutter/material.dart';

import '../../products/domain/product.dart';
import '../../products/presentation/controllers.dart';
import '../../sales/domain/sale.dart';
import '../../sales/domain/sale_repository.dart';
import '../models/inventory_alerts_data.dart';
import '../services/inventory_alert_service.dart';
import '../widgets/inventory_alert_product_card.dart';

class InventoryAlertsScreen extends StatefulWidget {
  final ProductController? productController;
  final SaleRepository? saleRepository;
  final VoidCallback onBack;

  const InventoryAlertsScreen({
    super.key,
    required this.onBack,
    this.productController,
    this.saleRepository,
  });

  @override
  State<InventoryAlertsScreen> createState() => _InventoryAlertsScreenState();
}

class _InventoryAlertsScreenState extends State<InventoryAlertsScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = [
    'LOW STOCK',
    'EXPIRATION',
    'SLOW-MOVING',
    'TOP SOLD',
    'SUGGESTIONS',
  ];
  static const _periods = {
    'THIS DAY': Duration(days: 1),
    'THIS WEEK': Duration(days: 7),
    'THIS MONTH': Duration(days: 30),
  };
  static const _alertService = InventoryAlertService();

  late final TabController _tabController;
  late Future<List<Sale>> _salesFuture;
  String _searchTerm = '';
  String _selectedPeriod = 'THIS WEEK';
  InventorySuggestionType _selectedSuggestionType =
      InventorySuggestionType.slowMoving;
  final Map<String, InventoryComboSuggestion> _editedSuggestions = {};
  final Set<String> _acceptedSuggestions = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _salesFuture = _loadSales();
  }

  Future<List<Sale>> _loadSales() =>
      widget.saleRepository?.getAllSales() ?? Future<List<Sale>>.value([]);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<ProductModel> _filterByName(Iterable<ProductModel> products) {
    final query = _searchTerm.trim().toLowerCase();
    final matches = query.isEmpty
        ? products
        : products.where(
            (product) => product.name.toLowerCase().contains(query),
          );
    return matches.toList();
  }

  Widget _searchField() => TextField(
    decoration: const InputDecoration(
      hintText: 'Search products',
      prefixIcon: Icon(Icons.search),
      filled: true,
    ),
    onChanged: (value) => setState(() => _searchTerm = value),
  );

  Widget _emptyMessage(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );

  Widget _productList(
    List<ProductModel> products, {
    required String emptyMessage,
    required Widget Function(ProductModel product) buildCard,
  }) {
    if (products.isEmpty) return _emptyMessage(emptyMessage);
    return ListView(
      padding: const EdgeInsets.only(top: 12),
      children: products.map(buildCard).toList(),
    );
  }

  Widget _lowStockTab(List<ProductModel> products) {
    final alerts = _filterByName(_alertService.lowStockProducts(products));
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _AlertBanner(
            color: Colors.red,
            icon: Icons.warning_amber_rounded,
            title: '${alerts.length} products are running low on stock',
          ),
          const SizedBox(height: 12),
          _searchField(),
          const SizedBox(height: 4),
          Expanded(
            child: _productList(
              alerts,
              emptyMessage:
                  'No low-stock products found. Add products and set a minimum stock level to see alerts.',
              buildCard: (product) => InventoryAlertProductCard(
                product: product,
                subtitle: product.category.isEmpty ? 'Category not set' : null,
                status: product.quantity <= 0 ? 'OUT OF STOCK' : 'LOW STOCK',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _expirationTab() => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        const _AlertBanner(
          color: Colors.amber,
          icon: Icons.calendar_today_rounded,
          title: 'Expiration tracking is not configured',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _emptyMessage(
            'Products do not currently store batch or expiration dates, so expiration alerts cannot be calculated yet.',
          ),
        ),
      ],
    ),
  );

  Widget _salesTab(List<ProductModel> products, {required bool slowMoving}) {
    return FutureBuilder<List<Sale>>(
      future: _salesFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptyMessage(
            'Could not load sales history: ${snapshot.error}',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final matchingProducts = slowMoving
            ? _alertService.slowMovingProducts(products, snapshot.data ?? [])
            : <ProductModel>[];
        final filtered = _filterByName(matchingProducts);

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _AlertBanner(
                color: Colors.purple,
                icon: Icons.schedule_rounded,
                title: slowMoving
                    ? '${filtered.length} products have not been sold for 30 days'
                    : 'Best sellers based on recorded sales',
              ),
              const SizedBox(height: 12),
              _searchField(),
              const SizedBox(height: 4),
              Expanded(
                child: _productList(
                  filtered,
                  emptyMessage: 'No slow-moving products found.',
                  buildCard: (product) => InventoryAlertProductCard(
                    product: product,
                    status: 'SLOW-MOVING',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _topSoldTab(List<ProductModel> products) {
    return FutureBuilder<List<Sale>>(
      future: _salesFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptyMessage(
            'Could not load sales history: ${snapshot.error}',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final topSelling = _alertService
            .topSellingProducts(
              products,
              snapshot.data ?? [],
              period: _periods[_selectedPeriod]!,
            )
            .where((entry) {
              final query = _searchTerm.trim().toLowerCase();
              return query.isEmpty ||
                  entry.key.name.toLowerCase().contains(query);
            })
            .toList();

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButton<String>(
                value: _selectedPeriod,
                items: _periods.keys
                    .map(
                      (period) =>
                          DropdownMenuItem(value: period, child: Text(period)),
                    )
                    .toList(),
                onChanged: (period) {
                  if (period != null) setState(() => _selectedPeriod = period);
                },
              ),
              _searchField(),
              const SizedBox(height: 8),
              Expanded(
                child: topSelling.isEmpty
                    ? _emptyMessage('No sales in the selected period.')
                    : ListView(
                        children: topSelling
                            .map(
                              (entry) => InventoryAlertProductCard(
                                product: entry.key,
                                status: 'SOLD: ${entry.value} UNITS',
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _suggestionsTab(List<ProductModel> products) {
    return FutureBuilder<List<Sale>>(
      future: _salesFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptyMessage(
            'Could not load sales history: ${snapshot.error}',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final suggestions = _alertService
            .comboSuggestions(
              products: products,
              sales: snapshot.data ?? [],
              type: _selectedSuggestionType,
            )
            .where((suggestion) {
              final query = _searchTerm.trim().toLowerCase();
              return query.isEmpty ||
                  suggestion.featuredProduct.name.toLowerCase().contains(
                    query,
                  ) ||
                  (suggestion.pairedProduct?.name.toLowerCase().contains(
                        query,
                      ) ??
                      false);
            })
            .map(
              (suggestion) => _editedSuggestions[suggestion.id] ?? suggestion,
            )
            .toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: InventorySuggestionType.values.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final type = InventorySuggestionType.values[index];
                    return _SuggestionTypeChip(
                      key: ValueKey('suggestion-type-${type.name}'),
                      label: _suggestionTypeLabel(type),
                      selected: type == _selectedSuggestionType,
                      onTap: () => setState(() {
                        _selectedSuggestionType = type;
                        _searchTerm = '';
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              _AlertBanner(
                color: Colors.green,
                icon: Icons.lightbulb_outline_rounded,
                title: _suggestionHeader(_selectedSuggestionType),
              ),
              const SizedBox(height: 12),
              _searchField(),
              const SizedBox(height: 8),
              if (_selectedSuggestionType == InventorySuggestionType.expiration)
                _emptyMessage(
                  'Expiration dates are not recorded for products yet, so expiration-based suggestions are not available.',
                )
              else if (suggestions.isEmpty)
                _emptyMessage(
                  _selectedSuggestionType == InventorySuggestionType.slowMoving
                      ? 'No slow-moving products with sales history are ready for a combo suggestion.'
                      : 'No fast-moving products with recent sales are ready for a combo suggestion.',
                )
              else
                ...suggestions.map(
                  (suggestion) => Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _ComboSuggestionCard(
                      suggestion: suggestion,
                      accepted: _acceptedSuggestions.contains(suggestion.id),
                      onAccept: () => _acceptSuggestion(suggestion),
                      onEdit: () => _editSuggestion(suggestion),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _suggestionTypeLabel(InventorySuggestionType type) => switch (type) {
    InventorySuggestionType.slowMoving => 'SLOW-MOVING',
    InventorySuggestionType.fastMoving => 'FAST MOVING',
    InventorySuggestionType.expiration => 'EXPIRATION',
  };

  String _suggestionHeader(InventorySuggestionType type) => switch (type) {
    InventorySuggestionType.slowMoving =>
      'Pair slow-moving products with popular items',
    InventorySuggestionType.fastMoving =>
      'Bundle popular products to increase basket size',
    InventorySuggestionType.expiration => 'Expiration-based suggestions',
  };

  void _acceptSuggestion(InventoryComboSuggestion suggestion) {
    setState(() => _acceptedSuggestions.add(suggestion.id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Combo accepted for this session.')),
    );
  }

  Future<void> _editSuggestion(InventoryComboSuggestion suggestion) async {
    final discount = await showDialog<int>(
      context: context,
      builder: (context) =>
          _EditComboDialog(initialDiscount: suggestion.discountPercent),
    );
    if (discount == null || !mounted) return;
    setState(() {
      _editedSuggestions[suggestion.id] = suggestion.copyWith(
        discountPercent: discount,
      );
      _acceptedSuggestions.remove(suggestion.id);
    });
  }

  Future<void> _refresh() async {
    final controller = widget.productController;
    if (controller != null) await controller.loadProducts();
    if (!mounted) return;
    setState(() => _salesFuture = _loadSales());
  }

  Future<void> _addProduct() async {
    final controller = widget.productController;
    if (controller == null) return;

    final product = await showDialog<ProductModel>(
      context: context,
      builder: (context) => const _AddProductDialog(),
    );
    if (product == null) return;

    await controller.addProduct(product);
    if (!mounted) return;
    final error = controller.state.error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null ? 'Product saved.' : 'Could not save product: $error',
        ),
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.productController?.state;
    final products = state?.products ?? const <ProductModel>[];
    final tabs = [
      _lowStockTab(products),
      _expirationTab(),
      _salesTab(products, slowMoving: true),
      _topSoldTab(products),
      _suggestionsTab(products),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Text('Inventory Alerts'),
        actions: [
          IconButton(
            tooltip: 'Add product',
            icon: const Icon(Icons.add_box_outlined),
            onPressed: widget.productController == null ? null : _addProduct,
          ),
          IconButton(
            tooltip: 'Refresh alerts',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
      body: state?.error != null
          ? _emptyMessage('Could not load inventory: ${state!.error}')
          : TabBarView(controller: _tabController, children: tabs),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;

  const _AlertBanner({
    required this.color,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AddProductDialog extends StatefulWidget {
  const _AddProductDialog();

  @override
  State<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<_AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '0');
  final _minimumController = TextEditingController(text: '0');
  final _costPriceController = TextEditingController(text: '0');
  final _sellingPriceController = TextEditingController(text: '0');
  final _categoryController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _minimumController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  String? _validateNumber(String? value, {required bool integer}) {
    final parsed = integer
        ? int.tryParse(value ?? '')
        : double.tryParse(value ?? '');
    if (parsed == null || parsed < 0) {
      return 'Enter a valid non-negative number';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add product'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Product name'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Enter a name' : null,
            ),
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
              validator: (value) => _validateNumber(value, integer: true),
            ),
            TextFormField(
              controller: _minimumController,
              decoration: const InputDecoration(labelText: 'Minimum stock'),
              keyboardType: TextInputType.number,
              validator: (value) => _validateNumber(value, integer: true),
            ),
            TextFormField(
              controller: _costPriceController,
              decoration: const InputDecoration(labelText: 'Cost price'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) => _validateNumber(value, integer: false),
            ),
            TextFormField(
              controller: _sellingPriceController,
              decoration: const InputDecoration(labelText: 'Selling price'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) => _validateNumber(value, integer: false),
            ),
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            ProductModel(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              name: _nameController.text.trim(),
              quantity: int.parse(_quantityController.text),
              costPrice: double.parse(_costPriceController.text),
              sellingPrice: double.parse(_sellingPriceController.text),
              category: _categoryController.text.trim(),
              minStock: int.parse(_minimumController.text),
            ),
          );
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class _SuggestionTypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SuggestionTypeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: selected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ComboSuggestionCard extends StatelessWidget {
  final InventoryComboSuggestion suggestion;
  final bool accepted;
  final VoidCallback onAccept;
  final VoidCallback onEdit;

  const _ComboSuggestionCard({
    required this.suggestion,
    required this.accepted,
    required this.onAccept,
    required this.onEdit,
  });

  String _formatPrice(double price) => '₱${price.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final featured = suggestion.featuredProduct;
    final paired = suggestion.pairedProduct;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Suggested combo',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _SuggestionProductPreview(
                    product: featured,
                    formatPrice: _formatPrice,
                  ),
                ),
                if (paired != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SuggestionProductPreview(
                      product: paired,
                      formatPrice: _formatPrice,
                      namePrefix: '+ ',
                    ),
                  ),
                ],
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Original price\n${_formatPrice(suggestion.originalPrice)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Combo price (${suggestion.discountPercent}% off)\n'
                    '${_formatPrice(suggestion.comboPrice)}',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onEdit,
                    child: const Text('Edit combo'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: accepted ? null : onAccept,
                    child: Text(accepted ? 'Accepted' : 'Accept combo'),
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

class _SuggestionProductPreview extends StatelessWidget {
  final ProductModel product;
  final String Function(double) formatPrice;
  final String namePrefix;

  const _SuggestionProductPreview({
    required this.product,
    required this.formatPrice,
    this.namePrefix = '',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InventoryProductThumbnail(productName: product.name, size: 44),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$namePrefix${product.name}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (product.category.trim().isNotEmpty)
                Text(
                  product.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              Text(
                'Qty: ${product.quantity}',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                formatPrice(product.sellingPrice),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EditComboDialog extends StatefulWidget {
  final int initialDiscount;

  const _EditComboDialog({required this.initialDiscount});

  @override
  State<_EditComboDialog> createState() => _EditComboDialogState();
}

class _EditComboDialogState extends State<_EditComboDialog> {
  late double _discount;

  @override
  void initState() {
    super.initState();
    _discount = widget.initialDiscount.toDouble();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit combo'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Discount: ${_discount.round()}%'),
        Slider(
          value: _discount,
          min: 0,
          max: 50,
          divisions: 10,
          label: '${_discount.round()}%',
          onChanged: (value) => setState(() => _discount = value),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _discount.round()),
        child: const Text('Save'),
      ),
    ],
  );
}
