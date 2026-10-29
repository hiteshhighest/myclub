import 'package:flutter/material.dart';

/// Shared playful, accessible design system for Klubb.
class MyClubTheme {
  static const brand = Color(0xFF6C63FF);
  static const accentCoral = Color(0xFFFF8F7A);
  static const accentYellow = Color(0xFFFFD76E);
  static const accentMint = Color(0xFFA7D7C5);
  static const ink = Color(0xFF1F2937);
  static const canvas = Color(0xFFF9F7F1);
  static final border = ink.withValues(alpha: 0.16);
  static final mutedText = ink.withValues(alpha: 0.68);

  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final surface = isLight ? canvas : ink;
    final background = isLight ? canvas : ink;
    final foreground = isLight ? ink : canvas;
    final secondaryText = isLight ? mutedText : canvas.withValues(alpha: 0.72);
    final outline = isLight ? border : canvas.withValues(alpha: 0.22);
    final primary = brand;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: brand,
          brightness: brightness,
          surface: surface,
        ).copyWith(
          primary: primary,
          onPrimary: canvas,
          primaryContainer: isLight
              ? brand.withValues(alpha: 0.14)
              : brand.withValues(alpha: 0.28),
          onPrimaryContainer: isLight ? brand : canvas,
          secondary: accentCoral,
          onSecondary: ink,
          surface: surface,
          onSurface: foreground,
          onSurfaceVariant: secondaryText,
          outline: outline,
          outlineVariant: outline,
          error: accentCoral,
          onError: ink,
        );
    final radius = BorderRadius.circular(14);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: background,
        foregroundColor: foreground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: foreground,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      textTheme: Typography.material2021().black
          .apply(bodyColor: foreground, displayColor: foreground)
          .copyWith(
            headlineLarge: TextStyle(
              fontSize: 30,
              height: 1.15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.9,
              color: foreground,
            ),
            headlineMedium: TextStyle(
              fontSize: 25,
              height: 1.2,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.65,
              color: foreground,
            ),
            titleLarge: TextStyle(
              fontSize: 18,
              height: 1.3,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.15,
              color: foreground,
            ),
            titleMedium: TextStyle(
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
            bodyLarge: TextStyle(fontSize: 15, height: 1.5, color: foreground),
            bodyMedium: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: secondaryText,
            ),
            bodySmall: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: secondaryText,
            ),
            labelMedium: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: secondaryText,
            ),
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        hintStyle: TextStyle(color: secondaryText),
        labelStyle: TextStyle(color: secondaryText),
        floatingLabelStyle: TextStyle(
          color: primary,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          backgroundColor: primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: ink.withValues(alpha: 0.16),
          disabledForegroundColor: ink.withValues(alpha: 0.48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          side: BorderSide(color: outline),
          foregroundColor: foreground,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: foreground,
          minimumSize: const Size(44, 44),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: isLight ? 1 : 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shadowColor: brand.withValues(alpha: isLight ? 0.08 : 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: outline.withValues(alpha: isLight ? 0.85 : 0.7),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: brand.withValues(alpha: isLight ? 0.12 : 0.24),
        selectedColor: scheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide.none,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: foreground,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      ),
      dividerTheme: DividerThemeData(
        color: outline.withValues(alpha: 0.8),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight ? ink : canvas,
        contentTextStyle: TextStyle(
          color: isLight ? canvas : ink,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: isLight ? 0.14 : 0.24),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? primary
                : secondaryText,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          visualDensity: VisualDensity.standard,
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ),
    );
  }
}
