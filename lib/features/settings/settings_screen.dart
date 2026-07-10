import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme_preset.dart';
import 'package:grain_warehouse_erp_lite/core/theme/theme_controller.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _establishmentNameController = TextEditingController();
  String? _lastIdentityName;

  @override
  void dispose() {
    _establishmentNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeScope.of(context);
    final identityController = BusinessIdentityScope.of(context);
    final textTheme = Theme.of(context).textTheme;
    final identityName = identityController.identity.establishmentName ?? '';
    if (_lastIdentityName != identityName) {
      _lastIdentityName = identityName;
      _establishmentNameController.text = identityName;
    }

    return AnimatedBuilder(
      animation: Listenable.merge([themeController, identityController]),
      builder: (context, _) {
        return ListView(
          children: [
            Text('الإعدادات', style: textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'اختيار ألوان واضحة وبيانات منشأة محفوظة على هذا الجهاز فقط.',
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
            const SizedBox(height: 16),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('هوية المنشأة', style: textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text(
                    'اكتب اسم المنشأة ليظهر في عنوان التطبيق وعلى الفواتير. هذا لا يغير أي أرقام أو أرصدة.',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _establishmentNameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم المنشأة',
                      helperText:
                          'اتركه فارغا لاستخدام اسم النظام الافتراضي.',
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: identityController.isLoading
                            ? null
                            : () => identityController.saveEstablishmentName(
                                  _establishmentNameController.text,
                                ),
                        icon: const Icon(Icons.business_rounded),
                        label: const Text('حفظ اسم المنشأة'),
                      ),
                      OutlinedButton.icon(
                        onPressed: identityController.isLoading
                            ? null
                            : () {
                                _establishmentNameController.clear();
                                identityController.saveEstablishmentName('');
                              },
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('استخدام الاسم الافتراضي'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'الاسم الحالي على الفواتير: ${identityController.identity.displayName}',
                  ),
                  if (identityController.message != null) ...[
                    const SizedBox(height: 8),
                    Text(identityController.message!),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'إضافة شعار مخصص مؤجلة حتى يتم دعم اختيار وحفظ ملفات الصور بأمان. لا توجد خانة شعار غير مكتملة.',
                  ),
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
