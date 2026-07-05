import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/placeholder_feature_screen.dart';

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderFeatureScreen(
      title: 'الأصناف',
      subtitle: 'تعريف أصناف الحبوب وأسعار البيع الافتراضية لاحقا.',
      icon: Icons.inventory_2_rounded,
    );
  }
}
