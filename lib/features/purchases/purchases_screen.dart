import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_service.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/payment_routing_policy.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_controller.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/features/documents/document_history_screen.dart';
import 'package:grain_warehouse_erp_lite/features/financial_accounts/negative_balance_approval_dialog.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({
    super.key,
    this.controller,
    this.supplierAccountRepository,
    this.financialAccountRepository,
    this.authRepository,
    this.negativeBalanceApprovalService,
  });

  final PurchaseController? controller;
  final SupplierAccountRepository? supplierAccountRepository;
  final FinancialAccountRepository? financialAccountRepository;
  final AuthRepository? authRepository;
  final NegativeBalanceApprovalService? negativeBalanceApprovalService;

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  late final PurchaseController _controller;
  late final bool _ownsController;
  late final SupplierAccountRepository _accountRepo;
  late final FinancialAccountRepository _financialAccountRepo;
  late final AuthRepository _authRepo;
  late final NegativeBalanceApprovalService _approvalService;
  Set<String> _supplierIdsWithPayments = {};

  @override
  void initState() {
    super.initState();
    _accountRepo = widget.supplierAccountRepository ??
        AppRepositories.supplierAccountRepository;
    _financialAccountRepo = widget.financialAccountRepository ??
        AppRepositories.financialAccountRepository;
    _authRepo = widget.authRepository ?? AppRepositories.authRepository;
    _approvalService = widget.negativeBalanceApprovalService ??
        AppRepositories.negativeBalanceApprovalService;
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        PurchaseController(
          purchaseRepository: AppRepositories.purchaseRepository,
          supplierRepository: AppRepositories.supplierRepository,
          productRepository: AppRepositories.productRepository,
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = AuthScope.of(context).state.user;
      if (user != null) {
        _controller.load(user);
        _loadPaymentSuppliers();
      }
    });
  }

  Future<void> _loadPaymentSuppliers() async {
    try {
      final payments = await _accountRepo.listPayments();
      if (!mounted) return;
      setState(() {
        _supplierIdsWithPayments = payments.map((p) => p.supplierId).toSet();
      });
    } catch (_) {
      // silently ignore — cancel button stays active by default
    }
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
      return const PremiumCard(child: Text('يجب تسجيل الدخول لعرض المشتريات.'));
    }

    final canCreate = user.permissions.canCreatePurchaseIntake;
    final canCancel = user.permissions.canCancelInvoice;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final canOpenForm = _controller.suppliers.isNotEmpty &&
            _controller.products.isNotEmpty &&
            canCreate;

        return ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('استلامات الشراء', style: textTheme.headlineMedium),
                      const SizedBox(height: 6),
                      Text(
                        canCreate
                            ? 'استلام الحبوب من الموردين وزيادة المخزون بحركة مرحلة. الإلغاء للمالك فقط.'
                            : 'عرض استلامات الشراء فقط. تسجيل الاستلام وإلغاء المستندات للمالك.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openHistory(context),
                  icon: const Icon(Icons.manage_search_rounded),
                  label: const Text('سجل المستندات'),
                ),
                const SizedBox(width: 8),
                if (canCreate)
                  FilledButton.icon(
                    onPressed: canOpenForm
                        ? () => _showPurchaseForm(user: user)
                        : null,
                    icon: const Icon(Icons.add_business_rounded),
                    label: const Text('تسجيل استلام حبوب'),
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
            else if (_controller.intakes.isEmpty)
              const PremiumCard(
                child: Text(
                  'لا توجد استلامات شراء مسجلة بعد. ستظهر هنا مستندات استلام الحبوب من الموردين.',
                ),
              )
            else
              ..._controller.intakes.reversed.map(
                (intake) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PurchaseIntakeCard(
                    intake: intake,
                    hasPayment:
                        _supplierIdsWithPayments.contains(intake.supplierId),
                    supplierName: _controller.displaySupplierName(intake),
                    productName: _controller.productName(intake.productId),
                    canCancel: canCancel,
                    onCancel: intake.isCancelled
                        ? null
                        : () => _confirmCancelPurchase(context, user, intake),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _openHistory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DocumentHistoryScreen(),
      ),
    );
  }

  Future<void> _showPurchaseForm({required AppUser user}) async {
    final accounts = (await _financialAccountRepo.listAccounts())
        .where((account) => account.isActive)
        .toList(growable: false);
    final balances = <String, int>{};
    for (final account in accounts) {
      balances[account.id] =
          await _financialAccountRepo.currentBalanceForAccount(account.id);
    }
    if (!mounted) return;
    final requestId =
        'purchase-ui-${DateTime.now().microsecondsSinceEpoch}-${user.id}';
    final draft = await showDialog<PurchaseIntakeDraft>(
      context: context,
      builder: (context) => _PurchaseFormDialog(
        suppliers: _controller.suppliers.where((supplier) {
          return supplier.isActive;
        }).toList(growable: false),
        products: _controller.products.where((product) {
          return product.isActive;
        }).toList(growable: false),
        userId: user.id,
        financialAccounts: accounts,
        accountBalancesQirsh: balances,
        operationRequestId: requestId,
      ),
    );

    if (draft == null) {
      return;
    }

    var preparedDraft = draft;
    if (draft.paymentMode == PurchasePaymentMode.paid) {
      final accountId = draft.financialAccountId!;
      final account = accounts.firstWhere((value) => value.id == accountId);
      final currentBalance =
          await _financialAccountRepo.currentBalanceForAccount(accountId);
      if (currentBalance < draft.totalAmountPiasters) {
        if (!mounted) return;
        final deficit = draft.totalAmountPiasters - currentBalance;
        if (!account.allowNegativeBalance) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'الرصيد غير كافٍ بمقدار ${MoneyUtils.formatPiastersAsEgp(deficit)}. '
                'الحساب لا يسمح بالرصيد السالب، ولم يتم تسجيل الشراء.',
              ),
            ),
          );
          return;
        }
        final approvalId = await NegativeBalanceApprovalDialog.show(
          context: context,
          authRepository: _authRepo,
          accountName: account.name,
          currentBalanceQirsh: currentBalance,
          requestedAmountQirsh: draft.totalAmountPiasters,
          operationDescription: 'سداد شراء مدفوع بالكامل',
          approvalService: _approvalService,
          approvalDraft: NegativeBalanceApprovalDraft(
            requestedByUserId: user.id,
            approvedByOwnerUserId: '',
            accountId: account.id,
            amountQirsh: draft.totalAmountPiasters,
            operationType: NegativeBalanceOperationType.purchasePayment,
            sourceDocumentId: requestId,
            sourceDocumentType:
                FinancialAccountEntrySource.purchasePayment.name,
            balanceBeforeQirsh: currentBalance,
            expectedBalanceAfterQirsh:
                currentBalance - draft.totalAmountPiasters,
            reason: 'سداد شراء يتجاوز رصيد الحساب المالي',
          ),
        );
        if (approvalId == null || !mounted) return;
        preparedDraft = PurchaseIntakeDraft(
          supplierId: draft.supplierId,
          supplierName: draft.supplierName,
          supplierPhone: draft.supplierPhone,
          supplierAddress: draft.supplierAddress,
          productId: draft.productId,
          quantityKg: draft.quantityKg,
          entryUnit: draft.entryUnit,
          unitPricePiastersPerKg: draft.unitPricePiastersPerKg,
          createdByUserId: draft.createdByUserId,
          notes: draft.notes,
          financialAccountId: draft.financialAccountId,
          paymentMethod: draft.paymentMethod,
          paymentMode: draft.paymentMode,
          paidAmountQirsh: draft.paidAmountQirsh,
          negativeBalanceApprovalId: approvalId,
          operationRequestId: draft.operationRequestId,
        );
      }
    }

    await _controller.createPurchaseIntake(user: user, draft: preparedDraft);
  }

  Future<void> _confirmCancelPurchase(
    BuildContext context,
    user,
    PurchaseIntake intake,
  ) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد إلغاء استلام الشراء'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تحذير مهم: سيتم إنشاء حركة مخزون عكسية لإلغاء أثر هذا الاستلام. لن يتم حذف المستند الأصلي أو الحركة الأصلية، وسيظهر الإلغاء في سجل المستندات للمالك.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'سبب الإلغاء'),
              maxLines: 2,
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(reasonController.text),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );

    if (reason == null || reason.trim().isEmpty) {
      return;
    }

    await _controller.cancelPurchaseIntake(
      user: user,
      purchaseIntakeId: intake.id,
      cancellationReason: reason,
    );
  }
}

