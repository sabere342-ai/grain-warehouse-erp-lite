import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/application/commands/application_command.dart';
import 'package:grain_warehouse_erp_lite/application/commands/post_expense_command.dart';
import 'package:grain_warehouse_erp_lite/composition/application_scope.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_controller.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/payment_routing_policy.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_page_header.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_responsive_dialog.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_state_view.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';
import 'package:uuid/uuid.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key, this.controller});

  final ExpenseController? controller;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  ExpenseController? _controller;
  bool _ownsController = false;
  bool _isSubmittingExpense = false;
  String? _postingLifecycle;
  String? _postingStatusMessage;
  ApplicationCommandRequest<PostExpenseCommand>? _retryRequest;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _ownsController = widget.controller == null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= ExpenseController(
      repository: ApplicationScope.of(context)
          .dependencies
          .repositories
          .expenseRepository,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = AuthScope.of(context).state.user;
      if (user != null) {
        _controller!.loadExpenses(user);
      }
    });
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller?.dispose();
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
      animation: _controller!,
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
            if (_postingStatusMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _postingStatusMessage!,
                key: Key('expense-posting-${_postingLifecycle ?? 'draft'}'),
                style: textTheme.bodyMedium?.copyWith(
                  color: _postingLifecycle == 'confirmed'
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (_controller!.errorMessage != null &&
                _controller!.expenses.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _controller!.errorMessage!,
                style: textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_controller!.isLoading)
              const GhalalLoadingState(label: 'جاري تحميل المصروفات...')
            else if (_controller!.errorMessage != null &&
                _controller!.expenses.isEmpty)
              GhalalErrorState(
                message: _controller!.errorMessage!,
                onRetry: () => _controller!.loadExpenses(user),
              )
            else if (_controller!.expenses.isEmpty)
              const GhalalEmptyState(
                title: 'لا توجد مصروفات',
                message: 'ستظهر هنا المصروفات بعد تنفيذها.',
                icon: Icons.receipt_long_outlined,
              )
            else
              ..._controller!.expenses.map(
                (expense) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ExpenseCard(
                    expense: expense,
                    onReclassify: user.role == UserRole.owner
                        ? () => _reclassifyExpense(user, expense)
                        : null,
                  ),
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
    final application = ApplicationScope.of(context);
    final businessContext =
        application.dependencies.runtime.businessContextProvider.current;
    final sessionContext =
        application.dependencies.runtime.sessionContextProvider.current;
    if (businessContext == null ||
        !businessContext.isVerifiedMembership ||
        sessionContext == null ||
        !sessionContext.isVerifiedRemote) {
      _showMessage(
        lifecycle: 'rejected',
        message: 'يلزم تسجيل دخول سحابي وعضوية منشأة موثقة لتسجيل المصروف.',
      );
      return;
    }
    final repositories = application.dependencies.repositories;
    final financialAccountRepository = repositories.financialAccountRepository;
    final allAccounts = await financialAccountRepository.listAccounts();
    final financialAccounts = <FinancialAccount>[];
    for (final account in allAccounts) {
      final link = await repositories.financialAccountCloudLinkResolver
          .readyLinkForLocalAccount(
        localAccountId: account.id,
        businessId: businessContext.businessId,
      );
      if (link != null) financialAccounts.add(account);
    }
    if (financialAccounts.isEmpty) {
      _showMessage(
        lifecycle: 'rejected',
        message: 'لا يوجد حساب مالي سحابي تمت تسويته وأصبح جاهزاً.',
      );
      return;
    }
    final accountBalancesQirsh = <String, int>{};
    for (final account in financialAccounts) {
      accountBalancesQirsh[account.id] =
          await financialAccountRepository.currentBalanceForAccount(account.id);
    }
    if (!context.mounted) return;
    final draft = await showDialog<_ExpensePostingIntent>(
      context: context,
      builder: (context) => _ExpenseFormDialog(
        financialAccounts: financialAccounts,
        accountBalancesQirsh: accountBalancesQirsh,
      ),
    );
    if (draft == null) {
      return;
    }
    final link = await repositories.financialAccountCloudLinkResolver
        .readyLinkForLocalAccount(
      localAccountId: draft.localFinancialAccountId,
      businessId: businessContext.businessId,
    );
    if (link == null) {
      _showMessage(
        lifecycle: 'rejected',
        message:
            'فقد الحساب المالي جاهزيته السحابية. حدّث الحساب وحاول مجدداً.',
      );
      return;
    }
    final command = PostExpenseCommand(
      commandId: const Uuid().v7(),
      businessId: businessContext.businessId,
      businessDate: _formatDateOnly(draft.date),
      category: draft.category,
      amountQirsh: draft.amountQirsh,
      notes: draft.notes,
      financialAccountId: link.serverAccountUuid,
      paymentMethod: draft.paymentMethod,
      accountingClassification: draft.accountingClassification,
    );
    final request = ApplicationCommandRequest<PostExpenseCommand>(
      command: command,
      businessContext: businessContext,
      idempotencyKey: command.commandId,
    );
    _retryRequest = request;
    setState(() {
      _isSubmittingExpense = true;
      _postingLifecycle = 'queued';
      _postingStatusMessage = 'تم حفظ محاولة المصروف محلياً دون أثر مالي.';
    });
    try {
      await _submitPostExpense(user, request);
    } finally {
      if (mounted) setState(() => _isSubmittingExpense = false);
    }
  }

  Future<void> _submitPostExpense(
    AppUser user,
    ApplicationCommandRequest<PostExpenseCommand> request,
  ) async {
    setState(() {
      _postingLifecycle = 'sending';
      _postingStatusMessage = 'جارٍ إرسال المصروف إلى الخادم المالي...';
    });
    final result = await ApplicationScope.of(context)
        .commands
        .postExpense
        .execute(request);
    if (!mounted) return;
    if (result is PostExpenseSuccess) {
      if (result.projectionPending) {
        _showMessage(
          lifecycle: 'confirmedProjectionPending',
          message:
              'تم اعتماد المصروف مالياً، وتعذر تحديث النسخة المحلية. أعد المحاولة لإصلاح العرض فقط.',
          retry: true,
        );
      } else {
        _retryRequest = null;
        _showMessage(
          lifecycle: 'confirmed',
          message: result.replayed
              ? 'تم تأكيد المصروف السابق دون تكرار الأثر المالي.'
              : 'تم اعتماد المصروف وتحديث السجلات المحلية.',
        );
        await _controller!.refreshAfterConfirmedProjection(user);
      }
      return;
    }
    final failure = result as PostExpenseFailure;
    final lifecycle = failure.code == 'serverUnavailable'
        ? 'unknownOutcome'
        : failure.code == 'approvalRequired'
            ? 'approvalRequired'
            : 'rejected';
    final retry = failure.code == 'serverUnavailable';
    _showMessage(
      lifecycle: lifecycle,
      message: _messageForFailure(failure.code),
      retry: retry,
    );
    if (!retry) _retryRequest = null;
  }

  Future<void> _retryLastCommand(AppUser user) async {
    final request = _retryRequest;
    if (request == null || _isSubmittingExpense) return;
    setState(() => _isSubmittingExpense = true);
    try {
      await _submitPostExpense(user, request);
    } finally {
      if (mounted) setState(() => _isSubmittingExpense = false);
    }
  }

  void _showMessage({
    required String lifecycle,
    required String message,
    bool retry = false,
  }) {
    if (!mounted) return;
    setState(() {
      _postingLifecycle = lifecycle;
      _postingStatusMessage = message;
    });
    final user = AuthScope.of(context).state.user;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: retry && user != null
            ? SnackBarAction(
                label: 'إعادة المحاولة',
                onPressed: () => _retryLastCommand(user),
              )
            : null,
      ),
    );
  }

  String _messageForFailure(String code) => switch (code) {
        'validation.invalidField' => 'تحقق من بيانات المصروف المدخلة.',
        'unauthenticated.sessionRequired' =>
          'انتهت جلسة الدخول السحابية. سجل الدخول ثم أعد المحاولة.',
        'unauthorized.expensePostingDenied' =>
          'لا تسمح العضوية الحالية بتسجيل المصروف.',
        'wrongBusinessContext' =>
          'سياق المنشأة غير متطابق. حدّث الجلسة قبل المحاولة.',
        'account.notFoundOrInactive' =>
          'الحساب السحابي غير موجود أو غير نشط أو غير جاهز.',
        'paymentRoute.invalid' => 'طريقة الدفع لا تطابق نوع الحساب.',
        'period.closed' => 'لا يمكن التسجيل في فترة مالية مغلقة.',
        'balance.insufficient' => 'الرصيد الموثق على الخادم غير كافٍ.',
        'approvalRequired' =>
          'هذه العملية تحتاج موافقة تجاوز رصيد، وهي خارج هذا المسار.',
        'idempotencyConflict' =>
          'تعارضت المحاولة المحفوظة مع بيانات مختلفة. أنشئ عملية جديدة.',
        'serverUnavailable' =>
          'تعذر معرفة نتيجة الخادم. أعد المحاولة بنفس رقم العملية.',
        'transactionFailure' => 'ألغى الخادم العملية كاملة دون أي أثر مالي.',
        'projectionFailure' =>
          'تم الاعتماد المالي لكن تحديث العرض المحلي ما زال معلقاً.',
        _ => 'تعذر تسجيل المصروف بأمان. لم يحدث تسجيل محلي بديل.',
      };

  String _formatDateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  Future<void> _reclassifyExpense(
    AppUser user,
    ExpenseRecord expense,
  ) async {
    final result = await showDialog<(ExpenseAccountingClassification, String)>(
      context: context,
      builder: (context) => _ExpenseReclassificationDialog(expense: expense),
    );
    if (result == null) return;
    await _controller!.reclassifyExpense(
      user: user,
      expenseId: expense.id,
      classification: result.$1,
      reason: result.$2,
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.expense, this.onReclassify});

  final ExpenseRecord expense;
  final VoidCallback? onReclassify;

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
          const SizedBox(height: 4),
          Text(
            'التصنيف المحاسبي: ${expense.accountingClassification?.labelAr ?? 'غير مصنف (سجل قديم)'}',
          ),
          if (expense.paymentMethod != null) ...[
            const SizedBox(height: 4),
            Text('طريقة الدفع: ${expense.paymentMethod!.labelAr}'),
          ],
          if (expense.notes != null) ...[
            const SizedBox(height: 8),
            Text(expense.notes!),
          ],
          if (onReclassify != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onReclassify,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('تعديل التصنيف المحاسبي'),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}

