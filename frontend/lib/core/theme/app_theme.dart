import 'package:flutter/material.dart';
import 'package:apsbrat_frontend/core/theme/app_color_palette.dart';

export 'package:apsbrat_frontend/core/theme/app_color_palette.dart';

class AppTextStyles {
  const AppTextStyles._();

  static const headerTitle = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w900,
    color: Colors.white,
    height: 1.26,
    shadows: [Shadow(blurRadius: 12, color: Colors.black54)],
  );

  static const fieldLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.9,
    color: AppColors.textSecondary,
  );

  static const fieldInput = TextStyle(
    fontSize: 13,
    color: AppColors.inputText,
  );

  static const ctaButton = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.5,
    color: AppColors.gold,
  );
}

class AppRadius {
  const AppRadius._();

  static const sm = BorderRadius.all(Radius.circular(9));
  static const md = BorderRadius.all(Radius.circular(12));
  static const lg = BorderRadius.all(Radius.circular(14));
  static const pill = BorderRadius.all(Radius.circular(100));
  static const phone = BorderRadius.all(Radius.circular(40));
}

class AppTheme {
  const AppTheme._();

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.cream,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.g3,
        secondary: AppColors.gold,
        surface: AppColors.card,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.g2,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBg,
        hintStyle: const TextStyle(color: AppColors.inputHint),
        labelStyle: AppTextStyles.fieldLabel,
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: const BorderSide(color: AppColors.inputBord),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: const BorderSide(color: AppColors.gold, width: 1.4),
        ),
      ),
      textTheme: base.textTheme.copyWith(
        bodyLarge: const TextStyle(color: AppColors.textPrimary),
        bodyMedium: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}
