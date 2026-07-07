import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/features/audit/audit_logs_screen.dart';
import 'package:grain_warehouse_erp_lite/features/customers/customers_screen.dart';
import 'package:grain_warehouse_erp_lite/features/dashboard/dashboard_screen.dart';
import 'package:grain_warehouse_erp_lite/features/expenses/expenses_screen.dart';
import 'package:grain_warehouse_erp_lite/features/inventory/inventory_screen.dart';
import 'package:grain_warehouse_erp_lite/features/products/products_screen.dart';
import 'package:grain_warehouse_erp_lite/features/purchases/purchases_screen.dart';
import 'package:grain_warehouse_erp_lite/features/reports/reports_screen.dart';
import 'package:grain_warehouse_erp_lite/features/sales/sales_screen.dart';
import 'package:grain_warehouse_erp_lite/features/settings/settings_screen.dart';
import 'package:grain_warehouse_erp_lite/features/suppliers/suppliers_screen.dart';
import 'package:grain_warehouse_erp_lite/shared/layout/responsive_layout.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/page_back_button.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _selectedIndex = 0;

  static const _destinations = [
    _ShellDestination('الرئيسية', Icons.dashboard_rounded, DashboardScreen()),
    _ShellDestination('المبيعات', Icons.point_of_sale_rounded, SalesScreen()),
    _ShellDestination('المشتريات', Icons.shopping_bag_rounded, PurchasesScreen()),
    _ShellDestination('الأصناف', Icons.inventory_2_rounded, ProductsScreen()),
    _ShellDestination('المخزون', Icons.warehouse_rounded, InventoryScreen()),
    _ShellDestination('الموردون', Icons.local_shipping_rounded, SuppliersScreen()),
    _ShellDestination('العملاء', Icons.groups_2_rounded, CustomersScreen()),
    _ShellDestination(
      'المصروفات',
      Icons.receipt_long_rounded,
      ExpensesScreen(),
      requiresExpenses: true,
    ),
    _ShellDestination(
      'سجل التدقيق',
      Icons.fact_check_rounded,
      AuditLogsScreen(),
      requiresAuditLogs: true,
    ),
    _ShellDestination(
      'التقارير',
      Icons.bar_chart_rounded,
      ReportsScreen(),
      requiresReports: true,
    ),
    _ShellDestination(
      'الإعدادات',
      Icons.settings_rounded,
      SettingsScreen(),
      requiresSettings: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final user = auth.state.user;

    if (user == null || !user.isActive) {
      return const Scaffold(
        body: Center(child: Text('يجب تسجيل الدخول للمتابعة.')),
      );
    }

    final visibleDestinations = _destinations
        .where((destination) => destination.isVisibleFor(user))
        .toList(growable: false);
    final selectedIndex =
        _selectedIndex >= visibleDestinations.length ? 0 : _selectedIndex;
    final selected = visibleDestinations[selectedIndex];
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(selected.label),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Center(child: Text(user.role.labelAr)),
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: () => auth.signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (isDesktop)
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: _setSelectedIndex,
              labelType: NavigationRailLabelType.all,
              minWidth: 104,
              destinations: [
                for (final destination in visibleDestinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    label: Text(destination.label),
                  ),
              ],
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveLayout.horizontalPadding(context),
                vertical: 18,
              ),
              child: Column(
                children: [
                  if (selectedIndex != 0) ...[
                    PageBackButton(onPressed: () => _setSelectedIndex(0)),
                    const SizedBox(height: 12),
                  ],
                  Expanded(child: selected.screen),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex > 4 ? 0 : selectedIndex,
              onDestinationSelected: _setSelectedIndex,
              indicatorColor: AppColors.surfaceAlt,
              destinations: [
                for (final destination in visibleDestinations.take(5))
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    label: destination.label,
                  ),
              ],
            ),
    );
  }

  void _setSelectedIndex(int index) {
    setState(() => _selectedIndex = index);
  }
}

class _ShellDestination {
  const _ShellDestination(
    this.label,
    this.icon,
    this.screen, {
    this.requiresSettings = false,
    this.requiresReports = false,
    this.requiresExpenses = false,
    this.requiresAuditLogs = false,
  });

  final String label;
  final IconData icon;
  final Widget screen;
  final bool requiresSettings;
  final bool requiresReports;
  final bool requiresExpenses;
  final bool requiresAuditLogs;

  bool isVisibleFor(AppUser user) {
    if (requiresSettings) {
      return user.permissions.canAccessSettings;
    }
    if (requiresReports) {
      return user.permissions.canViewReports;
    }
    if (requiresExpenses) {
      return user.permissions.canCreateExpense;
    }
    if (requiresAuditLogs) {
      return user.permissions.canViewAuditLogs;
    }

    return true;
  }
}
