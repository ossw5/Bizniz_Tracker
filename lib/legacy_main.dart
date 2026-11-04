import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/hive_registry.dart';
import 'package:hive/hive.dart';
import 'package:bizniz_tracker/features/products/domain/product.dart';
import 'package:bizniz_tracker/features/sales/domain/sale.dart';
import 'package:bizniz_tracker/features/products/presentation/providers.dart';
import 'package:bizniz_tracker/features/products/presentation/controllers.dart';
import 'package:bizniz_tracker/features/sales/presentation/home_screen.dart';
import 'package:bizniz_tracker/core/formatters.dart';
import 'package:bizniz_tracker/core/theme.dart';
import 'package:bizniz_tracker/core/csv_export.dart';
import 'package:bizniz_tracker/features/sales/domain/sale_repository.dart';
import 'package:bizniz_tracker/features/sales/presentation/add_sale_screen.dart';
import 'package:bizniz_tracker/features/sales/presentation/sales_summary_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await registerHiveAdapters();

  // open boxes
  final Box<ProductModel> productsBox = await Hive.openBox<ProductModel>(
    'products_box',
  );
  final Box<Sale> salesBox = await Hive.openBox<Sale>('sales_box');

  runApp(
    ProviderScope(
      overrides: [
        productsBoxProvider.overrideWithValue(productsBox),
        salesBoxProvider.overrideWithValue(salesBox),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bizniz Tracker',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: const ProductHomePage(),
    );
  }
}

class ProductHomePage extends StatefulWidget {
  const ProductHomePage({super.key});

  @override
  State<ProductHomePage> createState() => _ProductHomePageState();
}

class _ProductHomePageState extends State<ProductHomePage> {
  late ProductController _productController;
  int _currentIndex = 0;
  bool _showInventoryAlerts = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get controller from Riverpod via context
    final ref = ProviderScope.containerOf(context);
    _productController = ref.read(productControllerProvider);
    // Load products on first build
    if (_productController.state.products.isEmpty &&
        !_productController.state.loading) {
      _productController.loadProducts();
    }
  }

  void _refresh() {
    setState(() {});
  }

  void _onNavigate(int index) {
    setState(() {
      _currentIndex = index;
      if (index != 1) {
        _showInventoryAlerts = false;
      }
    });
  }

  void _openInventoryAlerts() {
    setState(() {
      _showInventoryAlerts = true;
      _currentIndex = 1;
    });
  }

  void _closeInventoryAlerts() {
    setState(() {
      _showInventoryAlerts = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ref = ProviderScope.containerOf(context);
    final salesController = ref.read(salesControllerProvider);
    final saleRepository = ref.read(saleRepositoryProvider);

    final screens = [
      HomeScreen(
        productController: _productController,
        salesController: salesController,
        onNavigate: _onNavigate,
      ),
      _showInventoryAlerts
          ? InventoryAlertsScreen(
              productController: _productController,
              saleRepository: saleRepository,
              onBack: _closeInventoryAlerts,
            )
          : InventoryManagementScreen(
              productController: _productController,
              onRefresh: _refresh,
              onOpenInventoryAlerts: _openInventoryAlerts,
            ),
      AddSaleScreen(
        onNavigate: _onNavigate,
        productController: _productController,
        salesController: salesController,
        saleRepository: saleRepository,
      ),
      SalesSummaryScreen(onNavigate: _onNavigate),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle),
            label: 'Add Sale',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Summary',
          ),
        ],
        onTap: _onNavigate,
      ),
    );
  }
}

/// Inventory management screen with categories and editable low-stock items
class InventoryManagementScreen extends StatefulWidget {
  final ProductController productController;
  final Function() onRefresh;
  final VoidCallback onOpenInventoryAlerts;

  const InventoryManagementScreen({
    super.key,
    required this.productController,
    required this.onRefresh,
    required this.onOpenInventoryAlerts,
  });

