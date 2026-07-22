import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_controller.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/payment_routing_policy.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_workflow_service.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_page_header.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_responsive_dialog.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_state_view.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen(
      {super.key, this.controller, this.approvalWorkflowService});

  final ExpenseController? controller;
  final NegativeBalanceApprovalWorkflowService? approvalWorkflowService;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  late final ExpenseController _controller;
  late final bool _ownsController;
  late final NegativeBalanceApprovalWorkflowService _approvalWorkflow;
  bool _isSubmittingExpense = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        ExpenseController(repository: AppRepositories.expenseRepository);
    _approvalWorkflow = widget.approvalWorkflowService ??
        AppRepositories.negativeBalanceApprovalWorkflowService;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = AuthScope.of(context).state.user;
      if (user != null) {
        _controller.loadExpenses(user);
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
      return const GhalalEmptyState(
        title: 'يلزم تسجيل الدخول',
        message: 'سجل الدخول لعرض المصروفات.',
        icon: Icons.lock_outline_rounded,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ListView(
          children: [
            GhalalPageHeader(
              title: 'المصروفات',
              subtitle:
                  'تسجيل المصروفات النقدية فقط، ولا تؤثر على كميات المخزون.',
              icon: Icons.receipt_long_rounded,
              actions: [
                FilledButton.icon(
                  onPressed:
                      user.permissions.canCreateExpense && !_isSubmittingExpense
                          ? () => _showExpenseForm(context, user: user)
                          : null,
                  icon: _isSubmittingExpense
                      ? const SizedBox.square(
                          dimension: AppIconSizes.sm,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_card_rounded),
                  label: const Text('إضافة مصروف'),
                ),
              ],
            ),
            if (_controller.errorMessage != null &&
                _controller.expenses.isNotEmpty) ...[
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
              const GhalalLoadingState(label: 'جاري تحميل المصروفات...')
            else if (_controller.errorMessage != null &&
                _controller.expenses.isEmpty)
              GhalalErrorState(
                message: _controller.errorMessage!,
                onRetry: () => _controller.loadExpenses(user),
              )
            else if (_controller.expenses.isEmpty)
              const GhalalEmptyState(
                title: 'لا توجد مصروفات',
                message: 'ستظهر هنا المصروفات بعد تنفيذها.',
                icon: Icons.receipt_long_outlined,
              )
            else
              ..._controller.expenses.map(
                (expense) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ExpenseCard(expense: expense),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showExpenseForm(
    BuildContext context, {
    required AppUser user,
  }) async {
    if (_isSubmittingExpense) return;
    final financialAccountRepository =
        AppRepositories.financialAccountRepository;
    final financialAccounts = await financialAccountRepository.listAccounts();
    final accountBalancesQirsh = <String, int>{};
    for (final account in financialAccounts) {
      accountBalancesQirsh[account.id] =
          await financialAccountRepository.currentBalanceForAccount(account.id);
    }
    if (!context.mounted) return;
    final draft = await showDialog<ExpenseDraft>(
      context: context,
      builder: (context) => _ExpenseFormDialog(
        financialAccounts: financialAccounts,
        accountBalancesQirsh: accountBalancesQirsh,
        userId: user.id,
        operationRequestId:
            'expense-ui-${DateTime.now().microsecondsSinceEpoch}-${user.id}',
      ),
    );
    if (draft == null) {
      return;
    }
    setState(() => _isSubmittingExpense = true);
    try {
      final result = await _approvalWorkflow.submitExpense(
        requester: user,
        draft: draft,
      );
      if (!context.mounted) return;
      if (result.isPending) {
        final request = result.request!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إنشاء طلب الموافقة ${request.id}. لم يُسجل المصروف بعد. '
              'الرصيد ${MoneyUtils.formatPiastersAsEgp(request.balanceAtRequestQirsh)}، '
              'والعجز ${MoneyUtils.formatPiastersAsEgp(request.deficitAtRequestQirsh)}.',
            ),
          ),
        );
      } else {
        await _controller.loadExpenses(user);
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تسجيل المصروف: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingExpense = false);
    }
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.expense});

  final ExpenseRecord expense;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(expense.category, style: textTheme.titleLarge)),
              Text(
                MoneyUtils.formatPiastersAsEgp(expense.amountQirsh),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('التاريخ: ${_formatDate(expense.date)}'),
          if (expense.paymentMethod != null) ...[
            const SizedBox(height: 4),
            Text('طريقة الدفع: ${expense.paymentMethod!.labelAr}'),
          ],
          if (expense.notes != null) ...[
            const SizedBox(height: 8),
            Text(expense.notes!),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}

class _ExpenseFormDialog extends StatefulWidget {
  const _ExpenseFormDialog({
    required this.financialAccounts,
    required this.accountBalancesQirsh,
    required this.userId,
    required this.operationRequestId,
  });

  final List<FinancialAccount> financialAccounts;
  final Map<String, int> accountBalancesQirsh;
  final String userId;
  final String operationRequestId;

  @override
  State<_ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<_ExpenseFormDialog> {
  final _categoryController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _date = DateTime.now();
  String? _errorMessage;
  PaymentMethod? _selectedPaymentMethod;
  String? _selectedAccountId;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _categoryController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GhalalResponsiveDialog(
      isDirty: _isDirty,
      isBusy: _isSubmitting,
      title: const Text('إضافة مصروف'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: Text('التاريخ: ${_formatDate(_date)}')),
                TextButton.icon(
                  onPressed: _chooseDate,
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: const Text('اختيار'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _categoryController,
              decoration:
                  const InputDecoration(labelText: 'اسم أو تصنيف المصروف'),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'المبلغ بالجنيه'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PaymentMethod>(
              value: _selectedPaymentMethod,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'طريقة الدفع *'),
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
              decoration: const InputDecoration(labelText: 'الحساب المالي *'),
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
                  : (accountId) =>
                      setState(() => _selectedAccountId = accountId),
            ),
            if (_selectedAccount != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildAccountSummary(context, _selectedAccount!),
            ],
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
          onPressed: _isSubmitting
              ? null
              : () => GhalalResponsiveDialog.requestClose(
                    context,
                    isDirty: _isDirty,
                  ),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox.square(
                  dimension: AppIconSizes.sm,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('حفظ المصروف'),
        ),
      ],
    );
  }

  Future<void> _chooseDate() async {
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

  void _submit() {
    if (_isSubmitting) return;
    if (_categoryController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'أدخل اسم المصروف.');
      return;
    }
    try {
      final amountQirsh = MoneyUtils.parseEgpToPiasters(
        _amountController.text,
        allowZero: false,
        allowNegative: false,
      );
      if (_selectedPaymentMethod == null) {
        setState(() => _errorMessage = 'اختر طريقة الدفع.');
        return;
      }
      if (_selectedAccountId == null) {
        setState(() => _errorMessage = 'اختر الحساب المالي للمصروف.');
        return;
      }
      setState(() => _isSubmitting = true);
      Navigator.of(context).pop(
        ExpenseDraft(
          date: _date,
          category: _categoryController.text,
          amountQirsh: amountQirsh,
          createdByUserId: widget.userId,
          notes: _notesController.text,
          financialAccountId: _selectedAccountId,
          paymentMethod: _selectedPaymentMethod,
          operationRequestId: widget.operationRequestId,
        ),
      );
    } on FormatException {
      setState(() => _errorMessage = 'أدخل مبلغا صحيحا أكبر من صفر.');
    }
  }

  bool get _isDirty =>
      _categoryController.text.trim().isNotEmpty ||
      _amountController.text.trim().isNotEmpty ||
      _notesController.text.trim().isNotEmpty ||
      _selectedPaymentMethod != null ||
      _selectedAccountId != null ||
      !_isSameDay(_date, DateTime.now());

  FinancialAccount? get _selectedAccount {
    final accountId = _selectedAccountId;
    if (accountId == null) return null;
    for (final account in widget.financialAccounts) {
      if (account.id == accountId) return account;
    }
    return null;
  }

  Widget _buildAccountSummary(
    BuildContext context,
    FinancialAccount account,
  ) {
    final balance = widget.accountBalancesQirsh[account.id] ?? 0;
    int? amount;
    try {
      amount = MoneyUtils.parseEgpToPiasters(
        _amountController.text,
        allowZero: false,
        allowNegative: false,
      );
    } on Object {
      amount = null;
    }
    final projected = amount == null ? null : balance - amount;
    final hasDeficit = projected != null && projected < 0;
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('expense-account-impact-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: hasDeficit
            ? colors.errorContainer.withOpacity(0.55)
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الرصيد الحالي: ${MoneyUtils.formatPiastersAsEgp(balance)}'),
          if (amount != null)
            Text('قيمة المصروف: ${MoneyUtils.formatPiastersAsEgp(amount)}'),
          if (projected != null)
            Text(
              'الرصيد المتوقع: ${MoneyUtils.formatPiastersAsEgp(projected)}',
              style: TextStyle(
                color: hasDeficit ? colors.error : null,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (hasDeficit)
            Text(
              account.allowNegativeBalance
                  ? 'سيُنشأ طلب موافقة دائم، ولن يُنفذ المصروف قبل الاعتماد.'
                  : 'الرصيد غير كافٍ وهذا الحساب لا يسمح بطلب تجاوز الرصيد.',
              style: TextStyle(
                color: colors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

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

  String _formatDate(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}
