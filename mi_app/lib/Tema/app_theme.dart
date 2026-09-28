import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF0F2E1A);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF26442F);
  static const Color onPrimaryContainer = Color(0xFF8FB196);
  static const Color primaryFixed = Color(0xFFC8EBCE);
  static const Color onPrimaryFixed = Color(0xFF02210F);

  static const Color secondary = Color(0xFFA23E18);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFFE8357);
  static const Color onSecondaryContainer = Color(0xFF6F2000);

  static const Color tertiary = Color(0xFF1B2C16);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFF30422B);

  static const Color surface = Color(0xFFFFF8F1);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFFAF3E7);
  static const Color surfaceContainer = Color(0xFFF5EDE2);
  static const Color surfaceContainerHigh = Color(0xFFEFE7DC);
  static const Color surfaceContainerHighest = Color(0xFFE9E1D6);
  static const Color surfaceVariant = Color(0xFFE9E1D6);
  static const Color onSurface = Color(0xFF1E1B15);
  static const Color onSurfaceVariant = Color(0xFF424842);

  static const Color outline = Color(0xFF727972);
  static const Color outlineVariant = Color(0xFFC2C8C0);

  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);

  static const Color surfaceTint = Color(0xFF46654E);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        tertiaryContainer: AppColors.tertiaryContainer,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        error: AppColors.error,
        onError: AppColors.onError,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
      ),
      scaffoldBackgroundColor: AppColors.surface,
      fontFamily: 'Plus Jakarta Sans',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.onSurface),
        titleTextStyle: TextStyle(
          color: AppColors.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
