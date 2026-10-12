import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const fontFamily = 'Roboto';

  static TextTheme textTheme(Color text, Color secondary) => TextTheme(
    headlineSmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 29,
      fontWeight: FontWeight.w700,
      height: 1.2,
      color: text,
      letterSpacing: -0.5,
    ),
    titleLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 19,
      fontWeight: FontWeight.w700,
      height: 1.3,
      color: text,
      letterSpacing: -0.2,
    ),
    titleMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      height: 1.35,
      color: text,
    ),
    bodyLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 15,
      height: 1.5,
      color: text,
    ),
    bodyMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      height: 1.5,
      color: text,
    ),
    bodySmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 12,
      height: 1.45,
      color: secondary,
    ),
    labelLarge: const TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  );
}
