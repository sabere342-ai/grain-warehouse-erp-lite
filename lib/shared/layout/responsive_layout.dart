import 'package:flutter/widgets.dart';

class ResponsiveLayout {
  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= 900;
  }

  static double horizontalPadding(BuildContext context) {
    return isDesktop(context) ? 32 : 16;
  }
}