class _ExpenseReclassificationDialog extends StatefulWidget {
  const _ExpenseReclassificationDialog({required this.expense});
  final ExpenseRecord expense;

  @override
  State<_ExpenseReclassificationDialog> createState() =>
      _ExpenseReclassificationDialogState();
}

class _ExpenseReclassificationDialogState
    extends State<_ExpenseReclassificationDialog> {
  late ExpenseAccountingClassification _classification =
      widget.expense.accountingClassification ??
          ExpenseAccountingClassification.operating;
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GhalalResponsiveDialog(
        isDirty: _reason.text.isNotEmpty,
        title: const Text('تعديل التصنيف المحاسبي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<ExpenseAccountingClassification>(
              value: _classification,
              decoration: const InputDecoration(labelText: 'التصنيف الجديد'),
              items: ExpenseAccountingClassification.values
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.labelAr),
                      ))
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) setState(() => _classification = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              decoration: const InputDecoration(
                labelText: 'سبب التعديل *',
                helperText: 'سيُحفظ السبب وهوية المالك في سجل التدقيق.',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final reason = _reason.text.trim();
              if (reason.isEmpty) {
                setState(() => _error = 'سبب التعديل مطلوب.');
                return;
              }
              Navigator.of(context).pop((_classification, reason));
            },
            child: const Text('حفظ التعديل'),
          ),
        ],
      );
}

