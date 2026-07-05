import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: PremiumCard(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.admin_panel_settings_rounded,
                        size: 52,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'إعداد المالك الأول',
                        textAlign: TextAlign.center,
                        style: textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'لا يوجد مالك مسجل لهذا المخزن. أنشئ حساب المالك للبدء.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge?.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _nameController,
                        textDirection: TextDirection.rtl,
                        decoration: const InputDecoration(
                          labelText: 'اسم المالك',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phoneController,
                        textDirection: TextDirection.rtl,
                        decoration: const InputDecoration(
                          labelText: 'رقم الهاتف',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        textDirection: TextDirection.rtl,
                        decoration: const InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                      ),
                      if (auth.state.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          auth.state.errorMessage!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _isSubmitting ? null : _submit,
                        icon: const Icon(Icons.check_circle_rounded),
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
