import 'package:flutter/material.dart';

class AppThemePreset {
  const AppThemePreset._({
    required this.id,
    required this.labelAr,
    required this.seed,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.text,
    required this.mutedText,
    required this.border,
    required this.secondary,
    required this.tertiary,
    required this.isDark,
  });

  final String id;
  final String labelAr;
  final Color seed;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color text;
  final Color mutedText;
  final Color border;
  final Color secondary;
  final Color tertiary;
  final bool isDark;

  static const olive = AppThemePreset._(
    id: 'olive',
    labelAr: 'أخضر زيتوني',
    seed: Color(0xFF2F5D2F),
    background: Color(0xFFF6F1E6),
    surface: Color(0xFFFFFCF4),
    surfaceAlt: Color(0xFFE8D9B7),
    text: Color(0xFF151A12),
    mutedText: Color(0xFF4D5142),
    border: Color(0xFFB89B62),
    secondary: Color(0xFF406A35),
    tertiary: Color(0xFFB67818),
    isDark: false,
  );

  static const blue = AppThemePreset._(
    id: 'blue',
    labelAr: 'أزرق',
    seed: Color(0xFF245A8D),
    background: Color(0xFFF1F6FA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFD9E8F6),
    text: Color(0xFF102033),
    mutedText: Color(0xFF405365),
    border: Color(0xFF9DB8D0),
    secondary: Color(0xFF2F6F91),
    tertiary: Color(0xFF9A6A1D),
    isDark: false,
  );

  static const wheat = AppThemePreset._(
    id: 'wheat',
    labelAr: 'قمحي / بني',
    seed: Color(0xFF79521B),
    background: Color(0xFFF7EEDB),
    surface: Color(0xFFFFFBF2),
    surfaceAlt: Color(0xFFE9D0A5),
    text: Color(0xFF21160A),
    mutedText: Color(0xFF5B4A34),
    border: Color(0xFFC09755),
    secondary: Color(0xFF5E6A30),
    tertiary: Color(0xFF9D6416),
    isDark: false,
  );

  static const highContrast = AppThemePreset._(
    id: 'highContrast',
    labelAr: 'داكن عالي التباين',
    seed: Color(0xFF9FD45A),
    background: Color(0xFF10140D),
    surface: Color(0xFF1A2116),
    surfaceAlt: Color(0xFF26321F),
    text: Color(0xFFF7FFE8),
    mutedText: Color(0xFFD0DEC0),
    border: Color(0xFF7EA35A),
    secondary: Color(0xFFB8E06D),
    tertiary: Color(0xFFE0B24D),
    isDark: true,
  );

  static const values = [olive, blue, wheat, highContrast];

  static AppThemePreset byId(String id) {
    for (final preset in values) {
      if (preset.id == id) {
        return preset;
      }
    }
    return olive;
  }
}
