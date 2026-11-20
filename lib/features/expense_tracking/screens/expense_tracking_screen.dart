import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_theme.dart';
import '../../products/domain/product.dart';
import '../../sales/domain/sale.dart';
import '../../sales/domain/sale_repository.dart';
import '../../reports/services/expense_report_summary.dart';
import '../../reports/services/report_export_service.dart';
import '../../reports/services/report_period.dart';
import '../models/expense_record.dart';
import '../services/expense_service.dart';
import 'expense_correction_history_screen.dart';

class ExpenseTrackingScreen extends StatefulWidget {
  final SaleRepository? saleRepository;
  final List<ProductModel> products;
  final ExpenseService service;
  final String businessName;
  final String preparedBy;

  const ExpenseTrackingScreen({
    super.key,
    required this.saleRepository,
    required this.products,
    this.service = const ExpenseService(),
    this.businessName = 'Bizniz Tracker',
    this.preparedBy = '',
  });

  @override
  State<ExpenseTrackingScreen> createState() => _ExpenseTrackingScreenState();
}

class _ExpenseTrackingScreenState extends State<ExpenseTrackingScreen> {
  ReportPeriod _period = ReportPeriod.monthly;
  DateTime _selectedDate = DateTime.now();
  DateTimeRange? _customRange;
  List<ExpenseRecord> _expenses = const [];
  List<Sale> _sales = const [];
  bool _loading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTimeRange get _periodRange => ReportPeriodRange.resolve(
    period: _period,
    selectedDate: _selectedDate,
    customRange: _customRange,
  );

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final expensesFuture = widget.service.loadAll();
      final salesFuture = widget.saleRepository?.getAllSales();
      final expenses = await expensesFuture;
      final sales = salesFuture == null ? <Sale>[] : await salesFuture;
      if (!mounted) return;
      setState(() {
        _expenses = expenses;
        _sales = sales;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  List<ExpenseRecord> get _periodExpenses => _expenses
      .where((expense) {
        return ReportPeriodRange.contains(_periodRange, expense.expenseDate);
      })
      .toList(growable: false);

  List<Sale> get _periodSales => _sales
      .where((sale) {
        return ReportPeriodRange.contains(_periodRange, sale.saleDate);
      })
      .toList(growable: false);

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
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 5),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = _period == ReportPeriod.yearly
            ? DateTime(picked.year)
            : picked;
      });
    }
  }

  Future<void> _openExpenseForm({ExpenseRecord? expense}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ExpenseFormSheet(
        initial: expense,
        categories: ExpenseService.defaultCategories.toList(growable: false),
        onSave:
            (
              category,
              description,
              amount,
              date,
              paymentMethod,
              referenceNumber,
              remarks,
              expenseType,
              reason,
            ) async {
              if (expense == null) {
                await widget.service.addExpense(
                  category: category,
                  description: description,
                  amount: amount,
                  expenseDate: date,
                  paymentMethod: paymentMethod,
                  referenceNumber: referenceNumber,
                  recordedBy: widget.preparedBy,
                  remarks: remarks,
                  expenseType: expenseType,
                );
              } else {
                await widget.service.updateExpense(
                  updated: expense.copyWith(
                    category: category,
                    description: description,
                    amount: amount,
                    expenseDate: date,
                    paymentMethod: paymentMethod,
                    referenceNumber: referenceNumber,
                    recordedBy: widget.preparedBy.isEmpty
                        ? expense.recordedBy
                        : widget.preparedBy,
                    remarks: remarks,
                    expenseType: expenseType,
                  ),
                  reason: reason!,
                );
              }
            },
      ),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _deleteExpense(ExpenseRecord expense) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Delete "${expense.description}"? This cannot be undone.'),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Reason for deletion',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'A reason is required.'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context, reasonController.text.trim());
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || !mounted) return;
    try {
      await widget.service.deleteExpense(expenseId: expense.id, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense deleted and correction recorded.'),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete expense: $error')),
      );
    }
  }

  String get _periodLabel => reportPeriodLabel(_period);

  String get _businessName => widget.businessName.trim().isEmpty
      ? 'Bizniz Tracker'
      : widget.businessName.trim();

  List<List<Object?>> _expenseReportRows() {
    final report = ExpenseReportSummary.fromRecords(_periodExpenses);
    final range = _periodRange;
    final rows = <List<Object?>>[
      ['Business Name', _businessName],
      ['Report Type', 'Expense Report'],
      ['Report Period', _periodLabel],
      ['Start Date', _dateText(range.start)],
      ['End Date', _dateText(range.end.subtract(const Duration(days: 1)))],
      ['Generated Date', _dateText(DateTime.now())],
      ['Prepared By', widget.preparedBy],
      [],
      ['Expense Summary'],
      ['Total Expenses', report.total.toStringAsFixed(2)],
      ['Expense Transactions', report.transactionCount],
      ['Highest Expense', report.highest?.amount.toStringAsFixed(2) ?? '0.00'],
      ['Average Expense', report.average.toStringAsFixed(2)],
      [],
      ['Expense Breakdown by Category'],
      ['Category', 'Total Amount', 'Percent of Total'],
    ];
    for (final entry in report.categoryTotals.entries) {
      rows.add([
        entry.key,
        entry.value.toStringAsFixed(2),
        '${report.percentageOfTotal(entry.value).toStringAsFixed(2)}%',
      ]);
    }
    rows.addAll([
      [],
      ['Expense Breakdown by Payment Method'],
      ['Payment Method', 'Total Amount', 'Percent of Total'],
    ]);
    for (final entry in report.paymentMethodTotals.entries) {
      rows.add([
        entry.key,
        entry.value.toStringAsFixed(2),
        '${report.percentageOfTotal(entry.value).toStringAsFixed(2)}%',
      ]);
    }
    rows.addAll([
      [],
      ['Detailed Expense Records'],
      [
        'Expense ID',
        'Expense Date',
        'Expense Category',
        'Description',
        'Amount',
        'Payment Method',
        'Reference Number',
        'Recorded By',
        'Remarks',
        'Expense Type',
      ],
    ]);
    for (final expense in report.records) {
      rows.add([
        expense.id,
        _dateText(expense.expenseDate),
        expense.category,
        expense.description,
        expense.amount.toStringAsFixed(2),
        expense.paymentMethod,
        expense.referenceNumber ?? '',
        expense.recordedBy ?? '',
        expense.remarks,
        expense.expenseType,
      ]);
    }
    return rows;
  }

  String _dateText(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _export(String format) async {
    final range = _periodRange;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final baseName = 'expense_report_${_dateText(range.start)}_$stamp';
    try {
      if (format == 'pdf') {
        await _exportPdf(baseName);
      } else {
        final rows = _expenseReportRows();
        final bytes = format == 'csv'
            ? utf8.encode(ReportExportService.toCsv(rows))
            : ReportExportService.toXlsx(rows);
        await const ReportExportService().save(
          fileName: baseName,
          extension: format,
          bytes: bytes,
          mimeType: format == 'csv' ? MimeType.csv : MimeType.microsoftExcel,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Expense $format report exported.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export expense report: $error')),
      );
    }
  }

  Future<void> _exportPdf(String fileName) async {
    final report = ExpenseReportSummary.fromRecords(_periodExpenses);
    final range = _periodRange;
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => [
          pw.Text(
            'Expense Report',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(_businessName, style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 8),
          pw.Text(
            '$_periodLabel: ${_dateText(range.start)} - '
            '${_dateText(DateTime(range.end.year, range.end.month, range.end.day - 1))}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Expense Summary',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['Metric', 'Value'],
            data: [
              ['Total Expenses', report.total.toStringAsFixed(2)],
              ['Expense Transactions', report.transactionCount.toString()],
              [
                'Highest Expense',
                report.highest?.amount.toStringAsFixed(2) ?? '0.00',
              ],
              ['Average Expense', report.average.toStringAsFixed(2)],
            ],
            headerCount: 1,
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(1),
            },
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 5,
            ),
          ),
          if (report.categoryTotals.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              'Expense Breakdown by Category',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: const ['Category', 'Total Amount', 'Percent of Total'],
              data: [
                for (final entry in report.categoryTotals.entries)
                  [
                    entry.key,
                    entry.value.toStringAsFixed(2),
                    '${report.percentageOfTotal(entry.value).toStringAsFixed(2)}%',
                  ],
              ],
              headerCount: 1,
              columnWidths: const {
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(1),
              },
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 5,
              ),
            ),
          ],
          if (report.paymentMethodTotals.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              'Expense Breakdown by Payment Method',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: const [
                'Payment Method',
                'Total Amount',
                'Percent of Total',
              ],
              data: [
                for (final entry in report.paymentMethodTotals.entries)
                  [
                    entry.key,
                    entry.value.toStringAsFixed(2),
                    '${report.percentageOfTotal(entry.value).toStringAsFixed(2)}%',
                  ],
              ],
              headerCount: 1,
              columnWidths: const {
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(1),
              },
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 5,
              ),
            ),
          ],
          if (report.records.isEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'No expense records were found for this period.',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ],
      ),
    );
    if (report.records.isNotEmpty) {
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.fromLTRB(24, 42, 24, 30),
          header: (_) => pw.Text(
            'Expense Report - Detailed Expense Records',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          build: (_) => [
            pw.TableHelper.fromTextArray(
              headers: const [
                'Expense ID',
                'Expense Date',
                'Category',
                'Description',
                'Amount',
                'Payment Method',
                'Reference Number',
                'Recorded By',
                'Remarks',
                'Expense Type',
              ],
              data: [
                for (final expense in report.records)
                  [
                    expense.id,
                    _dateText(expense.expenseDate),
                    expense.category,
                    expense.description,
                    expense.amount.toStringAsFixed(2),
                    expense.paymentMethod,
                    expense.referenceNumber ?? '',
                    expense.recordedBy ?? '',
                    expense.remarks,
                    expense.expenseType,
                  ],
              ],
              headerCount: 1,
              columnWidths: const {
                0: pw.FlexColumnWidth(1),
                1: pw.FlexColumnWidth(0.75),
                2: pw.FlexColumnWidth(0.9),
                3: pw.FlexColumnWidth(1.4),
                4: pw.FlexColumnWidth(0.65),
                5: pw.FlexColumnWidth(0.9),
                6: pw.FlexColumnWidth(0.85),
                7: pw.FlexColumnWidth(0.8),
                8: pw.FlexColumnWidth(1.3),
                9: pw.FlexColumnWidth(1),
              },
              defaultColumnWidth: const pw.FlexColumnWidth(1),
              tableWidth: pw.TableWidth.max,
              cellStyle: const pw.TextStyle(fontSize: 7),
              headerStyle: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 3,
                vertical: 4,
              ),
              headerPadding: const pw.EdgeInsets.symmetric(
                horizontal: 3,
                vertical: 5,
              ),
              headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
            ),
          ],
        ),
      );
    }
    await Printing.layoutPdf(
      name: '$fileName.pdf',
      onLayout: (_) => document.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final periodExpenses = _periodExpenses;
    final totalExpenses = periodExpenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );
    final categoryTotals = <String, double>{};
    for (final expense in periodExpenses) {
      categoryTotals.update(
        expense.category,
        (total) => total + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
    final sales = _periodSales;
    final revenue = sales.fold<double>(
      0,
      (sum, sale) => sum + sale.totalRevenue,
    );
    final productsById = {
      for (final product in widget.products) product.id: product,
    };
    var costOfGoods = 0.0;
    var hasMissingCost = false;
    for (final sale in sales) {
      final unitCost =
          sale.productCostAtSale ?? productsById[sale.productId]?.costPrice;
      if (unitCost == null) {
        hasMissingCost = true;
      } else {
        costOfGoods += unitCost * sale.quantitySold;
      }
    }
    final operatingExpenseRecords = periodExpenses
        .where((expense) => expense.expenseType != 'Inventory Purchase')
        .toList();
    final operatingExpenses = operatingExpenseRecords.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );
    final inventoryPurchases = totalExpenses - operatingExpenses;
    final estimatedProfit = revenue - costOfGoods - operatingExpenses;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Expense Tracking'),
        actions: [
          IconButton(
            tooltip: 'Correction history',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) =>
                    ExpenseCorrectionHistoryScreen(service: widget.service),
              ),
            ),
            icon: const Icon(Icons.history_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Export expense report',
            enabled: !_loading,
            onSelected: _export,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'csv', child: Text('Export as CSV')),
              PopupMenuItem(value: 'pdf', child: Text('Export as PDF')),
              PopupMenuItem(value: 'xlsx', child: Text('Export as Excel')),
            ],
            icon: const Icon(Icons.download_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : () => _openExpenseForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Expense'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? _ExpenseLoadError(error: _loadError!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  _buildPeriodSelector(),
                  const SizedBox(height: 12),
                  _FinancialSummary(
                    sales: revenue,
                    costOfGoods: costOfGoods,
                    expenses: operatingExpenses,
                    inventoryPurchases: inventoryPurchases,
                    estimatedProfit: estimatedProfit,
                    hasMissingCost: hasMissingCost,
                    expenseCount: operatingExpenseRecords.length,
                  ),
                  const SizedBox(height: 16),
                  _CategorySummary(totals: categoryTotals),
                  const SizedBox(height: 16),
                  _PaymentMethodSummary(expenses: periodExpenses),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Expense records',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        '${periodExpenses.length}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (periodExpenses.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No expenses recorded for this period.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  else
                    for (final expense in periodExpenses)
                      _ExpenseListTile(
                        expense: expense,
                        onEdit: () => _openExpenseForm(expense: expense),
                        onDelete: () => _deleteExpense(expense),
                      ),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    const items = <(ReportPeriod, String)>[
      (ReportPeriod.daily, 'Daily'),
      (ReportPeriod.weekly, 'Weekly'),
      (ReportPeriod.monthly, 'Monthly'),
      (ReportPeriod.yearly, 'Yearly'),
      (ReportPeriod.custom, 'Custom'),
    ];
    final range = _periodRange;
    final label = _period == ReportPeriod.daily
        ? MaterialLocalizations.of(context).formatMediumDate(_selectedDate)
        : '${MaterialLocalizations.of(context).formatMediumDate(range.start)} – '
              '${MaterialLocalizations.of(context).formatMediumDate(range.end.subtract(const Duration(days: 1)))}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            DropdownButtonFormField<ReportPeriod>(
              initialValue: _period,
              decoration: const InputDecoration(labelText: 'Report period'),
              items: [
                for (final (period, label) in items)
                  DropdownMenuItem(value: period, child: Text(label)),
              ],
              onChanged: (period) {
                if (period != null) {
                  setState(() {
                    _period = period;
                    if (period == ReportPeriod.yearly) {
                      _selectedDate = DateTime(_selectedDate.year);
                    }
                  });
                }
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

class _FinancialSummary extends StatelessWidget {
  final double sales;
  final double costOfGoods;
  final double expenses;
  final double inventoryPurchases;
  final double estimatedProfit;
  final bool hasMissingCost;
  final int expenseCount;

  const _FinancialSummary({
    required this.sales,
    required this.costOfGoods,
    required this.expenses,
    required this.inventoryPurchases,
    required this.estimatedProfit,
    required this.hasMissingCost,
    required this.expenseCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Financial summary',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            _SummaryLine(label: 'Sales revenue', amount: sales),
            _SummaryLine(
              label: 'Estimated inventory cost',
              amount: costOfGoods,
            ),
            _SummaryLine(
              label: 'Operating expenses ($expenseCount)',
              amount: expenses,
            ),
            _SummaryLine(
              label: 'Inventory purchases (excluded from profit)',
              amount: inventoryPurchases,
            ),
            const Divider(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Estimated profit',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  formatCurrency(estimatedProfit),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: estimatedProfit < 0
                        ? AppColors.error
                        : AppColors.forestGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            if (hasMissingCost) ...[
              const SizedBox(height: 8),
              Text(
                'Some older sales have no saved product cost and are excluded from the cost estimate.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            Text(
              'Profit = sales − cost of goods sold − operating expenses. '
              'Inventory purchases are excluded to avoid counting the same stock cost twice.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final double amount;

  const _SummaryLine({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(formatCurrency(amount)),
      ],
    ),
  );
}

class _CategorySummary extends StatelessWidget {
  final Map<String, double> totals;

  const _CategorySummary({required this.totals});

  @override
  Widget build(BuildContext context) {
    final categories = totals.entries.toList()
      ..sort((first, second) => second.value.compareTo(first.value));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expenses by category',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (categories.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Category totals appear when expenses are recorded.',
                ),
              )
            else
              for (final entry in categories)
                _SummaryLine(label: entry.key, amount: entry.value),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodSummary extends StatelessWidget {
  final List<ExpenseRecord> expenses;

  const _PaymentMethodSummary({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final totals = <String, double>{};
    for (final expense in expenses) {
      totals.update(
        expense.paymentMethod,
        (total) => total + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expenses by payment method',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (totals.isEmpty)
              const Text('Payment totals appear when expenses are recorded.')
            else
              for (final entry in totals.entries)
                _SummaryLine(label: entry.key, amount: entry.value),
          ],
        ),
      ),
    );
  }
}

class _ExpenseListTile extends StatelessWidget {
  final ExpenseRecord expense;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExpenseListTile({
    required this.expense,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.softGreen,
        child: const Icon(
          Icons.receipt_long_rounded,
          color: AppColors.forestGreen,
        ),
      ),
      title: Text(expense.description),
      subtitle: Text(
        '${expense.category} · ${MaterialLocalizations.of(context).formatMediumDate(expense.expenseDate)}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatCurrency(expense.amount),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          PopupMenuButton<String>(
            tooltip: 'Expense actions',
            onSelected: (action) {
              if (action == 'edit') onEdit();
              if (action == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ExpenseFormSheet extends StatefulWidget {
  final ExpenseRecord? initial;
  final List<String> categories;
  final Future<void> Function(
    String category,
    String description,
    double amount,
    DateTime date,
    String paymentMethod,
    String? referenceNumber,
    String remarks,
    String expenseType,
    String? reason,
  )
  onSave;

  const _ExpenseFormSheet({
    required this.initial,
    required this.categories,
    required this.onSave,
  });

  @override
  State<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<_ExpenseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late final TextEditingController _reasonController;
  late final TextEditingController _referenceController;
  late final TextEditingController _remarksController;
  late final List<String> _categories;
  late String _category;
  late String _paymentMethod;
  late String _expenseType;
  late DateTime _date;
  bool _saving = false;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _categories = widget.categories.isEmpty
        ? ExpenseService.defaultCategories.toList(growable: false)
        : widget.categories.toList(growable: false);
    _category =
        initial?.category ??
        _categories.firstWhere(
          (category) => category == 'Other' || category == 'Utilities',
          orElse: () => _categories.first,
        );
    _date = initial?.expenseDate ?? DateTime.now();
    _descriptionController = TextEditingController(text: initial?.description);
    _amountController = TextEditingController(
      text: initial?.amount.toStringAsFixed(2),
    );
    _reasonController = TextEditingController();
    _referenceController = TextEditingController(
      text: initial?.referenceNumber,
    );
    _remarksController = TextEditingController(text: initial?.remarks);
    _paymentMethod = initial?.paymentMethod ?? 'Cash';
    _expenseType = initial?.expenseType ?? 'Operating Expense';
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _reasonController.dispose();
    _referenceController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text.trim());
    final description = _descriptionController.text.trim();
    final category = _category == 'Other' && description.isNotEmpty
        ? description
        : _category;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        category,
        description,
        amount,
        _date,
        _paymentMethod,
        _referenceController.text.trim().isEmpty
            ? null
            : _referenceController.text.trim(),
        _remarksController.text.trim(),
        _expenseType,
        _isEditing ? _reasonController.text.trim() : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save expense: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? 'Edit Expense' : 'Add Expense',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₱ ',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '');
                  if (amount == null || !amount.isFinite || amount <= 0) {
                    return 'Enter an amount greater than zero.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLength: 120,
                decoration: InputDecoration(
                  labelText: _category == 'Other'
                      ? 'Description (required for Other)'
                      : 'Description',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return _category == 'Other'
                        ? 'Please specify the expense description.'
                        : 'Description is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categories.contains(_category)
                    ? _category
                    : _categories.last,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final category in _categories)
                    DropdownMenuItem(value: category, child: Text(category)),
                  if (!_categories.contains(_category))
                    DropdownMenuItem(value: _category, child: Text(_category)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                decoration: const InputDecoration(
                  labelText: 'Payment method',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'GCash', child: Text('GCash')),
                  DropdownMenuItem(
                    value: 'Bank Transfer',
                    child: Text('Bank Transfer'),
                  ),
                  DropdownMenuItem(value: 'Card', child: Text('Card')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _paymentMethod = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _expenseType,
                decoration: const InputDecoration(
                  labelText: 'Expense type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Operating Expense',
                    child: Text('Operating Expense'),
                  ),
                  DropdownMenuItem(
                    value: 'Inventory Purchase',
                    child: Text('Inventory Purchase'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _expenseType = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _referenceController,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Reference number (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _remarksController,
                maxLength: 240,
                decoration: const InputDecoration(
                  labelText: 'Remarks',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _selectDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  MaterialLocalizations.of(context).formatMediumDate(_date),
                ),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reasonController,
                  maxLength: 160,
                  decoration: const InputDecoration(
                    labelText: 'Reason for change',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'A reason is required to save this correction.'
                      : null,
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'Save Changes' : 'Save Expense'),
              ),
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseLoadError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ExpenseLoadError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Could not load expenses.'),
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
