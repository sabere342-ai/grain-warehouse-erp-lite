import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/features/financial_reports/account_balance_report_screen.dart';
import 'package:grain_warehouse_erp_lite/features/financial_reports/account_statement_report_screen.dart';
import 'package:grain_warehouse_erp_lite/features/financial_reports/payment_method_report_screen.dart';
import 'package:grain_warehouse_erp_lite/features/financial_reports/transfer_report_screen.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class FinancialReportsScreen extends StatelessWidget {
  const FinancialReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).state.user;
    final textTheme = Theme.of(context).textTheme;

    if (user == null || !user.permissions.canViewFinancialReports) {
      return const Scaffold(
        body: Center(child: Text('ليس لديك صلاحية عرض التقارير المالية.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('التقارير المالية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('التقارير المالية', style: textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'تقارير الأرصدة، كشف الحساب، طرق الدفع، والتحويلات الداخلية',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
          ),
          const SizedBox(height: 16),
          _ReportCard(
            title: 'أرصدة الحسابات',
            subtitle: 'عرض أرصدة جميع الحسابات المالية لل période المحددة',
            icon: Icons.account_balance_wallet_rounded,
            onTap: () => _navigate(context, const AccountBalanceReportScreen()),
          ),
          const SizedBox(height: 12),
          _ReportCard(
            title: 'كشف حساب مالي',
            subtitle: 'عرض حركات حساب مالي محدد مع الرصيد الجاري',
            icon: Icons.receipt_long_rounded,
            onTap: () =>
                _navigate(context, const AccountStatementReportScreen()),
          ),
          const SizedBox(height: 12),
          _ReportCard(
            title: 'تقرير طرق الدفع',
            subtitle: 'إحصائيات العمليات حسب طريقة الدفع',
            icon: Icons.payments_rounded,
            onTap: () => _navigate(context, const PaymentMethodReportScreen()),
          ),
          const SizedBox(height: 12),
          _ReportCard(
            title: 'تقرير التحويلات الداخلية',
            subtitle: 'سجل التحويلات بين الحسابات المالية',
            icon: Icons.swap_horiz_rounded,
            onTap: () => _navigate(context, const TransferReportScreen()),
          ),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PremiumCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall
                        ?.copyWith(color: AppColors.mutedText),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded),
          ],
        ),
      ),
    );
  }
}
