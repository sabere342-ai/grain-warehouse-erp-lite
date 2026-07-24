import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_controller.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_advance.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_service.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';
import 'package:grain_warehouse_erp_lite/features/financial_accounts/negative_balance_approval_dialog.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_page_header.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_responsive_dialog.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_state_view.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

typedef CustomerAdvanceApprovalPrompt = Future<String?> Function({
  required BuildContext context,
  required FinancialAccount account,
  required int currentBalanceQirsh,
  required int requestedAmountQirsh,
  required String operationDescription,
  required NegativeBalanceApprovalDraft approvalDraft,
});

class CustomerAdvanceActionsScreen extends StatefulWidget {
  const CustomerAdvanceActionsScreen({
    super.key,
    required this.customer,
    required this.user,
    required this.controller,
    this.financialAccountRepository,
    this.authRepository,
    this.approvalService,
    this.approvalPrompt,
  });

  final Customer customer;
  final AppUser user;
  final CustomerController controller;
  final FinancialAccountRepository? financialAccountRepository;
  final AuthRepository? authRepository;
  final NegativeBalanceApprovalService? approvalService;
  final CustomerAdvanceApprovalPrompt? approvalPrompt;

  @override
  State<CustomerAdvanceActionsScreen> createState() =>
      _CustomerAdvanceActionsScreenState();
}

class _CustomerAdvanceActionsScreenState
    extends State<CustomerAdvanceActionsScreen> {
  late final FinancialAccountRepository _financialAccountRepository;
  late final AuthRepository _authRepository;
  late final NegativeBalanceApprovalService _approvalService;

  List<CustomerAdvanceSummary> _advances = const [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _activeAdvanceId;

  bool get _canManage =>
      widget.user.canProceed &&
      (widget.user.permissions.canCreateCustomerPayment ||
          widget.user.permissions.canAccessSettings);

  @override
  void initState() {
    super.initState();
    _financialAccountRepository = widget.financialAccountRepository ??
        AppRepositories.financialAccountRepository;
    _authRepository = widget.authRepository ?? AppRepositories.authRepository;
    _approvalService = widget.approvalService ??
        AppRepositories.negativeBalanceApprovalService;
    _loadAdvances();
  }

  Future<void> _loadAdvances() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final advances =
          await widget.controller.advancesForCustomer(widget.customer.id);
      if (!mounted) return;
      setState(() {
        _advances = advances;
        _isLoading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'تعذر تحميل سلف العميل. حاول مرة أخرى.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const GhalalLoadingState(
        key: Key('customer-advances-loading'),
        label: 'جاري تحميل سلف العميل...',
      );
    }
    if (_errorMessage != null) {
      return GhalalErrorState(
        key: const Key('customer-advances-error'),
        message: _errorMessage!,
        onRetry: _loadAdvances,
        retryButtonKey: const Key('customer-advances-retry'),
      );
    }
    if (_advances.isEmpty) {
      return const GhalalEmptyState(
        key: Key('customer-advances-empty'),
        title: 'لا توجد سلف للعميل',
        message: 'لا توجد سلف متاحة أو سابقة لهذا العميل.',
        icon: Icons.account_balance_wallet_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAdvances,
      child: ListView(
        key: const Key('customer-advances-list'),
        padding: const EdgeInsets.all(16),
        children: [
          GhalalPageHeader(
            title: 'سلف العميل - ${widget.customer.name}',
            icon: Icons.account_balance_wallet_rounded,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(height: 16),
          for (final summary in _advances)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AdvanceCard(
                summary: summary,
                canManage: _canManage,
                isBusy: _activeAdvanceId == summary.advance.id,
                onApply: () => _openApplication(summary),
                onRefund: () => _openRefund(summary),
                onReverseRefund: (refund) => _openRefundReversal(refund),
                canReverseRefund: widget.user.role == UserRole.owner,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openRefundReversal(CustomerAdvanceRefund refund) async {
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CustomerRefundReversalDialog(
        customer: widget.customer,
        user: widget.user,
        controller: widget.controller,
        refund: refund,
      ),
    );
    if (success != true || !mounted) return;
    await _loadAdvances();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم عكس استرداد سلفة العميل بنجاح')),
    );
  }

  Future<void> _openApplication(CustomerAdvanceSummary summary) async {
    if (_activeAdvanceId != null || !summary.canAct) return;
    setState(() => _activeAdvanceId = summary.advance.id);
    bool? success;
    try {
      success = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _AdvanceApplicationDialog(
          customer: widget.customer,
          user: widget.user,
          controller: widget.controller,
          summary: summary,
        ),
      );
    } finally {
      if (mounted) setState(() => _activeAdvanceId = null);
    }
    if (success != true || !mounted) return;
    await _loadAdvances();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تطبيق السلفة بنجاح.')),
    );
  }

  Future<void> _openRefund(CustomerAdvanceSummary summary) async {
    if (_activeAdvanceId != null || !summary.canAct) return;
    setState(() => _activeAdvanceId = summary.advance.id);
    bool? success;
    try {
      final accounts = await _financialAccountRepository.listAccounts();
      if (!mounted) return;
      final originalAccounts = accounts
          .where(
            (account) =>
                account.isActive &&
                account.id == summary.advance.financialAccountId,
          )
          .toList(growable: false);
      if (originalAccounts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الحساب المالي الأصلي للسلفة غير متاح.'),
          ),
        );
        return;
      }
      success = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _AdvanceRefundDialog(
          customer: widget.customer,
          user: widget.user,
          controller: widget.controller,
          summary: summary,
          financialAccounts: originalAccounts,
          financialAccountRepository: _financialAccountRepository,
          approvalPrompt: widget.approvalPrompt ?? _showApproval,
        ),
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تحميل الحساب المالي. حاول مرة أخرى.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _activeAdvanceId = null);
    }
    if (success != true || !mounted) return;
    await _loadAdvances();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم رد السلفة بنجاح.')),
    );
  }

  Future<String?> _showApproval({
    required BuildContext context,
    required FinancialAccount account,
    required int currentBalanceQirsh,
    required int requestedAmountQirsh,
    required String operationDescription,
    required NegativeBalanceApprovalDraft approvalDraft,
  }) {
    return NegativeBalanceApprovalDialog.show(
      context: context,
      authRepository: _authRepository,
      accountName: account.name,
      currentBalanceQirsh: currentBalanceQirsh,
      requestedAmountQirsh: requestedAmountQirsh,
      operationDescription: operationDescription,
      approvalService: _approvalService,
      approvalDraft: approvalDraft,
    );
  }
}

