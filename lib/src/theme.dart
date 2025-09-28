import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFFAFAFA), // neutral.bg
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF7C3AED),   // brand.DEFAULT
        secondary: Color(0xFFEC4899), // accent.pink
        surface: Color(0xFFFFFFFF),   // neutral.surface
        error: Color(0xFFEF4444),     // accent.error
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Color(0xFF1F2937)), // neutral.text
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1F2937),
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFFFFFFFF),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );
  }
}
