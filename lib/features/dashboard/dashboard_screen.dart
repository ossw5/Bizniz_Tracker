import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../legacy_main.dart' as legacy;
import '../inventory_alerts_and_smart_suggestions/screens/inventory_alerts_screen.dart';
import '../products/domain/product.dart';
import '../products/presentation/controllers.dart';
import '../sales/domain/sale_repository.dart';
import '../sales_management/screens/sales_in_one_screen.dart';
import 'widgets/quick_action_button.dart';
import 'widgets/recent_transaction_item.dart';
import 'widgets/summary_card.dart';

class DashboardScreen extends StatefulWidget {
  final ProductController? productController;
  final SaleRepository? saleRepository;

  const DashboardScreen({
    super.key,
    this.productController,
    this.saleRepository,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  bool _showInventoryAlerts = false;
  int _inventoryAlertsInitialTab = 0;

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.inventory_2_outlined),
      selectedIcon: Icon(Icons.inventory_2_rounded),
      label: 'Inventory',
    ),
    NavigationDestination(
      icon: Icon(Icons.point_of_sale_outlined),
      selectedIcon: Icon(Icons.point_of_sale_rounded),
      label: 'Sales',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_outlined),
      selectedIcon: Icon(Icons.bar_chart_rounded),
      label: 'Reports',
    ),
    NavigationDestination(
      icon: Icon(Icons.more_horiz_outlined),
      selectedIcon: Icon(Icons.more_horiz_rounded),
      label: 'More',
    ),
  ];

  void _handleNavigate(int index) {
    setState(() {
      _currentIndex = index;
      if (index != 1) _showInventoryAlerts = false;
    });
  }

  void _openInventoryAlerts({int initialTabIndex = 0}) {
    setState(() {
      _currentIndex = 1;
      _showInventoryAlerts = true;
      _inventoryAlertsInitialTab = initialTabIndex;
    });
  }

  void _closeInventoryAlerts() {
    setState(() {
      _showInventoryAlerts = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeDashboardPage(
        onNavigate: (index) => _handleNavigate(index),
        products: widget.productController?.state.products ?? const [],
        onOpenInventoryAlerts: () => _openInventoryAlerts(),
        onOpenSuggestions: () => _openInventoryAlerts(initialTabIndex: 4),
      ),
      _showInventoryAlerts
          ? InventoryAlertsScreen(
              productController: widget.productController,
              saleRepository: widget.saleRepository,
              onBack: _closeInventoryAlerts,
              initialTabIndex: _inventoryAlertsInitialTab,
            )
          : widget.productController == null
          ? _InventoryUnavailablePage(
              onOpenInventoryAlerts: _openInventoryAlerts,
            )
          : legacy.InventoryManagementScreen(
              productController: widget.productController!,
              onRefresh: () => setState(() {}),
              onOpenInventoryAlerts: _openInventoryAlerts,
            ),
      widget.productController == null || widget.saleRepository == null
          ? const _SalesUnavailablePage()
          : SalesInOneScreen(
              productController: widget.productController!,
              saleRepository: widget.saleRepository!,
            ),
      const _PlaceholderPage(
        title: 'Reports',
        message:
            'Business reports will be available in a future development step.',
      ),
      const _PlaceholderPage(
        title: 'More',
        message:
            'Expense tracking, customer credit, and settings are reserved for '
            'future development.',
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          _handleNavigate(index);
        },
        destinations: _destinations,
      ),
    );
  }
}

class _InventoryAlertsPage extends StatefulWidget {
  final VoidCallback onBack;

  const _InventoryAlertsPage({required this.onBack});

  @override
  State<_InventoryAlertsPage> createState() => _InventoryAlertsPageState();
}

class _InventoryAlertsPageState extends State<_InventoryAlertsPage> {
  final List<String> _mainTabs = [
    'LOW STOCK',
    'EXPIRATION',
    'SLOW-MOVING',
    'TOP SOLD',
    'SUGGESTIONS',
  ];

  final List<String> _secondaryTabs = [
    'SLOW-MOVING',
    'FAST MOVING',
    'EXPIRATION',
  ];

