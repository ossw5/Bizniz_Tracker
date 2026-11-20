import 'package:flutter/material.dart';

import '../../core/app_database.dart';
import '../../core/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../legacy_main.dart' as legacy;
import '../customer_credit_and_debit_tracking/screens/credit_debit_tracking_screen.dart';
import '../customer_credit_and_debit_tracking/services/credit_tracking_service.dart';
import '../expense_tracking/screens/expense_tracking_screen.dart';
import '../expense_tracking/services/expense_service.dart';
import '../inventory_alerts_and_smart_suggestions/services/inventory_alert_service.dart';
import '../inventory_alerts_and_smart_suggestions/screens/inventory_alerts_screen.dart';
import '../product_and_inventory_management/services/expiration_service.dart';
import '../products/domain/product.dart';
import '../products/presentation/controllers.dart';
import '../sales/domain/sale.dart';
import '../sales/domain/sale_repository.dart';
import '../sales_management/screens/sales_history_screen.dart';
import '../sales_management/screens/sales_in_one_screen.dart';
import '../reports/screens/reports_screen.dart';
import '../settings/controllers/app_settings_controller.dart';
import '../settings/services/local_backup_service.dart';
import '../settings/screens/settings_screen.dart';
import 'dashboard_data.dart';
import 'widgets/quick_action_button.dart';
import 'widgets/recent_transaction_item.dart';
import 'widgets/summary_card.dart';

class DashboardScreen extends StatefulWidget {
  final ProductController? productController;
  final SaleRepository? saleRepository;
  final AppDatabase? database;
  final AppSettingsController? settingsController;

