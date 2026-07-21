import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_controller.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/payment_routing_policy.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key, this.controller});

  final ExpenseController? controller;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  late final ExpenseController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        ExpenseController(repository: AppRepositories.expenseRepository);
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
      return const PremiumCard(child: Text('يجب تسجيل الدخول لعرض المصروفات.'));
    }

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
                      Text('المصروفات', style: textTheme.headlineMedium),
                      const SizedBox(height: 6),
                      Text(
                        'تسجيل المصروفات النقدية فقط، ولا تؤثر على كميات المخزون.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: user.permissions.canCreateExpense
                      ? () => _showExpenseForm(context, user: user)
                      : null,
                  icon: const Icon(Icons.add_card_rounded),
                  label: const Text('إضافة مصروف'),
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
            else if (_controller.expenses.isEmpty)
              const PremiumCard(child: Text('لا توجد مصروفات مسجلة بعد.'))
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
    final financialAccounts =
        await AppRepositories.financialAccountRepository.listAccounts();
    if (!context.mounted) return;
    final draft = await showDialog<ExpenseDraft>(
      context: context,
      builder: (context) => _ExpenseFormDialog(
        financialAccounts: financialAccounts,
      ),
    );
    if (draft == null) {
      return;
    }
    await _controller.createExpense(user: user, draft: draft);
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
  const _ExpenseFormDialog({required this.financialAccounts});

  final List<FinancialAccount> financialAccounts;

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

  @override
  void dispose() {
    _categoryController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
        FilledButton(onPressed: _submit, child: const Text('حفظ')),
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
      Navigator.of(context).pop(
        ExpenseDraft(
          date: _date,
          category: _categoryController.text,
          amountQirsh: amountQirsh,
          notes: _notesController.text,
          financialAccountId: _selectedAccountId,
          paymentMethod: _selectedPaymentMethod,
        ),
      );
    } on FormatException {
      setState(() => _errorMessage = 'أدخل مبلغا صحيحا أكبر من صفر.');
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

  String _formatDate(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}