  @override
  State<InventoryManagementScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryManagementScreen> {
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final state = widget.productController.state;
    final allProducts = state.products;

    // derive categories from existing products (non-empty)
    final categories = <String>{};
    for (final p in allProducts) {
      if (p.category.trim().isNotEmpty) categories.add(p.category.trim());
    }
    final categoryList = categories.toList()..sort();

    // filtered products by selected category
    final products = _selectedCategory == null
        ? allProducts
        : allProducts.where((p) => p.category == _selectedCategory).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: widget.onOpenInventoryAlerts,
              style: TextButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Inventory Alerts'),
            ),
          ),
          IconButton(
            tooltip: 'Export CSV',
            onPressed: () async {
              try {
                final csv = CsvExport.productsToCsv(allProducts);
                final fname =
                    'inventory_${DateTime.now().toIso8601String().replaceAll(':', '-')}.csv';
                final path = await CsvExport.saveCsvFile(fname, csv);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Saved CSV to: $path')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Export failed: ${e.toString()}')),
                  );
                }
              }
            },
            icon: const Icon(Icons.download),
          ),
        ],
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: ${state.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      widget.productController.loadProducts();
                      widget.onRefresh();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Category chips row
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              ChoiceChip(
                                label: const Text('All'),
                                selected: _selectedCategory == null,
                                selectedColor: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.12),
                                labelStyle: Theme.of(
                                  context,
                                ).textTheme.bodyMedium,
                                onSelected: (_) => setState(() {
                                  _selectedCategory = null;
                                }),
                              ),
                              const SizedBox(width: 8),
                              ...categoryList.map(
                                (c) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(c),
                                    selected: _selectedCategory == c,
                                    selectedColor: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.12),
                                    labelStyle: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                    onSelected: (_) => setState(() {
                                      _selectedCategory = c;
                                    }),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Add Category',
                        onPressed: () => _showAddCategoryDialog(context),
                        icon: const Icon(Icons.add_box_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: products.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('No products in this category.'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => _showAddProductDialog(
                                  context,
                                  widget.productController,
                                  widget.onRefresh,
                                  prefillCategory: _selectedCategory,
                                ),
                                child: const Text('Add Product'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            final isLowStock = product.isLowStock;
                            return ListTile(
                              title: Text(
                                product.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: isLowStock
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isLowStock
                                          ? Theme.of(context).colorScheme.error
                                          : Theme.of(
                                              context,
                                            ).textTheme.titleMedium?.color,
                                    ),
                              ),
                              subtitle: Text(
                                'ID: ${product.id}\nQty: ${product.quantity} (min: ${product.minStock}), '
                                'Cost: ${formatCurrency(product.costPrice)}, '
                                'Sell: ${formatCurrency(product.sellingPrice)}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isLowStock)
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      child: Text(
                                        'LOW',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  PopupMenuButton(
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        onTap: () => _showEditProductDialog(
                                          context,
                                          widget.productController,
                                          product,
                                          widget.onRefresh,
                                        ),
                                        child: const Text('Edit'),
                                      ),
                                      PopupMenuItem(
                                        onTap: () {
                                          widget.productController
                                              .deleteProduct(product.id);
                                          widget.onRefresh();
                                        },
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddProductDialog(
          context,
          widget.productController,
          widget.onRefresh,
          prefillCategory: _selectedCategory,
        ),
        tooltip: 'Add Product',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Category name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                // After adding a category, open add product dialog with prefilled category
                Navigator.pop(context);
                setState(() {
                  _selectedCategory = name;
                });
                _showAddProductDialog(
                  context,
                  widget.productController,
                  widget.onRefresh,
                  prefillCategory: name,
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog(
    BuildContext context,
    ProductController controller,
    Function() onRefresh, {
    String? prefillCategory,
  }) {
    final initial = prefillCategory != null
        ? ProductModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: '',
            quantity: 0,
            costPrice: 0.0,
            sellingPrice: 0.0,
            category: prefillCategory,
            minStock: 0,
          )
        : null;

    showDialog(
      context: context,
      builder: (context) => _ProductFormDialog(
        initialProduct: initial,
        onSave: (product) async {
          await controller.addProduct(product);
          if (context.mounted) {
            Navigator.pop(context);
            onRefresh();
          }
        },
      ),
    );
  }

  void _showEditProductDialog(
    BuildContext context,
    ProductController controller,
    ProductModel product,
    Function() onRefresh,
  ) {
    showDialog(
      context: context,
      builder: (context) => _ProductFormDialog(
        initialProduct: product,
        onSave: (updated) async {
          await controller.updateProduct(updated);
          if (context.mounted) {
            Navigator.pop(context);
            onRefresh();
          }
        },
      ),
    );
  }
}

class InventoryAlertsScreen extends StatefulWidget {
  final ProductController? productController;
  final SaleRepository? saleRepository;
  final VoidCallback onBack;

  const InventoryAlertsScreen({
    this.productController,
    this.saleRepository,
    required this.onBack,
    super.key,
  });

  @override
  State<InventoryAlertsScreen> createState() => _InventoryAlertsScreenState();
}

class _InventoryAlertsScreenState extends State<InventoryAlertsScreen> {
  final List<String> _tabs = [
    'LOW STOCK',
    'EXPIRATION',
    'SLOW-MOVING',
    'TOP SOLD',
    'SUGGESTIONS',
  ];
  int _selectedTab = 0;
  String _selectedPeriod = 'THIS WEEK';
  String _searchTerm = '';
  late Future<List<Sale>> _salesFuture;

  @override
  void initState() {
    super.initState();
    _salesFuture =
        widget.saleRepository?.getAllSales() ?? Future<List<Sale>>.value([]);
  }

  List<ProductModel> _getLowStockProducts(List<ProductModel> products) {
    return products.where((product) => product.isLowStock).toList();
  }

  List<ProductModel> _filterProductsByName(
    List<ProductModel> products,
    String searchTerm,
  ) {
    final term = searchTerm.trim().toLowerCase();
    if (term.isEmpty) return products;
    return products
        .where((product) => product.name.toLowerCase().contains(term))
        .toList();
  }

  Widget _buildAlertBanner({
    required Color color,
    required String title,
    required IconData icon,
    required Widget trailing,
  }) {
    return Container(
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildProductCard(
    ProductModel product, {
    String? subtitle,
    String? status,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.image_outlined,
                color: theme.colorScheme.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (product.category.trim().isNotEmpty)
                    Text(product.category, style: theme.textTheme.bodySmall),
                  if (subtitle != null)
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  if (status != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        status,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: product.quantity <= 0
                              ? Colors.red
                              : Colors.orange,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'QTY: ${product.quantity}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (product.minStock > 0)
                  Text(
                    'MIN: ${product.minStock}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockTab(List<ProductModel> products) {
    final lowStockProducts = _filterProductsByName(
      _getLowStockProducts(products),
      _searchTerm,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildAlertBanner(
            color: Colors.red,
            icon: Icons.warning_amber_rounded,
            title:
                '${lowStockProducts.length} products are running low on stock',
            trailing: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              hintText: 'search product',
              prefixIcon: Icon(Icons.search),
              filled: true,
            ),
            onChanged: (value) => setState(() => _searchTerm = value),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: lowStockProducts.isEmpty
                ? const Center(
                    child: Text(
                      'No low-stock products found. Add products and set a minimum stock level to see alerts.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView(
                    children: lowStockProducts
                        .map(
                          (product) => _buildProductCard(
                            product,
                            subtitle: product.category.isEmpty
                                ? 'Category not set'
                                : product.category,
                            status: product.quantity <= 0
                                ? 'OUT OF STOCK'
                                : 'LOW STOCK',
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpirationTab(List<ProductModel> products) {
    const expirationMessage =
        'No expiration tracking data is available in the current project. '
        'Please use the dedicated expiration management feature to maintain '
        'batch and expiry records before inventory alerts can monitor them.';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildAlertBanner(
            color: Colors.amber,
            icon: Icons.calendar_today_rounded,
            title: '0 products are expiring soon or already expired',
            trailing: const Icon(
              Icons.info_outline_rounded,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    expirationMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlowMovingTab(List<ProductModel> products) {
    final salesFuture = _salesFuture;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          FutureBuilder<List<Sale>>(
            future: salesFuture,
            builder: (context, snapshot) {
              final count = snapshot.hasData
                  ? _filterProductsByName(
                      products.where((product) {
                        if (!snapshot.hasData) return false;
                        final matchingSales = snapshot.data!
                            .where((sale) => sale.productId == product.id)
                            .toList();
                        if (matchingSales.isEmpty) return false;
                        final lastDate = matchingSales
                            .reduce(
                              (a, b) => a.saleDate.isAfter(b.saleDate) ? a : b,
                            )
                            .saleDate;
                        final daysSince = DateTime.now()
                            .difference(lastDate)
                            .inDays;
                        return daysSince >= 30;
                      }).toList(),
                      _searchTerm,
                    ).length
                  : 0;

              return _buildAlertBanner(
                color: Colors.purple,
                icon: Icons.schedule_rounded,
                title: '$count products have not been sold for a while',
                trailing: const Icon(
                  Icons.schedule_rounded,
                  color: Colors.purple,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              hintText: 'search product',
              prefixIcon: Icon(Icons.search),
              filled: true,
            ),
            onChanged: (value) => setState(() => _searchTerm = value),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Sale>>(
              future: salesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No sales history found.'));
                }

                final salesList = snapshot.data!;
                final items = products.where((product) {
                  final matchingSales = salesList
                      .where((sale) => sale.productId == product.id)
                      .toList();
                  if (matchingSales.isEmpty) return false;
                  final lastDate = matchingSales
                      .reduce((a, b) => a.saleDate.isAfter(b.saleDate) ? a : b)
                      .saleDate;
                  final daysSince = DateTime.now().difference(lastDate).inDays;
                  return daysSince >= 30;
                }).toList();

                final displayed = _filterProductsByName(items, _searchTerm);
                return displayed.isEmpty
                    ? const Center(
                        child: Text('No slow-moving products found.'),
                      )
                    : ListView(
                        children: displayed.map((product) {
                          final matchingSales = salesList
                              .where((sale) => sale.productId == product.id)
                              .toList();
                          final lastDate = matchingSales
                              .reduce(
                                (a, b) =>
                                    a.saleDate.isAfter(b.saleDate) ? a : b,
                              )
                              .saleDate;
                          final daysSince = DateTime.now()
                              .difference(lastDate)
                              .inDays;
                          return _buildProductCard(
                            product,
                            subtitle:
                                'Last sold: ${lastDate.toLocal().toString().split(' ')[0]}',
                            status: 'SLOW-MOVING • $daysSince DAYS',
                          );
                        }).toList(),
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSoldTab(List<ProductModel> products) {
    final periodMap = {'THIS DAY': 1, 'THIS WEEK': 7, 'THIS MONTH': 30};
    final selectedWindow = periodMap[_selectedPeriod] ?? 7;

    final salesFuture = _salesFuture;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Your top selling products in this period.',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: DropdownButton<String>(
              value: _selectedPeriod,
              items: periodMap.keys
                  .map(
                    (period) =>
                        DropdownMenuItem(value: period, child: Text(period)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedPeriod = value);
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<Sale>>(
              future: salesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No sales data available.'));
                }

                final sales = snapshot.data!;
                final byProduct = <String, int>{};
                final threshold = DateTime.now().subtract(
                  Duration(days: selectedWindow),
                );
                for (final sale in sales) {
                  if (sale.saleDate.isBefore(threshold)) continue;
                  byProduct[sale.productId] =
                      (byProduct[sale.productId] ?? 0) + sale.quantitySold;
                }

                final ordered = byProduct.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));

                if (ordered.isEmpty) {
                  return const Center(
                    child: Text('No sales in the selected period.'),
                  );
                }

                final matches = ordered.map((entry) {
                  final product = products.firstWhere(
                    (item) => item.id == entry.key,
                    orElse: () => ProductModel(
                      id: entry.key,
                      name: 'Unknown product',
                      quantity: 0,
                      costPrice: 0,
                      sellingPrice: 0,
                    ),
                  );
                  return MapEntry(product, entry.value);
                }).toList();

                return ListView(
                  children: matches
                      .map(
                        (entry) => _buildProductCard(
                          entry.key,
                          subtitle: entry.key.category.isEmpty
                              ? 'Category not set'
                              : entry.key.category,
                          status: 'SOLD: ${entry.value} UNITS',
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsTab(List<ProductModel> products) {
    final lowStockProducts = _getLowStockProducts(products);
    final suggestions = lowStockProducts.isEmpty
        ? <ProductModel>[]
        : lowStockProducts.take(3).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildAlertBanner(
            color: Colors.green,
            icon: Icons.lightbulb_outline_rounded,
            title: 'Smart suggestions',
            trailing: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: suggestions.isEmpty
                ? const Center(
                    child: Text('No suggestions available right now.'),
                  )
                : ListView(
                    children: suggestions
                        .map(
                          (product) => _buildProductCard(
                            product,
                            subtitle:
                                'Restock recommended before level falls below minimum stock.',
                            status: 'REORDER SUGGESTED',
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.productController?.state;
    final products = state?.products ?? const <ProductModel>[];
    final screens = [
      _buildLowStockTab(products),
      _buildExpirationTab(products),
      _buildSlowMovingTab(products),
      _buildTopSoldTab(products),
      _buildSuggestionsTab(products),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Text('Inventory Alerts'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Add product',
            icon: const Icon(Icons.add_box_outlined),
            onPressed: widget.productController == null
                ? null
                : () async {
                    await showDialog<void>(
                      context: context,
                      builder: (dialogContext) => _ProductFormDialog(
                        onSave: (product) async {
                          await widget.productController!.addProduct(product);
                          if (!mounted || !dialogContext.mounted) return;
                          Navigator.of(dialogContext).pop();
                          final error = widget.productController!.state.error;
                          if (error != null) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text('Could not save product: $error'),
                              ),
                            );
                            return;
                          }
                          setState(() {});
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(content: Text('Product saved.')),
                          );
                        },
                      ),
                    );
                  },
          ),
          IconButton(
            tooltip: 'Refresh inventory alerts',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: widget.productController == null
                ? null
                : () async {
                    final productController = widget.productController!;
                    await productController.loadProducts();
                    if (!mounted) return;
                    setState(() {
                      _salesFuture =
                          widget.saleRepository?.getAllSales() ??
                          Future<List<Sale>>.value([]);
                    });
                  },
          ),
        ],
      ),
      body: state?.error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load inventory: ${state!.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : DefaultTabController(
              length: _tabs.length,
              child: Column(
                children: [
                  TabBar(
                    isScrollable: true,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.black87,
                    indicator: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
                    onTap: (index) => setState(() => _selectedTab = index),
                  ),
                  Expanded(
                    child: IndexedStack(index: _selectedTab, children: screens),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProductFormDialog extends StatefulWidget {
  final ProductModel? initialProduct;
  final Function(ProductModel) onSave;

  const _ProductFormDialog({this.initialProduct, required this.onSave});

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  late TextEditingController _idController;
  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _costPriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _categoryController;
  late TextEditingController _minStockController;

  @override
  void initState() {
    super.initState();
    final product = widget.initialProduct;
    _idController = TextEditingController(text: product?.id ?? '');
    _nameController = TextEditingController(text: product?.name ?? '');
    _quantityController = TextEditingController(
      text: product?.quantity.toString() ?? '0',
    );
    _costPriceController = TextEditingController(
      text: product?.costPrice.toString() ?? '0.0',
    );
    _sellingPriceController = TextEditingController(
      text: product?.sellingPrice.toString() ?? '0.0',
    );
    _categoryController = TextEditingController(text: product?.category ?? '');
    _minStockController = TextEditingController(
      text: product?.minStock.toString() ?? '0',
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _categoryController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialProduct == null ? 'Add Product' : 'Edit Product',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _idController,
              decoration: const InputDecoration(labelText: 'Product ID'),
              enabled: widget.initialProduct == null,
            ),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _costPriceController,
              decoration: const InputDecoration(
                labelText: 'Cost Price',
                prefixText: '₱ ',
              ),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _sellingPriceController,
              decoration: const InputDecoration(
                labelText: 'Selling Price',
                prefixText: '₱ ',
              ),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            TextField(
              controller: _minStockController,
              decoration: const InputDecoration(labelText: 'Min Stock'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _nameController.text.trim();
            final quantity = int.tryParse(_quantityController.text);
            final costPrice = double.tryParse(_costPriceController.text);
            final sellingPrice = double.tryParse(_sellingPriceController.text);
            final minStock = int.tryParse(_minStockController.text);

            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter a product name.')),
              );
              return;
            }
            if (quantity == null || quantity < 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Enter a valid non-negative quantity.'),
                ),
              );
              return;
            }
            if (costPrice == null ||
                !costPrice.isFinite ||
                costPrice < 0 ||
                sellingPrice == null ||
                !sellingPrice.isFinite ||
                sellingPrice < 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Enter valid non-negative prices.'),
                ),
              );
              return;
            }
            if (minStock == null || minStock < 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Enter a valid non-negative minimum stock.'),
                ),
              );
              return;
            }

            final product = ProductModel(
              id: _idController.text.trim().isEmpty
                  ? DateTime.now().millisecondsSinceEpoch.toString()
                  : _idController.text.trim(),
              name: name,
              quantity: quantity,
              costPrice: costPrice,
              sellingPrice: sellingPrice,
              category: _categoryController.text.trim(),
              minStock: minStock,
            );
            widget.onSave(product);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
