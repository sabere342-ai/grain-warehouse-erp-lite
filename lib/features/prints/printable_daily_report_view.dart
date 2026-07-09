import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/reports/daily_activity_report.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_document_scaffold.dart';

class PrintableDailyReportView extends StatelessWidget {
  const PrintableDailyReportView({
    super.key,
    required this.report,
    required this.reportDate,
  });

  final DailyActivityReport report;
  final DateTime reportDate;

  String _formatDate(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  @override
  Widget build(BuildContext context) {
    return PrintableDocumentScaffold(
      title: 'التقرير اليومي',
      subtitle: _formatDate(reportDate),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Section(
            title: 'قسم المبيعات',
            children: [
              _MetricLine(
                'إجمالي المبيعات النقدية',
                MoneyUtils.formatPiastersAsEgp(report.cashSalesAmountQirsh),
              ),
              _MetricLine(
                'إجمالي المبيعات الآجلة',
                MoneyUtils.formatPiastersAsEgp(
                  report.totalCreditSalesAmountQirsh,
                ),
              ),
              _MetricLine(
                'إجمالي المبيعات',
                MoneyUtils.formatPiastersAsEgp(report.totalSalesAmountQirsh),
              ),
            ],
          ),
          const Divider(),
          _Section(
            title: 'قسم المشتريات',
            children: [
              _MetricLine(
                'إجمالي المشتريات',
                MoneyUtils.formatPiastersAsEgp(
                  report.totalPurchaseAmountQirsh,
                ),
              ),
            ],
          ),
          const Divider(),
          _Section(
            title: 'التحصيل والمدفوعات',
            children: [
              _MetricLine(
                'تحصيل من العملاء',
                MoneyUtils.formatPiastersAsEgp(report.totalCollectionsAmountQirsh),
              ),
              _MetricLine(
                'مدفوعات للموردين',
                MoneyUtils.formatPiastersAsEgp(report.totalSupplierPaymentsQirsh),
              ),
            ],
          ),
          const Divider(),
          _Section(
            title: 'الملخص',
            children: [
              _MetricLine(
                'إجمالي الإيرادات',
                MoneyUtils.formatPiastersAsEgp(report.totalSalesAmountQirsh),
              ),
              if (report.totalExpenseAmountQirsh > 0)
                _MetricLine(
                  'إجمالي المصروفات',
                  MoneyUtils.formatPiastersAsEgp(report.totalExpenseAmountQirsh),
                ),
              if (report.totalOutstandingReceivablesQirsh > 0)
                _MetricLine(
                  'المستحق على العملاء',
                  MoneyUtils.formatPiastersAsEgp(
                    report.totalOutstandingReceivablesQirsh,
                  ),
                ),
              if (report.totalOutstandingSupplierPayablesQirsh > 0)
                _MetricLine(
                  'المستحق للموردين',
                  MoneyUtils.formatPiastersAsEgp(
                    report.totalOutstandingSupplierPayablesQirsh,
                  ),
                ),
              _MetricLine('عدد فواتير البيع', '${report.saleCount}'),
              _MetricLine('عدد فواتير الشراء', '${report.purchaseCount}'),
            ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