  const DashboardScreen({
    super.key,
    this.productController,
    this.saleRepository,
    this.database,
    this.settingsController,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _showInventoryAlerts = false;
  int _inventoryAlertsInitialTab = 0;
  int _refreshVersion = 0;
  int _scanRequestVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() => _refreshVersion++);
    }
  }

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
      if (index == 0) _refreshVersion++;
      if (index != 1) _showInventoryAlerts = false;
    });
  }

  Future<void> _openExpenseTracking() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ExpenseTrackingScreen(
          saleRepository: widget.saleRepository,
          products: widget.productController?.state.products ?? const [],
          businessName: widget.settingsController?.profile.storeName ?? '',
          preparedBy: widget.settingsController?.profile.ownerName ?? '',
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _currentIndex = 0;
      _refreshVersion++;
    });
  }

  Future<void> _openCreditTracking() async {
    final controller = widget.productController;
    final repository = widget.saleRepository;
    if (controller == null || repository == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CreditDebitTrackingScreen(
          productController: controller,
          saleRepository: repository,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _currentIndex = 0;
      _refreshVersion++;
    });
  }

  Future<void> _openTransactions() async {
    final repository = widget.saleRepository;
    if (repository == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SalesHistoryScreen(
          saleRepository: repository,
          products: widget.productController?.state.products ?? const [],
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _currentIndex = 0;
      _refreshVersion++;
    });
  }

  void _scanBarcode() {
    setState(() {
      _currentIndex = 2;
      _scanRequestVersion++;
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
        productController: widget.productController,
        saleRepository: widget.saleRepository,
        refreshVersion: _refreshVersion,
        onOpenExpenses: _openExpenseTracking,
        onOpenCredit: _openCreditTracking,
        onOpenTransactions: _openTransactions,
        onScanBarcode: _scanBarcode,
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
              scanRequestVersion: _scanRequestVersion,
            ),
      ReportsScreen(
        saleRepository: widget.saleRepository,
        products: widget.productController?.state.products ?? const [],
        productController: widget.productController,
        businessName: widget.settingsController?.profile.storeName ?? '',
        preparedBy: widget.settingsController?.profile.ownerName ?? '',
      ),
      widget.settingsController == null
          ? const _PlaceholderPage(
              title: 'More',
              message: 'Settings are unavailable in this app instance.',
            )
          : SettingsScreen(
              controller: widget.settingsController!,
              backupService: widget.database == null
                  ? const LocalBackupService()
                  : LocalBackupService(database: widget.database),
              onDataRestored: widget.productController == null
                  ? null
                  : () => widget.productController!.loadProducts(),
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
                    Text(
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
                      style: TextStyle(fontSize: 12, color: AppColors.grey),
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
              Text(
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
  final ProductController? productController;
  final SaleRepository? saleRepository;
  final int refreshVersion;
  final VoidCallback onOpenExpenses;
  final VoidCallback onOpenCredit;
  final VoidCallback onOpenTransactions;
  final VoidCallback onScanBarcode;
  final VoidCallback onOpenInventoryAlerts;
  final VoidCallback onOpenSuggestions;

  const _HomeDashboardPage({
    required this.onNavigate,
    required this.products,
    required this.productController,
    required this.saleRepository,
    required this.refreshVersion,
    required this.onOpenExpenses,
    required this.onOpenCredit,
    required this.onOpenTransactions,
    required this.onScanBarcode,
    required this.onOpenInventoryAlerts,
    required this.onOpenSuggestions,
  });

  @override
  State<_HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<_HomeDashboardPage> {
  String _salesPeriod = 'Daily';
  late Future<DashboardData> _dashboardData;

  @override
  void initState() {
    super.initState();
    _dashboardData = _loadDashboardData();
  }

  @override
  void didUpdateWidget(covariant _HomeDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshVersion != widget.refreshVersion ||
        !identical(oldWidget.products, widget.products)) {
      _dashboardData = _loadDashboardData(refreshProducts: true);
    }
  }

  Future<DashboardData> _loadDashboardData({
    bool refreshProducts = false,
  }) async {
    final controller = widget.productController;
    var products = controller?.state.products ?? widget.products;
    if (refreshProducts && controller != null) {
      final result = await controller.repository.getAllProducts();
      products = result.fold(
        (failure) =>
            throw StateError('Could not refresh inventory: ${failure.message}'),
        (loadedProducts) => loadedProducts,
      );
    }
    final sales = await widget.saleRepository?.getAllSales() ?? const <Sale>[];
    final expenses = await const ExpenseService().loadAll();
    final expirationRecords = await const ExpirationService().loadAll(
      products: products,
    );
    final credits = await const CreditTrackingService().loadCredits();
    return DashboardData.fromRecords(
      products: products,
      sales: sales,
      expenses: expenses,
      expirationRecords: expirationRecords,
      creditAccounts: credits,
    );
  }

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
    return FutureBuilder<DashboardData>(
      future: _dashboardData,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 36),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load dashboard data: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _dashboardData = _loadDashboardData(
                            refreshProducts: true,
                          );
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const SafeArea(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildDashboardContent(context, snapshot.data!);
      },
    );
  }

  Widget _buildDashboardContent(BuildContext context, DashboardData data) {
    final now = data.calculatedAt;
    final formattedDate = '${_monthName(now.month)} ${now.day}, ${now.year}';
    final screenWidth = MediaQuery.sizeOf(context).width;
    final summaryColumns = screenWidth >= 900
        ? 4
        : screenWidth >= 600
        ? 3
        : 2;
    final quickActionColumns = screenWidth >= 600 ? 3 : 2;
    final summaryCardWidth =
        (screenWidth - 40 - 14 * (summaryColumns - 1)) / summaryColumns;
    final quickActionCardWidth =
        (screenWidth - 40 - 12 * (quickActionColumns - 1)) / quickActionColumns;

    final summaryCards = [
      SummaryCard(
        title: 'Today\'s Sales',
        value: formatAppCurrency(data.todaySales),
        icon: Icons.payments_rounded,
        accent: AppColors.freshGreen,
        note: 'Completed sales today',
      ),
      SummaryCard(
        title: 'Today\'s Expenses',
        value: formatAppCurrency(data.todayExpenses),
        icon: Icons.receipt_long_rounded,
        accent: AppColors.warning,
        note: 'Recorded today',
      ),
      SummaryCard(
        title: 'Estimated Profit',
        value: data.estimatedProfit == null
            ? 'Unavailable'
            : formatAppCurrency(data.estimatedProfit!),
        icon: Icons.trending_up_rounded,
        accent: AppColors.forestGreen,
        note: data.estimatedProfit == null
            ? 'Missing product cost data'
            : 'After product costs and expenses',
      ),
      SummaryCard(
        title: 'Total Products',
        value: '${data.totalProducts}',
        icon: Icons.inventory_2_rounded,
        accent: AppColors.grey,
        note: 'In inventory',
      ),
      SummaryCard(
        title: 'Low-Stock Products',
        value: '${data.lowStockProductCount}',
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
              crossAxisCount: summaryColumns,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: (summaryCardWidth / 185)
                  .clamp(0.68, 1.8)
                  .toDouble(),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: summaryCards,
            ),
            const SizedBox(height: 22),
            _buildSectionTitle('Quick Actions'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: quickActionColumns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: (quickActionCardWidth / 138)
                  .clamp(0.85, 1.9)
                  .toDouble(),
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
                  onTap: widget.onScanBarcode,
                ),
                QuickActionButton(
                  icon: Icons.wallet_rounded,
                  label: 'Add Expense',
                  onTap: widget.onOpenExpenses,
                ),
                QuickActionButton(
                  icon: Icons.people_alt_rounded,
                  label: 'Customer Credit',
                  onTap: widget.onOpenCredit,
                ),
                QuickActionButton(
                  icon: Icons.insert_chart_outlined_rounded,
                  label: 'View Reports',
                  onTap: () => widget.onNavigate(3),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _buildSalesOverviewCard(context, data),
            const SizedBox(height: 22),
            _buildInventoryAlertsCard(context, data),
            const SizedBox(height: 22),
            _buildPerformanceCard(data),
            const SizedBox(height: 22),
            _buildSuggestionsCard(data),
            const SizedBox(height: 22),
            _buildRecentTransactionsCard(context, data),
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
    final compact = MediaQuery.sizeOf(context).width < 380;
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: AppColors.forestGreen,
        borderRadius: BorderRadius.circular(24),
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
                width: compact ? 44 : 48,
                height: compact ? 44 : 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              SizedBox(width: compact ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bizniz Tracker',
                      style: TextStyle(
                        fontSize: compact ? 18 : 21,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Inventory & Sales Manager',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 38,
                      height: 40,
                    ),
                    onPressed: () => showMessage(
                      context,
                      'Notifications feature is being developed.',
                    ),
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 38,
                      height: 40,
                    ),
                    onPressed: () => widget.onNavigate(4),
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good day, Business Owner!',
                      style: TextStyle(
                        fontSize: compact ? 14 : 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Operational overview · $formattedDate',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 7 : 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 16,
                      color: AppColors.gold,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Live local data',
                      style: TextStyle(
                        fontSize: compact ? 10 : 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.charcoal,
      ),
    );
  }

  Widget _buildSalesOverviewCard(BuildContext context, DashboardData data) {
    final compact = MediaQuery.sizeOf(context).width < 380;
    final selectedPeriod = switch (_salesPeriod) {
      'Weekly' => DashboardSalesPeriod.weekly,
      'Monthly' => DashboardSalesPeriod.monthly,
      _ => DashboardSalesPeriod.daily,
    };
    final buckets = data.salesBuckets(selectedPeriod);
    final periodTransactions = data.transactionsFor(selectedPeriod);
    final salesTotal = periodTransactions.fold<double>(
      0,
      (total, transaction) => total + transaction.total,
    );
    final maximumBucketTotal = buckets.fold<double>(
      0,
      (maximum, bucket) => bucket.total > maximum ? bucket.total : maximum,
    );
    final periodSelector = compact
        ? SizedBox(
            width: 96,
            child: DropdownButton<String>(
              value: _salesPeriod,
              isDense: true,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
              ],
              onChanged: (period) {
                if (period != null) setState(() => _salesPeriod = period);
              },
            ),
          )
        : SegmentedButton<String>(
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
          );
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
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
              Expanded(
                child: Text(
                  'Sales Overview',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 16 : 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
              ),
              if (compact) const SizedBox(width: 8),
              periodSelector,
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 166,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < buckets.length; index++)
                  Expanded(
                    child: Tooltip(
                      message:
                          '${buckets[index].label}: '
                          '${formatAppCurrency(buckets[index].total)}',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  width: double.infinity,
                                  height: maximumBucketTotal == 0
                                      ? 4
                                      : 8 +
                                            112 *
                                                buckets[index].total /
                                                maximumBucketTotal,
                                  decoration: BoxDecoration(
                                    color: index.isEven
                                        ? AppColors.freshGreen
                                        : AppColors.forestGreen,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              buckets[index].label,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 9,
                                color: AppColors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Total sales',
                  style: TextStyle(fontSize: 13, color: AppColors.grey),
                ),
              ),
              Flexible(
                child: Text(
                  formatAppCurrency(salesTotal),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 17 : 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Transactions',
                  style: TextStyle(fontSize: 13, color: AppColors.grey),
                ),
              ),
              Flexible(
                child: Text(
                  '${periodTransactions.length} transactions',
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forestGreen,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryAlertsCard(BuildContext context, DashboardData data) {
    final compact = MediaQuery.sizeOf(context).width < 380;
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
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
              Expanded(
                child: Text(
                  'Inventory Alerts',
                  style: TextStyle(
                    fontSize: compact ? 16 : 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.onOpenInventoryAlerts,
                style: compact
                    ? TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      )
                    : null,
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _alertRow(
            'Low Stock',
            '${data.lowStockProductCount} products',
            AppColors.warning,
            Icons.warning_amber_rounded,
          ),
          const Divider(),
          _alertRow(
            'Expiration tracking',
            data.expirationRecords.isEmpty
                ? 'No expiration batches recorded'
                : '${data.nearingExpirationCount} near expiry · '
                      '${data.expiredCount} expired',
            data.expiredCount > 0
                ? AppColors.warning
                : data.nearingExpirationCount > 0
                ? AppColors.gold
                : AppColors.grey,
            data.expiredCount > 0 || data.nearingExpirationCount > 0
                ? Icons.event_busy_rounded
                : Icons.event_available_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(DashboardData data) {
    final compact = MediaQuery.sizeOf(context).width < 380;
    const alertService = InventoryAlertService();
    final frequentlySold = alertService
        .topSellingProducts(
          data.products,
          data.sales,
          period: const Duration(days: 30),
          now: data.calculatedAt,
        )
        .take(3)
        .toList();
    final slowMoving = alertService
        .slowMovingProducts(data.products, data.sales, now: data.calculatedAt)
        .take(3)
        .toList();
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
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
                  items: [for (final entry in frequentlySold) entry.key.name],
                  values: [
                    for (final entry in frequentlySold)
                      '${entry.value} units · 30 days',
                  ],
                  emptyMessage: 'No sales recorded in the last 30 days.',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _miniPerformanceColumn(
                  title: 'Slow-Moving',
                  items: [for (final product in slowMoving) product.name],
                  values: List.filled(slowMoving.length, 'No sale in 30+ days'),
                  emptyMessage:
                      'No products with older sales history qualify yet.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsCard(DashboardData data) {
    final compact = MediaQuery.sizeOf(context).width < 380;
    final pairings = const InventoryAlertService()
        .frequentProductPairs(data.products, data.sales)
        .take(3)
        .toList();
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
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
              Expanded(
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
                style: compact
                    ? TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      )
                    : null,
                child: const Text('View Suggestions'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (pairings.isEmpty)
            Text(
              'More sales history is needed. A product pair must appear '
              'together in at least two transactions before a suggestion is shown.',
              style: TextStyle(color: AppColors.charcoal, height: 1.5),
            )
          else
            ...pairings.map(
              (pair) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shopping_basket_outlined,
                      size: 18,
                      color: AppColors.forestGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${pair.first.name} + ${pair.second.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.charcoal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${pair.transactionsTogether}×',
                      style: const TextStyle(
                        color: AppColors.forestGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsCard(
    BuildContext context,
    DashboardData data,
  ) {
    final compact = MediaQuery.sizeOf(context).width < 380;
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          if (compact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent Transactions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: widget.onOpenTransactions,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('View All Transactions'),
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Transactions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
                TextButton(
                  onPressed: widget.onOpenTransactions,
                  child: const Text('View All Transactions'),
                ),
              ],
            ),
          const SizedBox(height: 8),
          if (data.recentTransactions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No recorded transactions yet.',
                textAlign: TextAlign.center,
              ),
            )
          else
            Column(
              children: [
                for (final transaction in data.recentTransactions)
                  RecentTransactionItem(
                    receiptNumber: transaction.receiptNumber,
                    date:
                        '${MaterialLocalizations.of(context).formatMediumDate(transaction.date)} · '
                        '${TimeOfDay.fromDateTime(transaction.date).format(context)}',
                    itemsCount: transaction.items.fold<int>(
                      0,
                      (count, item) => count + item.quantitySold,
                    ),
                    total: formatAppCurrency(transaction.total),
                    status: data.isTransactionPaid(transaction)
                        ? 'Paid'
                        : transaction.amountPaid > 0
                        ? 'Partial'
                        : 'Pending',
                    statusColor: data.isTransactionPaid(transaction)
                        ? AppColors.freshGreen
                        : AppColors.warning,
                  ),
              ],
            ),
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 12, color: AppColors.grey),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.grey),
        ],
      ),
    );
  }

  Widget _miniPerformanceColumn({
    required String title,
    required List<String> items,
    required List<String> values,
    required String emptyMessage,
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
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              emptyMessage,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.grey,
                height: 1.4,
              ),
            )
          else
            ...List.generate(items.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      items[index],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoal,
                      ),
                    ),
                    Text(
                      values[index],
                      style: TextStyle(fontSize: 11, color: AppColors.grey),
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
                    style: TextStyle(
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
