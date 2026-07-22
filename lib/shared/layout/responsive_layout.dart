import 'package:flutter/widgets.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';

class ResponsiveLayout {
  static bool isCompact(BuildContext context) {
    return MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= AppBreakpoints.tablet && width < AppBreakpoints.desktop;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= AppBreakpoints.desktop;
  }

  static bool isWide(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= AppBreakpoints.wide;
  }

  static double horizontalPadding(BuildContext context) {
    if (isDesktop(context)) return AppSpacing.xl;
    if (isCompact(context)) return AppSpacing.sm;
    return AppSpacing.md;
  }

  static int gridColumns(
    double availableWidth, {
    double minimumItemWidth = 260,
    int maximum = 4,
  }) {
    final columns = (availableWidth / minimumItemWidth).floor();
    return columns.clamp(1, maximum);
  }
}
