import 'package:flutter/material.dart';

import '../models/expiration_model.dart';

class ExpirationStatusBadge extends StatelessWidget {
  final ExpirationStatus status;
  final bool compact;

  const ExpirationStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final label = compact ? status.shortLabel : status.label;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: status.color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: status.color,
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
