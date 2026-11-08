import 'package:flutter/material.dart';

import '../../products/domain/product.dart';

class ExpirationForm extends StatefulWidget {
  final List<ProductModel> products;
  final DateTime? initialDate;
  final String? initialBatchIdentifier;
  final String? initialNotes;
  final int? initialQuantity;
  final String? initialProductId;
  final String? submitLabel;
  final bool allowProductSelection;
  final Future<void> Function({
    required String productId,
    required DateTime expirationDate,
    required int quantity,
    String batchIdentifier,
    String? notes,
  })
  onSubmit;

  const ExpirationForm({
    super.key,
    required this.products,
    this.initialDate,
    this.initialBatchIdentifier,
    this.initialNotes,
    this.initialQuantity,
    this.initialProductId,
    this.submitLabel,
    this.allowProductSelection = true,
    required this.onSubmit,
  });

  @override
  State<ExpirationForm> createState() => _ExpirationFormState();
}

class _ExpirationFormState extends State<ExpirationForm> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedProductId;
  DateTime? _expirationDate;
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _batchController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  void _syncInitialState() {
    final nextProductId =
        widget.initialProductId ??
        (widget.products.isEmpty ? null : widget.products.first.id);
    if (nextProductId != null &&
        (widget.products.isEmpty ||
            widget.products.any((product) => product.id == nextProductId))) {
      _selectedProductId = nextProductId;
    } else if (widget.products.isNotEmpty) {
      _selectedProductId = widget.products.first.id;
    } else {
      _selectedProductId = null;
    }

    if (widget.initialDate != null) {
      _expirationDate = widget.initialDate;
    } else if (widget.initialDate == null && _expirationDate != null) {
      _expirationDate = null;
    }

    if (widget.initialQuantity != null) {
      _quantityController.text = widget.initialQuantity.toString();
    } else if (_quantityController.text.isEmpty &&
        widget.initialQuantity == null) {
      _quantityController.clear();
    }

    final nextBatchIdentifier = widget.initialBatchIdentifier ?? '';
    if (_batchController.text != nextBatchIdentifier) {
      _batchController.text = nextBatchIdentifier;
    }

    final nextNotes = widget.initialNotes ?? '';
    if (_notesController.text != nextNotes) {
      _notesController.text = nextNotes;
    }
  }

  @override
  void initState() {
    super.initState();
    _syncInitialState();
  }

  @override
  void didUpdateWidget(covariant ExpirationForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialProductId != widget.initialProductId ||
        oldWidget.initialDate != widget.initialDate ||
        oldWidget.initialBatchIdentifier != widget.initialBatchIdentifier ||
        oldWidget.initialNotes != widget.initialNotes ||
        oldWidget.initialQuantity != widget.initialQuantity ||
        oldWidget.products != widget.products) {
      _syncInitialState();
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _batchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity must be greater than zero.')),
      );
      return;
    }
    if (_selectedProductId == null || _expirationDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete the required fields.')),
      );
      return;
    }

    await widget.onSubmit(
      productId: _selectedProductId!,
      expirationDate: _expirationDate!,
      quantity: quantity,
      batchIdentifier: _batchController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedProductId,
            decoration: const InputDecoration(labelText: 'Product'),
            items: widget.products
                .map(
                  (product) => DropdownMenuItem(
                    value: product.id,
                    child: Text('${product.name} (${product.id})'),
                  ),
                )
                .toList(),
            onChanged: widget.allowProductSelection
                ? (value) => setState(() => _selectedProductId = value)
                : null,
            validator: (value) =>
                value == null || value.isEmpty ? 'Select a product.' : null,
          ),
          const SizedBox(height: 16),
          FormField<DateTime>(
            initialValue: _expirationDate,
            validator: (value) =>
                value == null ? 'Expiration date is required.' : null,
            builder: (field) => InkWell(
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: field.value ?? now,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  field.didChange(picked);
                  setState(() => _expirationDate = picked);
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Expiration Date',
                  border: const OutlineInputBorder(),
                  errorText: field.errorText,
                ),
                child: Text(
                  field.value == null
                      ? 'Choose date'
                      : '${field.value!.day}/${field.value!.month}/${field.value!.year}',
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Initial Quantity'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Quantity is required.';
              }
              if (int.tryParse(value.trim()) == null ||
                  int.parse(value.trim()) <= 0) {
                return 'Quantity must be greater than zero.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _batchController,
            decoration: const InputDecoration(
              labelText: 'Batch Identifier (optional)',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_rounded),
            label: Text(widget.submitLabel ?? 'Save'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
