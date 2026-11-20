import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';
import 'package:printing/printing.dart';

import '../../reports/services/report_export_service.dart';
import '../../reports/services/report_period.dart';
import '../../sales/domain/sale_repository.dart';
import '../models/sales_transaction_record.dart';
import '../services/sales_summary_pdf_builder.dart';

class SalesSummaryScreen extends StatefulWidget {
  final SaleRepository saleRepository;
  final String businessName;
  final String preparedBy;

  const SalesSummaryScreen({
    super.key,
    required this.saleRepository,
    this.businessName = 'Bizniz Tracker',
    this.preparedBy = '',
  });

  @override
  State<SalesSummaryScreen> createState() => _SalesSummaryScreenState();
}

class _SalesSummaryScreenState extends State<SalesSummaryScreen> {
  late Future<List<SalesTransactionRecord>> _transactionsFuture;
  ReportPeriod _period = ReportPeriod.monthly;
  DateTime _selectedDate = DateTime.now();
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    _transactionsFuture = _loadTransactions();
  }

  Future<List<SalesTransactionRecord>> _loadTransactions() async =>
      SalesTransactionRecord.groupSales(
        await widget.saleRepository.getAllSales(),
      );

  Future<void> _refresh() async {
    setState(() => _transactionsFuture = _loadTransactions());
    await _transactionsFuture;
  }

  DateTimeRange get _periodRange => ReportPeriodRange.resolve(
    period: _period,
    selectedDate: _selectedDate,
    customRange: _customRange,
  );

  String get _periodLabel => reportPeriodLabel(_period);

  Future<void> _selectDate() async {
    final today = DateTime.now();
    if (_period == ReportPeriod.custom) {
      final selectedDay = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(today.year + 5),
        initialDateRange:
            _customRange ?? DateTimeRange(start: selectedDay, end: selectedDay),
      );
      if (range != null) {
        setState(() {
          _customRange = DateTimeRange(
            start: DateTime(
              range.start.year,
              range.start.month,
              range.start.day,
            ),
            end: DateTime(range.end.year, range.end.month, range.end.day),
          );
        });
      }
      return;
    }
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 5),
    );
    if (selected != null) {
      setState(() {
        _selectedDate = _period == ReportPeriod.yearly
            ? DateTime(selected.year)
            : selected;
      });
    }
  }

  List<SalesTransactionRecord> _transactionsForPeriod(
    List<SalesTransactionRecord> transactions,
  ) {
    final range = _periodRange;
    return transactions
        .where(
          (transaction) => ReportPeriodRange.contains(range, transaction.date),
        )
        .toList();
  }

  String _dateText(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String get _businessName => widget.businessName.trim().isEmpty
      ? 'Bizniz Tracker'
      : widget.businessName.trim();

  Future<void> _export(
    List<SalesTransactionRecord> transactions, {
    required bool includeProducts,
    required String format,
  }) async {
    final rows = _reportRows(transactions, includeProducts: includeProducts);
    final now = DateTime.now();
    final fileName =
        'sales_${includeProducts ? 'product_detail_' : ''}${_dateText(_periodRange.start)}_${now.millisecondsSinceEpoch}';
    try {
      if (format == 'pdf') {
        final document = const SalesSummaryPdfBuilder().build(
          title:
              '${includeProducts ? 'Sales Summary with Product Total Sales' : 'Sales Summary'} - $_businessName',
          rows: rows,
        );
        await Printing.layoutPdf(
          name: '$fileName.pdf',
          onLayout: (_) => document.save(),
        );
      } else {
        final bytes = format == 'csv'
            ? utf8.encode(ReportExportService.toCsv(rows))
            : ReportExportService.toXlsx(
                rows,
                columnWidths: const [30, 18, 18, 20, 23, 24],
              );
        await const ReportExportService().save(
          fileName: fileName,
          extension: format,
          bytes: bytes,
          mimeType: format == 'csv' ? MimeType.csv : MimeType.microsoftExcel,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${includeProducts ? 'Detailed' : 'General'} sales $format report exported.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export sales report: $error')),
      );
    }
  }

  List<List<Object?>> _reportRows(
    List<SalesTransactionRecord> transactions, {
    required bool includeProducts,
  }) {
    final range = _periodRange;
    final totalRevenue = transactions.fold<double>(
      0,
      (sum, transaction) => sum + transaction.total,
    );
    final totalDiscounts = transactions.fold<double>(
      0,
      (sum, transaction) => sum + transaction.discount,
    );
    final quantity = transactions.fold<int>(
      0,
      (sum, transaction) =>
          sum +
          transaction.items.fold(
            0,
            (subtotal, item) => subtotal + item.quantitySold,
          ),
    );
    final productSales = _productSales(transactions);
    final cost = productSales.values.fold<double>(
      0,
      (sum, product) => sum + product.costOfGoods,
    );
    final paymentTotals = <String, double>{};
    for (final transaction in transactions) {
      paymentTotals.update(
        transaction.paymentMethod,
        (total) => total + transaction.total,
        ifAbsent: () => transaction.total,
      );
    }
    final rows = <List<Object?>>[
      ['Business Name', _businessName],
      [
        'Report Type',
        includeProducts
            ? 'Sales Summary with Product Total Sales'
            : 'Sales Summary',
      ],
      ['Report Period', _periodLabel],
      ['Start Date', _dateText(range.start)],
      ['End Date', _dateText(range.end.subtract(const Duration(days: 1)))],
      ['Generated Date', _dateText(DateTime.now())],
      ['Prepared By', widget.preparedBy],
      [],
      ['Sales Overview'],
      ['Total Sales Revenue', totalRevenue.toStringAsFixed(2)],
      ['Total Completed Transactions', transactions.length],
      ['Total Quantity of Products Sold', quantity],
      ['Total Discounts', totalDiscounts.toStringAsFixed(2)],
      ['Estimated Gross Profit', (totalRevenue - cost).toStringAsFixed(2)],
      [],
      ['Sales Transaction Records'],
      [
        'Receipt/Transaction Number',
        'Transaction Date',
        'Number of Items',
        'Total Amount',
        'Payment Method',
        'Transaction Status',
      ],
    ];
    for (final transaction in transactions) {
      rows.add([
        transaction.receiptNumber,
        _dateText(transaction.date),
        transaction.items.fold<int>(0, (sum, item) => sum + item.quantitySold),
        transaction.total.toStringAsFixed(2),
        transaction.paymentMethod,
        'Completed',
      ]);
    }
    rows.addAll([
      [],
      ['Payment Summary'],
      ['Payment Method', 'Total Amount'],
    ]);
    for (final entry in paymentTotals.entries) {
      rows.add([entry.key, entry.value.toStringAsFixed(2)]);
    }
    if (!includeProducts) return rows;
    rows.addAll([
      [],
      ['Product Total Sales'],
      [
        'Product Name',
        'Product ID',
        'Total Quantity Sold',
        'Total Sales Revenue',
        'Total Cost of Goods Sold',
        'Estimated Profit per Product',
      ],
    ]);
    for (final product in productSales.values) {
      rows.add([
        product.name,
        product.id,
        product.quantity,
        product.revenue.toStringAsFixed(2),
        product.costOfGoods.toStringAsFixed(2),
        product.profit.toStringAsFixed(2),
      ]);
    }
    for (final (label, selector) in <(String, double Function(_ProductSales))>[
      ('Best-Selling Products', (product) => product.quantity.toDouble()),
      ('Products with Highest Sales Revenue', (product) => product.revenue),
      ('Products with Highest Estimated Profit', (product) => product.profit),
    ]) {
      final ranked = productSales.values.toList()
        ..sort((first, second) => selector(second).compareTo(selector(first)));
      rows.addAll([
        [],
        [label],
        ['Product Name', 'Product ID', 'Quantity', 'Sales Revenue', 'Profit'],
      ]);
      for (final product in ranked.take(5)) {
        rows.add([
          product.name,
          product.id,
          product.quantity,
          product.revenue.toStringAsFixed(2),
          product.profit.toStringAsFixed(2),
        ]);
      }
    }
    return rows;
  }

  Map<String, _ProductSales> _productSales(
    List<SalesTransactionRecord> transactions,
  ) {
    final products = <String, _ProductSales>{};
    for (final transaction in transactions) {
      for (final item in transaction.items) {
        final product = products.putIfAbsent(
          item.productId,
          () => _ProductSales(
            id: item.productId,
            name: item.productNameAtSale ?? item.productId,
          ),
        );
        product
          ..quantity += item.quantitySold
          ..revenue += item.sellingPrice * item.quantitySold
          ..costOfGoods += (item.productCostAtSale ?? 0) * item.quantitySold;
      }
    }
    return products;
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
          final transactions = _transactionsForPeriod(snapshot.data ?? []);
          final total = transactions.fold<double>(
            0,
            (sum, transaction) => sum + transaction.total,
          );
          final products = _productSales(transactions).values.toList()
            ..sort((first, second) => first.name.compareTo(second.name));
          final productsSold = products.fold<int>(
            0,
            (sum, product) => sum + product.quantity,
          );
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _periodPicker(context),
                const SizedBox(height: 16),
                Text(
                  'Completed sales · ${transactions.length} transaction${transactions.length == 1 ? '' : 's'} · $productsSold items',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    title: const Text('Total Sales Revenue'),
                    trailing: Text(
                      formatSalesCurrency(total),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                if (products.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No completed sales in this period.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  for (final product in products)
                    Card(
                      child: ListTile(
                        title: Text(product.name),
                        subtitle: Text(
                          'ID: ${product.id} · ${product.quantity} sold',
                        ),
                        trailing: Text(formatSalesCurrency(product.revenue)),
                      ),
                    ),
                const SizedBox(height: 12),
                Text(
                  'Export report',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final includeProducts in [false, true])
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              includeProducts
                                  ? 'Sales Summary with Product Total Sales'
                                  : 'Sales Summary',
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Choose export format',
                            onSelected: (format) => _export(
                              transactions,
                              includeProducts: includeProducts,
                              format: format,
                            ),
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'pdf', child: Text('PDF')),
                              PopupMenuItem(
                                value: 'xlsx',
                                child: Text('Excel (.xlsx)'),
                              ),
                              PopupMenuItem(value: 'csv', child: Text('CSV')),
                            ],
                            icon: const Icon(Icons.download_rounded),
                          ),
                        ],
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

  Widget _periodPicker(BuildContext context) {
    final range = _periodRange;
    final label = _period == ReportPeriod.daily
        ? MaterialLocalizations.of(context).formatMediumDate(_selectedDate)
        : '${MaterialLocalizations.of(context).formatMediumDate(range.start)} – '
              '${MaterialLocalizations.of(context).formatMediumDate(range.end.subtract(const Duration(days: 1)))}';
    const options = <(ReportPeriod, String)>[
      (ReportPeriod.daily, 'Daily'),
      (ReportPeriod.weekly, 'Weekly'),
      (ReportPeriod.monthly, 'Monthly'),
      (ReportPeriod.yearly, 'Yearly'),
      (ReportPeriod.custom, 'Custom Date Range'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            DropdownButtonFormField<ReportPeriod>(
              initialValue: _period,
              decoration: const InputDecoration(labelText: 'Report period'),
              items: [
                for (final (period, name) in options)
                  DropdownMenuItem(value: period, child: Text(name)),
              ],
              onChanged: (period) {
                if (period != null) setState(() => _period = period);
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _selectDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductSales {
  final String id;
  final String name;
  int quantity = 0;
  double revenue = 0;
  double costOfGoods = 0;

  _ProductSales({required this.id, required this.name});

  double get profit => revenue - costOfGoods;
}
