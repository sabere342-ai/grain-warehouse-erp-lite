import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme_mode.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme_preset.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';
import 'package:grain_warehouse_erp_lite/core/theme/theme_controller.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class GhalalThemeSelector extends StatelessWidget {
  const GhalalThemeSelector({
    super.key,
    required this.controller,
  });

  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final textTheme = Theme.of(context).textTheme;
        return PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('المظهر والألوان', style: textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'اختر وضع العرض ولمسة اللون. الاختيار محفوظ على هذا الجهاز ولا يغير بيانات البيع أو المخزون.',
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('وضع العرض', style: textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final mode in AppThemeMode.values)
                    ChoiceChip(
                      key: Key('theme-mode-${mode.id}'),
                      label: Text(mode.labelAr),
                      selected: controller.mode == mode,
                      onSelected: controller.isLoading
                          ? null
                          : (_) => controller.selectMode(mode),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text('لمسة اللون', style: textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              for (final preset in AppThemePreset.accentValues)
                RadioListTile<String>(
                  value: preset.id,
                  groupValue: controller.preset.id,
                  onChanged: controller.isLoading
                      ? null
                      : (_) => controller.selectPreset(preset),
                  title: Text(preset.labelAr),
                  secondary: _ThemeSwatch(preset: preset),
                ),
              if (controller.message != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Semantics(
                  liveRegion: true,
                  child: Text(controller.message!),
                ),
              ],
            ],
          ),
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
    return Semantics(
      label: 'ألوان ${preset.labelAr}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(color: preset.seed),
          const SizedBox(width: AppSpacing.xxs),
          _Dot(color: preset.surfaceAlt),
          const SizedBox(width: AppSpacing.xxs),
          _Dot(color: preset.tertiary),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppIconSizes.sm,
      height: AppIconSizes.sm,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}
