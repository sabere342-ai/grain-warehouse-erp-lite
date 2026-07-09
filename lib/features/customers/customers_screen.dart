import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_controller.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_customer_statement_view.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key, this.controller});

  final CustomerController? controller;

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  late final CustomerController _controller;
  late final bool _ownsController;

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
      return const PremiumCard(child: Text('يجب تسجيل الدخول لعرض العملاء.'));
    }

    final canManage = user.permissions.canCreateCustomerPayment ||
        user.permissions.canAccessSettings;

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
                      Text('العملاء', style: textTheme.headlineMedium),
                      const SizedBox(height: 6),
                      Text(
                        'أرصدة العملاء محسوبة من البيع الآجل والتحصيل فقط، ولا يوجد تعديل يدوي للرصيد.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canManage)
                  FilledButton.icon(
                    onPressed: () => _showCustomerForm(context, user: user),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('إضافة عميل'),
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
            else if (_controller.customers.isEmpty)
              const PremiumCard(child: Text('لا توجد بيانات عملاء بعد.'))
            else
              ..._controller.customers.map(
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
                    onPreviewStatement: () =>
                        _showStatementPreview(context, customer),
                    onCollection: () => _showCollectionForm(
                      context,
                      user: user,
                      customer: customer,
                      balanceQirsh: _controller.balanceForCustomer(customer.id),
                    ),
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
    final result = await showDialog<_CollectionFormResult>(
      context: context,
      builder: (context) => _CollectionFormDialog(
        customer: customer,
        balanceQirsh: balanceQirsh,
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
    );
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
      builder: (context) => const _CustomerOpeningBalanceDialog(),
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
    required this.onCollection,
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
  final VoidCallback onCollection;
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
                  onPressed: onCollection,
                  icon: const Icon(Icons.payments_rounded),
                  label: const Text('تسجيل تحصيل'),
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
  });

  final Customer customer;
  final int balanceQirsh;

  @override
  State<_CollectionFormDialog> createState() => _CollectionFormDialogState();
}

class _CollectionFormDialogState extends State<_CollectionFormDialog> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _date = DateTime.now();
  String? _errorMessage;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('تسجيل تحصيل - ${widget.customer.name}'),
      content: SingleChildScrollView(
        child: Column(
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
                helperText: 'لا يمكن تسجيل تحصيل أكبر من الرصيد المستحق.',
              ),
              textDirection: TextDirection.ltr,
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
          child: const Text('حفظ التحصيل'),
        ),
      ],
    );
  }

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

  void _submit() {
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
    if (amount > widget.balanceQirsh) {
      setState(
          () => _errorMessage = 'لا يمكن تسجيل تحصيل أكبر من الرصيد المستحق.');
      return;
    }
    Navigator.of(context).pop(
      _CollectionFormResult(
        date: _date,
        amountQirsh: amount,
        notes: _notesController.text,
      ),
    );
  }

  String _formatDate(DateTime value) {
    return '${value.year}-${_twoDigits(value.month)}-${_twoDigits(value.day)}';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

class _CollectionFormResult {
  const _CollectionFormResult({
    required this.date,
    required this.amountQirsh,
    this.notes,
  });

  final DateTime date;
  final int amountQirsh;
  final String? notes;
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
      appBar: AppBar(
        title: Text('كشف الحساب - ${customer.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.preview_rounded),
            tooltip: 'معاينة كشف الحساب',
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
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
            const PremiumCard(child: Text('لا توجد حركات على هذا العميل بعد.'))
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

class _CustomerOpeningBalanceDialog extends StatefulWidget {
  const _CustomerOpeningBalanceDialog();

  @override
  State<_CustomerOpeningBalanceDialog> createState() =>
      _CustomerOpeningBalanceDialogState();
}

class _CustomerOpeningBalanceDialogState
    extends State<_CustomerOpeningBalanceDialog> {
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
      title: const Text('رصيد افتتاحي للعميل'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'أدخل المبلغ المستحق على هذا العميل كرصيد افتتاحي (بقيمة مالية).',
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
    return AlertDialog(
      title: Text(widget.customer == null ? 'إضافة عميل' : 'تعديل عميل'),
      content: SingleChildScrollView(
        child: Column(
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

  void _submit() {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'أدخل اسم العميل.');
      return;
    }
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
