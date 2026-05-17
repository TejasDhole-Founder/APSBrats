import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/core/widgets/app_badge.dart';
import 'package:flutter/material.dart';

class CamoHeader extends StatelessWidget {
  const CamoHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.progress,
    this.badgeText,
  });

  final String title;
  final String? subtitle;
  final double? progress;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          radius: 1.5,
          colors: [AppColors.g4, AppColors.g2, AppColors.g1],
        ),
        borderRadius: AppRadius.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (badgeText != null) ...[
            AppBadge(label: badgeText!),
            const SizedBox(height: 10),
          ],
          Text(title, style: AppTextStyles.headerTitle),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
          if (progress != null) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.g1,
              color: AppColors.goldLight,
            ),
          ],
        ],
      ),
    );
  }
}
