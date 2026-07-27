import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/reports/daily_activity_report.dart';
import 'package:grain_warehouse_erp_lite/core/reports/report_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_daily_report_view.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.controller});

  final ReportController? controller;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final ReportController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        ReportController(repository: AppRepositories.reportRepository);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = AuthScope.of(context).state.user;
      if (user != null) {
        _controller.loadDailyActivity(user: user);
      }
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
    final user = AuthScope.of(context).state.user;
    final textTheme = Theme.of(context).textTheme;

    if (user == null) {
      return const PremiumCard(child: Text('يجب تسجيل الدخول لعرض التقارير.'));
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final report = _controller.report;

        return ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('تقارير حركة المخزن',
                          style: textTheme.headlineMedium),
                      const SizedBox(height: 6),
                      Text(
                        'ملخص يومي للمشتريات والمبيعات وحركات مخزون الحبوب.',
                        style: textTheme.titleMedium?.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: user.permissions.canViewReports
                      ? () => _chooseDate(context, user: user)
                      : null,
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: const Text('اختيار التاريخ'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('التاريخ: ${_formatDate(_controller.selectedDate)}'),
                FilledButton(
                  onPressed: user.permissions.canViewReports
                      ? () => _controller.loadDailyActivity(user: user)
                      : null,
                  child: const Text('عرض التقرير'),
                ),
              ],
            ),
            if (_controller.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _controller.errorMessage!,
                style: textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_controller.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (report == null)
              const PremiumCard(
                child: Text('اختر تاريخا لعرض تقرير حركة المخزن.'),
              )
            else ...[
              _ReportBody(report: report),
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => PrintableDailyReportView(
                          report: report,
                          reportDate: _controller.selectedDate,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.preview_rounded),
                  label: const Text('معاينة التقرير'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _chooseDate(
    BuildContext context, {
    required user,
  }) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _controller.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('ar'),
    );

    if (selected != null) {
      await _controller.loadDailyActivity(
        user: user,
        selectedDate: selected,
      );
    }
  }

  String _formatDate(DateTime value) {
    return '${value.year}-${_twoDigits(value.month)}-${_twoDigits(value.day)}';
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});

  final DailyActivityReport report;

  @override
  Widget build(BuildContext context) {
    final hasNoActivity = report.purchaseCount == 0 &&
        report.saleCount == 0 &&
        report.stockMovementCount == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasNoActivity) ...[
          const PremiumCard(
            child: Text(
              'لا توجد حركة في التاريخ المحدد. لا توجد مشتريات أو مبيعات أو حركات مخزون لهذا اليوم.',
            ),
          ),
          const SizedBox(height: 12),
        ],
        _SummaryGrid(report: report),
        if (report.hasIncompleteCostData) ...[
          const SizedBox(height: 12),
          _CostWarningCard(report: report),
        ],
        const SizedBox(height: 12),
        _Section(
          title: 'المشتريات',
          children: [
            _MetricLine(
              'إجمالي الكمية المشتراة',
              '${report.totalPurchasedKg} كجم',
            ),
            _MetricLine(
              'إجمالي قيمة المشتريات',
              MoneyUtils.formatPiastersAsEgp(
                report.totalPurchaseAmountQirsh,
              ),
            ),
            _MetricLine('عدد عمليات الشراء', '${report.purchaseCount}'),
          ],
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'المبيعات',
          children: [
            _MetricLine('إجمالي الكمية المباعة', '${report.totalSoldKg} كجم'),
            _MetricLine(
              'إجمالي قيمة المبيعات',
              MoneyUtils.formatPiastersAsEgp(
                report.totalSalesAmountQirsh,
              ),
            ),
            _MetricLine(
              'تكلفة المبيعات التقديرية',
              _formatOptionalMoney(report.estimatedSalesCostQirsh),
            ),
            _MetricLine('عدد عمليات البيع', '${report.saleCount}'),
          ],
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'حسابات العملاء',
          children: [
            _MetricLine(
              'إجمالي البيع الآجل',
              MoneyUtils.formatPiastersAsEgp(
                report.totalCreditSalesAmountQirsh,
              ),
            ),
            _MetricLine(
              'إجمالي التحصيلات من العملاء',
              MoneyUtils.formatPiastersAsEgp(
                report.totalCollectionsAmountQirsh,
              ),
            ),
            _MetricLine(
              'إجمالي أرصدة العملاء المستحقة',
              MoneyUtils.formatPiastersAsEgp(
                report.totalOutstandingReceivablesQirsh,
              ),
            ),
            const Text(
                'مبالغ لنا عند العملاء. التحصيلات تقلل مديونية العملاء فقط ولا تُحسب كمبيعات أو ربح جديد.'),
          ],
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'حسابات الموردين',
          children: [
            _MetricLine(
              'إجمالي مدفوعات الموردين',
              MoneyUtils.formatPiastersAsEgp(
                report.totalSupplierPaymentsQirsh,
              ),
            ),
            _MetricLine(
              'إجمالي أرصدة الموردين المستحقة',
              MoneyUtils.formatPiastersAsEgp(
                report.totalOutstandingSupplierPayablesQirsh,
              ),
            ),
            const Text(
                'مبالغ علينا للموردين. المدفوعات للموردين تقلل الرصيد المستحق فقط ولا تُحسب كمصروفات.'),
          ],
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'حركة النقد اليوم',
          children: [
            _MetricLine(
              'نقد داخل اليوم',
              MoneyUtils.formatPiastersAsEgp(report.cashInQirsh),
            ),
            _MetricLine(
              'مبيعات نقدية',
              MoneyUtils.formatPiastersAsEgp(report.cashSalesAmountQirsh),
            ),
            _MetricLine(
              'تحصيلات من العملاء',
              MoneyUtils.formatPiastersAsEgp(
                report.totalCollectionsAmountQirsh,
              ),
            ),
            const SizedBox(height: 4),
            _MetricLine(
              'نقد خارج اليوم',
              MoneyUtils.formatPiastersAsEgp(report.cashOutQirsh),
            ),
            _MetricLine(
              'مدفوعات الموردين',
              MoneyUtils.formatPiastersAsEgp(
                report.totalSupplierPaymentsQirsh,
              ),
            ),
            _MetricLine(
              'مصروفات',
              MoneyUtils.formatPiastersAsEgp(report.totalExpenseAmountQirsh),
            ),
            const SizedBox(height: 4),
            _MetricLine(
              'صافي حركة النقد اليوم',
              MoneyUtils.formatPiastersAsEgp(report.netCashQirsh),
            ),
            const Text(
              'نقد داخل (نقدي + تحصيلات) ناقص نقد خارج (مدفوعات موردين + مصروفات). هذا هو صافي النقد الفعلي الذي دخل أو خرج اليوم.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'المخزون الحالي',
          children: [
            _MetricLine(
              'قيمة المخزون التقديرية',
              _formatOptionalMoney(report.estimatedStockValueQirsh),
            ),
            if (report.stockBalances.isEmpty)
              const Text('لا توجد أصناف.')
            else
              for (final balance in report.stockBalances)
                Text(
                  '${balance.productName}: ${balance.quantityKg} كجم (${balance.unitLabel})',
                ),
          ],
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'حركات المخزون',
          children: [
            _MetricLine('عدد الحركات', '${report.stockMovementCount}'),
            if (report.recentMovements.isEmpty)
              const Text('لا توجد حركات في هذه الفترة.')
            else
              for (final movement in report.recentMovements.take(8))
                Text(
                  '${movement.type.labelAr} - ${movement.productName}: ${movement.quantityKg} كجم - ${_formatDateTime(movement.createdAt)}${movement.reference == null ? '' : ' - ${movement.reference}'}',
                ),
          ],
        ),
      ],
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final date =
        '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)}';
    final time = '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';

    return '$date $time';
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  String _formatOptionalMoney(int? value) {
    if (value == null) {
      return 'غير مكتمل';
    }

    return MoneyUtils.formatPiastersAsEgp(value);
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.report});

  final DailyActivityReport report;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 980
            ? 3
            : width >= 640
                ? 2
                : 1;
        final itemWidth = (width - ((columns - 1) * 12)) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryCard(
              width: itemWidth,
              title: 'إجمالي المبيعات',
              value: MoneyUtils.formatPiastersAsEgp(
                report.totalSalesAmountQirsh,
              ),
              caption: 'قيمة مؤكدة',
              icon: Icons.point_of_sale_rounded,
            ),
            _SummaryCard(
              width: itemWidth,
              title: 'إجمالي المشتريات',
              value: MoneyUtils.formatPiastersAsEgp(
                report.totalPurchaseAmountQirsh,
              ),
              caption: 'قيمة مؤكدة',
              icon: Icons.local_shipping_rounded,
            ),
            _SummaryCard(
              width: itemWidth,
              title: 'المصروفات',
              value: MoneyUtils.formatPiastersAsEgp(
                report.totalExpenseAmountQirsh,
              ),
              caption: 'لا يوجد سجل مصروفات حاليا',
              icon: Icons.receipt_long_rounded,
            ),
            _SummaryCard(
              width: itemWidth,
              title: 'إجمالي البيع الآجل',
              value: MoneyUtils.formatPiastersAsEgp(
                report.totalCreditSalesAmountQirsh,
              ),
              caption: 'ضمن المبيعات مع إثبات مديونية العميل',
              icon: Icons.person_add_alt_1_rounded,
            ),
            _SummaryCard(
              width: itemWidth,
              title: 'إجمالي التحصيلات من العملاء',
              value: MoneyUtils.formatPiastersAsEgp(
                report.totalCollectionsAmountQirsh,
              ),
              caption: 'تحصيل مديونية وليس مبيعات جديدة',
              icon: Icons.payments_rounded,
            ),
            _SummaryCard(
              width: itemWidth,
              title: 'أرصدة العملاء المستحقة',
              value: MoneyUtils.formatPiastersAsEgp(
                report.totalOutstandingReceivablesQirsh,
              ),
              caption: 'مبالغ لنا عند العملاء.',
              icon: Icons.account_balance_wallet_rounded,
            ),
            _SummaryCard(
              width: itemWidth,
              title: 'إجمالي مدفوعات الموردين',
              value: MoneyUtils.formatPiastersAsEgp(
                report.totalSupplierPaymentsQirsh,
              ),
              caption: 'مدفوعات مسجلة للموردين',
              icon: Icons.payments_rounded,
            ),
            _SummaryCard(
              width: itemWidth,
              title: 'أرصدة الموردين المستحقة',
              value: MoneyUtils.formatPiastersAsEgp(
                report.totalOutstandingSupplierPayablesQirsh,
              ),
              caption: 'مبالغ علينا للموردين.',
              icon: Icons.account_balance_wallet_rounded,
            ),
            _SummaryCard(
              width: itemWidth,
              title: 'صافي حركة المستندات',
              value: MoneyUtils.formatPiastersAsEgp(report.netMovementQirsh),
              caption: 'مبيعات ناقص مشتريات ومصروفات، وليس رصيد النقدية.',
              icon: Icons.swap_vert_rounded,
            ),
            _SummaryCard(
              width: itemWidth,
              title: 'نقد داخل اليوم',
              value: MoneyUtils.formatPiastersAsEgp(report.cashInQirsh),
              caption: 'مبيعات نقدية + تحصيلات',
              icon: Icons.payments_rounded,
            ),
            _SummaryCard(
              width: itemWidth,
              title: 'نقد خارج اليوم',
              value: MoneyUtils.formatPiastersAsEgp(report.cashOutQirsh),
              caption: 'مدفوعات موردين + مصروفات',
              icon: Icons.money_off_rounded,
            ),
            _SummaryCard(
              width: itemWidth,
              title: 'صافي حركة النقد',
              value: MoneyUtils.formatPiastersAsEgp(report.netCashQirsh),
              caption: 'نقد داخل ناقص نقد خارج',
              icon: Icons.account_balance_rounded,
            ),
            _SummaryCard(
              width: itemWidth,
              title: 'مؤشر هامش مرجعي غير محاسبي',
              value: _formatOptionalMoney(report.estimatedGrossProfitQirsh),
              caption: report.hasCompleteSalesCost
                  ? 'مبيعات ناقص تكلفة مرجعية — لا يمثل ربحًا محاسبيًا'
                  : 'غير مكتمل — لا يمثل ربحًا محاسبيًا',
              icon: Icons.trending_up_rounded,
            ),
            _SummaryCard(
              width: itemWidth,
              title: 'قيمة المخزون التقديرية',
              value: _formatOptionalMoney(report.estimatedStockValueQirsh),
              caption: report.hasCompleteStockValuation
                  ? 'بسعر التكلفة المرجعية'
                  : 'غير مكتملة',
              icon: Icons.inventory_2_rounded,
            ),
          ],
        );
      },
    );
  }

  String _formatOptionalMoney(int? value) {
    if (value == null) {
      return 'غير مكتمل';
    }

    return MoneyUtils.formatPiastersAsEgp(value);
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.width,
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
  });

  final double width;
  final String title;
  final String value;
  final String caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: width,
      child: PremiumCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.olive),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    caption,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CostWarningCard extends StatelessWidget {
  const _CostWarningCard({required this.report});

  final DailyActivityReport report;

  @override
  Widget build(BuildContext context) {
    final missing = {
      ...report.missingSalesCostProductNames,
      ...report.missingStockCostProductNames,
    }.toList();

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تنبيه نقص التكلفة المرجعية',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'المؤشر المرجعي غير مكتمل لأن بعض الأصناف لا تحتوي على تكلفة مرجعية. هذا المؤشر لا يمثل ربحًا محاسبيًا.',
                ),
                if (missing.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('الأصناف: ${missing.join('، ')}'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
