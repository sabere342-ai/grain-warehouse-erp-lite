import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payment.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/features/purchases/supplier_purchases_screen.dart';
import 'package:grain_warehouse_erp_lite/features/supplier_accounts/supplier_payment_dialog.dart';
import 'package:grain_warehouse_erp_lite/features/supplier_accounts/supplier_statement_screen.dart';
import 'package:grain_warehouse_erp_lite/features/suppliers/supplier_advance_actions_screen.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key, this.controller});

  final SupplierController? controller;

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  late final SupplierController _controller;
  late final SupplierAccountRepository _accountRepo;
  late final bool _ownsController;
  Map<String, int> _balances = const {};
  Set<String> _suppliersWithOpeningBalance = const {};

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        SupplierController(
          repository: AppRepositories.supplierRepository,
          accountRepository: AppRepositories.supplierAccountRepository,
        );
    _accountRepo = AppRepositories.supplierAccountRepository;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = AuthScope.of(context).state.user;
      if (user != null) {
        _controller.loadSuppliers(user);
        _loadBalances();
      }
    });
  }

  Future<void> _loadBalances() async {
    try {
      final balances = await _accountRepo.balancesBySupplierId();
      final entries = await _accountRepo.listEntries();
      final withOpening = entries
          .where((e) => e.type == SupplierAccountEntryType.openingBalance)
          .map((e) => e.supplierId)
          .toSet();
      if (!mounted) return;
      setState(() {
        _balances = balances;
        _suppliersWithOpeningBalance = withOpening;
      });
    } catch (_) {
      if (!mounted) return;
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _recordPayment(
    BuildContext context, {
    required user,
    required Supplier supplier,
  }) async {
    final balance = _balances[supplier.id] ?? 0;

    final financialAccounts =
        await AppRepositories.financialAccountRepository.listAccounts();
    if (!mounted) return;

    // ignore: use_build_context_synchronously
    final result = await showDialog<SupplierPaymentResult>(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (_) => SupplierPaymentDialog(
        supplier: supplier,
        balanceQirsh: balance,
        userId: user.id,
        financialAccounts: financialAccounts,
      ),
    );

    if (result == null) return;

    final draft = SupplierPaymentDraft(
      supplierId: supplier.id,
      date: result.date,
      amountQirsh: result.amountQirsh,
      createdByUserId: user.id,
      notes: result.notes,
      financialAccountId: result.financialAccountId,
      paymentMethod: result.paymentMethod,
      operationRequestId: result.operationRequestId,
      overpaymentApprovalId: result.overpaymentApprovalId,
    );

    try {
      await _accountRepo.createPayment(draft);
      await _loadBalances();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('تعذر تسجيل الدفع. تأكد من صحة البيانات.')),
      );
    }
  }

  Future<void> _recordOpeningBalance(
    BuildContext context, {
    required user,
    required Supplier supplier,
  }) async {
    final amount = await showDialog<int>(
      context: context,
      builder: (context) => const _SupplierOpeningBalanceDialog(),
    );

    if (amount == null) return;

    try {
      await _accountRepo.createOpeningBalanceEntry(
        supplierId: supplier.id,
        amountQirsh: amount,
        createdByUserId: user.id,
      );
      await _loadBalances();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل الرصيد الافتتاحي بنجاح.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('تعذر تسجيل الرصيد الافتتاحي. تأكد من صحة البيانات.')),
      );
    }
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
                    balanceQirsh: _balances[supplier.id] ?? 0,
                    hasOpeningBalance:
                        _suppliersWithOpeningBalance.contains(supplier.id),
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
                    onPayment: () =>
                        _recordPayment(context, user: user, supplier: supplier),
                    onOpeningBalance: () => _recordOpeningBalance(context,
                        user: user, supplier: supplier),
                    onAdvances: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SupplierAdvanceActionsScreen(
                            supplier: supplier,
                            user: user,
                            controller: _controller,
                          ),
                        ),
                      );
                      if (mounted) await _loadBalances();
                    },
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
    required this.balanceQirsh,
    required this.hasOpeningBalance,
    required this.onEdit,
    required this.onToggleActive,
    this.onPayment,
    this.onOpeningBalance,
    required this.onAdvances,
  });

  final Supplier supplier;
  final bool canManage;
  final int balanceQirsh;
  final bool hasOpeningBalance;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback? onPayment;
  final VoidCallback? onOpeningBalance;
  final VoidCallback onAdvances;

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
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                balanceQirsh > 0
                    ? 'له علينا: ${MoneyUtils.formatPiastersAsEgp(balanceQirsh)}'
                    : 'لا يوجد رصيد مستحق',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: balanceQirsh > 0
                          ? AppColors.text
                          : AppColors.mutedText,
                    ),
              ),
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
                if (!hasOpeningBalance)
                  OutlinedButton.icon(
                    onPressed: onOpeningBalance,
                    icon: const Icon(Icons.account_balance_rounded),
                    label: const Text('رصيد افتتاحي'),
                  ),
                if (balanceQirsh > 0)
                  OutlinedButton.icon(
                    onPressed: onPayment,
                    icon: const Icon(Icons.payments_rounded),
                    label: const Text('تسجيل دفعة'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: Key('supplier-advances-${supplier.id}'),
              onPressed: onAdvances,
              icon: const Icon(Icons.account_balance_wallet_rounded),
              label: const Text('سلف المورد'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => SupplierPurchasesScreen(
                          supplierId: supplier.id,
                          supplierName: supplier.name,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text('المشتريات'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => SupplierStatementScreen(
                          supplier: supplier,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.account_balance_rounded),
                  label: const Text('كشف حساب'),
                ),
              ),
            ],
          ),
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
      setState(() => _errorMessage = 'أدخل اسم المورد.');
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

class _SupplierOpeningBalanceDialog extends StatefulWidget {
  const _SupplierOpeningBalanceDialog();

  @override
  State<_SupplierOpeningBalanceDialog> createState() =>
      _SupplierOpeningBalanceDialogState();
}

class _SupplierOpeningBalanceDialogState
    extends State<_SupplierOpeningBalanceDialog> {
  final _amountController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('رصيد افتتاحي للمورد'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'أدخل المبلغ المستحق لهذا المورد كرصيد افتتاحي (بقيمة مالية).',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ بقروش',
                helperText:
                    'أدخل المبلغ الإجمالي بالقرش (مثال: 50000 = 500 جنيه).',
              ),
              textDirection: TextDirection.ltr,
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
          child: const Text('حفظ الرصيد الافتتاحي'),
        ),
      ],
    );
  }

  void _submit() {
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = 'أدخل مبلغا صحيحا أكبر من صفر.');
      return;
    }
    if (amount % 100 != 0) {
      setState(() => _errorMessage =
          'المبلغ يجب أن يكون من مضاعفات 100 (أي جنيه كامل بدون قروش مفردة).');
      return;
    }

    Navigator.of(context).pop(amount);
  }
}
