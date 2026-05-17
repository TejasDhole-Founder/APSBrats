import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class GoldCTAButton extends StatelessWidget {
  const GoldCTAButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.trailingIcon = Icons.arrow_forward_rounded,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData trailingIcon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.g1,
          foregroundColor: AppColors.gold,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: const SizedBox.shrink(),
        label: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: AppTextStyles.ctaButton),
            const SizedBox(width: 8),
            Icon(trailingIcon, size: 16, color: AppColors.gold),
          ],
        ),
      ),
    );
  }
}
