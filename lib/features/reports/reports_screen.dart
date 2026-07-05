import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/placeholder_feature_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderFeatureScreen(
      title: 'التقارير',
      subtitle: 'تقارير بسيطة للمخزون والأرصدة والمبيعات لاحقا.',
      icon: Icons.bar_chart_rounded,
    );
  }
}
