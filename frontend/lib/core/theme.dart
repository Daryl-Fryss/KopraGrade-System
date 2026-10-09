import 'package:flutter/material.dart';

/// The KopraGrade palette. Every screen takes its colors from here.
class KopraColors {
  KopraColors._();

  /// Primary brand color: sidebar, headers, strong text.
  static const Color forest = Color(0xFF174D36);

  /// Primary action buttons and highlights.
  static const Color fresh = Color(0xFF2E8B57);

  /// Main content backgrounds and cards.
  static const Color white = Color(0xFFFFFFFF);

  /// Page backgrounds and secondary sections.
  static const Color page = Color(0xFFF4F6F4);

  /// Main text.
  static const Color text = Color(0xFF333333);

  /// Subtle highlights and selected states.
  static const Color soft = Color(0xFFE6F2E8);

  // Supporting neutrals (derived from the palette above).
  static const Color border = Color(0xFFDCE4DE);
  static const Color muted = Color(0xFF5B665F); // secondary text, 5.8:1 on white
  static const Color freshLight = Color(0xFF8FD6AE); // accents on dark backgrounds

  // Status colors for "Moderately Dried", "Poorly Dried" and errors.
  static const Color amber = Color(0xFFB26A00);
  static const Color amberText = Color(0xFF7A4800);
  static const Color amberTint = Color(0xFFFFF4DF);
  static const Color red = Color(0xFFB3261E);
  static const Color redText = Color(0xFF8C1D18);
  static const Color redTint = Color(0xFFFCE9E7);
}

/// Kept for older code: the main action green.
const Color kopraGreen = KopraColors.fresh;

/// Screens at least this wide (web / tablet / laptop) get the sidebar layout.
const double kWideBreakpoint = 900;

bool isWideScreen(BuildContext context) => MediaQuery.sizeOf(context).width >= kWideBreakpoint;

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: KopraColors.fresh, brightness: Brightness.light).copyWith(
    primary: KopraColors.fresh,
    onPrimary: Colors.white,
    primaryContainer: KopraColors.soft,
    onPrimaryContainer: KopraColors.forest,
    secondary: KopraColors.forest,
    onSecondary: Colors.white,
    secondaryContainer: KopraColors.soft,
    onSecondaryContainer: KopraColors.forest,
    surface: Colors.white,
    onSurface: KopraColors.text,
    outline: const Color(0xFF86928A),
    outlineVariant: KopraColors.border,
    error: KopraColors.red,
    onError: Colors.white,
    errorContainer: KopraColors.redTint,
    onErrorContainer: KopraColors.redText,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final t = base.textTheme.apply(bodyColor: KopraColors.text, displayColor: KopraColors.text);
  final textTheme = t.copyWith(
    headlineMedium: t.headlineMedium?.copyWith(fontSize: 30, fontWeight: FontWeight.w800, height: 1.2),
    headlineSmall: t.headlineSmall?.copyWith(fontSize: 24, fontWeight: FontWeight.w800, height: 1.25),
    titleLarge: t.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3),
    titleMedium: t.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w700, height: 1.35),
    titleSmall: t.titleSmall?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
    bodyLarge: t.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
    bodyMedium: t.bodyMedium?.copyWith(fontSize: 15, height: 1.5),
    bodySmall: t.bodySmall?.copyWith(fontSize: 13, height: 1.4, color: KopraColors.muted),
    labelLarge: t.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
  );

  const buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14)));
  const buttonText = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);

  OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: KopraColors.page,
    appBarTheme: AppBarTheme(
      backgroundColor: KopraColors.forest,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      toolbarHeight: 60,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: Colors.white),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: inputBorder(KopraColors.border),
      enabledBorder: inputBorder(KopraColors.border),
      focusedBorder: inputBorder(KopraColors.fresh, 2),
      errorBorder: inputBorder(KopraColors.red),
      focusedErrorBorder: inputBorder(KopraColors.red, 2),
      labelStyle: const TextStyle(color: KopraColors.muted),
      floatingLabelStyle: const TextStyle(color: KopraColors.forest, fontWeight: FontWeight.w600),
      prefixIconColor: KopraColors.muted,
      suffixIconColor: KopraColors.muted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: KopraColors.fresh,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFD3DCD5),
        disabledForegroundColor: const Color(0xFF6C766F),
        minimumSize: const Size(64, 54),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: KopraColors.forest,
        backgroundColor: Colors.white,
        minimumSize: const Size(64, 54),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        side: const BorderSide(color: KopraColors.fresh, width: 1.5),
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: KopraColors.forest,
        minimumSize: const Size(64, 48),
        shape: buttonShape,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: KopraColors.soft,
      height: 68,
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? KopraColors.forest : KopraColors.muted, size: 26);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12.5,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? KopraColors.forest : KopraColors.muted,
        );
      }),
    ),
    dividerTheme: const DividerThemeData(color: KopraColors.border, space: 1, thickness: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: KopraColors.fresh),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: KopraColors.forest,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

// ---- Drying-quality indicators ---------------------------------------------------------
// Each class has its own color AND its own icon, so it never depends on color alone.

/// Accent color (icons, bars, dots) for a class.
Color gradeColor(String grade) {
  switch (grade) {
    case 'Well-Dried':
      return KopraColors.fresh;
    case 'Moderately Dried':
      return KopraColors.amber;
    default:
      return KopraColors.red;
  }
}

/// Darker version of [gradeColor] that is safe to use for text on [gradeTint].
Color gradeTextColor(String grade) {
  switch (grade) {
    case 'Well-Dried':
      return KopraColors.forest;
    case 'Moderately Dried':
      return KopraColors.amberText;
    default:
      return KopraColors.redText;
  }
}

/// Light background for badges and panels of a class.
Color gradeTint(String grade) {
  switch (grade) {
    case 'Well-Dried':
      return KopraColors.soft;
    case 'Moderately Dried':
      return KopraColors.amberTint;
    default:
      return KopraColors.redTint;
  }
}

IconData gradeIcon(String grade) {
  switch (grade) {
    case 'Well-Dried':
      return Icons.check_circle_rounded;
    case 'Moderately Dried':
      return Icons.timelapse_rounded;
    default:
      return Icons.error_rounded;
  }
}
