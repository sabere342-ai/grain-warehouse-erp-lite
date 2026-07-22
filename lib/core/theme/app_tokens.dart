import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 18;
  static const double pill = 999;
}

abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 360);
}

abstract final class AppBreakpoints {
  static const double compact = 480;
  static const double tablet = 720;
  static const double desktop = 960;
  static const double wide = 1280;
  static const double maxContentWidth = 1440;
}

abstract final class AppIconSizes {
  static const double sm = 18;
  static const double md = 24;
  static const double lg = 32;
  static const double hero = 52;
}

abstract final class AppComponentSizes {
  static const double minimumTouchTarget = 48;
  static const double fieldHeight = 52;
  static const double desktopSidebarWidth = 252;
  static const double dialogMaxWidth = 640;
  static const double authMaxWidth = 480;
}

abstract final class AppShadows {
  static List<BoxShadow> card(Brightness brightness) => [
        BoxShadow(
          color: Colors.black.withOpacity(
            brightness == Brightness.dark ? 0.24 : 0.08,
          ),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];
}

abstract final class AppTypography {
  static TextTheme build({
    required Brightness brightness,
    required Color textColor,
  }) {
    final base = Typography.material2021(
      platform: TargetPlatform.windows,
    ).black.apply(
          fontFamily: 'Arial',
          bodyColor: textColor,
          displayColor: textColor,
        );
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontWeight: FontWeight.w900,
        height: 1.15,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w900,
        height: 1.2,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w900,
        height: 1.2,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w900,
        height: 1.25,
      ),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}
