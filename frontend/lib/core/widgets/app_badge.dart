import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class AppBadge extends StatelessWidget {
  const AppBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.15),
        borderRadius: AppRadius.pill,
        border: Border.all(color: AppColors.gold),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.goldDark,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
