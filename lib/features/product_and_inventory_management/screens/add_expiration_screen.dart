import 'package:flutter/material.dart';

import '../../products/domain/product.dart';
import '../../products/presentation/controllers.dart';
import '../services/expiration_service.dart';
import '../widgets/expiration_form.dart';

class AddExpirationScreen extends StatefulWidget {
  final ProductController? productController;
  final ExpirationService service;
  final String? initialProductId;

  const AddExpirationScreen({
    super.key,
    this.productController,
    this.service = const ExpirationService(),
    this.initialProductId,
  });

  @override
  State<AddExpirationScreen> createState() => _AddExpirationScreenState();
}

class _AddExpirationScreenState extends State<AddExpirationScreen> {
  bool _saving = false;

  Future<void> _save({
    required String productId,
    required DateTime expirationDate,
    required int quantity,
    String batchIdentifier = '',
    String? notes,
  }) async {
    final products =
        widget.productController?.state.products ?? const <ProductModel>[];
    ProductModel? product;
    for (final item in products) {
      if (item.id == productId) {
        product = item;
        break;
      }
    }

    if (product == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid product.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.service.addRecord(
        product: product,
        expirationDate: expirationDate,
        initialQuantity: quantity,
        batchIdentifier: batchIdentifier,
        notes: notes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expiration record saved successfully.')),
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
    final products =
        widget.productController?.state.products ?? const <ProductModel>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Add Product Expiration')),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : ExpirationForm(
              products: products,
              initialProductId: widget.initialProductId,
              onSubmit: _save,
            ),
    );
  }
}
