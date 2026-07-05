import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/placeholder_feature_screen.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderFeatureScreen(
      title: 'المصروفات',
      subtitle: 'تسجيل المصروفات النقدية سيضاف في مرحلة لاحقة.',
      icon: Icons.receipt_long_rounded,
    );
  }
}