class _ExpenseFormDialog extends StatefulWidget {
  const _ExpenseFormDialog({
    required this.financialAccounts,
    required this.accountBalancesQirsh,
  });

  final List<FinancialAccount> financialAccounts;
  final Map<String, int> accountBalancesQirsh;

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
  ExpenseAccountingClassification? _selectedAccountingClassification;
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
            DropdownButtonFormField<ExpenseAccountingClassification>(
              value: _selectedAccountingClassification,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: 'التصنيف المحاسبي *'),
              items: ExpenseAccountingClassification.values
                  .map((classification) => DropdownMenuItem(
                        value: classification,
                        child: Text(classification.labelAr),
                      ))
                  .toList(growable: false),
              onChanged: (value) =>
                  setState(() => _selectedAccountingClassification = value),
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
      if (_selectedAccountingClassification == null) {
        setState(() => _errorMessage = 'اختر التصنيف المحاسبي للمصروف.');
        return;
      }
      if (_selectedAccountId == null) {
        setState(() => _errorMessage = 'اختر الحساب المالي للمصروف.');
        return;
      }
      setState(() => _isSubmitting = true);
      Navigator.of(context).pop(
        _ExpensePostingIntent(
          date: _date,
          category: _categoryController.text,
          amountQirsh: amountQirsh,
          notes: _notesController.text,
          localFinancialAccountId: _selectedAccountId!,
          paymentMethod: _selectedPaymentMethod!,
          accountingClassification: _selectedAccountingClassification!,
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
      _selectedAccountingClassification != null ||
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
                  ? 'قد يطلب الخادم موافقة تجاوز؛ لن يُسجل المصروف محلياً قبل الاعتماد.'
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

final class _ExpensePostingIntent {
  const _ExpensePostingIntent({
    required this.date,
    required this.category,
    required this.amountQirsh,
    required this.localFinancialAccountId,
    required this.paymentMethod,
    required this.accountingClassification,
    this.notes,
  });

  final DateTime date;
  final String category;
  final int amountQirsh;
  final String? notes;
  final String localFinancialAccountId;
  final PaymentMethod paymentMethod;
  final ExpenseAccountingClassification accountingClassification;
}
