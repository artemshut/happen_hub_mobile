import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get light {
    const scaffold = Color(0xFFF5F5F8);
    const surface = Colors.white;
    const surfaceVariant = Color(0xFFE9E9F2);
    const outline = Color(0xFFCBCADA);

    const scheme = ColorScheme.light(
      primary: Color(0xFF7C3AED),
      secondary: Color(0xFFEC4899),
      tertiary: Color(0xFF22D3EE),
      surface: surface,
      background: scaffold,
      surfaceVariant: surfaceVariant,
      outline: outline,
      error: Color(0xFFEF4444),
    );

    final base = ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: scaffold,
      colorScheme: scheme,
      useMaterial3: true,
      textTheme: base.textTheme.apply(
        bodyColor: const Color(0xFF111220),
        displayColor: const Color(0xFF111220),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111220),
        elevation: 0,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: const Color(0xFF111220),
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: outline.withOpacity(0.4)),
        ),
        shadowColor: Colors.black.withOpacity(0.08),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaceVariant,
        selectedColor: scheme.primary.withOpacity(0.12),
        labelStyle: const TextStyle(color: Color(0xFF111220)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: outline.withOpacity(0.6)),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7C3AED)),
        ),
      ),
      filledButtonTheme: base.filledButtonTheme,
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF111220),
          side: BorderSide(color: outline.withOpacity(0.6)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: scheme.primary.withOpacity(0.12),
        elevation: 0,
        labelTextStyle: MaterialStateProperty.resolveWith(
          (states) => TextStyle(
            fontWeight: states.contains(MaterialState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(MaterialState.selected)
                ? scheme.primary
                : const Color(0xFF4B4C59),
          ),
        ),
        iconTheme: MaterialStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(MaterialState.selected)
                ? scheme.primary
                : const Color(0xFF4B4C59),
          ),
        ),
      ),
    );
  }

  static ThemeData get dark {
    const scaffold = Color(0xFF0F0F12);
    const surface = Color(0xFF16171D);
    const surfaceVariant = Color(0xFF1D1E25);
    const outline = Color(0xFF2A2B33);

    const scheme = ColorScheme.dark(
      primary: Color(0xFF7C3AED),
      secondary: Color(0xFFEC4899),
      tertiary: Color(0xFF22D3EE),
      surface: surface,
      background: scaffold,
      surfaceVariant: surfaceVariant,
      outline: outline,
      error: Color(0xFFEF4444),
    );

    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: scaffold,
      colorScheme: scheme,
      useMaterial3: true,
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: outline.withOpacity(0.5)),
        ),
        shadowColor: Colors.black.withOpacity(0.25),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaceVariant,
        selectedColor: scheme.primary.withOpacity(0.18),
        labelStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: outline.withOpacity(0.6)),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline.withOpacity(0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: outline.withOpacity(0.6)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scaffold,
        indicatorColor: scheme.primary.withOpacity(0.18),
        elevation: 0,
        labelTextStyle: MaterialStateProperty.resolveWith(
          (states) => TextStyle(
            fontWeight:
                states.contains(MaterialState.selected) ? FontWeight.w600 : FontWeight.w500,
            color: states.contains(MaterialState.selected)
                ? Colors.white
                : Colors.white.withOpacity(0.7),
          ),
        ),
        iconTheme: MaterialStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(MaterialState.selected)
                ? scheme.primary
                : Colors.white.withOpacity(0.7),
          ),
        ),
      ),
    );
  }
}
