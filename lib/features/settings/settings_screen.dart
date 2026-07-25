import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/theme_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/business_identity_header.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_page_header.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_theme_selector.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _establishmentNameController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _lastIdentityName;
  String? _lastTaxNumber;
  String? _lastAddress;
  String? _lastPhone;

  @override
  void dispose() {
    _establishmentNameController.dispose();
    _taxNumberController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
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
    final currentTax = identityController.identity.taxNumber ?? '';
    if (_lastTaxNumber != currentTax) {
      _lastTaxNumber = currentTax;
      _taxNumberController.text = currentTax;
    }
    final currentAddress = identityController.identity.address ?? '';
    if (_lastAddress != currentAddress) {
      _lastAddress = currentAddress;
      _addressController.text = currentAddress;
    }
    final currentPhone = identityController.identity.phone ?? '';
    if (_lastPhone != currentPhone) {
      _lastPhone = currentPhone;
      _phoneController.text = currentPhone;
    }

    return AnimatedBuilder(
      animation: Listenable.merge([themeController, identityController]),
      builder: (context, _) {
        return ListView(
          children: [
            const GhalalPageHeader(
              title: 'الإعدادات',
              subtitle:
                  'اختيار ألوان واضحة وبيانات منشأة محفوظة على هذا الجهاز فقط.',
              icon: Icons.settings_rounded,
            ),
            const SizedBox(height: AppSpacing.md),
            GhalalThemeSelector(controller: themeController),
            const SizedBox(height: AppSpacing.md),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('هوية المنشأة', style: textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'اكتب اسم المنشأة ليظهر في عنوان التطبيق وعلى الفواتير. هذا لا يغير أي أرقام أو أرصدة.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _establishmentNameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم المنشأة',
                      helperText: 'اتركه فارغا لاستخدام اسم النظام الافتراضي.',
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: AppSpacing.sm),
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
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'الاسم الحالي على الفواتير: ${identityController.identity.displayName}',
                  ),
                  if (identityController.message != null) ...[
                    const SizedBox(height: 8),
                    Text(identityController.message!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('معاينة الهوية', style: textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'هذا شكل الهوية كما يظهر في التطبيق.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: BusinessIdentityHeader(
                      identity: identityController.identity,
                      showLogo: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _LogoSection(identityController: identityController),
            const SizedBox(height: AppSpacing.md),
            _ProfileDetailsSection(
              identityController: identityController,
              taxNumberController: _taxNumberController,
              addressController: _addressController,
              phoneController: _phoneController,
            ),
          ],
        );
      },
    );
  }
}

class _LogoSection extends StatelessWidget {
  const _LogoSection({required this.identityController});

  final BusinessIdentityController identityController;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasLogo = identityController.identity.hasLogo;
    final logo = identityController.identity.logo;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('شعار المنشأة', style: textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'اختر شعارا ليظهر داخل التطبيق وعلى فواتير البيع والشراء المطبوعة وملفات PDF.',
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'الأنواع المدعومة: PNG, JPG/JPEG. الحد الأقصى: 1 ميجابايت، 2048×2048 بكسل.',
          ),
          const SizedBox(height: AppSpacing.md),
          if (hasLogo) ...[
            _LogoPreview(managedFileName: logo?.managedFileName ?? ''),
            const SizedBox(height: AppSpacing.sm),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: identityController.isLoading
                    ? null
                    : () => _pickAndSaveLogo(context, identityController),
                icon: const Icon(Icons.image_rounded),
                label: Text(hasLogo ? 'استبدال الشعار' : 'اختيار شعار'),
              ),
              if (hasLogo)
                OutlinedButton.icon(
                  onPressed: identityController.isLoading
                      ? null
                      : () => identityController.removeLogo(),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('إزالة الشعار'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (hasLogo && logo != null)
            Text(
              'الشعار الحالي: ${logo.mimeType} — ${logo.width}×${logo.height}',
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'أيقونة تطبيق Windows تحدد أثناء تجهيز وبناء النسخة ولا تتغير من داخل البرنامج.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndSaveLogo(
    BuildContext context,
    BusinessIdentityController controller,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('الملف فارغ أو غير قابل للقراءة.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final ext = file.extension?.toLowerCase() ?? '';
      String mimeType;
      if (ext == 'png') {
        mimeType = 'image/png';
      } else if (ext == 'jpg' || ext == 'jpeg') {
        mimeType = 'image/jpeg';
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('النوع غير مدعوم. استخدم PNG أو JPG فقط.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      if (bytes.length > 1024 * 1024) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('حجم الملف يتجاوز الحد الأقصى (1 ميجابايت).'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      if (!_isValidImageSignature(bytes, mimeType)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('الملف تالف أو ليس صورة صالحة.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      if (!_isValidDimensions(bytes, mimeType)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('أبعاد الصورة تتجاوز الحد الأقصى (2048×2048 بكسل).'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      await controller.saveLogo(bytes, mimeType);

      if (context.mounted) {
        final msg = controller.message;
        if (msg != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: msg.contains('تعذر') ? Colors.red : Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء اختيار الملف.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  bool _isValidImageSignature(Uint8List bytes, String mimeType) {
    if (bytes.isEmpty) return false;
    if (mimeType == 'image/png') {
      return bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47 &&
          bytes[4] == 0x0D &&
          bytes[5] == 0x0A &&
          bytes[6] == 0x1A &&
          bytes[7] == 0x0A;
    }
    if (mimeType == 'image/jpeg') {
      return bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
    }
    return false;
  }

  bool _isValidDimensions(Uint8List bytes, String mimeType) {
    try {
      if (mimeType == 'image/png' && bytes.length >= 24) {
        if (bytes[0] == 0x89 && bytes[1] == 0x50) {
          final w = (bytes[16] << 24) |
              (bytes[17] << 16) |
              (bytes[18] << 8) |
              bytes[19];
          final h = (bytes[20] << 24) |
              (bytes[21] << 16) |
              (bytes[22] << 8) |
              bytes[23];
          return w > 0 && w <= 2048 && h > 0 && h <= 2048;
        }
      }
      if (mimeType == 'image/jpeg' && bytes.length >= 4) {
        if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
          int offset = 2;
          while (offset < bytes.length - 1) {
            if (bytes[offset] != 0xFF) break;
            final marker = bytes[offset + 1];
            if (marker >= 0xC0 &&
                marker <= 0xCF &&
                marker != 0xC4 &&
                marker != 0xC8 &&
                marker != 0xCC) {
              if (offset + 9 < bytes.length) {
                final h = (bytes[offset + 5] << 8) | bytes[offset + 6];
                final w = (bytes[offset + 7] << 8) | bytes[offset + 8];
                return w > 0 && w <= 2048 && h > 0 && h <= 2048;
              }
            }
            if (offset + 3 < bytes.length) {
              final segLen = (bytes[offset + 2] << 8) | bytes[offset + 3];
              offset += 2 + segLen;
            } else {
              break;
            }
          }
        }
      }
    } catch (_) {}
    return true;
  }
}

class _LogoPreview extends StatelessWidget {
  const _LogoPreview({required this.managedFileName});

  final String managedFileName;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _loadLogoBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        return Container(
          constraints: const BoxConstraints(maxHeight: 80, maxWidth: 200),
          child: Image.memory(
            snapshot.data!,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  Future<Uint8List?> _loadLogoBytes() async {
    if (managedFileName.isEmpty) return null;
    try {
      return await AppRepositories.businessIdentityRepository
          .loadLogoBytes(managedFileName);
    } catch (_) {
      return null;
    }
  }
}

class _ProfileDetailsSection extends StatelessWidget {
  const _ProfileDetailsSection({
    required this.identityController,
    required this.taxNumberController,
    required this.addressController,
    required this.phoneController,
  });

  final BusinessIdentityController identityController;
  final TextEditingController taxNumberController;
  final TextEditingController addressController;
  final TextEditingController phoneController;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('بيانات المنشأة الإضافية', style: textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'بيانات اختيارية تظهر على الفواتير والمستندات المطبوعة. اترك الحقل فارغاً إذا لا تريد إظهاره.',
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: taxNumberController,
            decoration: const InputDecoration(
              labelText: 'رقم التسجيل الضريبي',
              helperText: 'اختياري — لا يظهر إذا فارغ.',
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: addressController,
            decoration: const InputDecoration(
              labelText: 'العنوان',
              helperText: 'اختياري — يظهر تحت اسم المنشأة.',
            ),
            textDirection: TextDirection.rtl,
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: phoneController,
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف',
              helperText: 'اختياري — يظهر على المستندات.',
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: identityController.isLoading
                ? null
                : () => identityController.saveProfileDetails(
                      taxNumber: taxNumberController.text,
                      address: addressController.text,
                      phone: phoneController.text,
                    ),
            icon: const Icon(Icons.save_rounded),
            label: const Text('حفظ البيانات'),
          ),
        ],
      ),
    );
  }
}
