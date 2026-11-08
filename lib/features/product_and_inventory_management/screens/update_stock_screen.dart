import 'package:flutter/material.dart';

import '../../products/domain/product.dart';
import '../../products/presentation/controllers.dart';
import '../models/expiration_model.dart';
import '../services/expiration_service.dart';

class UpdateStockScreen extends StatefulWidget {
  final ProductController? productController;
  final ExpirationService service;
  final String? defaultProductId;
  final String? defaultRecordId;

  const UpdateStockScreen({
    super.key,
    this.productController,
    this.service = const ExpirationService(),
    this.defaultProductId,
    this.defaultRecordId,
  });

  @override
  State<UpdateStockScreen> createState() => _UpdateStockScreenState();
}

class _UpdateStockScreenState extends State<UpdateStockScreen> {
  String? _selectedProductId;
  String? _selectedRecordId;
  StockMovementType _movementType = StockMovementType.sold;
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final Map<String, List<ExpirationModel>> _recordsByProduct =
      <String, List<ExpirationModel>>{};

  @override
  void initState() {
    super.initState();
    _selectedProductId =
        widget.defaultProductId ??
        (widget.productController?.state.products.isNotEmpty ?? false
            ? widget.productController!.state.products.first.id
            : null);
    _selectedRecordId = widget.defaultRecordId;
    _refreshRecords();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _refreshRecords() async {
    final products =
        widget.productController?.state.products ?? const <ProductModel>[];
    _recordsByProduct.clear();
    for (final product in products) {
      _recordsByProduct[product.id] = await widget.service.getByProduct(
        product.id,
        products: products,
      );
    }
    if (!mounted) return;
    setState(() {
      if (_selectedProductId == null && products.isNotEmpty) {
        _selectedProductId = products.first.id;
      }
      if (_selectedProductId != null &&
          !_recordsByProduct.containsKey(_selectedProductId)) {
        _selectedProductId = products.isEmpty ? null : products.first.id;
      }
      final available = _availableRecords;
      if (available.isEmpty) {
        _selectedRecordId = null;
      } else if (_selectedRecordId == null ||
          available.every((record) => record.id != _selectedRecordId)) {
        _selectedRecordId = available.first.id;
      }
    });
  }

  List<ExpirationModel> get _availableRecords {
    if (_selectedProductId == null) return const <ExpirationModel>[];
    return _recordsByProduct[_selectedProductId] ?? const <ExpirationModel>[];
  }

  ExpirationModel? get _selectedRecord {
    for (final record in _availableRecords) {
      if (record.id == _selectedRecordId) return record;
    }
    return null;
  }

  Future<void> _save() async {
    final available = _availableRecords;
    if (_selectedRecordId == null ||
        available.isEmpty ||
        available.every((record) => record.id != _selectedRecordId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a valid product batch first.')),
      );
      return;
    }
    final value = int.tryParse(_quantityController.text.trim());
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity must be greater than zero.')),
      );
      return;
    }
    try {
      await widget.service.updateStock(
        recordId: _selectedRecordId!,
        movementType: _movementType,
        quantity: value,
        remarks: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock updated successfully.')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final products =
        widget.productController?.state.products ?? const <ProductModel>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Update Stock')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedProductId,
              decoration: const InputDecoration(labelText: 'Product'),
              items: products
                  .map(
                    (product) => DropdownMenuItem(
                      value: product.id,
                      child: Text(product.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedProductId = value;
                  _selectedRecordId = _availableRecords.isNotEmpty
                      ? _availableRecords.first.id
                      : null;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey(_selectedProductId),
              initialValue: _selectedRecordId,
              decoration: const InputDecoration(labelText: 'Batch'),
              items: _availableRecords
                  .map(
                    (record) => DropdownMenuItem(
                      value: record.id,
                      child: Text(
                        '${record.batchIdentifier} (${record.remainingQuantity} left)',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedRecordId = value),
            ),
            if (_selectedRecord != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Available batch stock: ${_selectedRecord!.remainingQuantity}',
                ),
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<StockMovementType>(
              initialValue: _movementType,
              decoration: const InputDecoration(labelText: 'Transaction Type'),
              items: StockMovementType.values
                  .map(
                    (type) =>
                        DropdownMenuItem(value: type, child: Text(type.label)),
                  )
                  .toList(),
              onChanged: (value) => setState(
                () => _movementType = value ?? StockMovementType.sold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity'),
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
              icon: const Icon(Icons.sync_alt_rounded),
              label: const Text('Update Stock'),
            ),
          ],
        ),
      ),
    );
  }
}
