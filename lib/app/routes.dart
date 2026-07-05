import 'package:flutter/widgets.dart';
import 'package:grain_warehouse_erp_lite/features/auth/login_screen.dart';
import 'package:grain_warehouse_erp_lite/features/dashboard/dashboard_shell.dart';

class AppRoutes {
  static const login = '/login';
  static const dashboard = '/dashboard';

  static Map<String, WidgetBuilder> get routes => {
        login: (_) => const LoginScreen(),
        dashboard: (_) => const DashboardShell(),
      };
}
