import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../products/domain/product.dart';
import '../models/sales_transaction_record.dart';
import '../services/sales_in_one_service.dart';
import 'receipt_screen.dart';
import '../../customer_credit_and_debit_tracking/models/credit_records.dart';
import '../../customer_credit_and_debit_tracking/services/credit_tracking_service.dart';

class SalesPaymentScreen extends StatefulWidget {
  final Map<String, int> quantities;
  final List<ProductModel> products;
  final SalesInOneService saleService;

  const SalesPaymentScreen({
    super.key,
    required this.quantities,
    required this.products,
    required this.saleService,
  });

  @override
  State<SalesPaymentScreen> createState() => _SalesPaymentScreenState();
}

class _SalesPaymentScreenState extends State<SalesPaymentScreen> {
  late final TextEditingController _amountController;
  final String _transactionId = 'BZT-${DateTime.now().microsecondsSinceEpoch}';
  String _paymentMethod = 'Cash';
  bool _submitting = false;
  List<CreditCustomer> _customers = const [];
  CreditCustomer? _creditCustomer;
  Map<String, double> _outstandingBalances = const {};
  bool _loadingCustomers = false;
  String _customerSearch = '';

  CreditTrackingService get _creditService => widget.saleService.creditService;

  int get _totalCents {
    final prices = {
      for (final product in widget.products)
        product.id: (product.sellingPrice * 100).round(),
    };
    return widget.quantities.entries.fold(
      0,
      (sum, entry) => sum + (prices[entry.key] ?? 0) * entry.value,
    );
  }

  double get _total => _totalCents / 100;

  double get _amountPaid {
    final amount = double.tryParse(_amountController.text.trim());
    return amount != null && amount.isFinite ? amount : 0;
  }

