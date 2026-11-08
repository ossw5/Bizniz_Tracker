import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/csv_export.dart';
import '../../../core/formatters.dart';
import '../../../core/theme/app_theme.dart';
import '../../products/domain/product.dart';
import '../../sales/domain/sale.dart';
import '../../sales/domain/sale_repository.dart';
import '../models/expense_record.dart';
import '../services/expense_service.dart';
import 'expense_correction_history_screen.dart';

enum _ExpensePeriod { daily, weekly, monthly }

class ExpenseTrackingScreen extends StatefulWidget {
  final SaleRepository? saleRepository;
  final List<ProductModel> products;
  final ExpenseService service;

  const ExpenseTrackingScreen({
    super.key,
    required this.saleRepository,
    required this.products,
    this.service = const ExpenseService(),
  });

  @override
  State<ExpenseTrackingScreen> createState() => _ExpenseTrackingScreenState();
}

class _ExpenseTrackingScreenState extends State<ExpenseTrackingScreen> {
  _ExpensePeriod _period = _ExpensePeriod.monthly;
  DateTime _selectedDate = DateTime.now();
  List<ExpenseRecord> _expenses = const [];
  List<Sale> _sales = const [];
  bool _loading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTimeRange get _periodRange {
    final selected = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    switch (_period) {
      case _ExpensePeriod.daily:
        return DateTimeRange(
          start: selected,
          end: selected.add(const Duration(days: 1)),
        );
      case _ExpensePeriod.weekly:
        final start = selected.subtract(Duration(days: selected.weekday - 1));
        return DateTimeRange(
          start: start,
          end: start.add(const Duration(days: 7)),
        );
      case _ExpensePeriod.monthly:
        final start = DateTime(selected.year, selected.month);
        return DateTimeRange(
          start: start,
          end: DateTime(start.year, start.month + 1),
        );
    }
  }

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
        return !expense.expenseDate.isBefore(_periodRange.start) &&
            expense.expenseDate.isBefore(_periodRange.end);
      })
      .toList(growable: false);

  List<Sale> get _periodSales => _sales
      .where((sale) {
        return !sale.saleDate.isBefore(_periodRange.start) &&
            sale.saleDate.isBefore(_periodRange.end);
      })
      .toList(growable: false);

  Future<void> _selectDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 5),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _openExpenseForm({ExpenseRecord? expense}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ExpenseFormSheet(
        initial: expense,
        onSave: (category, description, amount, date, reason) async {
          if (expense == null) {
            await widget.service.addExpense(
              category: category,
              description: description,
              amount: amount,
              expenseDate: date,
            );
          } else {
            await widget.service.updateExpense(
              updated: expense.copyWith(
                category: category,
                description: description,
                amount: amount,
                expenseDate: date,
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

  Future<void> _exportCsv() async {
    final csv = _expensesToCsv(_expenses);
    final fileName =
        'expenses_${DateTime.now().toIso8601String().replaceAll(':', '-')}.csv';
    if (kIsWeb) {
      try {
        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: Uint8List.fromList(utf8.encode(csv)),
          fileExtension: 'csv',
          mimeType: MimeType.csv,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense CSV downloaded.')),
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export expenses: $error')),
        );
      }
      return;
    }
    try {
      final path = await CsvExport.saveCsvFile(fileName, csv);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Expense CSV saved to $path')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export expenses: $error')),
      );
    }
  }

  Future<void> _exportPdf() async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Text(
            'Expense Records',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const ['Date', 'Category', 'Description', 'Amount (PHP)'],
            data: [
              for (final expense in _expenses)
                [
                  '${expense.expenseDate.year}-${expense.expenseDate.month.toString().padLeft(2, '0')}-${expense.expenseDate.day.toString().padLeft(2, '0')}',
                  expense.category,
                  expense.description,
                  expense.amount.toStringAsFixed(2),
                ],
            ],
          ),
        ],
      ),
    );
    try {
      await Printing.layoutPdf(
        name: 'expense_records_${DateTime.now().millisecondsSinceEpoch}.pdf',
        onLayout: (_) => document.save(),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export expense PDF: $error')),
      );
    }
  }

  String _expensesToCsv(List<ExpenseRecord> expenses) {
    String escape(String value) {
      if (!value.contains(',') &&
          !value.contains('\n') &&
          !value.contains('"')) {
        return value;
      }
      return '"${value.replaceAll('"', '""')}"';
    }

    final output = StringBuffer('id,category,description,amount,date\n');
    for (final expense in expenses) {
      output.writeln(
        '${escape(expense.id)},${escape(expense.category)},'
        '${escape(expense.description)},${expense.amount.toStringAsFixed(2)},'
        '${expense.expenseDate.toIso8601String()}',
      );
    }
    return output.toString();
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
    final estimatedProfit = revenue - costOfGoods - totalExpenses;

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
            tooltip: 'Export expenses as CSV',
            enabled: !_loading,
            onSelected: (format) {
              if (format == 'csv') _exportCsv();
              if (format == 'pdf') _exportPdf();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'csv', child: Text('Export as CSV')),
              PopupMenuItem(value: 'pdf', child: Text('Export as PDF')),
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
                    expenses: totalExpenses,
                    estimatedProfit: estimatedProfit,
                    hasMissingCost: hasMissingCost,
                    expenseCount: periodExpenses.length,
                  ),
                  const SizedBox(height: 16),
                  _CategorySummary(totals: categoryTotals),
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
    const items = <(_ExpensePeriod, String)>[
      (_ExpensePeriod.daily, 'Daily'),
      (_ExpensePeriod.weekly, 'Weekly'),
      (_ExpensePeriod.monthly, 'Monthly'),
    ];
    final range = _periodRange;
    final label = _period == _ExpensePeriod.daily
        ? MaterialLocalizations.of(context).formatMediumDate(_selectedDate)
        : '${MaterialLocalizations.of(context).formatMediumDate(range.start)} – '
              '${MaterialLocalizations.of(context).formatMediumDate(range.end.subtract(const Duration(days: 1)))}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SegmentedButton<_ExpensePeriod>(
              segments: [
                for (final (period, label) in items)
                  ButtonSegment(value: period, label: Text(label)),
              ],
              selected: {_period},
              onSelectionChanged: (selected) =>
                  setState(() => _period = selected.first),
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
  final double estimatedProfit;
  final bool hasMissingCost;
  final int expenseCount;

  const _FinancialSummary({
    required this.sales,
    required this.costOfGoods,
    required this.expenses,
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
              'Profit = sales − inventory cost − expenses',
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
  final Future<void> Function(
    String category,
    String description,
    double amount,
    DateTime date,
    String? reason,
  )
  onSave;

  const _ExpenseFormSheet({required this.initial, required this.onSave});

  @override
  State<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<_ExpenseFormSheet> {
  static const _categories = [
    'Utilities',
    'Rent',
    'Supplies',
    'Transportation',
    'Salaries',
    'Maintenance',
    'Other',
  ];
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late final TextEditingController _reasonController;
  late String _category;
  late DateTime _date;
  bool _saving = false;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _category = initial?.category ?? _categories.first;
    _date = initial?.expenseDate ?? DateTime.now();
    _descriptionController = TextEditingController(text: initial?.description);
    _amountController = TextEditingController(
      text: initial?.amount.toStringAsFixed(2),
    );
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _reasonController.dispose();
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
    setState(() => _saving = true);
    try {
      await widget.onSave(
        _category,
        _descriptionController.text.trim(),
        amount,
        _date,
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
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Description is required.'
                    : null,
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
