import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_controller.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/payment_routing_policy.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';
import 'package:grain_warehouse_erp_lite/features/customers/customer_advance_actions_screen.dart';
import 'package:grain_warehouse_erp_lite/features/financial_accounts/negative_balance_approval_dialog.dart';
import 'package:grain_warehouse_erp_lite/features/opening_balances/opening_balance_amount_dialog.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_customer_statement_view.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_page_header.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_responsive_dialog.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_search_field.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_state_view.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key, this.controller});

  final CustomerController? controller;

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  late final CustomerController _controller;
  late final bool _ownsController;
  String? _activeCollectionCustomerId;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        CustomerController(
          repository: AppRepositories.customerRepository,
          accountRepository: AppRepositories.customerAccountRepository,
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = AuthScope.of(context).state.user;
      if (user != null) {
        _controller.loadCustomers(user);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).state.user;

    if (user == null) {
      return const PremiumCard(child: Text('يجب تسجيل الدخول لعرض العملاء.'));
    }

    final canManage = user.permissions.canCreateCustomerPayment ||
        user.permissions.canAccessSettings;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final normalizedQuery = _query.trim().toLowerCase();
        final visibleCustomers = _controller.customers.where((customer) {
          if (normalizedQuery.isEmpty) return true;
          return [
            customer.name,
            customer.phone ?? '',
            customer.notes ?? '',
          ].join(' ').toLowerCase().contains(normalizedQuery);
        }).toList(growable: false);
        return ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          children: [
            GhalalPageHeader(
              title: 'العملاء',
              subtitle:
                  'أرصدة العملاء محسوبة من البيع الآجل والتحصيل فقط، ولا يوجد تعديل يدوي للرصيد.',
              icon: Icons.people_rounded,
              actions: [
                if (canManage)
                  FilledButton.icon(
                    onPressed: () => _showCustomerForm(context, user: user),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('إضافة عميل'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            GhalalSearchField(
              key: const Key('customers-search-field'),
              controller: _searchController,
              hintText: 'بحث باسم العميل أو الهاتف...',
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_controller.errorMessage != null)
              GhalalErrorState(
                message: _controller.errorMessage!,
                onRetry: () {
                  final user = AuthScope.of(context).state.user;
                  if (user != null) _controller.loadCustomers(user);
                },
              )
            else if (_controller.isLoading)
              const GhalalLoadingState(label: 'جاري تحميل العملاء...')
            else if (_controller.customers.isEmpty)
              const GhalalEmptyState(
                title: 'لا توجد بيانات عملاء',
                message: 'أضف أول عميل لبدء إدارة الحسابات.',
                icon: Icons.people_outline_rounded,
              )
            else if (visibleCustomers.isEmpty)
              const GhalalEmptyState(
                title: 'لا توجد نتائج مطابقة',
                message: 'امسح البحث أو استخدم اسمًا أو هاتفًا مختلفًا.',
                icon: Icons.search_off_rounded,
              )
            else
              ...visibleCustomers.map(
                (customer) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CustomerCard(
                    customer: customer,
                    balanceQirsh: _controller.balanceForCustomer(customer.id),
                    hasOpeningBalance:
                        _controller.hasOpeningBalanceForCustomer(customer.id),
                    canManage: canManage,
                    onEdit: () => _showCustomerForm(
                      context,
                      user: user,
                      customer: customer,
                    ),
                    onToggleActive: () => _controller.setCustomerActive(
                      user: user,
                      customerId: customer.id,
                      isActive: !customer.isActive,
                    ),
                    onStatement: () => _showStatement(context, customer),
                    onAdvances: () => _showAdvances(
                      context,
                      user: user,
                      customer: customer,
                    ),
                    onPreviewStatement: () =>
                        _showStatementPreview(context, customer),
                    onCollection: () => _showCollectionForm(
                      context,
                      user: user,
                      customer: customer,
                      balanceQirsh: _controller.balanceForCustomer(customer.id),
                    ),
                    collectionBusy: _activeCollectionCustomerId == customer.id,
                    onOpeningBalance: () => _recordOpeningBalance(
                      context,
                      user: user,
                      customer: customer,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showCustomerForm(
    BuildContext context, {
    required AppUser user,
    Customer? customer,
  }) async {
    final draft = await showDialog<CustomerDraft>(
      context: context,
      builder: (context) => _CustomerFormDialog(customer: customer),
    );
    if (draft == null) {
      return;
    }
    if (customer == null) {
      await _controller.createCustomer(user: user, draft: draft);
    } else {
      await _controller.updateCustomer(
        user: user,
        customerId: customer.id,
        draft: draft,
      );
    }
  }

  Future<void> _showCollectionForm(
    BuildContext context, {
    required AppUser user,
    required Customer customer,
    required int balanceQirsh,
  }) async {
    if (_activeCollectionCustomerId != null) return;
    setState(() => _activeCollectionCustomerId = customer.id);
    try {
      final financialAccounts =
          await AppRepositories.financialAccountRepository.listAccounts();
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      final result = await showDialog<_CollectionFormResult>(
        context: this.context,
        builder: (_) => _CollectionFormDialog(
          customer: customer,
          balanceQirsh: balanceQirsh,
          financialAccounts: financialAccounts,
        ),
      );
      if (result == null) {
        return;
      }
      await _controller.recordCollection(
        user: user,
        customerId: customer.id,
        date: result.date,
        amountQirsh: result.amountQirsh,
        notes: result.notes,
        financialAccountId: result.financialAccountId,
        paymentMethod: result.paymentMethod,
        operationRequestId: result.operationRequestId,
        overpaymentApprovalId: result.overpaymentApprovalId,
      );
    } finally {
      if (mounted) setState(() => _activeCollectionCustomerId = null);
    }
  }

  Future<void> _showStatement(BuildContext context, Customer customer) async {
    final navigator = Navigator.of(context);
    final statement = await _controller.statementForCustomer(customer.id);
    if (!mounted) return;
    await navigator.push(
      MaterialPageRoute(
        builder: (context) => _CustomerStatementScreen(
          customer: customer,
          statement: statement,
        ),
      ),
    );
  }

  Future<void> _showAdvances(
    BuildContext context, {
    required AppUser user,
    required Customer customer,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CustomerAdvanceActionsScreen(
          customer: customer,
          user: user,
          controller: _controller,
        ),
      ),
    );
    if (!mounted) return;
    await _controller.loadCustomers(user);
  }

  Future<void> _showStatementPreview(
      BuildContext context, Customer customer) async {
    final navigator = Navigator.of(context);
    final statement = await _controller.statementForCustomer(customer.id);
    if (!mounted) return;
    await navigator.push(
      MaterialPageRoute(
        builder: (context) => PrintableCustomerStatementView(
          statement: statement,
          customerName: customer.name,
        ),
      ),
    );
  }

  Future<void> _recordOpeningBalance(
    BuildContext context, {
    required AppUser user,
    required Customer customer,
  }) async {
    final amount = await showDialog<int>(
      context: context,
      builder: (context) => const OpeningBalanceAmountDialog(
        party: OpeningBalanceParty.customer,
      ),
    );

    if (amount == null) return;

    final success = await _controller.recordOpeningBalance(
      user: user,
      customerId: customer.id,
      amountQirsh: amount,
    );
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل الرصيد الافتتاحي بنجاح.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _controller.errorMessage ?? 'خطأ في تسجيل الرصيد الافتتاحي.',
          ),
        ),
      );
    }
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.balanceQirsh,
    required this.hasOpeningBalance,
    required this.canManage,
    required this.onEdit,
    required this.onToggleActive,
    required this.onStatement,
    required this.onAdvances,
    required this.onCollection,
    required this.collectionBusy,
    this.onOpeningBalance,
    this.onPreviewStatement,
  });

  final Customer customer;
  final int balanceQirsh;
  final bool hasOpeningBalance;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onStatement;
  final VoidCallback onAdvances;
  final VoidCallback onCollection;
  final bool collectionBusy;
  final VoidCallback? onOpeningBalance;
  final VoidCallback? onPreviewStatement;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasBalance = balanceQirsh > 0;
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(customer.name, style: textTheme.titleLarge)),
              Chip(label: Text(customer.isActive ? 'نشط' : 'متوقف')),
            ],
          ),
          const SizedBox(height: 8),
          if (customer.phone != null) Text('الهاتف: ${customer.phone}'),
          const SizedBox(height: 8),
          Text(
            hasBalance
                ? 'الرصيد المستحق: ${MoneyUtils.formatPiastersAsEgp(balanceQirsh)}'
                : 'لا يوجد رصيد مستحق على العميل.',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: hasBalance ? AppColors.olive : AppColors.mutedText,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
              'الرصيد ناتج من حركات البيع الآجل والتحصيل، ولا يتم تعديله يدويا.'),
          if (customer.notes != null) ...[
            const SizedBox(height: 8),
            Text(customer.notes!),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onStatement,
                icon: const Icon(Icons.receipt_long_rounded),
                label: const Text('كشف الحساب'),
              ),
              OutlinedButton.icon(
                key: const Key('customer-advances-entry'),
                onPressed: onAdvances,
                icon: const Icon(Icons.account_balance_wallet_rounded),
                label: const Text('سلف العميل'),
              ),
              if (onPreviewStatement != null)
                OutlinedButton.icon(
                  onPressed: onPreviewStatement,
                  icon: const Icon(Icons.preview_rounded),
                  label: const Text('معاينة كشف الحساب'),
                ),
              if (!hasOpeningBalance)
                OutlinedButton.icon(
                  onPressed: onOpeningBalance,
                  icon: const Icon(Icons.account_balance_rounded),
                  label: const Text('رصيد افتتاحي'),
                ),
              if (canManage && hasBalance)
                FilledButton.icon(
                  onPressed: collectionBusy ? null : onCollection,
                  icon: collectionBusy
                      ? const SizedBox.square(
                          dimension: AppIconSizes.sm,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.payments_rounded),
                  label: Text(
                      collectionBusy ? 'جاري تسجيل التحصيل...' : 'تسجيل تحصيل'),
                ),
              if (canManage) ...[
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('تعديل'),
                ),
                OutlinedButton.icon(
                  onPressed: onToggleActive,
                  icon: Icon(customer.isActive
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded),
                  label: Text(customer.isActive ? 'إيقاف' : 'تفعيل'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CollectionFormDialog extends StatefulWidget {
  const _CollectionFormDialog({
    required this.customer,
    required this.balanceQirsh,
    required this.financialAccounts,
  });

  final Customer customer;
  final int balanceQirsh;
  final List<FinancialAccount> financialAccounts;

  @override
  State<_CollectionFormDialog> createState() => _CollectionFormDialogState();
}

class _CollectionFormDialogState extends State<_CollectionFormDialog> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _date = DateTime.now();
  String? _errorMessage;
  bool _isLoading = false;

  String? _selectedAccountId;
  PaymentMethod? _selectedPaymentMethod;

  int? _tryParseAmount() {
    try {
      return MoneyUtils.parseEgpToPiasters(
        _amountController.text,
        allowZero: false,
      );
    } on Object {
      return null;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final amount = _tryParseAmount();
    final isOverpayment = amount != null && amount > widget.balanceQirsh;
    final settled = isOverpayment ? widget.balanceQirsh : (amount ?? 0);
    final advance = isOverpayment ? amount - widget.balanceQirsh : 0;

    return GhalalResponsiveDialog(
      isDirty: _isDirty,
      isBusy: _isLoading,
      title: Text('تسجيل تحصيل - ${widget.customer.name}'),
      content: SingleChildScrollView(
        child: StatefulBuilder(
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'الرصيد المستحق: ${MoneyUtils.formatPiastersAsEgp(widget.balanceQirsh)}'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: Text('تاريخ التحصيل: ${_formatDate(_date)}'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'مبلغ التحصيل بالجنيه',
                    helperText:
                        'يمكن تسجيل تحصيل أكبر من الرصيد — سيُنشأ سلفة للعميل.',
                  ),
                  textDirection: TextDirection.ltr,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PaymentMethod>(
                  value: _selectedPaymentMethod,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'طريقة الدفع *',
                  ),
                  items: PaymentRoutingPolicy.selectablePaymentMethods
                      .map((method) => DropdownMenuItem(
                            value: method,
                            child: Text(method.labelAr),
                          ))
                      .toList(),
                  onChanged: (method) {
                    setState(() {
                      _selectedPaymentMethod = method;
                      if (!_selectedAccountIsCompatible()) {
                        _selectedAccountId = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedAccountId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'الحساب المالي *',
                  ),
                  items: _compatibleAccounts()
                      .map((account) => DropdownMenuItem(
                            value: account.id,
                            child: Text(
                              '${account.type.iconEmoji} ${account.name} (${account.type.labelAr})',
                            ),
                          ))
                      .toList(),
                  onChanged: _selectedPaymentMethod == null
                      ? null
                      : (accountId) => setState(
                            () => _selectedAccountId = accountId,
                          ),
                ),
                if (isOverpayment) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تفاصيل السلفة',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        _summaryRow('المسوى من المستحق',
                            MoneyUtils.formatPiastersAsEgp(settled)),
                        _summaryRow('السلفة الجديدة',
                            MoneyUtils.formatPiastersAsEgp(advance)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: colorScheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'يجب موافقة المالك لتسجيل السلفة.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.primary,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  decoration:
                      const InputDecoration(labelText: 'ملاحظات اختيارية'),
                  maxLines: 2,
                  textDirection: TextDirection.rtl,
                  onChanged: (_) => setState(() {}),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: colorScheme.error),
                  ),
                ],
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading
              ? null
              : () => GhalalResponsiveDialog.requestClose(
                    context,
                    isDirty: _isDirty,
                  ),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('حفظ التحصيل'),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xxs,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  bool get _isDirty =>
      _amountController.text.trim().isNotEmpty ||
      _notesController.text.trim().isNotEmpty ||
      _selectedAccountId != null ||
      _selectedPaymentMethod != null ||
      !_isSameDay(_date, DateTime.now());

  bool _isSameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('ar'),
    );
    if (selected != null) {
      setState(() => _date = selected);
    }
  }

  Future<void> _submit() async {
    int amount;
    try {
      amount = MoneyUtils.parseEgpToPiasters(
        _amountController.text,
        allowZero: false,
      );
    } on Object {
      setState(() => _errorMessage = 'اكتب مبلغ التحصيل بشكل صحيح.');
      return;
    }

    if (_selectedPaymentMethod == null) {
      setState(() => _errorMessage = 'اختر طريقة الدفع.');
      return;
    }
    if (_selectedAccountId == null) {
      setState(() => _errorMessage = 'اختر الحساب المالي للتحصيل.');
      return;
    }

    final isOverpayment = amount > widget.balanceQirsh;

    if (isOverpayment) {
      if (_selectedAccountId == null) {
        setState(
            () => _errorMessage = 'اختر الحساب المالي الذي ستُودع فيه السلفة.');
        return;
      }
      final approved = await _requestApproval(amount);
      if (approved == null || !mounted) return;
      Navigator.of(context).pop(_CollectionFormResult(
        date: _date,
        amountQirsh: amount,
        notes: _notesController.text,
        financialAccountId: _selectedAccountId,
        paymentMethod: _selectedPaymentMethod,
        operationRequestId: approved.requestId,
        overpaymentApprovalId: approved.approvalId,
      ));
    } else {
      Navigator.of(context).pop(_CollectionFormResult(
        date: _date,
        amountQirsh: amount,
        notes: _notesController.text,
        financialAccountId: _selectedAccountId,
        paymentMethod: _selectedPaymentMethod,
      ));
    }
  }

  List<FinancialAccount> _compatibleAccounts() {
    final method = _selectedPaymentMethod;
    if (method == null) return const [];
    return widget.financialAccounts
        .where((account) =>
            account.isActive &&
            PaymentRoutingPolicy.isCompatible(
              paymentMethod: method,
              accountType: account.type,
            ))
        .toList(growable: false);
  }

  bool _selectedAccountIsCompatible() {
    final accountId = _selectedAccountId;
    if (accountId == null) return true;
    return _compatibleAccounts().any((account) => account.id == accountId);
  }

  Future<_ApprovalResult?> _requestApproval(int amount) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final account = widget.financialAccounts
          .firstWhere((a) => a.id == _selectedAccountId);
      final accountBalance = await AppRepositories.financialAccountRepository
          .currentBalanceForAccount(account.id);
      if (!mounted) return null;
      final requestId = DateTime.now().millisecondsSinceEpoch.toString();

      final approvalId = await NegativeBalanceApprovalDialog.show(
        context: context,
        authRepository: AppRepositories.authRepository,
        accountName: account.name,
        currentBalanceQirsh: accountBalance,
        requestedAmountQirsh: amount,
        operationDescription: 'تسجيل سلفة للعميل ${widget.customer.name}',
        approvalService: AppRepositories.negativeBalanceApprovalService,
        approvalDraft: NegativeBalanceApprovalDraft(
          requestedByUserId: '',
          approvedByOwnerUserId: '',
          accountId: account.id,
          amountQirsh: amount - widget.balanceQirsh,
          operationType: NegativeBalanceOperationType.customerOverpayment,
          sourceDocumentId: requestId,
          sourceDocumentType: 'customerOverpayment',
          balanceBeforeQirsh: accountBalance,
          expectedBalanceAfterQirsh: accountBalance + amount,
          reason: 'تحصيل يتجاوز الرصيد المستحق',
        ),
      );

      if (approvalId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'تم إلغاء الموافقة.';
        });
        return null;
      }

      setState(() => _isLoading = false);
      return _ApprovalResult(requestId: requestId, approvalId: approvalId);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'حدث خطأ أثناء طلب الموافقة.';
      });
      return null;
    }
  }

  String _formatDate(DateTime value) {
    return '${value.year}-${_twoDigits(value.month)}-${_twoDigits(value.day)}';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

class _ApprovalResult {
  const _ApprovalResult({required this.requestId, required this.approvalId});
  final String requestId;
  final String approvalId;
}

class _CollectionFormResult {
  const _CollectionFormResult({
    required this.date,
    required this.amountQirsh,
    this.notes,
    this.financialAccountId,
    this.paymentMethod,
    this.operationRequestId,
    this.overpaymentApprovalId,
  });

  final DateTime date;
  final int amountQirsh;
  final String? notes;
  final String? financialAccountId;
  final PaymentMethod? paymentMethod;
  final String? operationRequestId;
  final String? overpaymentApprovalId;
}

class _CustomerStatementScreen extends StatelessWidget {
  const _CustomerStatementScreen({
    required this.customer,
    required this.statement,
  });

  final Customer customer;
  final CustomerStatement statement;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          GhalalPageHeader(
            title: 'كشف الحساب - ${customer.name}',
            subtitle: 'عرض حركات الحساب والرصيد النهائي للعميل.',
            icon: Icons.receipt_long_rounded,
            onBack: () => Navigator.of(context).maybePop(),
            actions: [
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PrintableCustomerStatementView(
                        statement: statement,
                        customerName: customer.name,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.preview_rounded),
                label: const Text('معاينة كشف الحساب'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.name,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'الرصيد النهائي: ${MoneyUtils.formatPiastersAsEgp(statement.finalBalanceQirsh)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                const Text(
                    'البيع الآجل يزيد رصيد العميل المستحق، والتحصيل يقلله.'),
                const SizedBox(height: 6),
                const Text('كشف الحساب يعرض كل الحركات التي صنعت الرصيد.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (statement.lines.isEmpty)
            const GhalalEmptyState(
              title: 'لا توجد حركات',
              message: 'لم تُسجَّل أي حركة على هذا العميل بعد.',
              icon: Icons.receipt_long_outlined,
            )
          else
            for (final line in statement.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _StatementLineCard(line: line),
              ),
        ],
      ),
    );
  }
}

