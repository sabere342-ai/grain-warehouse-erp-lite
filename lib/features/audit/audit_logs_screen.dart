import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/placeholder_feature_screen.dart';

class AuditLogsScreen extends StatelessWidget {
  const AuditLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderFeatureScreen(
      title: 'سجل التدقيق',
      subtitle:
          'مسار محمي للمالك فقط. لا توجد بيانات تدقيق منفذة في هذه المرحلة.',
      icon: Icons.fact_check_rounded,
    );
  }
}
