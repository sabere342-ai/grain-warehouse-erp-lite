import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/placeholder_feature_screen.dart';

class PurchasesScreen extends StatelessWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderFeatureScreen(
      title: 'المشتريات',
      subtitle: 'مكان فواتير شراء الحبوب من الموردين لاحقا.',
      icon: Icons.shopping_bag_rounded,
    );
  }
}
