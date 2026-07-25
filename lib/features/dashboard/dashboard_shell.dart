import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';
import 'package:grain_warehouse_erp_lite/features/audit/audit_logs_screen.dart';
import 'package:grain_warehouse_erp_lite/features/customers/customers_screen.dart';
import 'package:grain_warehouse_erp_lite/features/dashboard/dashboard_screen.dart';
import 'package:grain_warehouse_erp_lite/features/expenses/expenses_screen.dart';
import 'package:grain_warehouse_erp_lite/features/financial_accounts/financial_accounts_screen.dart';
import 'package:grain_warehouse_erp_lite/features/financial_accounts/negative_balance_approval_requests_screen.dart';
import 'package:grain_warehouse_erp_lite/features/financial_reports/financial_reports_screen.dart';
import 'package:grain_warehouse_erp_lite/features/inventory/inventory_screen.dart';
import 'package:grain_warehouse_erp_lite/features/inventory/stock_adjustment_report_screen.dart';
import 'package:grain_warehouse_erp_lite/features/inventory/stock_take_screen.dart';
import 'package:grain_warehouse_erp_lite/features/products/products_screen.dart';
import 'package:grain_warehouse_erp_lite/features/purchases/purchases_screen.dart';
import 'package:grain_warehouse_erp_lite/features/reports/reports_screen.dart';
import 'package:grain_warehouse_erp_lite/features/sales/sales_screen.dart';
import 'package:grain_warehouse_erp_lite/features/settings/settings_screen.dart';
import 'package:grain_warehouse_erp_lite/features/suppliers/suppliers_screen.dart';
import 'package:grain_warehouse_erp_lite/shared/layout/responsive_layout.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/business_identity_header.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/page_back_button.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;

  static const _destinations = [
    _ShellDestination('الرئيسية', Icons.dashboard_rounded, DashboardScreen()),
    _ShellDestination('المبيعات', Icons.point_of_sale_rounded, SalesScreen()),
    _ShellDestination(
        'المشتريات', Icons.shopping_bag_rounded, PurchasesScreen()),
    _ShellDestination('الأصناف', Icons.inventory_2_rounded, ProductsScreen()),
    _ShellDestination('المخزون', Icons.warehouse_rounded, InventoryScreen()),
    _ShellDestination(
        'الموردون', Icons.local_shipping_rounded, SuppliersScreen()),
    _ShellDestination('العملاء', Icons.groups_2_rounded, CustomersScreen()),
    _ShellDestination(
      'الحسابات المالية',
      Icons.account_balance_wallet_rounded,
      FinancialAccountsScreen(),
      requiresFinancialAccounts: true,
    ),
    _ShellDestination(
      'طلبات الموافقة',
      Icons.approval_rounded,
      NegativeBalanceApprovalRequestsScreen(),
    ),
    _ShellDestination(
      'التقارير المالية',
      Icons.assessment_rounded,
      FinancialReportsScreen(),
      requiresFinancialAccounts: true,
    ),
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
      'جرد المخزون',
      Icons.balance_rounded,
      StockTakeScreen(),
      requiresStockAdjustment: true,
    ),
    _ShellDestination(
      'تقرير التسويات',
      Icons.fact_check_rounded,
      StockAdjustmentReportScreen(),
      requiresStockAdjustment: true,
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
    final isCompact = ResponsiveLayout.isCompact(context);
    final primaryDestinationCount =
        visibleDestinations.length > 4 ? 4 : visibleDestinations.length;
    final hasMoreDestinations =
        visibleDestinations.length > primaryDestinationCount;

    final identityCtrl = BusinessIdentityScope.maybeOf(context);
    final identity = identityCtrl?.identity;
    final hasLogo = identity?.hasLogo ?? false;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true):
            _handleBack,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          key: _scaffoldKey,
          drawer: isDesktop
              ? null
              : _MobileNavigationDrawer(
                  destinations: visibleDestinations,
                  selectedIndex: selectedIndex,
                  identityName: identity?.displayName ?? 'غلال',
                  onSelected: (index) {
                    Navigator.of(context).pop();
                    _setSelectedIndex(index);
                  },
                ),
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasLogo) ...[
                  _AppBarLogo(
                    managedFileName: identity?.logo?.managedFileName ?? '',
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    '${identity?.displayName ?? 'غلال'} · ${selected.label}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              if (!isCompact)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
                  child: Center(child: Text(user.role.labelAr)),
                ),
              IconButton(
                tooltip: 'تسجيل الخروج',
                onPressed: () => auth.signOut(),
                icon: const Icon(Icons.logout_rounded),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
          ),
          body: Row(
            children: [
              if (isDesktop)
                _DesktopNavigationSidebar(
                  key: const Key('desktop-navigation-sidebar'),
                  destinations: visibleDestinations,
                  selectedIndex: selectedIndex,
                  onSelected: _setSelectedIndex,
                ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppBreakpoints.maxContentWidth,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveLayout.horizontalPadding(context),
                        vertical: AppSpacing.md,
                      ),
                      child: Column(
                        children: [
                          if (selectedIndex != 0) ...[
                            PageBackButton(
                              buttonKey: const Key('shell-back-button'),
                              onPressed: () => _setSelectedIndex(0),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          Expanded(child: selected.screen),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: isDesktop
              ? null
              : NavigationBar(
                  key: const Key('mobile-bottom-navigation'),
                  selectedIndex: selectedIndex < primaryDestinationCount
                      ? selectedIndex
                      : primaryDestinationCount,
                  onDestinationSelected: (index) {
                    if (hasMoreDestinations &&
                        index == primaryDestinationCount) {
                      _scaffoldKey.currentState?.openDrawer();
                      return;
                    }
                    _setSelectedIndex(index);
                  },
                  destinations: [
                    for (final destination
                        in visibleDestinations.take(primaryDestinationCount))
                      NavigationDestination(
                        icon: Icon(destination.icon),
                        label: destination.label,
                      ),
                    if (hasMoreDestinations)
                      const NavigationDestination(
                        icon: Icon(Icons.menu_rounded),
                        label: 'المزيد',
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  void _setSelectedIndex(int index) {
    setState(() => _selectedIndex = index);
  }

  void _handleBack() {
    if (_selectedIndex != 0) {
      _setSelectedIndex(0);
      return;
    }
    Navigator.of(context).maybePop();
  }
}

class _DesktopNavigationSidebar extends StatelessWidget {
  const _DesktopNavigationSidebar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppComponentSizes.desktopSidebarWidth,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.xs,
                ),
                child: BusinessIdentityHeader(
                  compact: true,
                  subtitle: 'إدارة مخازن الحبوب',
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  itemCount: destinations.length,
                  itemBuilder: (context, index) {
                    final destination = destinations[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                      child: ListTile(
                        selected: selectedIndex == index,
                        selectedTileColor:
                            Theme.of(context).colorScheme.secondaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        leading: Icon(destination.icon),
                        title: Text(destination.label),
                        onTap: () => onSelected(index),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNavigationDrawer extends StatelessWidget {
  const _MobileNavigationDrawer({
    required this.destinations,
    required this.selectedIndex,
    required this.identityName,
    required this.onSelected,
  });

  final List<_ShellDestination> destinations;
  final int selectedIndex;
  final String identityName;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      key: const Key('mobile-navigation-drawer'),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: BusinessIdentityHeader(
                subtitle: 'إدارة مخازن الحبوب',
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.sm),
                itemCount: destinations.length,
                itemBuilder: (context, index) {
                  final destination = destinations[index];
                  return ListTile(
                    selected: selectedIndex == index,
                    leading: Icon(destination.icon),
                    title: Text(destination.label),
                    onTap: () => onSelected(index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
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
    this.requiresStockAdjustment = false,
    this.requiresFinancialAccounts = false,
  });

  final String label;
  final IconData icon;
  final Widget screen;
  final bool requiresSettings;
  final bool requiresReports;
  final bool requiresExpenses;
  final bool requiresAuditLogs;
  final bool requiresStockAdjustment;
  final bool requiresFinancialAccounts;

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
    if (requiresStockAdjustment) {
      return user.permissions.canCreateStockAdjustment;
    }
    if (requiresFinancialAccounts) {
      return user.role.name == 'owner';
    }

    return true;
  }
}

class _AppBarLogo extends StatelessWidget {
  const _AppBarLogo({required this.managedFileName});

  final String managedFileName;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _loadBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 32, maxWidth: 80),
          child: Image.memory(
            snapshot.data!,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  Future<Uint8List?> _loadBytes() async {
    if (managedFileName.isEmpty) return null;
    try {
      return await AppRepositories.businessIdentityRepository
          .loadLogoBytes(managedFileName);
    } catch (_) {
      return null;
    }
  }
}
