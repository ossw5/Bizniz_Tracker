import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/controllers.dart';
import '../../sales/domain/sale.dart';
import '../../sales/domain/sale_repository.dart';
import '../../sales_management/models/sales_transaction_record.dart';
import '../models/credit_records.dart';
import '../services/credit_tracking_service.dart';

class CreditDebitTrackingScreen extends StatefulWidget {
  final ProductController? productController;
  final SaleRepository? saleRepository;
  final CreditTrackingService service;

  const CreditDebitTrackingScreen({
    super.key,
    required this.productController,
    required this.saleRepository,
    this.service = const CreditTrackingService(),
  });

  @override
  State<CreditDebitTrackingScreen> createState() =>
      _CreditDebitTrackingScreenState();
}

class _CreditDebitTrackingScreenState extends State<CreditDebitTrackingScreen> {
  late Future<_CreditDashboardData> _dashboard;

  @override
  void initState() {
    super.initState();
    _dashboard = _loadDashboard();
  }

  Future<_CreditDashboardData> _loadDashboard() async {
    final results = await Future.wait([
      widget.service.loadCustomers(),
      widget.service.loadCredits(),
    ]);
    return _CreditDashboardData(
      customers: results[0] as List<CreditCustomer>,
      credits: results[1] as List<CreditAccount>,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _dashboard = _loadDashboard();
    });
    await _dashboard;
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) await _refresh();
  }

  Future<void> _registerCustomer() async {
    await _open(_CustomerRegistrationScreen(service: widget.service));
  }

  Future<void> _startCredit(List<CreditCustomer> customers) async {
    if (widget.productController == null || widget.saleRepository == null) {
      _showMessage('Products and sales are not connected to credit tracking.');
      return;
    }
    if (customers.isEmpty) {
      _showMessage('Register a customer before adding a credit transaction.');
      return;
    }
    await _open(
      _CreditTransactionScreen(
        customers: customers,
        productController: widget.productController!,
        saleRepository: widget.saleRepository!,
        service: widget.service,
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Credit and Debit Tracking'),
        actions: [
          IconButton(
            tooltip: 'Refresh credit tracking',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_CreditDashboardData>(
        future: _dashboard,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _LoadError(
              message:
                  'Could not load customer credit records: ${snapshot.error}',
              onRetry: _refresh,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final activeCredits = data.credits
              .where((credit) => !credit.isSettled)
              .toList();
          final totalOutstanding = activeCredits.fold<double>(
            0,
            (total, credit) => total + credit.outstandingBalance,
          );
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _OutstandingOverview(
                  balance: totalOutstanding,
                  accountCount: activeCredits.length,
                  customerCount: data.customers.length,
                ),
                const SizedBox(height: 20),
                Text(
                  'Manage customer credit',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _ActionCard(
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'Customer Registration',
                  subtitle: 'Save customer contact details',
                  onTap: _registerCustomer,
                ),
                const SizedBox(height: 10),
                _ActionCard(
                  icon: Icons.add_shopping_cart_rounded,
                  title: 'Credit Transaction',
                  subtitle: 'Record an item sale with a due date',
                  onTap: () => _startCredit(data.customers),
                ),
                const SizedBox(height: 10),
                _ActionCard(
                  icon: Icons.payments_rounded,
                  title: 'Payment Recording',
                  subtitle: 'Record partial or full payments',
                  onTap: () =>
                      _open(_PaymentRecordingScreen(service: widget.service)),
                ),
                const SizedBox(height: 18),
                Text(
                  'Accounts and reports',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _ActionCard(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Outstanding Balance',
                  subtitle: 'Review balances and correct account records',
                  onTap: () => _open(
                    _OutstandingBalancesScreen(service: widget.service),
                  ),
                ),
                const SizedBox(height: 10),
                _ActionCard(
                  icon: Icons.history_rounded,
                  title: 'Payment History',
                  subtitle: 'Review recorded customer payments',
                  onTap: () =>
                      _open(_PaymentHistoryScreen(service: widget.service)),
                ),
                const SizedBox(height: 10),
                _ActionCard(
                  icon: Icons.event_available_rounded,
                  title: 'Due-Date Tracking',
                  subtitle: 'See upcoming, overdue, and settled credits',
                  onTap: () =>
                      _open(_DueDateTrackingScreen(service: widget.service)),
                ),
                const SizedBox(height: 10),
                _ActionCard(
                  icon: Icons.receipt_long_rounded,
                  title: 'Customer Statement',
                  subtitle: 'View credit and payment activity by customer',
                  onTap: () =>
                      _open(_CustomerStatementScreen(service: widget.service)),
                ),
                const SizedBox(height: 10),
                _ActionCard(
                  icon: Icons.rule_rounded,
                  title: 'Balance Corrections',
                  subtitle: 'Review authorized balance changes',
                  onTap: () =>
                      _open(_BalanceCorrectionsScreen(service: widget.service)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CreditDashboardData {
  final List<CreditCustomer> customers;
  final List<CreditAccount> credits;

  const _CreditDashboardData({required this.customers, required this.credits});
}

class _OutstandingOverview extends StatelessWidget {
  final double balance;
  final int accountCount;
  final int customerCount;

  const _OutstandingOverview({
    required this.balance,
    required this.accountCount,
    required this.customerCount,
  });

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.softGreen,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total outstanding balance',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            formatSalesCurrency(balance),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.forestGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$accountCount open ${accountCount == 1 ? 'account' : 'accounts'} · '
            '$customerCount ${customerCount == 1 ? 'customer' : 'customers'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.softGreen,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: AppColors.forestGreen),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleSmall),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}

class _CustomerRegistrationScreen extends StatefulWidget {
  final CreditTrackingService service;

  const _CustomerRegistrationScreen({required this.service});

  @override
  State<_CustomerRegistrationScreen> createState() =>
      _CustomerRegistrationScreenState();
}

class _CustomerRegistrationScreenState
    extends State<_CustomerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.service.addCustomer(
        fullName: _name.text,
        phone: _phone.text,
        address: _address.text,
        notes: _notes.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not register customer: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Customer Registration')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Full name *'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Enter a name.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone (optional)'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _address,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Address (optional)'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notes,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: Text(_saving ? 'Saving...' : 'Register Customer'),
          ),
        ],
      ),
    ),
  );
}

class _CreditTransactionScreen extends StatefulWidget {
  final List<CreditCustomer> customers;
  final ProductController productController;
  final SaleRepository saleRepository;
  final CreditTrackingService service;

  const _CreditTransactionScreen({
    required this.customers,
    required this.productController,
    required this.saleRepository,
    required this.service,
  });

  @override
  State<_CreditTransactionScreen> createState() =>
      _CreditTransactionScreenState();
}

class _CreditTransactionScreenState extends State<_CreditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController(text: '1');
  final _price = TextEditingController();
  CreditCustomer? _customer;
  ProductModel? _product;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  bool _saving = false;

  List<ProductModel> get _availableProducts => widget
      .productController
      .state
      .products
      .where((product) => product.quantity > 0)
      .toList(growable: false);

  int get _quantityValue => int.tryParse(_quantity.text.trim()) ?? 0;
  double get _priceValue => double.tryParse(_price.text.trim()) ?? 0;
  double get _total => (_quantityValue * _priceValue * 100).round() / 100;

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  void _selectProduct(ProductModel? product) {
    setState(() {
      _product = product;
      _price.text = product?.sellingPrice.toStringAsFixed(2) ?? '';
    });
  }

  Future<void> _selectDueDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate.isBefore(now) ? now : _dueDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10),
    );
    if (selected != null) setState(() => _dueDate = selected);
  }

  Future<void> _saveCredit() async {
    if (!_formKey.currentState!.validate() ||
        _customer == null ||
        _product == null) {
      return;
    }
    final product = _product!;
    final quantity = _quantityValue;
    if (quantity > product.quantity) {
      _showError('Only ${product.quantity} units are available.');
      return;
    }
    setState(() => _saving = true);
    final transactionId =
        'credit-${DateTime.now().microsecondsSinceEpoch}-${_customer!.id}';
    ProductModel? inventoryBefore;
    Sale? sale;
    var inventoryUpdated = false;
    var saleSaved = false;
    var transactionCompleted = false;
    CreditAccount? credit;
    try {
      final currentProductResult = await widget.productController.repository
          .getProductById(product.id);
      inventoryBefore = currentProductResult.fold<ProductModel>(
        (failure) => throw StateError(failure.message),
        (currentProduct) => currentProduct,
      );
      if (quantity > inventoryBefore.quantity) {
        throw StateError(
          'Only ${inventoryBefore.quantity} units are currently available.',
        );
      }
      final transactionDate = DateTime.now();
      sale = Sale(
        id: '$transactionId-${inventoryBefore.id}',
        transactionId: transactionId,
        receiptNumber: transactionId,
        productId: inventoryBefore.id,
        productNameAtSale: inventoryBefore.name,
        productCostAtSale: inventoryBefore.costPrice,
        quantitySold: quantity,
        sellingPrice: _priceValue,
        saleDate: transactionDate,
        totalRevenue: _total,
        subtotal: _total,
        discount: 0,
        transactionTotal: _total,
        amountPaid: 0,
        changeDue: 0,
        paymentMethod: 'Credit',
      );
      final updatedProduct = inventoryBefore.copyWith(
        quantity: inventoryBefore.quantity - quantity,
      );
      final inventoryResult = await widget.productController.repository
          .updateProduct(updatedProduct);
      inventoryResult.fold<void>(
        (failure) => throw StateError(failure.message),
        (_) => inventoryUpdated = true,
      );
      await widget.saleRepository.addSale(sale);
      saleSaved = true;
      credit = await widget.service.addCredit(
        customer: _customer!,
        saleId: transactionId,
        itemName: inventoryBefore.name,
        quantity: quantity,
        unitPrice: _priceValue,
        creditDate: transactionDate,
        dueDate: _dueDate,
      );
      await widget.productController.loadProducts();
      if (!mounted) return;
      transactionCompleted = true;
      Navigator.of(context).pop();
    } catch (error) {
      final rollbackErrors = <String>[];
      if (credit != null) {
        try {
          await widget.service.rollbackCredit(credit.id);
        } catch (rollbackError) {
          rollbackErrors.add('credit record: $rollbackError');
        }
      }
      if (saleSaved && sale != null) {
        try {
          if (!await widget.saleRepository.deleteSale(sale.id)) {
            rollbackErrors.add('sale record could not be removed');
          }
        } catch (rollbackError) {
          rollbackErrors.add('sale record: $rollbackError');
        }
      }
      if (inventoryUpdated && inventoryBefore != null) {
        try {
          final result = await widget.productController.repository
              .updateProduct(inventoryBefore);
          result.fold<void>(
            (failure) => rollbackErrors.add('inventory: ${failure.message}'),
            (_) {},
          );
          await widget.productController.loadProducts();
        } catch (rollbackError) {
          rollbackErrors.add('inventory: $rollbackError');
        }
      }
      if (!mounted) return;
      final message = rollbackErrors.isEmpty
          ? 'Could not save credit transaction: $error'
          : 'Could not save credit transaction: $error. '
                'Rollback issues: ${rollbackErrors.join('; ')}';
      _showError(message);
    } finally {
      if (mounted && !transactionCompleted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final products = _availableProducts;
    return Scaffold(
      appBar: AppBar(title: const Text('Credit Transaction')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<CreditCustomer>(
              initialValue: _customer,
              decoration: const InputDecoration(labelText: 'Select customer'),
              items: [
                for (final customer in widget.customers)
                  DropdownMenuItem(
                    value: customer,
                    child: Text(customer.fullName),
                  ),
              ],
              onChanged: (value) => setState(() => _customer = value),
              validator: (value) => value == null ? 'Select a customer.' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _product?.id,
              decoration: const InputDecoration(labelText: 'Item'),
              items: [
                for (final product in products)
                  DropdownMenuItem(
                    value: product.id,
                    child: Text(
                      '${product.name} · ${product.quantity} in stock',
                    ),
                  ),
              ],
              onChanged: (productId) {
                if (productId == null) {
                  _selectProduct(null);
                } else {
                  _selectProduct(
                    products.firstWhere((product) => product.id == productId),
                  );
                }
              },
              validator: (value) => value == null ? 'Select an item.' : null,
            ),
            if (products.isEmpty) ...[
              const SizedBox(height: 8),
              const Text('There are no in-stock products to add on credit.'),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _quantity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity'),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                final number = int.tryParse(value?.trim() ?? '');
                if (number == null || number <= 0) {
                  return 'Enter a quantity greater than zero.';
                }
                if (_product != null && number > _product!.quantity) {
                  return 'Only ${_product!.quantity} units are available.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Price per item'),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                final number = double.tryParse(value?.trim() ?? '');
                return number == null || !number.isFinite || number <= 0
                    ? 'Enter a valid price.'
                    : null;
              },
            ),
            const SizedBox(height: 16),
            _ValueCard(
              label: 'Total amount',
              value: formatSalesCurrency(_total),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.event_rounded),
                title: const Text('Due date'),
                subtitle: Text(_formatDate(_dueDate)),
                trailing: const Icon(Icons.calendar_month_rounded),
                onTap: _selectDueDate,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving || products.isEmpty ? null : _saveCredit,
              icon: const Icon(Icons.add_card_rounded),
              label: Text(_saving ? 'Saving...' : 'Add to Credit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentRecordingScreen extends StatefulWidget {
  final CreditTrackingService service;

  const _PaymentRecordingScreen({required this.service});

  @override
  State<_PaymentRecordingScreen> createState() =>
      _PaymentRecordingScreenState();
}

class _PaymentRecordingScreenState extends State<_PaymentRecordingScreen> {
  late Future<List<CreditAccount>> _credits;

  @override
  void initState() {
    super.initState();
    _credits = widget.service.loadCredits();
  }

  Future<void> _recordPayment(CreditAccount account) async {
    String method = 'Cash';
    String paymentAmount = '';
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Payment · ${account.customerName}'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LabeledValue(
                  label: 'Remaining balance',
                  value: formatSalesCurrency(account.outstandingBalance),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Amount paid'),
                  onSaved: (value) => paymentAmount = value?.trim() ?? '',
                  validator: (value) {
                    final entered = double.tryParse(value?.trim() ?? '');
                    if (entered == null || !entered.isFinite || entered <= 0) {
                      return 'Enter a valid payment amount.';
                    }
                    if ((entered * 100).round() >
                        (account.outstandingBalance * 100).round()) {
                      return 'Payment cannot exceed the balance.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(
                    labelText: 'Payment method',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'GCash', child: Text('GCash')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => method = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Record Payment'),
            ),
          ],
        ),
      ),
    );
    if (result != true) return;
    try {
      await widget.service.recordPayment(
        creditId: account.id,
        amount: double.parse(paymentAmount),
        paymentMethod: method,
      );
      if (!mounted) return;
      setState(() {
        _credits = widget.service.loadCredits();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment recorded and balance updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not record payment: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Payment Recording')),
    body: FutureBuilder<List<CreditAccount>>(
      future: _credits,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _LoadError(
            message: 'Could not load credit accounts: ${snapshot.error}',
            onRetry: () => setState(() {
              _credits = widget.service.loadCredits();
            }),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final accounts = snapshot.data!
            .where((account) => !account.isSettled)
            .toList();
        if (accounts.isEmpty) {
          return const _EmptyState(
            icon: Icons.payments_outlined,
            message: 'There are no outstanding credits to collect.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: accounts.length,
          itemBuilder: (context, index) {
            final account = accounts[index];
            return _CreditListTile(
              account: account,
              actionLabel: 'Record payment',
              onTap: () => _recordPayment(account),
            );
          },
        );
      },
    ),
  );
}

class _OutstandingBalancesScreen extends StatefulWidget {
  final CreditTrackingService service;

  const _OutstandingBalancesScreen({required this.service});

  @override
  State<_OutstandingBalancesScreen> createState() =>
      _OutstandingBalancesScreenState();
}

class _OutstandingBalancesScreenState
    extends State<_OutstandingBalancesScreen> {
  late Future<List<CreditAccount>> _credits;

  @override
  void initState() {
    super.initState();
    _credits = widget.service.loadCredits();
  }

  Future<void> _correctBalance(CreditAccount account) async {
    var correctedBalance = account.outstandingBalance.toStringAsFixed(2);
    var correctionDetails = '';
    var authorizer = '';
    String reason = 'Entry Error';
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Balance Correction'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LabeledValue(label: 'Customer', value: account.customerName),
                  const SizedBox(height: 10),
                  _LabeledValue(
                    label: 'Original balance',
                    value: formatSalesCurrency(account.outstandingBalance),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: correctedBalance,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Corrected balance',
                    ),
                    onSaved: (value) => correctedBalance = value?.trim() ?? '',
                    validator: (value) {
                      final parsed = double.tryParse(value?.trim() ?? '');
                      return parsed == null || !parsed.isFinite || parsed < 0
                          ? 'Enter a valid balance.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: reason,
                    decoration: const InputDecoration(labelText: 'Reason'),
                    items: const [
                      DropdownMenuItem(
                        value: 'Entry Error',
                        child: Text('Entry Error'),
                      ),
                      DropdownMenuItem(
                        value: 'Payment Not Recorded',
                        child: Text('Payment Not Recorded'),
                      ),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => reason = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Details (required)',
                    ),
                    onSaved: (value) => correctionDetails = value?.trim() ?? '',
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Explain the correction.'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Authorized by (required)',
                    ),
                    onSaved: (value) => authorizer = value?.trim() ?? '',
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter the authorizer.'
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Apply Correction'),
            ),
          ],
        ),
      ),
    );
    if (result != true) return;
    try {
      await widget.service.correctBalance(
        creditId: account.id,
        correctedBalance: double.parse(correctedBalance),
        reason: reason,
        details: correctionDetails,
        authorizedBy: authorizer,
      );
      if (mounted) {
        setState(() {
          _credits = widget.service.loadCredits();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Balance correction recorded.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not correct balance: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Outstanding Balance')),
    body: FutureBuilder<List<CreditAccount>>(
      future: _credits,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _LoadError(
            message: 'Could not load balances: ${snapshot.error}',
            onRetry: () => setState(() {
              _credits = widget.service.loadCredits();
            }),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final accounts = snapshot.data!;
        if (accounts.isEmpty) {
          return const _EmptyState(
            icon: Icons.account_balance_wallet_outlined,
            message: 'No credit balances have been recorded.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ValueCard(
              label: 'Total outstanding',
              value: formatSalesCurrency(
                accounts.fold<double>(
                  0,
                  (total, account) => total + account.outstandingBalance,
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final account in accounts)
              _CreditListTile(
                account: account,
                actionLabel: 'Correct balance',
                onTap: () => _correctBalance(account),
              ),
          ],
        );
      },
    ),
  );
}

class _PaymentHistoryScreen extends StatefulWidget {
  final CreditTrackingService service;

  const _PaymentHistoryScreen({required this.service});

  @override
  State<_PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<_PaymentHistoryScreen> {
  late Future<List<CreditPayment>> _payments;

  @override
  void initState() {
    super.initState();
    _payments = widget.service.loadPayments();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Payment History')),
    body: FutureBuilder<List<CreditPayment>>(
      future: _payments,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _LoadError(
            message: 'Could not load payment history: ${snapshot.error}',
            onRetry: () => setState(() {
              _payments = widget.service.loadPayments();
            }),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final payments = snapshot.data!;
        if (payments.isEmpty) {
          return const _EmptyState(
            icon: Icons.history_rounded,
            message: 'Recorded payments will appear here.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: payments.length,
          itemBuilder: (context, index) {
            final payment = payments[index];
            return Card(
              child: ListTile(
                leading: const Icon(
                  Icons.check_circle,
                  color: AppColors.freshGreen,
                ),
                title: Text(payment.customerName),
                subtitle: Text(
                  '${payment.paymentMethod} · ${_formatDate(payment.paymentDate)}',
                ),
                trailing: Text(
                  formatSalesCurrency(payment.amount),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class _DueDateTrackingScreen extends StatefulWidget {
  final CreditTrackingService service;

  const _DueDateTrackingScreen({required this.service});

  @override
  State<_DueDateTrackingScreen> createState() => _DueDateTrackingScreenState();
}

class _DueDateTrackingScreenState extends State<_DueDateTrackingScreen> {
  late Future<List<CreditAccount>> _credits;

  @override
  void initState() {
    super.initState();
    _credits = widget.service.loadCredits();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Due-Date Tracking')),
    body: FutureBuilder<List<CreditAccount>>(
      future: _credits,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _LoadError(
            message: 'Could not load due dates: ${snapshot.error}',
            onRetry: () => setState(() {
              _credits = widget.service.loadCredits();
            }),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final accounts = snapshot.data!
          ..sort((first, second) => first.dueDate.compareTo(second.dueDate));
        if (accounts.isEmpty) {
          return const _EmptyState(
            icon: Icons.event_available_rounded,
            message: 'Credit due dates will appear here.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final account in accounts)
              _CreditListTile(account: account, showDueStatus: true),
          ],
        );
      },
    ),
  );
}

class _CustomerStatementScreen extends StatefulWidget {
  final CreditTrackingService service;

  const _CustomerStatementScreen({required this.service});

  @override
  State<_CustomerStatementScreen> createState() =>
      _CustomerStatementScreenState();
}

class _CustomerStatementScreenState extends State<_CustomerStatementScreen> {
  CreditCustomer? _selected;
  late DateTime _periodStart;
  late DateTime _periodEnd;
  late Future<_StatementData> _data;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodStart = DateTime(now.year, now.month);
    _periodEnd = DateTime(now.year, now.month + 1, 0);
    _data = _load();
  }

  Future<_StatementData> _load() async {
    final values = await Future.wait([
      widget.service.loadCustomers(),
      widget.service.loadCredits(),
      widget.service.loadPayments(),
    ]);
    return _StatementData(
      customers: values[0] as List<CreditCustomer>,
      credits: values[1] as List<CreditAccount>,
      payments: values[2] as List<CreditPayment>,
    );
  }

  Future<void> _selectPeriod() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 10),
      initialDateRange: DateTimeRange(start: _periodStart, end: _periodEnd),
    );
    if (range != null) {
      setState(() {
        _periodStart = range.start;
        _periodEnd = range.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Customer Statement')),
    body: FutureBuilder<_StatementData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _LoadError(
            message: 'Could not load customer statement: ${snapshot.error}',
            onRetry: () => setState(() {
              _data = _load();
            }),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final selected =
            data.customers.any((customer) => customer.id == _selected?.id)
            ? _selected
            : (data.customers.isEmpty ? null : data.customers.first);
        final creditsInPeriod =
            selected == null
                  ? <CreditAccount>[]
                  : data.credits
                        .where(
                          (account) =>
                              account.customerId == selected.id &&
                              _isInPeriod(
                                account.creditDate,
                                _periodStart,
                                _periodEnd,
                              ),
                        )
                        .toList()
              ..sort(
                (first, second) =>
                    second.creditDate.compareTo(first.creditDate),
              );
        final customerCredits = selected == null
            ? <CreditAccount>[]
            : data.credits
                  .where((account) => account.customerId == selected.id)
                  .toList();
        final paymentsInPeriod =
            selected == null
                  ? <CreditPayment>[]
                  : data.payments
                        .where(
                          (payment) =>
                              payment.customerId == selected.id &&
                              _isInPeriod(
                                payment.paymentDate,
                                _periodStart,
                                _periodEnd,
                              ),
                        )
                        .toList()
              ..sort(
                (first, second) =>
                    second.paymentDate.compareTo(first.paymentDate),
              );
        final outstanding = customerCredits.fold<double>(
          0,
          (total, account) => total + account.outstandingBalance,
        );
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (data.customers.isEmpty)
              const _EmptyState(
                icon: Icons.person_outline_rounded,
                message: 'Register a customer to create a statement.',
              )
            else ...[
              DropdownButtonFormField<CreditCustomer>(
                initialValue: selected,
                decoration: const InputDecoration(labelText: 'Customer'),
                items: [
                  for (final customer in data.customers)
                    DropdownMenuItem(
                      value: customer,
                      child: Text(customer.fullName),
                    ),
                ],
                onChanged: (value) => setState(() => _selected = value),
              ),
              if (selected != null) ...[
                const SizedBox(height: 14),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.date_range_rounded),
                    title: const Text('Statement period'),
                    subtitle: Text(
                      '${_formatDate(_periodStart)} - ${_formatDate(_periodEnd)}',
                    ),
                    trailing: const Icon(Icons.calendar_month_rounded),
                    onTap: _selectPeriod,
                  ),
                ),
                if (selected.phone.isNotEmpty ||
                    selected.address.isNotEmpty ||
                    selected.notes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selected.fullName,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          if (selected.phone.isNotEmpty) Text(selected.phone),
                          if (selected.address.isNotEmpty)
                            Text(selected.address),
                          if (selected.notes.isNotEmpty) Text(selected.notes),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _StatementTotals(
                  credits: creditsInPeriod,
                  payments: paymentsInPeriod,
                  outstanding: outstanding,
                ),
                const SizedBox(height: 20),
                Text(
                  'Transactions in period',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (creditsInPeriod.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('No credit transactions in this period.'),
                  ),
                for (final credit in creditsInPeriod)
                  _CreditListTile(account: credit, showDueStatus: true),
                const SizedBox(height: 12),
                Text(
                  'Payments in period',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (paymentsInPeriod.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('No payments in this period.'),
                  ),
                for (final payment in paymentsInPeriod)
                  Card(
                    child: ListTile(
                      title: Text(payment.paymentMethod),
                      subtitle: Text(_formatDate(payment.paymentDate)),
                      trailing: Text(formatSalesCurrency(payment.amount)),
                    ),
                  ),
              ],
            ],
          ],
        );
      },
    ),
  );
}

class _StatementData {
  final List<CreditCustomer> customers;
  final List<CreditAccount> credits;
  final List<CreditPayment> payments;

  const _StatementData({
    required this.customers,
    required this.credits,
    required this.payments,
  });
}

class _StatementTotals extends StatelessWidget {
  final List<CreditAccount> credits;
  final List<CreditPayment> payments;
  final double outstanding;

  const _StatementTotals({
    required this.credits,
    required this.payments,
    required this.outstanding,
  });

  @override
  Widget build(BuildContext context) {
    final totalCredit = credits.fold<double>(
      0,
      (total, account) => total + account.originalAmount,
    );
    final totalPaid = payments.fold<double>(
      0,
      (total, payment) => total + payment.amount,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _LabeledValue(
              label: 'Credits',
              value: formatSalesCurrency(totalCredit),
            ),
            const Divider(height: 18),
            _LabeledValue(
              label: 'Payments',
              value: formatSalesCurrency(totalPaid),
            ),
            const Divider(height: 18),
            _LabeledValue(
              label: 'Balance',
              value: formatSalesCurrency(outstanding),
              emphasized: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCorrectionsScreen extends StatefulWidget {
  final CreditTrackingService service;

  const _BalanceCorrectionsScreen({required this.service});

  @override
  State<_BalanceCorrectionsScreen> createState() =>
      _BalanceCorrectionsScreenState();
}

class _BalanceCorrectionsScreenState extends State<_BalanceCorrectionsScreen> {
  late Future<List<BalanceCorrection>> _corrections;

  @override
  void initState() {
    super.initState();
    _corrections = widget.service.loadCorrections();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Balance Corrections')),
    body: FutureBuilder<List<BalanceCorrection>>(
      future: _corrections,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _LoadError(
            message: 'Could not load balance corrections: ${snapshot.error}',
            onRetry: () => setState(() {
              _corrections = widget.service.loadCorrections();
            }),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final corrections = snapshot.data!;
        if (corrections.isEmpty) {
          return const _EmptyState(
            icon: Icons.rule_rounded,
            message: 'Authorized balance corrections will appear here.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: corrections.length,
          itemBuilder: (context, index) {
            final correction = corrections[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      correction.customerName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatSalesCurrency(correction.originalBalance)} → '
                      '${formatSalesCurrency(correction.correctedBalance)}',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${correction.reason} · ${_formatDate(correction.changedAt)}',
                    ),
                    Text('Authorized by ${correction.authorizedBy}'),
                    Text(correction.details),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class _CreditListTile extends StatelessWidget {
  final CreditAccount account;
  final String? actionLabel;
  final VoidCallback? onTap;
  final bool showDueStatus;

  const _CreditListTile({
    required this.account,
    this.actionLabel,
    this.onTap,
    this.showDueStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    final dueStatus = _dueStatus(account);
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(account.customerName),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${account.quantity} × ${account.itemName}'),
              Text('Due ${_formatDate(account.dueDate)}'),
              if (showDueStatus)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: _StatusPill(
                    label: dueStatus.label,
                    color: dueStatus.color,
                  ),
                ),
              if (actionLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    actionLabel!,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.forestGreen,
                    ),
                  ),
                ),
              if (account.isSettled && actionLabel != null)
                const Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: _StatusPill(
                    label: 'Settled',
                    color: AppColors.freshGreen,
                  ),
                ),
            ],
          ),
        ),
        trailing: Text(
          formatSalesCurrency(account.outstandingBalance),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: account.isSettled ? AppColors.grey : AppColors.forestGreen,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DueStatus {
  final String label;
  final Color color;

  const _DueStatus(this.label, this.color);
}

_DueStatus _dueStatus(CreditAccount account) {
  if (account.isSettled) {
    return const _DueStatus('Settled', AppColors.freshGreen);
  }
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final due = DateTime(
    account.dueDate.year,
    account.dueDate.month,
    account.dueDate.day,
  );
  if (due.isBefore(todayDate)) {
    return const _DueStatus('Overdue', AppColors.error);
  }
  if (due.difference(todayDate).inDays <= 3) {
    return const _DueStatus('Due soon', AppColors.warning);
  }
  return const _DueStatus('Upcoming', AppColors.forestGreen);
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ValueCard extends StatelessWidget {
  final String label;
  final String value;

  const _ValueCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: _LabeledValue(label: label, value: value, emphasized: true),
    ),
  );
}

class _LabeledValue extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _LabeledValue({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      Text(
        value,
        style: emphasized
            ? Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.forestGreen,
                fontWeight: FontWeight.w700,
              )
            : Theme.of(context).textTheme.titleSmall,
      ),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.forestGreen, size: 44),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
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

String _formatDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

bool _isInPeriod(DateTime value, DateTime start, DateTime end) {
  final date = DateTime(value.year, value.month, value.day);
  final first = DateTime(start.year, start.month, start.day);
  final lastExclusive = DateTime(end.year, end.month, end.day + 1);
  return !date.isBefore(first) && date.isBefore(lastExclusive);
}
