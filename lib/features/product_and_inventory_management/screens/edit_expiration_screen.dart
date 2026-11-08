import 'package:flutter/material.dart';

import '../../products/presentation/controllers.dart';
import '../models/expiration_model.dart';
import '../services/expiration_service.dart';
import '../widgets/expiration_form.dart';

class EditExpirationScreen extends StatefulWidget {
  final ExpirationModel record;
  final ProductController? productController;
  final ExpirationService service;

  const EditExpirationScreen({
    super.key,
    required this.record,
    this.productController,
    this.service = const ExpirationService(),
  });

  @override
  State<EditExpirationScreen> createState() => _EditExpirationScreenState();
}

class _EditExpirationScreenState extends State<EditExpirationScreen> {
  bool _saving = false;

  Future<void> _save({
    required String productId,
    required DateTime expirationDate,
    required int quantity,
    String batchIdentifier = '',
    String? notes,
  }) async {
    try {
      if (productId != widget.record.productId) {
        throw StateError('A batch cannot be reassigned to another product.');
      }
      if (quantity < widget.record.remainingQuantity) {
        throw StateError(
          'Initial quantity cannot be lower than the current remaining quantity (${widget.record.remainingQuantity}).',
        );
      }
      setState(() => _saving = true);
      final updated = widget.record.copyWith(
        expirationDate: expirationDate,
        initialQuantity: quantity,
        batchIdentifier: batchIdentifier,
        notes: notes,
        clearNotes: notes == null,
      );
      await widget.service.updateRecord(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expiration details updated.')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.productController?.state.products ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Expiration Details')),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : ExpirationForm(
              products: products,
              initialDate: widget.record.expirationDate,
              initialBatchIdentifier: widget.record.batchIdentifier,
              initialNotes: widget.record.notes,
              initialQuantity: widget.record.initialQuantity,
              initialProductId: widget.record.productId,
              submitLabel: 'Update',
              allowProductSelection: false,
              onSubmit: _save,
            ),
    );
  }
}