class _PurchaseIntakeCard extends StatelessWidget {
  const _PurchaseIntakeCard({
    required this.intake,
    required this.hasPayment,
    required this.supplierName,
    required this.productName,
    required this.canCancel,
    this.onCancel,
  });

  final PurchaseIntake intake;
  final bool hasPayment;
  final String supplierName;
  final String productName;
  final bool canCancel;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(productName, style: textTheme.titleLarge)),
              if (intake.isCancelled)
                Chip(
                  label: const Text('ملغي'),
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Text('المورد: $supplierName'),
              Text('الكمية: ${_formatQuantity(intake.quantityKg)}'),
              Text(
                'السعر: ${MoneyUtils.formatPiastersAsEgp(intake.unitPricePiastersPerKg)} / كجم',
                textDirection: TextDirection.rtl,
              ),
              Text(
                'الإجمالي: ${MoneyUtils.formatPiastersAsEgp(intake.totalAmountPiasters)}',
              ),
              Text('التسوية: ${intake.paymentMode.labelAr}'),
              if (intake.paymentMethod != null)
                Text('طريقة الدفع: ${intake.paymentMethod!.labelAr}'),
            ],
          ),
          if (intake.notes != null) ...[
            const SizedBox(height: 8),
            Text(intake.notes!),
          ],
          if (intake.cancellation != null) ...[
            const SizedBox(height: 8),
            Text('سبب الإلغاء: ${intake.cancellation!.cancellationReason}'),
          ],
          if (canCancel &&
              !intake.isCancelled &&
              intake.paymentMode == PurchasePaymentMode.credit &&
              hasPayment) ...[
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Tooltip(
                message:
                    'للحفاظ على الحسابات، لا يتم إلغاء شراء تم تسجيل دفعة عليه.',
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('لا يمكن الإلغاء بعد تسجيل دفعة للمورد'),
                ),
              ),
            ),
          ],
          if (canCancel &&
              !intake.isCancelled &&
              (intake.paymentMode != PurchasePaymentMode.credit ||
                  !hasPayment)) ...[
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('إلغاء مستند الاستلام'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatQuantity(int quantityKg) {
    if (quantityKg >= GrainUnitConverter.kilogramsPerTon &&
        quantityKg % GrainUnitConverter.kilogramsPerTon == 0) {
      return '$quantityKg كجم (${quantityKg ~/ GrainUnitConverter.kilogramsPerTon} طن)';
    }

    return '$quantityKg كجم';
  }
}

class _PurchaseFormDialog extends StatefulWidget {
  const _PurchaseFormDialog({
    required this.suppliers,
    required this.products,
    required this.userId,
    required this.financialAccounts,
    required this.accountBalancesQirsh,
    required this.operationRequestId,
  });

  final List<Supplier> suppliers;
  final List<Product> products;
  final String userId;
  final List<FinancialAccount> financialAccounts;
  final Map<String, int> accountBalancesQirsh;
  final String operationRequestId;

  @override
  State<_PurchaseFormDialog> createState() => _PurchaseFormDialogState();
}

class _PurchaseFormDialogState extends State<_PurchaseFormDialog> {
  late String _supplierId = widget.suppliers.first.id;
  late String _productId = widget.products.first.id;
  GrainUnit _inputUnit = GrainUnit.kilogram;
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _notesController = TextEditingController();
  PurchasePaymentMode _paymentMode = PurchasePaymentMode.credit;
  PaymentMethod? _paymentMethod;
  String? _financialAccountId;
  String? _errorMessage;

  @override
  void dispose() {
    _quantityController.dispose();
    _unitPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تسجيل استلام حبوب'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _supplierId,
              decoration: const InputDecoration(labelText: 'المورد'),
              items: [
                for (final supplier in widget.suppliers)
                  DropdownMenuItem(
                    value: supplier.id,
                    child: Text(supplier.name),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _supplierId = value);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _productId,
              decoration: const InputDecoration(labelText: 'الصنف'),
              items: [
                for (final product in widget.products)
                  DropdownMenuItem(
                    value: product.id,
                    child: Text(product.name),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _productId = value);
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'الكمية',
                      helperText: 'اكتب الكمية حسب الوحدة المختارة.',
                    ),
                    textDirection: TextDirection.ltr,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<GrainUnit>(
                    value: _inputUnit,
                    decoration: const InputDecoration(labelText: 'الوحدة'),
                    items: const [
                      DropdownMenuItem(
                        value: GrainUnit.kilogram,
                        child: Text('كجم'),
                      ),
                      DropdownMenuItem(
                        value: GrainUnit.ton,
                        child: Text('طن'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _inputUnit = value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _unitPriceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'سعر الشراء بالجنيه / كجم',
                helperText: 'اكتب سعر شراء الكيلو بالجنيه.',
              ),
              textDirection: TextDirection.ltr,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PurchasePaymentMode>(
              key: const Key('purchase-payment-mode-field'),
              value: _paymentMode,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'نوع تسوية الشراء',
              ),
              items: const [
                DropdownMenuItem(
                  value: PurchasePaymentMode.credit,
                  child: Text('آجل بالكامل'),
                ),
                DropdownMenuItem(
                  value: PurchasePaymentMode.paid,
                  child: Text('مدفوع بالكامل'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _paymentMode = value;
                  if (value == PurchasePaymentMode.credit) {
                    _paymentMethod = null;
                    _financialAccountId = null;
                  }
                  _errorMessage = null;
                });
              },
            ),
            const SizedBox(height: 12),
            _buildSettlementSummary(context),
            if (_paymentMode == PurchasePaymentMode.paid) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<PaymentMethod>(
                key: const Key('purchase-payment-method-field'),
                value: _paymentMethod,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'طريقة الدفع *',
                  helperText: 'الشيكات غير مدعومة في العقد الحالي.',
                ),
                items: PaymentRoutingPolicy.selectablePaymentMethods
                    .map(
                      (method) => DropdownMenuItem(
                        value: method,
                        child: Text(method.labelAr),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (method) {
                  setState(() {
                    _paymentMethod = method;
                    if (!_selectedAccountIsCompatible()) {
                      _financialAccountId = null;
                    }
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('purchase-financial-account-field'),
                value: _financialAccountId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'الحساب المالي *',
                ),
                items: _compatibleAccounts()
                    .map(
                      (account) => DropdownMenuItem(
                        value: account.id,
                        child: Text(
                          '${account.type.iconEmoji} ${account.name} — '
                          '${MoneyUtils.formatPiastersAsEgp(widget.accountBalancesQirsh[account.id] ?? 0)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _paymentMethod == null
                    ? null
                    : (accountId) => setState(() {
                          _financialAccountId = accountId;
                          _errorMessage = null;
                        }),
              ),
              if (_selectedAccount != null) ...[
                const SizedBox(height: 12),
                _buildAccountImpact(context, _selectedAccount!),
              ],
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات اختيارية',
                helperText: 'مثال: رقم النقلة أو اسم السائق.',
              ),
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
          child: const Text('حفظ الاستلام'),
        ),
      ],
    );
  }

  void _submit() {
    final quantity = int.tryParse(_quantityController.text.trim());
    final unitPrice = _tryParsePrice(_unitPriceController.text);
    if (quantity == null || quantity <= 0) {
      setState(() =>
          _errorMessage = 'اكتب كمية الاستلام، ويجب أن تكون أكبر من صفر.');
      return;
    }
    if (unitPrice == null || unitPrice <= 0) {
      setState(() => _errorMessage = 'اكتب سعر الشراء بالجنيه بشكل صحيح.');
      return;
    }

    final quantityKg = _inputUnit == GrainUnit.ton
        ? GrainUnitConverter.tonsToKilograms(quantity)
        : quantity;

    final selectedSupplier = widget.suppliers.firstWhere(
      (s) => s.id == _supplierId,
    );
    final total = quantityKg * unitPrice;
    if (_paymentMode == PurchasePaymentMode.paid) {
      if (_paymentMethod == null) {
        setState(() => _errorMessage = 'اختر طريقة الدفع للشراء المدفوع.');
        return;
      }
      if (_financialAccountId == null) {
        setState(() => _errorMessage = 'اختر الحساب المالي لسداد الشراء.');
        return;
      }
      final account = _selectedAccount;
      if (account == null ||
          !account.isActive ||
          !PaymentRoutingPolicy.isCompatible(
            paymentMethod: _paymentMethod!,
            accountType: account.type,
          )) {
        setState(() => _errorMessage =
            'الحساب المالي غير نشط أو لا يتوافق مع طريقة الدفع.');
        return;
      }
    }

    Navigator.of(context).pop(
      PurchaseIntakeDraft(
        supplierId: _supplierId,
        supplierName: selectedSupplier.name,
        supplierPhone: selectedSupplier.phone,
        supplierAddress: selectedSupplier.address,
        productId: _productId,
        quantityKg: quantityKg,
        entryUnit: _inputUnit,
        unitPricePiastersPerKg: unitPrice,
        createdByUserId: widget.userId,
        notes: _notesController.text,
        paymentMode: _paymentMode,
        paymentMethod:
            _paymentMode == PurchasePaymentMode.paid ? _paymentMethod : null,
        financialAccountId: _paymentMode == PurchasePaymentMode.paid
            ? _financialAccountId
            : null,
        paidAmountQirsh:
            _paymentMode == PurchasePaymentMode.paid ? total : null,
        operationRequestId: widget.operationRequestId,
      ),
    );
  }

  int? _tryParsePrice(String value) {
    try {
      return MoneyUtils.parseEgpToPiasters(value, allowZero: false);
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  int? get _calculatedTotalQirsh {
    final quantity = int.tryParse(_quantityController.text.trim());
    final unitPrice = _tryParsePrice(_unitPriceController.text);
    if (quantity == null || quantity <= 0 || unitPrice == null) return null;
    final quantityKg = _inputUnit == GrainUnit.ton
        ? GrainUnitConverter.tonsToKilograms(quantity)
        : quantity;
    return quantityKg * unitPrice;
  }

  List<FinancialAccount> _compatibleAccounts() {
    final method = _paymentMethod;
    if (method == null) return const [];
    return widget.financialAccounts
        .where(
          (account) =>
              account.isActive &&
              PaymentRoutingPolicy.isCompatible(
                paymentMethod: method,
                accountType: account.type,
              ),
        )
        .toList(growable: false);
  }

  bool _selectedAccountIsCompatible() {
    final accountId = _financialAccountId;
    if (accountId == null) return true;
    return _compatibleAccounts().any((account) => account.id == accountId);
  }

  FinancialAccount? get _selectedAccount {
    final accountId = _financialAccountId;
    if (accountId == null) return null;
    for (final account in widget.financialAccounts) {
      if (account.id == accountId) return account;
    }
    return null;
  }

  Widget _buildSettlementSummary(BuildContext context) {
    final isCredit = _paymentMode == PurchasePaymentMode.credit;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCredit
            ? colorScheme.secondaryContainer.withAlpha(90)
            : colorScheme.primaryContainer.withAlpha(90),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isCredit
            ? 'سيُضاف كامل إجمالي الفاتورة إلى مديونية المورد، ولن يتغير أي حساب مالي.'
            : 'سيُسدد كامل إجمالي الفاتورة من الحساب المختار، ولن تبقى مديونية على المورد.',
        key: const Key('purchase-settlement-summary'),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildAccountImpact(
    BuildContext context,
    FinancialAccount account,
  ) {
    final balance = widget.accountBalancesQirsh[account.id] ?? 0;
    final total = _calculatedTotalQirsh;
    final projected = total == null ? null : balance - total;
    final hasDeficit = projected != null && projected < 0;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('purchase-account-impact-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasDeficit
            ? colorScheme.errorContainer.withAlpha(100)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الرصيد الحالي: ${MoneyUtils.formatPiastersAsEgp(balance)}'),
          if (total != null)
            Text('قيمة السداد: ${MoneyUtils.formatPiastersAsEgp(total)}'),
          if (projected != null)
            Text(
              'الرصيد بعد السداد: ${MoneyUtils.formatPiastersAsEgp(projected)}',
              style: TextStyle(
                color: hasDeficit ? colorScheme.error : null,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (hasDeficit)
            Text(
              account.allowNegativeBalance
                  ? 'العجز ${MoneyUtils.formatPiastersAsEgp(-projected)} — يلزم اعتماد المالك قبل التسجيل.'
                  : 'العجز ${MoneyUtils.formatPiastersAsEgp(-projected)} — الحساب لا يسمح بالرصيد السالب.',
              style: TextStyle(
                color: colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
