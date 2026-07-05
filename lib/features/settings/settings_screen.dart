import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/placeholder_feature_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderFeatureScreen(
      title: 'الإعدادات',
      subtitle: 'إعدادات المستخدمين وفايربيز والصلاحيات الأساسية لاحقا.',
      icon: Icons.settings_rounded,
    );
  }
}
