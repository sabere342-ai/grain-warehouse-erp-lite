import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      children: [
        Text('لوحة المتابعة', style: textTheme.headlineMedium),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 4 : 2;
            return GridView.count(
              crossAxisCount: columns,
              childAspectRatio: constraints.maxWidth >= 900 ? 1.8 : 1.35,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: const [
                _MetricCard('رصيد النقدية', '0.00 ج.م', Icons.payments_rounded),
                _MetricCard(
                    'مبيعات اليوم', '0.00 ج.م', Icons.point_of_sale_rounded),
                _MetricCard('مخزون القمح', '0 كجم', Icons.grain_rounded),
                _MetricCard(
                    'تنبيهات المخزون', '0', Icons.warning_amber_rounded),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        const PremiumCard(
          child: Text(
            'مرحلة تأسيس الواجهة فقط: لا توجد مبيعات أو مشتريات أو قيود مالية أو حركات مخزون منفذة بعد.',
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: AppColors.olive),
          Text(label, style: textTheme.titleMedium),
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
