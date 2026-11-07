import 'package:flutter/material.dart';

import '../../products/domain/product.dart';
import '../../sales/domain/sale_repository.dart';
import '../models/sales_transaction_record.dart';
import 'receipt_screen.dart';

class SalesHistoryScreen extends StatefulWidget {
  final SaleRepository saleRepository;
  final List<ProductModel> products;

  const SalesHistoryScreen({
    super.key,
    required this.saleRepository,
    required this.products,
  });

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final _searchController = TextEditingController();
  late Future<List<SalesTransactionRecord>> _transactionsFuture;
  String _searchTerm = '';
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _transactionsFuture = _loadTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
      initialDate: _selectedDate ?? today,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 5),
    );
    if (selected != null) setState(() => _selectedDate = selected);
  }

  List<SalesTransactionRecord> _filter(
    List<SalesTransactionRecord> transactions,
  ) {
    final query = _searchTerm.trim().toLowerCase();
    final productNames = {
      for (final product in widget.products) product.id: product.name,
    };
    return transactions.where((transaction) {
      if (_selectedDate != null &&
          (transaction.date.year != _selectedDate!.year ||
              transaction.date.month != _selectedDate!.month ||
              transaction.date.day != _selectedDate!.day)) {
        return false;
      }
      if (query.isEmpty) return true;
      return transaction.receiptNumber.toLowerCase().contains(query) ||
          transaction.date.toString().toLowerCase().contains(query) ||
          transaction.items.any((item) {
            final name =
                item.productNameAtSale ?? productNames[item.productId] ?? '';
            return name.toLowerCase().contains(query);
          });
    }).toList();
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
        title: const Text('Sales History'),
        actions: [
          IconButton(
            tooltip: 'Refresh history',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<SalesTransactionRecord>>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load sales history: ${snapshot.error}'),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final transactions = _filter(snapshot.data ?? []);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search date, receipt, or product',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchTerm = '');
                      },
                      icon: const Icon(Icons.clear),
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchTerm = value),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _selectDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        _selectedDate == null
                            ? 'Filter by date'
                            : MaterialLocalizations.of(
                                context,
                              ).formatMediumDate(_selectedDate!),
                      ),
                    ),
                    if (_selectedDate != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => setState(() => _selectedDate = null),
                        child: const Text('Clear date'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                if (transactions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Text(
                      'No recorded sales match this search.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  for (final transaction in transactions)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(transaction.receiptNumber),
                        subtitle: Text(
                          '${MaterialLocalizations.of(context).formatMediumDate(transaction.date)} · '
                          '${transaction.items.length} items',
                        ),
                        trailing: Text(
                          formatSalesCurrency(transaction.total),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) =>
                                ReceiptScreen(transaction: transaction),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}
