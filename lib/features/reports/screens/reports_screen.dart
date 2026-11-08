import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../customer_credit_and_debit_tracking/screens/credit_debit_tracking_screen.dart';
import '../../expense_tracking/screens/expense_tracking_screen.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/controllers.dart';
import '../../sales/domain/sale.dart';
import '../../sales/domain/sale_repository.dart';
import '../../sales_management/models/sales_transaction_record.dart';
import '../../sales_management/screens/sales_summary_screen.dart';

class ReportsScreen extends StatefulWidget {
  final SaleRepository? saleRepository;
  final List<ProductModel> products;
  final ProductController? productController;

  const ReportsScreen({
    super.key,
    required this.saleRepository,
    this.products = const <ProductModel>[],
    this.productController,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<List<Sale>> _salesFuture;

  @override
  void initState() {
    super.initState();
    _salesFuture = _loadSales();
  }

  Future<List<Sale>> _loadSales() {
    final repository = widget.saleRepository;
    if (repository == null) {
      return Future<List<Sale>>.error(
        StateError('Sales data is not connected to reports.'),
      );
    }
    return repository.getAllSales();
  }

  Future<void> _refresh() async {
    setState(() => _salesFuture = _loadSales());
    await _salesFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            tooltip: 'Refresh reports',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<Sale>>(
        future: _salesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ReportError(error: snapshot.error!, onRetry: _refresh);
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final transactions = SalesTransactionRecord.groupSales(
            snapshot.data ?? const <Sale>[],
          );
          return RefreshIndicator(
            onRefresh: _refresh,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SalesSummaryPreview(
                          transactions: transactions,
                          onViewAll: widget.saleRepository == null
                              ? null
                              : () => Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder: (_) => SalesSummaryScreen(
                                      saleRepository: widget.saleRepository!,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 24),
                        const _SectionDivider(label: 'Business tracking'),
                        const SizedBox(height: 18),
                        Center(
                          child: _FeatureButton(
                            icon: Icons.receipt_long_rounded,
                            title: 'Expense Tracking',
                            subtitle: 'Record and review business expenses',
                            onPressed: () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => ExpenseTrackingScreen(
                                  saleRepository: widget.saleRepository,
                                  products: widget.products,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: _FeatureButton(
                            icon: Icons.account_balance_wallet_rounded,
                            title: 'Credit and Debit Tracking',
                            subtitle: 'Customer balances and payments',
                            onPressed: () => Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => CreditDebitTrackingScreen(
                                  productController: widget.productController,
                                  saleRepository: widget.saleRepository,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _SalesSummaryPreview extends StatelessWidget {
  final List<SalesTransactionRecord> transactions;
  final VoidCallback? onViewAll;

  const _SalesSummaryPreview({
    required this.transactions,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final weekStart = todayStart.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(today.year, today.month);
    final todaySales = _inRange(
      transactions,
      todayStart,
      todayStart.add(const Duration(days: 1)),
    );
    final weekSales = _inRange(
      transactions,
      weekStart,
      weekStart.add(const Duration(days: 7)),
    );
    final monthSales = _inRange(
      transactions,
      monthStart,
      DateTime(monthStart.year, monthStart.month + 1),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Sales Summary',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onViewAll,
                  child: const Text(
                    'View all sales summary',
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _SalesPeriodSummary(label: 'Today', transactions: todaySales),
            const Divider(height: 18),
            _SalesPeriodSummary(label: 'This week', transactions: weekSales),
            const Divider(height: 18),
            _SalesPeriodSummary(label: 'This month', transactions: monthSales),
          ],
        ),
      ),
    );
  }

  List<SalesTransactionRecord> _inRange(
    List<SalesTransactionRecord> records,
    DateTime start,
    DateTime end,
  ) => records
      .where(
        (transaction) =>
            !transaction.date.isBefore(start) && transaction.date.isBefore(end),
      )
      .toList(growable: false);
}

class _SalesPeriodSummary extends StatelessWidget {
  final String label;
  final List<SalesTransactionRecord> transactions;

  const _SalesPeriodSummary({required this.label, required this.transactions});

  @override
  Widget build(BuildContext context) {
    final total = transactions.fold<double>(
      0,
      (sum, transaction) => sum + transaction.total,
    );
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                '${transactions.length} transaction${transactions.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Text(
          formatSalesCurrency(total),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.forestGreen,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  final String label;

  const _SectionDivider({required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: Divider()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(label, style: Theme.of(context).textTheme.labelLarge),
      ),
      const Expanded(child: Divider()),
    ],
  );
}

class _FeatureButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  const _FeatureButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 340,
    child: Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.forestGreen),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ReportError extends StatelessWidget {
  final Object error;
  final Future<void> Function() onRetry;

  const _ReportError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bar_chart_rounded, size: 44),
          const SizedBox(height: 12),
          const Text('Could not load sales summary.'),
          const SizedBox(height: 8),
          Text(error.toString(), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