class _StatementLineCard extends StatelessWidget {
  const _StatementLineCard({required this.line});

  final CustomerStatementLine line;

  @override
  Widget build(BuildContext context) {
    final entry = line.entry;
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.descriptionAr,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Chip(label: Text(entry.type.labelAr)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Text('التاريخ: ${_formatDate(entry.date)}'),
              Text('رقم المرجع: ${entry.sourceDocumentId}'),
              if (entry.type == CustomerAccountEntryType.openingBalance) ...[
                Text(
                    'الرصيد الافتتاحي: ${MoneyUtils.formatPiastersAsEgp(entry.debitAmountQirsh)}'),
              ] else ...[
                Text(
                    'مدين: ${MoneyUtils.formatPiastersAsEgp(entry.debitAmountQirsh)}'),
                Text(
                    'دائن / تحصيل: ${MoneyUtils.formatPiastersAsEgp(entry.creditAmountQirsh)}'),
              ],
              Text(
                  'الرصيد: ${MoneyUtils.formatPiastersAsEgp(line.runningBalanceQirsh)}'),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)}';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

class _CustomerFormDialog extends StatefulWidget {
  const _CustomerFormDialog({this.customer});

  final Customer? customer;

  @override
  State<_CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<_CustomerFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _notesController;
  late bool _isActive;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    _nameController = TextEditingController(text: customer?.name ?? '');
    _phoneController = TextEditingController(text: customer?.phone ?? '');
    _notesController = TextEditingController(text: customer?.notes ?? '');
    _isActive = customer?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GhalalResponsiveDialog(
      isDirty: _isDirty,
      isBusy: _isLoading,
      title: Text(widget.customer == null ? 'إضافة عميل' : 'تعديل عميل'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'اسم العميل'),
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
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'ملاحظات اختيارية'),
            maxLines: 2,
            textDirection: TextDirection.rtl,
          ),
          SwitchListTile(
            value: _isActive,
            onChanged: (value) => setState(() => _isActive = value),
            title: const Text('العميل نشط'),
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
      actions: [
        TextButton(
          onPressed: _isLoading
              ? null
              : () => GhalalResponsiveDialog.requestClose(
                    context,
                    isDirty: _isDirty,
                  ),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('حفظ'),
        ),
      ],
    );
  }

  bool get _isDirty =>
      _nameController.text.trim().isNotEmpty ||
      _phoneController.text.trim().isNotEmpty ||
      _notesController.text.trim().isNotEmpty;

  void _submit() {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'أدخل اسم العميل.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    Navigator.of(context).pop(
      CustomerDraft(
        name: _nameController.text,
        phone: _phoneController.text,
        notes: _notesController.text,
        isActive: _isActive,
      ),
    );
  }
}
