import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/placeholder_feature_screen.dart';

class SuppliersScreen extends StatelessWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderFeatureScreen(
      title: 'الموردون',
      subtitle: 'بطاقات الموردين وحساباتهم المحسوبة لاحقا من القيود.',
      icon: Icons.local_shipping_rounded,
    );
  }
}
