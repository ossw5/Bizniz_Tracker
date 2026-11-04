import 'package:flutter/material.dart';

import '../../products/domain/product.dart';

class InventoryProductThumbnail extends StatelessWidget {
  final String productName;
  final double size;

  const InventoryProductThumbnail({
    super.key,
    required this.productName,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmedName = productName.trim();
    final productAsset = _sampleAssetForName(trimmedName);
    final initial = trimmedName.isEmpty
        ? null
        : String.fromCharCode(trimmedName.runes.first).toUpperCase();

    return Semantics(
      label: productAsset == null
          ? 'Image placeholder for ${trimmedName.isEmpty ? 'product' : trimmedName}'
          : 'Product image for $trimmedName',
      image: true,
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: productAsset != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    productAsset,
                    fit: BoxFit.contain,
                    width: size,
                    height: size,
                  ),
                )
              : initial == null
              ? Icon(
                  Icons.inventory_2_outlined,
                  color: theme.colorScheme.primary,
                )
              : Text(
                  initial,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }

  String? _sampleAssetForName(String name) {
    final normalizedName = name.toLowerCase();
    if (normalizedName.contains('lucky me') ||
        normalizedName.contains('pancit canton')) {
      return 'assets/product_samples/lucky_pancit_canton.png';
    }
    if (normalizedName.contains('milk') || normalizedName.contains('netle')) {
      return 'assets/product_samples/fresh_milk.png';
    }
    if (normalizedName.contains('gardenia')) {
      return 'assets/product_samples/gardenia_bread.png';
    }
    if (normalizedName.contains('coca-cola') ||
        normalizedName.contains('coca cola') ||
        normalizedName.contains('coke')) {
      return 'assets/product_samples/coca_cola.png';
    }
    if (normalizedName.contains('century') || normalizedName.contains('tuna')) {
      return 'assets/product_samples/century_tuna.png';
    }
    if (normalizedName.contains('chips ahoy')) {
      return 'assets/product_samples/chips_ahoy.png';
    }
    if (normalizedName.contains('milo')) {
      return 'assets/product_samples/milo.png';
    }
    if (normalizedName.contains('yakult')) {
      return 'assets/product_samples/yakult.png';
    }
    if (normalizedName.contains('tide')) {
      return 'assets/product_samples/tide.png';
    }
    if (normalizedName.contains('nescafe') ||
        normalizedName.contains('nescafé')) {
      return 'assets/product_samples/nescafe.png';
    }
    return null;
  }
}

class InventoryAlertProductCard extends StatelessWidget {
  final ProductModel product;
  final String? subtitle;
  final String? status;

  const InventoryAlertProductCard({
    super.key,
    required this.product,
    this.subtitle,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = product.quantity <= 0 ? Colors.red : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            InventoryProductThumbnail(productName: product.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (product.category.trim().isNotEmpty)
                    Text(product.category, style: theme.textTheme.bodySmall),
                  if (subtitle != null)
                    Text(subtitle!, style: theme.textTheme.bodySmall),
                  if (status != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        status!,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'QTY: ${product.quantity}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (product.minStock > 0)
                  Text(
                    'MIN: ${product.minStock}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
