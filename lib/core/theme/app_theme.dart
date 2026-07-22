import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_semantic_colors.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme_preset.dart';

class AppTheme {
  static ThemeData get light => lightFor(AppThemePreset.olive);

  static ThemeData get dark => darkFor(AppThemePreset.olive);

  static ThemeData lightFor(AppThemePreset preset) =>
      fromPreset(preset, brightness: Brightness.light);

  static ThemeData darkFor(AppThemePreset preset) =>
      fromPreset(preset, brightness: Brightness.dark);

  static ThemeData fromPreset(
    AppThemePreset preset, {
    Brightness? brightness,
  }) {
    final resolvedBrightness =
        brightness ?? (preset.isDark ? Brightness.dark : Brightness.light);
    final generatedScheme = ColorScheme.fromSeed(
      seedColor: preset.seed,
      brightness: resolvedBrightness,
    );
    final usePresetSurfaces = resolvedBrightness == Brightness.light ||
        (preset.isDark && resolvedBrightness == Brightness.dark);
    final surface =
        usePresetSurfaces ? preset.surface : generatedScheme.surface;
    final background =
        usePresetSurfaces ? preset.background : generatedScheme.surface;
    final text = usePresetSurfaces ? preset.text : generatedScheme.onSurface;
    final mutedText =
        usePresetSurfaces ? preset.mutedText : generatedScheme.onSurfaceVariant;
    final border = usePresetSurfaces ? preset.border : generatedScheme.outline;
    final surfaceAlt = usePresetSurfaces
        ? preset.surfaceAlt
        : generatedScheme.surfaceContainerHighest;
    final semantic = AppSemanticColors.forBrightness(resolvedBrightness);
    final textTheme = AppTypography.build(
      brightness: resolvedBrightness,
      textColor: text,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: resolvedBrightness,
      colorScheme: generatedScheme.copyWith(
        primary: preset.seed,
        secondary: preset.secondary,
        tertiary: preset.tertiary,
        surface: surface,
        onSurface: text,
        outline: border,
      ),
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      extensions: [semantic],
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(
          resolvedBrightness == Brightness.dark ? 0.24 : 0.08,
        ),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: border.withOpacity(0.72)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: preset.seed,
          foregroundColor: generatedScheme.onPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
          minimumSize: const Size(0, AppComponentSizes.minimumTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: preset.seed,
          side: BorderSide(color: preset.seed, width: 1.4),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          minimumSize: const Size(0, AppComponentSizes.minimumTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
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
        backgroundColor: surface,
        foregroundColor: text,
        shadowColor: Colors.black.withOpacity(0.12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: TextStyle(color: mutedText, fontWeight: FontWeight.w700),
        helperStyle: TextStyle(color: mutedText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: preset.seed, width: 2),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: surfaceAlt,
        selectedIconTheme: IconThemeData(color: preset.seed),
        unselectedIconTheme: IconThemeData(color: mutedText),
        selectedLabelTextStyle: TextStyle(
          color: preset.seed,
          fontWeight: FontWeight.w900,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: mutedText,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: surfaceAlt,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color:
                states.contains(WidgetState.selected) ? preset.seed : mutedText,
            fontWeight: FontWeight.w800,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceAlt,
        selectedColor: surfaceAlt,
        labelStyle: TextStyle(color: text, fontWeight: FontWeight.w700),
        side: BorderSide(color: border),
      ),
      dividerTheme: DividerThemeData(color: border.withOpacity(0.7)),
      dialogTheme: DialogTheme(
        backgroundColor: semantic.elevatedSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      focusColor: preset.seed.withOpacity(0.18),
    );
  }
}
