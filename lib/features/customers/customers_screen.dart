import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/placeholder_feature_screen.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderFeatureScreen(
      title: 'العملاء',
      subtitle: 'بطاقات العملاء وأرصدتهم المحسوبة لاحقا من القيود.',
      icon: Icons.groups_2_rounded,
    );
  }
}
