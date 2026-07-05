import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/placeholder_feature_screen.dart';

class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderFeatureScreen(
      title: 'المبيعات',
      subtitle: 'مكان فواتير البيع لاحقا مع سعر صنف قابل للتعديل.',
      icon: Icons.point_of_sale_rounded,
    );
  }
}