  int _selectedMainTab = 0;
  int _selectedSecondaryTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: widget.onBack,
        ),
        title: const Text('Inventory Alerts'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Column(
          children: [
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _mainTabs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final selected = index == _selectedMainTab;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedMainTab = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.forestGreen
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _mainTabs[index],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? AppColors.white
                              : AppColors.charcoal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _secondaryTabs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final selected = index == _selectedSecondaryTab;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedSecondaryTab = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.forestGreen
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _secondaryTabs[index],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? AppColors.white
                              : AppColors.charcoal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedMainTab == 0
                                ? '5 products are running low on stock'
                                : _selectedMainTab == 1
                                ? '3 products are expiring soon or already expired'
                                : _selectedMainTab == 2
                                ? '3 products have not been sold for a while'
                                : _selectedMainTab == 3
                                ? 'Your top selling products in this period.'
                                : 'Restock rice and canned goods before weekend demand peaks.',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'search product',
                      filled: true,
                      fillColor: AppColors.white,
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._buildAlertCards(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAlertCards() {
    final cards = <Widget>[];
    final label = _selectedMainTab == 0
        ? 'LOW STOCK'
        : _selectedMainTab == 1
        ? 'EXPIRING'
        : _selectedMainTab == 2
        ? 'SLOW-MOVING'
        : _selectedMainTab == 3
        ? 'TOP SOLD'
        : 'SUGGESTION';

    for (var i = 0; i < 3; i++) {
      cards.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.forestGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.image_outlined,
                  color: AppColors.forestGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '3x Sardines 250g',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedMainTab == 4 ? 'Suggested action' : 'Category',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.grey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _selectedMainTab == 4
                            ? AppColors.forestGreen
                            : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'QTY: 12',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.charcoal,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return cards;
  }
}

class _HomeDashboardPage extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  final List<ProductModel> products;
  final VoidCallback onOpenInventoryAlerts;
  final VoidCallback onOpenSuggestions;

  const _HomeDashboardPage({
    required this.onNavigate,
    required this.products,
    required this.onOpenInventoryAlerts,
    required this.onOpenSuggestions,
  });

  @override
  State<_HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<_HomeDashboardPage> {
  String _salesPeriod = 'Daily';

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formattedDate = '${_monthName(now.month)} ${now.day}, ${now.year}';
    final lowStockCount = widget.products
        .where((product) => product.isLowStock)
        .length;

    final summaryCards = [
      SummaryCard(
        title: 'Today\'s Sales',
        value: '₱5,250.00',
        icon: Icons.payments_rounded,
        accent: AppColors.freshGreen,
        note: 'Sample data',
      ),
      SummaryCard(
        title: 'Today\'s Expenses',
        value: '₱850.00',
        icon: Icons.receipt_long_rounded,
        accent: AppColors.warning,
        note: 'Sample data',
      ),
      SummaryCard(
        title: 'Estimated Profit',
        value: '₱1,450.00',
        icon: Icons.trending_up_rounded,
        accent: AppColors.forestGreen,
        note: 'Before overhead',
      ),
      SummaryCard(
        title: 'Total Products',
        value: '${widget.products.length}',
        icon: Icons.inventory_2_rounded,
        accent: AppColors.grey,
        note: 'In inventory',
      ),
      SummaryCard(
        title: 'Low-Stock Products',
        value: '$lowStockCount',
        icon: Icons.warning_amber_rounded,
        accent: AppColors.warning,
        note: 'Needs restock',
      ),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, formattedDate, _showMessage),
            const SizedBox(height: 18),
            _buildSectionTitle('Business Overview'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: summaryCards,
            ),
            const SizedBox(height: 22),
            _buildSectionTitle('Quick Actions'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.15,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                QuickActionButton(
                  icon: Icons.add_box_rounded,
                  label: 'Add Product',
                  onTap: () => widget.onNavigate(1),
                ),
                QuickActionButton(
                  icon: Icons.point_of_sale_rounded,
                  label: 'Record Sale',
                  onTap: () => widget.onNavigate(2),
                ),
                QuickActionButton(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Scan Barcode',
                  onTap: () {
                    widget.onNavigate(2);
                    _showMessage(
                      context,
                      'Barcode scanning is not implemented yet.',
                    );
                  },
                ),
                QuickActionButton(
                  icon: Icons.wallet_rounded,
                  label: 'Add Expense',
                  onTap: () => widget.onNavigate(4),
                ),
                QuickActionButton(
                  icon: Icons.people_alt_rounded,
                  label: 'Customer Credit',
                  onTap: () => widget.onNavigate(4),
                ),
                QuickActionButton(
                  icon: Icons.insert_chart_outlined_rounded,
                  label: 'View Reports',
                  onTap: () => widget.onNavigate(3),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _buildSalesOverviewCard(context),
            const SizedBox(height: 22),
            _buildInventoryAlertsCard(context, lowStockCount),
            const SizedBox(height: 22),
            _buildPerformanceCard(),
            const SizedBox(height: 22),
            _buildSuggestionsCard(),
            const SizedBox(height: 22),
            _buildRecentTransactionsCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String formattedDate,
    void Function(BuildContext context, String message) showMessage,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.forestGreen.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.forestGreen,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Bizniz Tracker',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.charcoal,
                      ),
                    ),
                    Text(
                      'Inventory & Sales Manager',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => showMessage(
                      context,
                      'Notifications feature is being developed.',
                    ),
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: AppColors.charcoal,
                    ),
                  ),
                  IconButton(
                    onPressed: () => widget.onNavigate(4),
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: AppColors.charcoal,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Good day, Business Owner!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Operational overview · $formattedDate',
                    style: TextStyle(fontSize: 12, color: AppColors.grey),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 16,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Sample data',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.charcoal,
      ),
    );
  }

  Widget _buildSalesOverviewCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sales Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.charcoal,
                ),
              ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Daily', label: Text('Daily')),
                  ButtonSegment(value: 'Weekly', label: Text('Weekly')),
                  ButtonSegment(value: 'Monthly', label: Text('Monthly')),
                ],
                selected: {_salesPeriod},
                onSelectionChanged: (selection) {
                  setState(() => _salesPeriod = selection.first);
                },
                showSelectedIcon: false,
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _bar(40, AppColors.freshGreen),
                _bar(90, AppColors.forestGreen),
                _bar(65, AppColors.freshGreen),
                _bar(120, AppColors.forestGreen),
                _bar(83, AppColors.freshGreen),
                _bar(105, AppColors.forestGreen),
                _bar(140, AppColors.freshGreen),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Total sales',
                style: TextStyle(fontSize: 13, color: AppColors.grey),
              ),
              Text(
                '₱5,250.00',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Transactions',
                style: TextStyle(fontSize: 13, color: AppColors.grey),
              ),
              Text(
                '48 sales',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forestGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryAlertsCard(BuildContext context, int lowStockCount) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Inventory Alerts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.charcoal,
                ),
              ),
              TextButton(
                onPressed: widget.onOpenInventoryAlerts,
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _alertRow(
            'Low Stock',
            '$lowStockCount products',
            AppColors.warning,
            Icons.warning_amber_rounded,
          ),
          const Divider(),
          _alertRow(
            'Expiration tracking',
            'Not configured',
            AppColors.grey,
            Icons.event_busy_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Product Performance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _miniPerformanceColumn(
                  title: 'Frequently Sold',
                  items: const ['Rice', 'Canned Tuna', 'Coffee'],
                  values: const ['42 units', '31 units', '26 units'],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _miniPerformanceColumn(
                  title: 'Slow-Moving',
                  items: const ['Soap', 'Biscuits', 'Condiments'],
                  values: const ['8 units', '6 units', '4 units'],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Smart Suggestions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.onOpenSuggestions,
                child: const Text('View Suggestions'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Explore product-pairing ideas based on your recorded sales history.',
            style: TextStyle(color: AppColors.charcoal, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsCard(BuildContext context) {
    final transactions = [
      const RecentTransactionItem(
        receiptNumber: 'BZT-1045',
        date: 'Nov 03, 2026 • 09:20 AM',
        itemsCount: 6,
        total: '₱680.00',
        status: 'Paid',
        statusColor: AppColors.freshGreen,
      ),
      const RecentTransactionItem(
        receiptNumber: 'BZT-1042',
        date: 'Nov 03, 2026 • 08:46 AM',
        itemsCount: 3,
        total: '₱420.00',
        status: 'Pending',
        statusColor: AppColors.warning,
      ),
      const RecentTransactionItem(
        receiptNumber: 'BZT-1038',
        date: 'Nov 02, 2026 • 06:18 PM',
        itemsCount: 9,
        total: '₱1,250.00',
        status: 'Paid',
        statusColor: AppColors.freshGreen,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.charcoal,
                ),
              ),
              TextButton(
                onPressed: () => widget.onNavigate(2),
                child: const Text('View All Transactions'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(children: transactions),
        ],
      ),
    );
  }

  Widget _alertRow(String label, String value, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 12, color: AppColors.grey),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.grey),
        ],
      ),
    );
  }

  Widget _bar(double heightFactor, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: heightFactor,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniPerformanceColumn({
    required String title,
    required List<String> items,
    required List<String> values,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(items.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[index],
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.charcoal,
                          ),
                        ),
                        Text(
                          values[index],
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_upward_rounded,
                    color: AppColors.freshGreen,
                    size: 16,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}

class _InventoryUnavailablePage extends StatelessWidget {
  final VoidCallback onOpenInventoryAlerts;

  const _InventoryUnavailablePage({required this.onOpenInventoryAlerts});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Inventory Management'),
      actions: [
        TextButton(
          onPressed: onOpenInventoryAlerts,
          child: const Text('Inventory Alerts'),
        ),
      ],
    ),
    body: const Center(child: Text('Inventory data is unavailable.')),
  );
}

class _SalesUnavailablePage extends StatelessWidget {
  const _SalesUnavailablePage();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sales in One')),
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Sales is unavailable because inventory or sales storage '
          'has not been initialized.',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

class _PlaceholderPage extends StatelessWidget {
  final String title;
  final String message;

  const _PlaceholderPage({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.construction_rounded,
                    size: 52,
                    color: AppColors.forestGreen,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.charcoal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
