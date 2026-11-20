import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../products/domain/product.dart';

class InventoryProductMonogram extends StatelessWidget {
  final String productName;
  final double size;

  const InventoryProductMonogram({
    super.key,
    required this.productName,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = productName.trim();
    final initial = name.isEmpty
        ? null
        : String.fromCharCode(name.runes.first).toUpperCase();
    final color = _colorForName(name);

    return Semantics(
      label: name.isEmpty ? 'Product' : 'Product $name',
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, color.withValues(alpha: 0.78)],
            ),
            borderRadius: BorderRadius.circular(size * 0.3),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.22),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (initial == null)
                Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.white,
                  size: size * 0.48,
                )
              else
                Text(
                  initial,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontSize: size * 0.42,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              Positioned(
                right: size * 0.12,
                bottom: size * 0.12,
                child: Container(
                  width: size * 0.13,
                  height: size * 0.13,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _colorForName(String name) {
    const palette = [
      AppColors.forestGreen,
      Color(0xFF426A86),
      Color(0xFF75608A),
      Color(0xFF8A642D),
    ];
    final seed = name.runes.fold<int>(0, (total, rune) => total + rune);
    return palette[seed % palette.length];
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
    final isOutOfStock = product.quantity <= 0;
    final statusColor = isOutOfStock
        ? theme.colorScheme.error
        : theme.colorScheme.secondary;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: statusColor, width: 3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              InventoryProductMonogram(productName: product.name),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (product.category.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        product.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (status != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(minWidth: 56),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'QTY',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.6,
                      ),
                    ),
                    Text(
                      '${product.quantity}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (product.minStock > 0)
                      Text(
                        'MIN ${product.minStock}',
                        maxLines: 1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 9,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
