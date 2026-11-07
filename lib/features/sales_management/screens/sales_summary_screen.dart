import 'package:flutter/material.dart';

import '../../sales/domain/sale_repository.dart';
import '../models/sales_transaction_record.dart';

class SalesSummaryScreen extends StatefulWidget {
  final SaleRepository saleRepository;

  const SalesSummaryScreen({super.key, required this.saleRepository});

  @override
  State<SalesSummaryScreen> createState() => _SalesSummaryScreenState();
}

class _SalesSummaryScreenState extends State<SalesSummaryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<List<SalesTransactionRecord>> _transactionsFuture;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _transactionsFuture = _loadTransactions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<SalesTransactionRecord>> _loadTransactions() async =>
      SalesTransactionRecord.groupSales(
        await widget.saleRepository.getAllSales(),
      );

  Future<void> _refresh() async {
    setState(() => _transactionsFuture = _loadTransactions());
    await _transactionsFuture;
  }

  Future<void> _selectDate() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 5),
    );
    if (selected != null) setState(() => _selectedDate = selected);
  }

  DateTimeRange _periodRange(int tab) {
    final day = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    if (tab == 0) {
      return DateTimeRange(start: day, end: day.add(const Duration(days: 1)));
    }
    if (tab == 1) {
      final start = day.subtract(Duration(days: day.weekday - 1));
      return DateTimeRange(
        start: start,
        end: start.add(const Duration(days: 7)),
      );
    }
    final start = DateTime(day.year, day.month);
    return DateTimeRange(
      start: start,
      end: DateTime(start.year, start.month + 1),
    );
  }

  List<SalesTransactionRecord> _transactionsForPeriod(
    List<SalesTransactionRecord> allTransactions,
    int tab,
  ) {
    final range = _periodRange(tab);
    return allTransactions
        .where(
          (transaction) =>
              !transaction.date.isBefore(range.start) &&
              transaction.date.isBefore(range.end),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to sales',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Sales Summary'),
        actions: [
          IconButton(
            tooltip: 'Refresh summary',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Daily'),
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly'),
          ],
        ),
      ),
      body: FutureBuilder<List<SalesTransactionRecord>>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load sales summary: ${snapshot.error}'),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final allTransactions = snapshot.data ?? [];
          return TabBarView(
            controller: _tabController,
            children: [
              for (var period = 0; period < 3; period++)
                _summaryBody(context, allTransactions, period),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryBody(
    BuildContext context,
    List<SalesTransactionRecord> allTransactions,
    int period,
  ) {
    final range = _periodRange(period);
    final transactions = _transactionsForPeriod(allTransactions, period);
    final totalSales = transactions.fold<double>(
      0,
      (total, transaction) => total + transaction.total,
    );
    final labels = ['Daily', 'Weekly', 'Monthly'];
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed: _selectDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              period == 0
                  ? MaterialLocalizations.of(
                      context,
                    ).formatMediumDate(_selectedDate)
                  : '${MaterialLocalizations.of(context).formatMediumDate(range.start)} – '
                        '${MaterialLocalizations.of(context).formatMediumDate(range.end.subtract(const Duration(days: 1)))}',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${labels[period]} Summary',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _SummaryValueCard(
            label: 'Total Sales',
            value: formatSalesCurrency(totalSales),
            icon: Icons.payments_rounded,
          ),
          const SizedBox(height: 8),
          _SummaryValueCard(
            label: 'Transactions',
            value: '${transactions.length}',
            icon: Icons.receipt_long_rounded,
            valueKey: const ValueKey('summary-transaction-count'),
          ),
          const SizedBox(height: 16),
          if (transactions.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No saved transactions in this period.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            for (final transaction in transactions)
              ListTile(
                title: Text(transaction.receiptNumber),
                subtitle: Text(
                  MaterialLocalizations.of(
                    context,
                  ).formatMediumDate(transaction.date),
                ),
                trailing: Text(formatSalesCurrency(transaction.total)),
              ),
        ],
      ),
    );
  }
}

class _SummaryValueCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Key? valueKey;

  const _SummaryValueCard({
    required this.label,
    required this.value,
    required this.icon,
    this.valueKey,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: Text(
        value,
        key: valueKey,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ),
  );
}
