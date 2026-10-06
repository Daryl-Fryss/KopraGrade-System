import 'package:flutter/material.dart';

const Color kopraGreen = Color(0xFF2E7D32);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kopraGreen, brightness: Brightness.light);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF7F5EE),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      centerTitle: true,
    ),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    ),
  );
}

Color gradeColor(String grade) {
  switch (grade) {
    case 'Well-Dried':
      return const Color(0xFF2E7D32);
    case 'Moderately Dried':
      return const Color(0xFFEF8F00);
    default:
      return const Color(0xFFC62828);
  }
}
