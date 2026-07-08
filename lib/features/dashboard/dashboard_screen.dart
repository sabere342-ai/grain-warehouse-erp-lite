import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/dashboard/dashboard_controller.dart';
import 'package:grain_warehouse_erp_lite/core/dashboard/dashboard_service.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/features/backup/backup_export_screen.dart';
import 'package:grain_warehouse_erp_lite/features/help/help_guide_screen.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.loadGuidance,
    this.controller,
  });

  final Future<DashboardGuidanceState> Function()? loadGuidance;
  final DashboardController? controller;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        DashboardController(
          service: DashboardService(
            saleRepository: AppRepositories.saleRepository,
            inventoryRepository: AppRepositories.inventoryRepository,
            productRepository: AppRepositories.productRepository,
            expenseRepository: AppRepositories.expenseRepository,
            customerAccountRepository:
                AppRepositories.customerAccountRepository,
            supplierAccountRepository:
                AppRepositories.supplierAccountRepository,
          ),
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.load();
    });
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
    final textTheme = Theme.of(context).textTheme;
    final ownerCanExport =
        AuthScope.maybeOf(context)?.state.user?.permissions.canExportBackups ??
            false;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final data = _controller.data;

        return ListView(
          children: [
            Text('لوحة متابعة المخزن', style: textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'نظرة سريعة على حركة الحبوب والمخزون. استخدم التقارير للتفاصيل اليومية.',
              style: textTheme.bodyMedium
                  ?.copyWith(color: AppColors.mutedText),
            ),
            const SizedBox(height: 16),
            if (ownerCanExport) ...[
              const _BackupExportCard(),
              const SizedBox(height: 16),
            ],
            FutureBuilder<DashboardGuidanceState>(
              future:
                  (widget.loadGuidance ?? DashboardGuidanceState.load)(),
              builder: (context, snapshot) {
                final guidance =
                    snapshot.data ?? DashboardGuidanceState.empty();
                return _GettingStartedCard(guidance: guidance);
              },
            ),
            const SizedBox(height: 16),
            if (_controller.isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900 ? 4 : 2;
                  return GridView.count(
                    crossAxisCount: columns,
                    childAspectRatio:
                        constraints.maxWidth >= 900 ? 1.35 : 1.15,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      _MetricCard(
                        'مبيعات اليوم',
                        MoneyUtils.formatPiastersAsEgp(data.todaySalesQirsh),
                        Icons.point_of_sale_rounded,
                      ),
                      _MetricCard(
                        'رصيد النقدية',
                        MoneyUtils.formatPiastersAsEgp(data.cashBalanceQirsh),
                        Icons.payments_rounded,
                        subtitle: 'محسوب من النقد الداخل ناقص المصروفات ومدفوعات الموردين.',
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
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 16),
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

class _BackupExportCard extends StatelessWidget {
  const _BackupExportCard();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.backup_rounded, color: AppColors.olive),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'النسخ الاحتياطي',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                const Text(
                  'احفظ نسخة من البيانات قبل أي تعديل كبير. يمكن فحص النسخة واسترجاعها إلى نظام فارغ فقط.',
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _openBackup(context),
                  icon: const Icon(Icons.backup_rounded),
                  label: const Text('تصدير نسخة احتياطية'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openBackup(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const BackupExportScreen()),
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
    final products = await AppRepositories.productRepository.listProducts(
      includeInactive: true,
    );
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
          const Icon(Icons.help_outline_rounded, color: AppColors.olive),
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
          Icon(icon, color: AppColors.olive, size: 22),
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
                  color: AppColors.text,
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
                color: AppColors.mutedText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
