import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key, this.controller});

  final SupplierController? controller;

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  late final SupplierController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        SupplierController(repository: AppRepositories.supplierRepository);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = AuthScope.of(context).state.user;
      if (user != null) {
        _controller.loadSuppliers(user);
      }
    });
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).state.user;
    final textTheme = Theme.of(context).textTheme;

    if (user == null) {
      return const PremiumCard(child: Text('يجب تسجيل الدخول لعرض الموردين.'));
    }

    final canManage = user.permissions.canManageSuppliers;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الموردون', style: textTheme.headlineMedium),
                      const SizedBox(height: 6),
                      Text(
                        canManage
                            ? 'إدارة بيانات موردي الحبوب فقط.'
                            : 'عرض الموردين النشطين فقط.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canManage)
                  FilledButton.icon(
                    onPressed: () => _showSupplierForm(context, user: user),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('إضافة مورد'),
                  ),
              ],
            ),
            if (_controller.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _controller.errorMessage!,
                style: textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_controller.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_controller.suppliers.isEmpty)
              const PremiumCard(child: Text('لا توجد بيانات موردين بعد.'))
            else
              ..._controller.suppliers.map(
                (supplier) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SupplierCard(
                    supplier: supplier,
                    canManage: canManage,
                    onEdit: () => _showSupplierForm(
                      context,
                      user: user,
                      supplier: supplier,
                    ),
                    onToggleActive: () => _controller.setSupplierActive(
                      user: user,
                      supplierId: supplier.id,
                      isActive: !supplier.isActive,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showSupplierForm(
    BuildContext context, {
    required user,
    Supplier? supplier,
  }) async {
    final draft = await showDialog<SupplierDraft>(
      context: context,
      builder: (context) => _SupplierFormDialog(supplier: supplier),
    );

    if (draft == null) {
      return;
    }

    if (supplier == null) {
      await _controller.createSupplier(user: user, draft: draft);
    } else {
      await _controller.updateSupplier(
        user: user,
        supplierId: supplier.id,
        draft: draft,
      );
    }
  }
}

class _SupplierCard extends StatelessWidget {
  const _SupplierCard({
    required this.supplier,
    required this.canManage,
    required this.onEdit,
    required this.onToggleActive,
  });

  final Supplier supplier;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(supplier.name, style: textTheme.titleLarge)),
              _StatusChip(isActive: supplier.isActive),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (supplier.phone != null) Text('الهاتف: ${supplier.phone}'),
              if (supplier.address != null)
                Text('العنوان: ${supplier.address}'),
            ],
          ),
          if (supplier.notes != null) ...[
            const SizedBox(height: 8),
            Text(supplier.notes!),
          ],
          if (canManage) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('تعديل'),
                ),
                OutlinedButton.icon(
                  onPressed: onToggleActive,
                  icon: Icon(
                    supplier.isActive
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                  label: Text(supplier.isActive ? 'إيقاف' : 'تفعيل'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(isActive ? 'نشط' : 'متوقف'),
      backgroundColor: isActive ? AppColors.surfaceAlt : AppColors.border,
    );
  }
}

class _SupplierFormDialog extends StatefulWidget {
  const _SupplierFormDialog({this.supplier});

  final Supplier? supplier;

  @override
  State<_SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends State<_SupplierFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final supplier = widget.supplier;
    _nameController = TextEditingController(text: supplier?.name ?? '');
    _phoneController = TextEditingController(text: supplier?.phone ?? '');
    _addressController = TextEditingController(text: supplier?.address ?? '');
    _notesController = TextEditingController(text: supplier?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.supplier == null ? 'إضافة مورد' : 'تعديل مورد'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'اسم المورد'),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'الهاتف اختياري'),
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'العنوان اختياري'),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'ملاحظات اختيارية'),
              maxLines: 2,
              textDirection: TextDirection.rtl,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('حفظ'),
        ),
      ],
    );
  }

  void _submit() {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'ادخل اسم المورد.');
      return;
    }

    Navigator.of(context).pop(
      SupplierDraft(
        name: _nameController.text,
        phone: _phoneController.text,
        address: _addressController.text,
        notes: _notesController.text,
      ),
    );
  }
}
