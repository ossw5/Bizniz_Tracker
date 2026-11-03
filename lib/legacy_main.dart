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
    setState(() => _currentIndex = index);
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
      _InventoryScreen(
        productController: _productController,
        onRefresh: _refresh,
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
class _InventoryScreen extends StatefulWidget {
  final ProductController productController;
  final Function() onRefresh;

  const _InventoryScreen({
    required this.productController,
    required this.onRefresh,
  });

  @override
  State<_InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<_InventoryScreen> {
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
                                ).colorScheme.primary.withOpacity(0.12),
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
                                    selectedColor: Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.12),
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
                            final isLowStock =
                                product.quantity < product.minStock;
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
            final product = ProductModel(
              id: _idController.text.isEmpty
                  ? DateTime.now().millisecondsSinceEpoch.toString()
                  : _idController.text,
              name: _nameController.text,
              quantity: int.tryParse(_quantityController.text) ?? 0,
              costPrice: double.tryParse(_costPriceController.text) ?? 0.0,
              sellingPrice:
                  double.tryParse(_sellingPriceController.text) ?? 0.0,
              category: _categoryController.text,
              minStock: int.tryParse(_minStockController.text) ?? 0,
            );
            widget.onSave(product);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
