import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData light({
    Color accent = AppColors.brand,
    bool compact = false,
  }) => _build(Brightness.light, accent, compact);
  static ThemeData dark({
    Color accent = AppColors.brand,
    bool compact = false,
  }) => _build(Brightness.dark, accent, compact);

  static ThemeData _build(Brightness brightness, Color accent, bool compact) {
    final isDark = brightness == Brightness.dark;
    final background = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final text = isDark ? AppColors.darkText : AppColors.lightText;
    final secondary = isDark
        ? AppColors.darkSecondaryText
        : AppColors.lightSecondaryText;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
          surface: surface,
          error: AppColors.error,
        ).copyWith(
          primary: accent,
          onPrimary: accent.computeLuminance() > 0.5
              ? AppColors.lightText
              : Colors.white,
          secondary: AppColors.purple,
          onSecondary: Colors.white,
          tertiary: AppColors.blue,
          error: AppColors.error,
        );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: border, width: isDark ? 1.5 : 2),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      scaffoldBackgroundColor: background,
      textTheme: AppTypography.textTheme(text, secondary),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        elevation: isDark ? 0 : 3,
        shadowColor: isDark ? Colors.transparent : AppColors.lightText,
        margin: EdgeInsets.zero,
        shape: shape,
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: accent.withValues(alpha: isDark ? 0.35 : 0.5),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightText,
        contentTextStyle: TextStyle(color: isDark ? text : Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
