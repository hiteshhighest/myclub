import 'package:flutter/material.dart';

/// Shared accessible colors and component styles for MyClub.
class MyClubTheme {
  static const brand = Color(0xFF205F57);
  static const ink = Color(0xFF18231F);
  static const canvas = Color(0xFFF6F8F7);
  static const border = Color(0xFFD5DEDA);
  static const mutedText = Color(0xFF4F5F59);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final surface = isLight ? Colors.white : const Color(0xFF1A2421);
    final background = isLight ? canvas : const Color(0xFF101714);
    final foreground = isLight ? ink : const Color(0xFFEAF1ED);
    final secondaryText = isLight ? mutedText : const Color(0xFFBECBC4);
    final outline = isLight ? border : const Color(0xFF45554D);
    final primary = isLight ? brand : const Color(0xFF8BD0C1);

    final scheme =
        ColorScheme.fromSeed(
          seedColor: brand,
          brightness: brightness,
          surface: surface,
        ).copyWith(
          primary: primary,
          onPrimary: isLight ? Colors.white : const Color(0xFF102A25),
          primaryContainer: isLight
              ? const Color(0xFFDCEFE9)
              : const Color(0xFF244A42),
          onPrimaryContainer: isLight
              ? const Color(0xFF153F37)
              : const Color(0xFFD4F4E9),
          secondary: isLight
              ? const Color(0xFF4C626C)
              : const Color(0xFFB8CDD4),
          onSecondary: isLight ? Colors.white : const Color(0xFF1B3037),
          surface: surface,
          onSurface: foreground,
          onSurfaceVariant: secondaryText,
          outline: isLight ? const Color(0xFF687870) : const Color(0xFF899A91),
          outlineVariant: outline,
          error: isLight ? const Color(0xFFB3261E) : const Color(0xFFFFB4AB),
          onError: isLight ? Colors.white : const Color(0xFF690005),
        );
    final radius = BorderRadius.circular(12);

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
              letterSpacing: -0.6,
              color: foreground,
            ),
            headlineMedium: TextStyle(
              fontSize: 25,
              height: 1.2,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.45,
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
          horizontal: 14,
          vertical: 15,
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
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          backgroundColor: primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: isLight
              ? const Color(0xFFE1E7E4)
              : const Color(0xFF34433C),
          disabledForegroundColor: isLight
              ? const Color(0xFF53615B)
              : const Color(0xFFCFD9D3),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: radius),
          side: BorderSide(color: isLight ? const Color(0xFF87968F) : outline),
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
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: outline.withValues(alpha: isLight ? 0.85 : 0.7),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isLight
            ? const Color(0xFFEDF3F0)
            : const Color(0xFF273630),
        selectedColor: scheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
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
        backgroundColor: isLight
            ? const Color(0xFF26332E)
            : const Color(0xFFEAF1ED),
        contentTextStyle: TextStyle(
          color: isLight ? Colors.white : const Color(0xFF18231F),
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
