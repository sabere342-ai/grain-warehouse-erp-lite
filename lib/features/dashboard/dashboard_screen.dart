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
        Text('لوحة متابعة المخزن', style: textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          'نظرة سريعة على حركة الحبوب والمخزون. استخدم التقارير للتفاصيل اليومية.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 4 : 2;
            return GridView.count(
              crossAxisCount: columns,
              childAspectRatio: constraints.maxWidth >= 900 ? 1.35 : 1.15,
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
            'الأرقام هنا للمتابعة السريعة فقط. راجع شاشة المخزون وسجل المستندات قبل أي قرار مؤثر على الكميات.',
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
        ],
      ),
    );
  }
}
