import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accent;
  final String note;

  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 260;
        return Container(
          padding: EdgeInsets.all(compact ? 12 : 16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: compact ? 36 : 42,
                    height: compact ? 36 : 42,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: accent, size: 22),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_upward_rounded,
                    size: 18,
                    color: AppColors.forestGreen,
                  ),
                ],
              ),
              SizedBox(height: compact ? 12 : 18),
              Text(
                title,
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.grey,
                ),
              ),
              SizedBox(height: compact ? 4 : 6),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: compact ? 24 : 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal,
                    ),
                  ),
                ),
              ),
              SizedBox(height: compact ? 6 : 8),
              Text(
                note,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 10 : 11,
                  color: AppColors.grey,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
