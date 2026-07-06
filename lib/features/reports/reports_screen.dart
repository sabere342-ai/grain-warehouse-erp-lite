import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/reports/daily_activity_report.dart';
import 'package:grain_warehouse_erp_lite/core/reports/report_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
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
            else
              _ReportBody(report: report),
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
            _MetricLine('عدد عمليات البيع', '${report.saleCount}'),
          ],
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'المخزون الحالي',
          children: [
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
