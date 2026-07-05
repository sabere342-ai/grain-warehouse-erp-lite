import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/features/customers/customers_screen.dart';
import 'package:grain_warehouse_erp_lite/features/dashboard/dashboard_screen.dart';
import 'package:grain_warehouse_erp_lite/features/expenses/expenses_screen.dart';
import 'package:grain_warehouse_erp_lite/features/products/products_screen.dart';
import 'package:grain_warehouse_erp_lite/features/purchases/purchases_screen.dart';
import 'package:grain_warehouse_erp_lite/features/reports/reports_screen.dart';
import 'package:grain_warehouse_erp_lite/features/sales/sales_screen.dart';
import 'package:grain_warehouse_erp_lite/features/settings/settings_screen.dart';
import 'package:grain_warehouse_erp_lite/features/suppliers/suppliers_screen.dart';
import 'package:grain_warehouse_erp_lite/shared/layout/responsive_layout.dart';

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
    _ShellDestination(
        'المشتريات', Icons.shopping_bag_rounded, PurchasesScreen()),
    _ShellDestination('الأصناف', Icons.inventory_2_rounded, ProductsScreen()),
    _ShellDestination('العملاء', Icons.groups_2_rounded, CustomersScreen()),
    _ShellDestination(
        'الموردون', Icons.local_shipping_rounded, SuppliersScreen()),
    _ShellDestination(
        'المصروفات', Icons.receipt_long_rounded, ExpensesScreen()),
    _ShellDestination('التقارير', Icons.bar_chart_rounded, ReportsScreen()),
    _ShellDestination('الإعدادات', Icons.settings_rounded, SettingsScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final selected = _destinations[_selectedIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(selected.label),
        actions: const [
          Padding(
            padding: EdgeInsetsDirectional.only(end: 16),
            child: Center(child: Text('مخزن الحبوب')),
          ),
        ],
      ),
      body: Row(
        children: [
          if (isDesktop)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _setSelectedIndex,
              labelType: NavigationRailLabelType.all,
              minWidth: 96,
              destinations: [
                for (final destination in _destinations)
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
              child: selected.screen,
            ),
          ),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex > 4 ? 0 : _selectedIndex,
              onDestinationSelected: _setSelectedIndex,
              indicatorColor: AppColors.surfaceAlt,
              destinations: [
                for (final destination in _destinations.take(5))
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
  const _ShellDestination(this.label, this.icon, this.screen);

  final String label;
  final IconData icon;
  final Widget screen;
}
