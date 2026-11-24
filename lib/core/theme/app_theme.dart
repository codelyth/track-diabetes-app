import 'package:flutter/material.dart';

import 'app_typography.dart';

export 'app_typography.dart';

class AppColors {
  AppColors._();

  static const primary = Color(0xFF63409D);
  static const background = Color(0xFFFCF7FF);
  static const field = Color(0xFFF7F0FF);
  static const lavender = Color(0xFFEEE2FF);
  static const mint = Color(0xFFAEF0DC);
  static const text = Color(0xFF211632);
  static const muted = Color(0xFF706779);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    );

    final defaults = ThemeData(useMaterial3: true, colorScheme: colorScheme);
    final textTheme = AppTypography.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      appBarTheme: defaults.appBarTheme.copyWith(
        titleTextStyle: AppTypography.pageTitle.copyWith(color: AppColors.text),
      ),
      listTileTheme: defaults.listTileTheme.copyWith(
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.muted,
        ),
      ),
      navigationBarTheme: defaults.navigationBarTheme.copyWith(
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontSize: AppTypography.navigationLabelSize,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      tabBarTheme: defaults.tabBarTheme.copyWith(
        labelStyle: AppTypography.button,
        unselectedLabelStyle: const TextStyle(fontSize: AppTypography.bodySize),
      ),
      chipTheme: defaults.chipTheme.copyWith(labelStyle: textTheme.bodyMedium),
      floatingActionButtonTheme: defaults.floatingActionButtonTheme.copyWith(
        extendedTextStyle: AppTypography.button,
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: AppTypography.body,
        hintStyle: AppTypography.body.copyWith(color: AppColors.muted),
        helperStyle: AppTypography.caption.copyWith(color: AppColors.muted),
        errorStyle: AppTypography.caption.copyWith(color: colorScheme.error),
        helperMaxLines: 3,
        errorMaxLines: 3,
        filled: true,
        fillColor: AppColors.field,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          textStyle: AppTypography.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTypography.button,
          minimumSize: const Size(0, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: AppTypography.button,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: AppTypography.button,
          minimumSize: const Size(0, 48),
        ),
      ),
    );
  }
}
