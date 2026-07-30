import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_controller.dart';
import 'package:grain_warehouse_erp_lite/core/dashboard/dashboard_controller.dart';
import 'package:grain_warehouse_erp_lite/core/dashboard/dashboard_service.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';
import 'package:grain_warehouse_erp_lite/features/help/help_guide_screen.dart';
import 'package:grain_warehouse_erp_lite/features/dashboard/dashboard_alerts_section.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_page_header.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_state_view.dart';
import 'package:grain_warehouse_erp_lite/shared/layout/responsive_layout.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.loadGuidance,
    this.loadAlerts,
    this.controller,
  });

  final Future<DashboardGuidanceState> Function()? loadGuidance;
  final Future<OwnerAlertData> Function()? loadAlerts;
  final DashboardController? controller;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardController _controller;
  late final bool _ownsController;
  bool _hasLoadedProtectedData = false;
  Future<DashboardGuidanceState>? _guidanceFuture;
  Future<OwnerAlertData>? _alertsFuture;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        DashboardController(
          service: DashboardService(
            saleRepository: AppRepositories.saleRepository,
            inventoryRepository: AppRepositories.inventoryRepository,
            productCatalogReadRepository:
                AppRepositories.productCatalogReadRepository,
            expenseRepository: AppRepositories.expenseRepository,
            customerAccountRepository:
                AppRepositories.customerAccountRepository,
            financialAccountRepository:
                AppRepositories.financialAccountRepository,
            supplierAccountRepository:
                AppRepositories.supplierAccountRepository,
          ),
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = AuthScope.maybeOf(context)?.state.user;
    if (user == null || !user.permissions.canViewFinancialReports) return;
    if (_hasLoadedProtectedData) return;
    _hasLoadedProtectedData = true;
    _guidanceFuture = (widget.loadGuidance ?? DashboardGuidanceState.load)();
    _alertsFuture = (widget.loadAlerts ?? OwnerAlertData.load)();
    _controller.load();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.maybeOf(context)?.state.user;
    final canViewDashboardData =
        user?.permissions.canViewFinancialReports ?? false;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final data = _controller.data;

        return ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          children: [
            Builder(
              builder: (context) {
                final displayName = BusinessIdentityScope.maybeOf(context)
                        ?.identity
                        .displayName ??
                    BusinessIdentity.defaultDisplayName;
                return GhalalPageHeader(
                  title: 'لوحة متابعة $displayName',
                  subtitle:
                      'نظرة سريعة على حركة الحبوب والمخزون والحسابات المصرح بها.',
                  icon: Icons.dashboard_rounded,
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            if (!canViewDashboardData)
              const PremiumCard(
                child: Text('ملخصات لوحة المتابعة المالية متاحة للمالك فقط.'),
              )
            else
              FutureBuilder<DashboardGuidanceState>(
                future: _guidanceFuture,
                builder: (context, snapshot) {
                  final guidance =
                      snapshot.data ?? DashboardGuidanceState.empty();
                  return _GettingStartedCard(guidance: guidance);
                },
              ),
            const SizedBox(height: 16),
            if (!canViewDashboardData)
              const SizedBox.shrink()
            else if (_controller.isLoading)
              const GhalalLoadingState(label: 'جاري تحميل مؤشرات المخزن...')
            else if (_controller.errorMessage != null)
              GhalalErrorState(
                message: _controller.errorMessage!,
                onRetry: _controller.load,
              )
            else ...[
              Text(
                'ملخص التشغيل اليومي',
                key: const Key('dashboard-daily-summary-section-title'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              LayoutBuilder(
                builder: (context, constraints) {
                  const gap = AppSpacing.sm;
                  final columns = ResponsiveLayout.gridColumns(
                    constraints.maxWidth,
                    minimumItemWidth: 250,
                  );
                  final itemWidth =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  final cards = <Widget>[
                    _MetricCard(
                      'مبيعات اليوم',
                      MoneyUtils.formatPiastersAsEgp(data.todaySalesQirsh),
                      Icons.point_of_sale_rounded,
                      subtitle: data.todayCashSalesQirsh > 0 ||
                              data.todayCreditSalesQirsh > 0
                          ? 'نقدي ${MoneyUtils.formatPiastersAsEgp(data.todayCashSalesQirsh)} • آجل ${MoneyUtils.formatPiastersAsEgp(data.todayCreditSalesQirsh)}'
                          : null,
                    ),
                    _MetricCard(
                      'نقد داخل اليوم',
                      MoneyUtils.formatPiastersAsEgp(data.todayCashInQirsh),
                      Icons.payments_rounded,
                      subtitle: data.todayCashSalesQirsh > 0 ||
                              data.todayCollectionsQirsh > 0
                          ? 'مبيعات نقدية ${MoneyUtils.formatPiastersAsEgp(data.todayCashSalesQirsh)} • تحصيلات ${MoneyUtils.formatPiastersAsEgp(data.todayCollectionsQirsh)}'
                          : null,
                    ),
                    _MetricCard(
                      'المستحق على العملاء',
                      MoneyUtils.formatPiastersAsEgp(
                          data.customerReceivablesQirsh),
                      Icons.account_balance_wallet_rounded,
                      subtitle: 'إجمالي المبالغ المستحقة لنا على العملاء.',
                    ),
                    _MetricCard(
                      'المستحق للموردين',
                      MoneyUtils.formatPiastersAsEgp(
                          data.supplierPayablesQirsh),
                      Icons.account_balance_wallet_rounded,
                      subtitle: 'إجمالي المبالغ المستحقة للموردين.',
                    ),
                    _MetricCard(
                      'إجمالي أرصدة الحسابات المالية',
                      MoneyUtils.formatPiastersAsEgp(data.cashBalanceQirsh),
                      Icons.savings_rounded,
                      subtitle:
                          'إجمالي الأرصدة الحالية للحسابات المالية، شاملاً الحسابات غير النشطة.',
                    ),
                    _MetricCard(
                      'مخزون القمح',
                      data.wheatStockKg > 0
                          ? '${data.wheatStockKg} كجم'
                          : '${data.totalStockKg} كجم',
                      Icons.grain_rounded,
                      subtitle: data.wheatStockKg > 0
                          ? 'إجمالي المخزون: ${data.totalStockKg} كجم'
                          : data.totalStockKg > 0
                              ? 'إجمالي المخزون'
                              : null,
                    ),
                    _MetricCard(
                      'تنبيهات المخزون',
                      '${data.stockAlertCount}',
                      Icons.warning_amber_rounded,
                    ),
                  ];
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final card in cards)
                        SizedBox(width: itemWidth, child: card),
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 16),
            if (canViewDashboardData)
              OwnerAlertsSection(loadData: _alertsFuture!),
            const SizedBox(height: 16),
            if (canViewDashboardData)
              const PremiumCard(
                child: Text(
                  'الأرقام هنا للمتابعة السريعة فقط. راجع شاشة المخزون وسجل المستندات قبل أي قرار مؤثر على الكميات.',
                ),
              ),
          ],
        );
      },
    );
  }
}

class DashboardGuidanceState {
  const DashboardGuidanceState({
    required this.productCount,
    required this.stockMovementCount,
    required this.saleCount,
  });

  final int productCount;
  final int stockMovementCount;
  final int saleCount;

  factory DashboardGuidanceState.empty() {
    return const DashboardGuidanceState(
      productCount: 0,
      stockMovementCount: 0,
      saleCount: 0,
    );
  }

  static Future<DashboardGuidanceState> load() async {
    final products = await AppRepositories.productCatalogReadRepository
        .listProductCatalog(includeInactive: true);
    final movements =
        await AppRepositories.inventoryRepository.listAllMovements();
    final sales = await AppRepositories.saleRepository.listSales();

    return DashboardGuidanceState(
      productCount: products.length,
      stockMovementCount: movements.length,
      saleCount: sales.length,
    );
  }

  String get title => 'خطوات العمل اليومية';

  String get message {
    if (productCount == 0) {
      return 'ابدأ بإضافة أول صنف في المخزن.';
    }
    if (stockMovementCount == 0) {
      return 'بعد إضافة الأصناف، سجّل رصيد افتتاحي أو وارد حبوب عند الحاجة.';
    }
    if (saleCount == 0) {
      return 'بعد وجود رصيد، يمكنك تسجيل المبيعات عند خروج الحبوب.';
    }

    return 'راجع التقرير اليومي وسجل المستندات قبل نهاية اليوم.';
  }
}

class _GettingStartedCard extends StatelessWidget {
  const _GettingStartedCard({required this.guidance});

  final DashboardGuidanceState guidance;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.help_outline_rounded,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guidance.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(guidance.message),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _openHelp(context),
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text('دليل الاستخدام'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openHelp(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const HelpGuideScreen()),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value, this.icon, {this.subtitle});

  final String label;
  final String value;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                textDirection: TextDirection.ltr,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