class _AdvanceCard extends StatelessWidget {
  const _AdvanceCard({
    required this.summary,
    required this.canManage,
    required this.isBusy,
    required this.onApply,
    required this.onRefund,
    required this.onReverseRefund,
    required this.canReverseRefund,
  });

  final CustomerAdvanceSummary summary;
  final bool canManage;
  final bool isBusy;
  final VoidCallback onApply;
  final VoidCallback onRefund;
  final ValueChanged<CustomerAdvanceRefund> onReverseRefund;
  final bool canReverseRefund;

  @override
  Widget build(BuildContext context) {
    final advance = summary.advance;
    return PremiumCard(
      key: Key('advance-card-${advance.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'سلفة بتاريخ ${_formatDate(advance.createdAt)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Chip(label: Text(summary.statusLabelAr)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _AmountLabel('القيمة الأصلية', advance.amountQirsh),
              _AmountLabel('المبلغ المطبق', summary.appliedQirsh),
              _AmountLabel('المبلغ المردود', summary.refundedQirsh),
              _AmountLabel(
                'الرصيد المتاح',
                summary.remainingQirsh,
                emphasize: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'المصدر: تحصيل عميل تجاوز الرصيد المستحق',
            style: TextStyle(color: AppColors.mutedText),
          ),
          if (canManage && summary.canAct) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: Key('apply-advance-${advance.id}'),
                  onPressed: isBusy ? null : onApply,
                  icon: const Icon(Icons.account_balance_wallet_rounded),
                  label: const Text('تطبيق السلفة'),
                ),
                OutlinedButton.icon(
                  key: Key('refund-advance-${advance.id}'),
                  onPressed: isBusy ? null : onRefund,
                  icon: const Icon(Icons.currency_exchange_rounded),
                  label: const Text('رد السلفة'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Text('سجل الاستردادات',
              style: TextStyle(fontWeight: FontWeight.w800)),
          if (summary.refunds.isEmpty)
            const Text('لا توجد استردادات مسجلة.')
          else
            for (final refund in summary.refunds)
              ListTile(
                key: Key('customer-refund-${refund.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(MoneyUtils.formatPiastersAsEgp(refund.amountQirsh)),
                subtitle: Text(
                  '${_formatDate(refund.refundedAt)} • ${refund.financialAccountId}\n'
                  '${refund.isReversed ? 'معكوس — ${refund.reversalReason ?? ''}' : 'نشط'}',
                ),
                trailing: canReverseRefund && !refund.isReversed
                    ? TextButton(
                        key: Key('reverse-customer-refund-${refund.id}'),
                        onPressed: () => onReverseRefund(refund),
                        child: const Text('عكس الاسترداد'),
                      )
                    : null,
              ),
        ],
      ),
    );
  }
}

class _CustomerRefundReversalDialog extends StatefulWidget {
  const _CustomerRefundReversalDialog({
    required this.customer,
    required this.user,
    required this.controller,
    required this.refund,
  });
  final Customer customer;
  final AppUser user;
  final CustomerController controller;
  final CustomerAdvanceRefund refund;
  @override
  State<_CustomerRefundReversalDialog> createState() =>
      _CustomerRefundReversalDialogState();
}

class _CustomerRefundReversalDialogState
    extends State<_CustomerRefundReversalDialog> {
  final _reason = TextEditingController();
  late final String _requestId = _newRequestId('customer-reverse-refund');
  bool _submitting = false;
  String? _error;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GhalalResponsiveDialog(
        isDirty: _reason.text.trim().isNotEmpty,
        isBusy: _submitting,
        icon: Icon(
          Icons.undo_rounded,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text('عكس استرداد سلفة العميل - ${widget.customer.name}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
              'المبلغ الأصلي: ${MoneyUtils.formatPiastersAsEgp(widget.refund.amountQirsh)}'),
          Text('الحساب المالي الأصلي: ${widget.refund.financialAccountId}'),
          Text('تاريخ الاسترداد: ${_formatDate(widget.refund.refundedAt)}'),
          const Text(
              'سيعاد المبلغ إلى الحساب المالي المرتبط بالاسترداد، وسيعود إلى الرصيد المتاح من سلفة العميل.'),
          TextField(
            key: const Key('customer-refund-reversal-reason'),
            controller: _reason,
            enabled: !_submitting,
            decoration: const InputDecoration(labelText: 'سبب العكس *'),
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null)
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ]),
        actions: [
          TextButton(
              onPressed: _submitting
                  ? null
                  : () => GhalalResponsiveDialog.requestClose(
                        context,
                        isDirty: _reason.text.trim().isNotEmpty,
                      ),
              child: const Text('إلغاء')),
          FilledButton(
              key: const Key('customer-refund-reversal-submit'),
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: _submitting
                  ? const SizedBox.square(
                      dimension: AppIconSizes.sm,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('تأكيد العكس')),
        ],
      );
  Future<void> _submit() async {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'سبب العكس مطلوب.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await widget.controller.reverseCustomerAdvanceRefund(
      user: widget.user,
      refund: widget.refund,
      reason: reason,
      operationRequestId: _requestId,
    );
    if (!mounted) return;
    if (result.isSuccess) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _submitting = false;
      _error = result.message;
    });
  }
}

