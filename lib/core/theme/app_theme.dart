import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme_preset.dart';

class AppTheme {
  static ThemeData get light => fromPreset(AppThemePreset.olive);

  static ThemeData fromPreset(AppThemePreset preset) {
    final brightness = preset.isDark ? Brightness.dark : Brightness.light;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: preset.seed,
      brightness: brightness,
      surface: preset.surface,
    );

    final baseTextTheme = Typography.material2021(
      platform: TargetPlatform.windows,
    ).black.apply(
          fontFamily: 'Arial',
          bodyColor: preset.text,
          displayColor: preset.text,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme.copyWith(
        primary: preset.seed,
        secondary: preset.secondary,
        tertiary: preset.tertiary,
        surface: preset.surface,
        onSurface: preset.text,
        outline: preset.border,
      ),
      scaffoldBackgroundColor: preset.background,
      textTheme: baseTextTheme.copyWith(
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w900,
          height: 1.2,
          color: preset.text,
        ),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w900,
          color: preset.text,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
          height: 1.25,
          color: preset.text,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: preset.text,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(height: 1.5),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: preset.text),
      ),
      cardTheme: CardTheme(
        color: preset.surface,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(preset.isDark ? 0.35 : 0.16),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: preset.border, width: 1.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: preset.seed,
          foregroundColor: preset.isDark ? const Color(0xFF10140D) : Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: preset.seed,
          side: BorderSide(color: preset.seed, width: 1.4),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: preset.seed,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 1,
        backgroundColor: preset.surface,
        foregroundColor: preset.text,
        shadowColor: Colors.black.withOpacity(0.12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: preset.surface,
        labelStyle: TextStyle(color: preset.mutedText, fontWeight: FontWeight.w700),
        helperStyle: TextStyle(color: preset.mutedText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: preset.border, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: preset.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: preset.seed, width: 2),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: preset.surface,
        indicatorColor: preset.surfaceAlt,
        selectedIconTheme: IconThemeData(color: preset.seed),
        unselectedIconTheme: IconThemeData(color: preset.mutedText),
        selectedLabelTextStyle: TextStyle(
          color: preset.seed,
          fontWeight: FontWeight.w900,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: preset.mutedText,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: preset.surface,
        indicatorColor: preset.surfaceAlt,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? preset.seed
                : preset.mutedText,
            fontWeight: FontWeight.w800,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: preset.surfaceAlt,
        selectedColor: preset.surfaceAlt,
        labelStyle: TextStyle(color: preset.text, fontWeight: FontWeight.w700),
        side: BorderSide(color: preset.border),
      ),
    );
  }
}