  double get _changeDue => _paymentMethod == 'Cash'
      ? (_amountPaid - _total).clamp(0, double.infinity)
      : 0;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: _total.toStringAsFixed(2));
  }

  Future<void> _loadCustomers() async {
    setState(() => _loadingCustomers = true);
    try {
      final results = await Future.wait([
        _creditService.loadCustomers(),
        _creditService.loadCredits(),
      ]);
      final customers = results[0] as List<CreditCustomer>;
      final credits = results[1] as List<CreditAccount>;
      final balances = <String, double>{};
      for (final credit in credits) {
        balances.update(
          credit.customerId,
          (balance) => balance + credit.outstandingBalance,
          ifAbsent: () => credit.outstandingBalance,
        );
      }
      if (mounted) {
        setState(() {
          _customers = customers;
          _outstandingBalances = balances;
        });
      }
    } catch (error) {
      if (mounted) _showError('Could not load credit accounts: $error');
    } finally {
      if (mounted) setState(() => _loadingCustomers = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _completeSale() async {
    if (_submitting) return;
    final amountPaid = _paymentMethod == 'Credit'
        ? 0.0
        : double.tryParse(_amountController.text.trim());
    if (amountPaid == null || !amountPaid.isFinite) {
      _showError('Enter a valid payment amount.');
      return;
    }
    if (_paymentMethod == 'Credit' && _creditCustomer == null) {
      _showError('Select or register a customer for credit payment.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final transaction = await widget.saleService.completeSale(
        quantities: widget.quantities,
        amountPaid: amountPaid,
        paymentMethod: _paymentMethod,
        transactionId: _transactionId,
        creditCustomer: _creditCustomer,
        initialCreditPayment: 0,
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ReceiptScreen(transaction: transaction),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _registerCustomer() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final customer = await showDialog<CreditCustomer>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add New Credit Account'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const ValueKey('credit-name'),
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Customer Name *',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Customer name is required.'
                      : null,
                ),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Contact Number',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final created = await _creditService.addCustomer(
                  fullName: nameController.text,
                  phone: phoneController.text,
                  address: addressController.text,
                  notes: '',
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, created);
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Could not create account: $error')),
                  );
                }
              }
            },
            child: const Text('Register Customer'),
          ),
        ],
      ),
    );
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    if (!mounted || customer == null) return;
    setState(() {
      _customers = [..._customers, customer]
        ..sort(
          (first, second) => first.fullName.toLowerCase().compareTo(
            second.fullName.toLowerCase(),
          ),
        );
      _creditCustomer = customer;
      _outstandingBalances = {..._outstandingBalances, customer.id: 0};
    });
  }

  @override
  Widget build(BuildContext context) {
    const teal = AppColors.forestGreen;
    const yellow = AppColors.gold;
    final pageBackground = AppColors.background;

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: teal,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('Payment'),
        leading: IconButton(
          tooltip: 'Back to cart',
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            children: [
              Row(
                children: [
                  Text(
                    'Payment Method',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'TOTAL  ${formatSalesCurrency(_total)}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: teal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: SalesInOneService.paymentMethods.map((method) {
                  final selected = _paymentMethod == method;
                  return ChoiceChip(
                    label: Text(method),
                    selected: selected,
                    showCheckmark: false,
                    selectedColor: yellow,
                    backgroundColor: AppColors.white,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : teal,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: _submitting
                        ? null
                        : (value) {
                            if (!value) return;
                            setState(() {
                              _paymentMethod = method;
                              if (method != 'Cash') {
                                _amountController.text = _total.toStringAsFixed(
                                  2,
                                );
                              }
                            });
                            if (method == 'Credit') {
                              _loadCustomers();
                            }
                          },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              if (_paymentMethod == 'Credit') ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Credit Account',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        if (_loadingCustomers)
                          const LinearProgressIndicator()
                        else ...[
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'Search customer',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (value) =>
                                setState(() => _customerSearch = value),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<CreditCustomer>(
                            initialValue:
                                _customers.any(
                                  (customer) =>
                                      customer.id == _creditCustomer?.id,
                                )
                                ? _creditCustomer
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Select customer',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final customer in _customers.where(
                                (customer) =>
                                    _customerSearch.trim().isEmpty ||
                                    customer.fullName.toLowerCase().contains(
                                      _customerSearch.trim().toLowerCase(),
                                    ),
                              ))
                                DropdownMenuItem(
                                  value: customer,
                                  child: Text(customer.fullName),
                                ),
                            ],
                            onChanged: _submitting
                                ? null
                                : (customer) => setState(
                                    () => _creditCustomer = customer,
                                  ),
                          ),
                        ],
                        if (_creditCustomer != null) ...[
                          const SizedBox(height: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Customer: ${_creditCustomer!.fullName}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_creditCustomer!.phone.isNotEmpty)
                                Text('Phone: ${_creditCustomer!.phone}'),
                              if (_creditCustomer!.address.isNotEmpty)
                                Text('Address: ${_creditCustomer!.address}'),
                              Text(
                                'Existing outstanding balance: ${formatSalesCurrency(_outstandingBalances[_creditCustomer!.id] ?? 0)}',
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _submitting ? null : _registerCustomer,
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('ADD NEW CREDIT ACCOUNT'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x10000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.softGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: teal,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _paymentMethod == 'Credit'
                                ? 'Total Amount Owed'
                                : 'Total Amount',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatSalesCurrency(_total),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: teal,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_paymentMethod == 'Credit') ...[
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Payment Status'),
                    trailing: Chip(
                      label: const Text('UNPAID'),
                      backgroundColor: AppColors.softGreen,
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 22),
                Text(
                  'Payment Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('amount-paid'),
                  controller: _amountController,
                  enabled: !_submitting,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Amount Received',
                    prefixText: '₱ ',
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.softGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Change',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        formatSalesCurrency(_changeDue),
                        key: const ValueKey('change-due'),
                        style: const TextStyle(
                          color: teal,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: teal,
                        backgroundColor: AppColors.softGreen,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submitting ? null : _completeSale,
                      style: FilledButton.styleFrom(
                        backgroundColor: yellow,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _submitting
                            ? _paymentMethod == 'Credit'
                                  ? 'Saving Credit Sale'
                                  : 'Saving Sale'
                            : _paymentMethod == 'Credit'
                            ? 'Complete Credit Sale'
                            : 'Complete Sale',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
