import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme_preset.dart';
import 'package:grain_warehouse_erp_lite/core/theme/theme_controller.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeScope.of(context);
    final textTheme = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return ListView(
          children: [
            Text('الإعدادات', style: textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'اختيار ألوان واضحة للبرنامج على هذا الجهاز فقط.',
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ألوان البرنامج', style: textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text(
                    'اختر شكلا بسيطا. الاختيار يحفظ على هذا الجهاز ولا يغير بيانات البيع أو المخزون.',
                  ),
                  const SizedBox(height: 14),
                  for (final preset in AppThemePreset.values) ...[
                    RadioListTile<String>(
                      value: preset.id,
                      groupValue: themeController.preset.id,
                      onChanged: themeController.isLoading
                          ? null
                          : (_) => themeController.selectPreset(preset),
                      title: Text(preset.labelAr),
                      secondary: _ThemeSwatch(preset: preset),
                    ),
                  ],
                  if (themeController.message != null) ...[
                    const SizedBox(height: 8),
                    Text(themeController.message!),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.preset});

  final AppThemePreset preset;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Dot(color: preset.seed),
        const SizedBox(width: 4),
        _Dot(color: preset.surfaceAlt),
        const SizedBox(width: 4),
        _Dot(color: preset.tertiary),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}