class _AmountLabel extends StatelessWidget {
  const _AmountLabel(this.label, this.amountQirsh, {this.emphasize = false});

  final String label;
  final int amountQirsh;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: ${MoneyUtils.formatPiastersAsEgp(amountQirsh)}',
      style: emphasize
          ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.olive,
                fontWeight: FontWeight.w800,
              )
          : null,
    );
  }
}

class _AdvanceApplicationDialog extends StatefulWidget {
  const _AdvanceApplicationDialog({
    required this.customer,
    required this.user,
    required this.controller,
    required this.summary,
  });

  final Customer customer;
  final AppUser user;
  final CustomerController controller;
  final CustomerAdvanceSummary summary;

  @override
  State<_AdvanceApplicationDialog> createState() =>
      _AdvanceApplicationDialogState();
}

class _AdvanceApplicationDialogState extends State<_AdvanceApplicationDialog> {
  final _amountController = TextEditingController();
  late String _requestId;
  late DateTime _operationDate;
  int? _attemptAmountQirsh;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _resetAttempt();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _resetAttempt() {
    _requestId = _newRequestId('customer-advance-apply');
    _operationDate = DateTime.now();
    _attemptAmountQirsh = null;
  }

  @override
  Widget build(BuildContext context) {
    return GhalalResponsiveDialog(
      isDirty: _amountController.text.trim().isNotEmpty,
      isBusy: _isSubmitting,
      title: Text('تطبيق السلفة - ${widget.customer.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الرصيد المتاح: ${MoneyUtils.formatPiastersAsEgp(widget.summary.remainingQirsh)}',
            ),
            const SizedBox(height: 8),
            const Text('سيخفض المبلغ ذمة العميل وفق رصيده المستحق الحالي.'),
            const SizedBox(height: 12),
            TextField(
              key: const Key('advance-application-amount'),
              controller: _amountController,
              enabled: !_isSubmitting,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'مبلغ التطبيق بالجنيه',
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                key: const Key('advance-application-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => GhalalResponsiveDialog.requestClose(
                    context,
                    isDirty: _amountController.text.trim().isNotEmpty,
                  ),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          key: const Key('advance-application-submit'),
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  key: Key('advance-application-progress'),
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('تأكيد التطبيق'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final amount = _validatedAmount(
      text: _amountController.text,
      availableQirsh: widget.summary.remainingQirsh,
    );
    if (amount.message != null) {
      setState(() => _errorMessage = amount.message);
      return;
    }
    final amountQirsh = amount.amountQirsh!;
    final receivable = widget.controller.balanceForCustomer(widget.customer.id);
    if (amountQirsh > receivable) {
      setState(() {
        _errorMessage = 'المبلغ يتجاوز ذمة العميل الحالية.';
      });
      return;
    }
    if (_attemptAmountQirsh != null && _attemptAmountQirsh != amountQirsh) {
      _resetAttempt();
    }
    _attemptAmountQirsh = amountQirsh;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    final result = await widget.controller.applyCustomerAdvance(
      user: widget.user,
      advance: widget.summary.advance,
      amountQirsh: amountQirsh,
      date: _operationDate,
      operationRequestId: _requestId,
    );
    if (!mounted) return;
    if (result.isSuccess) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _isSubmitting = false;
      _errorMessage =
          result.message ?? 'تعذر تطبيق السلفة. راجع البيانات وحاول مرة أخرى.';
    });
  }
}

class _AdvanceRefundDialog extends StatefulWidget {
  const _AdvanceRefundDialog({
    required this.customer,
    required this.user,
    required this.controller,
    required this.summary,
    required this.financialAccounts,
    required this.financialAccountRepository,
    required this.approvalPrompt,
  });

