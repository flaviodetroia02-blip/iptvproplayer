import 'package:flutter/material.dart';

const kAppName = 'PRIMA';
const kAppTagline = 'Tutto in prima fila';

class AppColors {
  static const background = Color(0xFF111113);
  static const surface = Color(0xFF1B1B1F);
  static const surfaceHigh = Color(0xFF26262C);
  static const accent = Color(0xFFE5173F);
  static const accentDark = Color(0xFFB5102E);
  static const textPrimary = Color(0xFFF4F4F6);
  static const textSecondary = Color(0xFF9A9AA5);
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    ),
    textTheme: base.textTheme
        .apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary)
        .copyWith(
          headlineMedium: const TextStyle(
              fontSize: 30, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -0.5),
          titleMedium: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          bodySmall: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        side: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.focused) ? const BorderSide(color: Colors.white, width: 3) : null,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
