import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class FirstOwnerSetupScreen extends StatefulWidget {
  const FirstOwnerSetupScreen({super.key});

  @override
  State<FirstOwnerSetupScreen> createState() => _FirstOwnerSetupScreenState();
}

class _FirstOwnerSetupScreenState extends State<FirstOwnerSetupScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppComponentSizes.authMaxWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: PremiumCard(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        label: 'إعداد المالك الأول',
                        child: Icon(
                          Icons.admin_panel_settings_rounded,
                          size: AppIconSizes.hero,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'إعداد المالك الأول',
                        textAlign: TextAlign.center,
                        style: textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'لا يوجد مالك مسجل لهذا المخزن. أنشئ حساب المالك للبدء.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        key: const Key('setup-name-field'),
                        controller: _nameController,
                        textDirection: TextDirection.rtl,
                        decoration: const InputDecoration(
                          labelText: 'اسم المالك',
                          prefixIcon: Icon(Icons.badge_rounded),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        key: const Key('setup-phone-field'),
                        controller: _phoneController,
                        textDirection: TextDirection.rtl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'رقم الهاتف',
                          prefixIcon: Icon(Icons.phone_rounded),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        key: const Key('setup-password-field'),
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textDirection: TextDirection.rtl,
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'إظهار كلمة المرور'
                                : 'إخفاء كلمة المرور',
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                          ),
                        ),
                      ),
                      if (auth.state.errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            auth.state.errorMessage!,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton.icon(
                        key: const Key('setup-submit-button'),
                        onPressed: _isSubmitting ? null : _submit,
                        icon: _isSubmitting
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle_rounded),
                        label: Text(_isSubmitting
                            ? 'جاري الحفظ...'
                            : 'إنشاء حساب المالك'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    await AuthScope.of(context).createFirstOwner(
      name: _nameController.text,
      phone: _phoneController.text,
      password: _passwordController.text,
    );
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }
}