  final Customer customer;
  final AppUser user;
  final CustomerController controller;
  final CustomerAdvanceSummary summary;
  final List<FinancialAccount> financialAccounts;
  final FinancialAccountRepository financialAccountRepository;
  final CustomerAdvanceApprovalPrompt approvalPrompt;

  @override
  State<_AdvanceRefundDialog> createState() => _AdvanceRefundDialogState();
}

class _AdvanceRefundDialogState extends State<_AdvanceRefundDialog> {
  final _amountController = TextEditingController();
  late String _requestId;
  late DateTime _operationDate;
  int? _attemptAmountQirsh;
  String? _attemptAccountId;
  PaymentMethod? _attemptPaymentMethod;
  String? _selectedAccountId;
  PaymentMethod? _selectedPaymentMethod;
  int? _currentBalanceQirsh;
  bool _isLoadingBalance = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedPaymentMethod = widget.summary.advance.paymentMethod;
    _resetAttempt();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _resetAttempt() {
    _requestId = _newRequestId('customer-advance-refund');
    _operationDate = DateTime.now();
    _attemptAmountQirsh = null;
    _attemptAccountId = null;
    _attemptPaymentMethod = null;
  }

  FinancialAccount? get _selectedAccount {
    final id = _selectedAccountId;
    if (id == null) return null;
    for (final account in widget.financialAccounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _tryParseAmount(_amountController.text);
    final account = _selectedAccount;
    return GhalalResponsiveDialog(
      isDirty: _isDirty,
      isBusy: _isSubmitting || _isLoadingBalance,
      title: Text('رد السلفة - ${widget.customer.name}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الرصيد المتاح: ${MoneyUtils.formatPiastersAsEgp(widget.summary.remainingQirsh)}',
              ),
              const SizedBox(height: 8),
              const Text('سيخرج مبلغ الرد من الحساب المالي المحدد إلى العميل.'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('advance-refund-account'),
                value: _selectedAccountId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'الحساب المالي *',
                ),
                items: widget.financialAccounts
                    .map(
                      (value) => DropdownMenuItem(
                        value: value.id,
                        child: Text('${value.type.iconEmoji} ${value.name}'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _isSubmitting ? null : _selectAccount,
              ),
              if (_isLoadingBalance) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(
                  key: Key('advance-refund-balance-loading'),
                ),
              ] else if (_currentBalanceQirsh != null) ...[
                const SizedBox(height: 8),
                Text(
                  'رصيد الحساب الحالي: ${MoneyUtils.formatPiastersAsEgp(_currentBalanceQirsh!)}',
                  key: const Key('advance-refund-account-balance'),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                key: const Key('advance-refund-amount'),
                controller: _amountController,
                enabled: !_isSubmitting,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'مبلغ الرد بالجنيه',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PaymentMethod>(
                key: const Key('advance-refund-payment-method'),
                value: _selectedPaymentMethod,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'طريقة الدفع (اختياري)',
                ),
                items: PaymentMethod.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.labelAr),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _isSubmitting
                    ? null
                    : (value) => setState(() => _selectedPaymentMethod = value),
              ),
              if (account != null && parsed != null && parsed > 0) ...[
                const SizedBox(height: 12),
                Text(
                  'تأكيد: رد ${MoneyUtils.formatPiastersAsEgp(parsed)} للعميل ${widget.customer.name} من حساب ${account.name}.',
                  key: const Key('advance-refund-confirmation'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  key: const Key('advance-refund-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => GhalalResponsiveDialog.requestClose(
                    context,
                    isDirty: _isDirty,
                  ),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          key: const Key('advance-refund-submit'),
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  key: Key('advance-refund-progress'),
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('تأكيد الرد'),
        ),
      ],
    );
  }

  bool get _isDirty =>
      _amountController.text.trim().isNotEmpty || _selectedAccountId != null;

  Future<void> _selectAccount(String? accountId) async {
    setState(() {
      _selectedAccountId = accountId;
      _currentBalanceQirsh = null;
      _errorMessage = null;
      _isLoadingBalance = accountId != null;
    });
    if (accountId == null) return;
    try {
      final balance = await widget.financialAccountRepository
          .currentBalanceForAccount(accountId);
      if (!mounted || _selectedAccountId != accountId) return;
      setState(() {
        _currentBalanceQirsh = balance;
        _isLoadingBalance = false;
      });
    } on Object {
      if (!mounted || _selectedAccountId != accountId) return;
      setState(() {
        _isLoadingBalance = false;
        _errorMessage = 'تعذر تحميل رصيد الحساب. حاول مرة أخرى.';
      });
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final account = _selectedAccount;
    if (account == null) {
      setState(() => _errorMessage = 'اختر الحساب المالي أولًا.');
      return;
    }
    final amount = _validatedAmount(
      text: _amountController.text,
      availableQirsh: widget.summary.remainingQirsh,
    );
    if (amount.message != null) {
      setState(() => _errorMessage = amount.message);
      return;
    }
    final amountQirsh = amount.amountQirsh!;
    if (_attemptAmountQirsh != null &&
        (_attemptAmountQirsh != amountQirsh ||
            _attemptAccountId != account.id ||
            _attemptPaymentMethod != _selectedPaymentMethod)) {
      _resetAttempt();
    }
    _attemptAmountQirsh = amountQirsh;
    _attemptAccountId = account.id;
    _attemptPaymentMethod = _selectedPaymentMethod;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    var result = await widget.controller.refundCustomerAdvance(
      user: widget.user,
      advance: widget.summary.advance,
      amountQirsh: amountQirsh,
      date: _operationDate,
      operationRequestId: _requestId,
      financialAccountId: account.id,
      paymentMethod: _selectedPaymentMethod,
    );
    if (!mounted) return;

    if (result.requiresApproval) {
      final balance = await _loadFreshBalance(account);
      if (!mounted) return;
      if (balance == null) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'تعذر تحميل رصيد الحساب. حاول مرة أخرى.';
        });
        return;
      }
      String? approvalId;
      try {
        approvalId = await widget.approvalPrompt(
          context: context,
          account: account,
          currentBalanceQirsh: balance,
          requestedAmountQirsh: amountQirsh,
          operationDescription:
              'رصيد الحساب غير كافٍ، ويلزم اعتماد المالك لإتمام رد سلفة العميل ${widget.customer.name}.',
          approvalDraft: NegativeBalanceApprovalDraft(
            requestedByUserId: widget.user.id,
            approvedByOwnerUserId: '',
            accountId: account.id,
            amountQirsh: amountQirsh,
            operationType: NegativeBalanceOperationType.customerAdvanceRefund,
            sourceDocumentId: _requestId,
            sourceDocumentType: 'customerAdvanceRefund',
            balanceBeforeQirsh: balance,
            expectedBalanceAfterQirsh: balance - amountQirsh,
            reason: 'رد جزء من سلفة العميل ${widget.customer.name}',
            authorizationContext:
                NegativeBalanceApprovalContext.customerAdvanceRefund(
              customerId: widget.customer.id,
              advanceId: widget.summary.advance.id,
            ),
          ),
        );
      } on Object {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'تعذر طلب اعتماد المالك. حاول مرة أخرى.';
        });
        return;
      }
      if (!mounted) return;
      if (approvalId == null) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'تم إلغاء الاعتماد. لم يتم رد السلفة.';
        });
        return;
      }
      result = await widget.controller.refundCustomerAdvance(
        user: widget.user,
        advance: widget.summary.advance,
        amountQirsh: amountQirsh,
        date: _operationDate,
        operationRequestId: _requestId,
        financialAccountId: account.id,
        paymentMethod: _selectedPaymentMethod,
        negativeBalanceApprovalId: approvalId,
      );
      if (!mounted) return;
    }

    if (result.isSuccess) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _isSubmitting = false;
      _errorMessage =
          result.message ?? 'تعذر رد السلفة. راجع البيانات وحاول مرة أخرى.';
    });
  }

  Future<int?> _loadFreshBalance(FinancialAccount account) async {
    try {
      final balance = await widget.financialAccountRepository
          .currentBalanceForAccount(account.id);
      if (mounted) setState(() => _currentBalanceQirsh = balance);
      return balance;
    } on Object {
      return null;
    }
  }
}

class _ValidatedAmount {
  const _ValidatedAmount({this.amountQirsh, this.message});

  final int? amountQirsh;
  final String? message;
}

_ValidatedAmount _validatedAmount({
  required String text,
  required int availableQirsh,
}) {
  if (text.trim().isEmpty) {
    return const _ValidatedAmount(message: 'أدخل المبلغ أولًا.');
  }
  final amount = _tryParseAmount(text);
  if (amount == null || amount <= 0) {
    return const _ValidatedAmount(
      message: 'المبلغ غير صالح ويجب أن يكون أكبر من صفر.',
    );
  }
  if (amount > availableQirsh) {
    return const _ValidatedAmount(
      message: 'المبلغ يتجاوز الرصيد المتاح من السلفة.',
    );
  }
  return _ValidatedAmount(amountQirsh: amount);
}

int? _tryParseAmount(String text) {
  try {
    return MoneyUtils.parseEgpToPiasters(text, allowZero: true);
  } on Object {
    return null;
  }
}

int _requestSequence = 0;

String _newRequestId(String prefix) {
  _requestSequence += 1;
  return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_requestSequence';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
