import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/page_back_button.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class SupplierAdvanceActionsScreen extends StatefulWidget {
  const SupplierAdvanceActionsScreen({
    super.key,
    required this.supplier,
    required this.user,
    required this.controller,
    this.financialAccountRepository,
  });

  final Supplier supplier;
  final AppUser user;
  final SupplierController controller;
  final FinancialAccountRepository? financialAccountRepository;

  @override
  State<SupplierAdvanceActionsScreen> createState() =>
      _SupplierAdvanceActionsScreenState();
}

class _SupplierAdvanceActionsScreenState
    extends State<SupplierAdvanceActionsScreen> {
  late final FinancialAccountRepository _financialRepository;
  List<SupplierAdvanceSummary> _advances = const [];
  bool _loading = true;
  String? _error;
  String? _activeAdvanceId;

  @override
  void initState() {
    super.initState();
    _financialRepository = widget.financialAccountRepository ??
        AppRepositories.financialAccountRepository;
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final values =
          await widget.controller.advancesForSupplier(widget.supplier.id);
      if (!mounted) return;
      setState(() { _advances = values; _loading = false; });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل سلف المورد. حاول مرة أخرى.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: 112,
          leading: const AppBarBackButton(),
          title: Text('سلف المورد - ${widget.supplier.name}'),
        ),
        body: SafeArea(child: _body()),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        key: Key('supplier-advances-loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_error != null) {
      return Center(
        key: const Key('supplier-advances-error'),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('supplier-advances-retry'),
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ]),
        ),
      );
    }
    if (_advances.isEmpty) {
      return const Center(
        key: Key('supplier-advances-empty'),
        child: PremiumCard(child: Text('لا توجد سلف مسجلة لهذا المورد')),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: const Key('supplier-advances-list'),
        padding: const EdgeInsets.all(16),
        children: [
          Text('سلف المورد', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          const Text(
            'يمكن تطبيق الرصيد على ذمة المورد أو استرداده منه إلى الحساب المالي الأصلي.',
            style: TextStyle(color: AppColors.mutedText),
          ),
          const SizedBox(height: 16),
          for (final summary in _advances)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AdvanceCard(
                summary: summary,
                busy: _activeAdvanceId == summary.advance.id,
                onApply: () => _apply(summary),
                onRefund: () => _refund(summary),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _apply(SupplierAdvanceSummary summary) async {
    if (_activeAdvanceId != null || !summary.canAct) return;
    setState(() => _activeAdvanceId = summary.advance.id);
    bool? success;
    try {
      success = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ApplyDialog(
          supplier: widget.supplier,
          user: widget.user,
          controller: widget.controller,
          summary: summary,
        ),
      );
    } finally {
      if (mounted) setState(() => _activeAdvanceId = null);
    }
    if (success != true || !mounted) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تطبيق السلفة بنجاح')),
    );
  }

  Future<void> _refund(SupplierAdvanceSummary summary) async {
    if (_activeAdvanceId != null || !summary.canAct) return;
    setState(() => _activeAdvanceId = summary.advance.id);
    bool? success;
    try {
      final accounts = await _financialRepository.listAccounts();
      if (!mounted) return;
      final available = accounts
          .where((value) =>
              value.isActive && value.id == summary.advance.financialAccountId)
          .toList(growable: false);
      if (available.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('الحساب المالي الأصلي للسلفة غير متاح.'),
        ));
        return;
      }
      success = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _RefundDialog(
          supplier: widget.supplier,
          user: widget.user,
          controller: widget.controller,
          summary: summary,
          accounts: available,
          financialRepository: _financialRepository,
        ),
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر تحميل الحساب المالي. حاول مرة أخرى.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _activeAdvanceId = null);
    }
    if (success != true || !mounted) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('تم استرداد مبلغ السلفة من المورد بنجاح'),
    ));
  }
}

class _AdvanceCard extends StatelessWidget {
  const _AdvanceCard({required this.summary, required this.busy,
    required this.onApply, required this.onRefund});
  final SupplierAdvanceSummary summary;
  final bool busy;
  final VoidCallback onApply;
  final VoidCallback onRefund;

  @override
  Widget build(BuildContext context) {
    final advance = summary.advance;
    return PremiumCard(
      key: Key('supplier-advance-card-${advance.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('سلفة بتاريخ ${_date(advance.createdAt)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
          Chip(label: Text(summary.statusLabelAr)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 18, runSpacing: 8, children: [
          _Amount('قيمة السلفة', advance.amountQirsh),
          _Amount('المبلغ المطبق', summary.appliedQirsh),
          _Amount('المبلغ المسترد', summary.refundedQirsh),
          _Amount('الرصيد المتاح', summary.remainingQirsh),
        ]),
        const SizedBox(height: 8),
        Text('المصدر: دفعة زائدة للمورد • المرجع: ${advance.sourcePaymentId}',
          style: const TextStyle(color: AppColors.mutedText)),
        if (summary.canAct) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              key: Key('apply-supplier-advance-${advance.id}'),
              onPressed: busy ? null : onApply,
              icon: const Icon(Icons.account_balance_wallet_rounded),
              label: const Text('تطبيق السلفة'),
            ),
            OutlinedButton.icon(
              key: Key('refund-supplier-advance-${advance.id}'),
              onPressed: busy ? null : onRefund,
              icon: const Icon(Icons.south_west_rounded),
              label: const Text('استرداد السلفة من المورد'),
            ),
          ]),
        ],
      ]),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount(this.label, this.value);
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [Text(label, style: const TextStyle(color: AppColors.mutedText)),
      Text(MoneyUtils.formatPiastersAsEgp(value),
        style: const TextStyle(fontWeight: FontWeight.w700))],
  );
}

class _ApplyDialog extends StatefulWidget {
  const _ApplyDialog({required this.supplier, required this.user,
    required this.controller, required this.summary});
  final Supplier supplier;
  final AppUser user;
  final SupplierController controller;
  final SupplierAdvanceSummary summary;
  @override
  State<_ApplyDialog> createState() => _ApplyDialogState();
}

class _ApplyDialogState extends State<_ApplyDialog> {
  final _amount = TextEditingController();
  late final String _requestId = _newRequestId('supplier-advance-apply');
  late final DateTime _date = DateTime.now();
  bool _submitting = false;
  String? _error;
  @override
  void dispose() { _amount.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('تطبيق السلفة - ${widget.supplier.name}'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('الرصيد المتاح: ${MoneyUtils.formatPiastersAsEgp(widget.summary.remainingQirsh)}'),
        const Text('سيتم استخدام المبلغ لتخفيض المبلغ المستحق للمورد'),
        TextField(key: const Key('supplier-advance-application-amount'),
          controller: _amount, enabled: !_submitting,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'مبلغ التطبيق بالجنيه')),
        if (_error != null) Text(_error!, key: const Key('supplier-advance-application-error'),
          style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ])),
    actions: [
      TextButton(onPressed: _submitting ? null : () => Navigator.pop(context, false), child: const Text('إلغاء')),
      FilledButton(key: const Key('supplier-advance-application-submit'),
        onPressed: _submitting ? null : _submit,
        child: _submitting ? const SizedBox(width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2)) : const Text('تأكيد التطبيق')),
    ]);
  Future<void> _submit() async {
    if (_submitting) return;
    final value = _validate(_amount.text, widget.summary.remainingQirsh);
    if (value.message != null) { setState(() => _error = value.message); return; }
    setState(() { _submitting = true; _error = null; });
    final result = await widget.controller.applySupplierAdvance(user: widget.user,
      advance: widget.summary.advance, amountQirsh: value.amount!, date: _date,
      operationRequestId: _requestId);
    if (!mounted) return;
    if (result.isSuccess) { Navigator.pop(context, true); return; }
    setState(() { _submitting = false; _error = result.message; });
  }
}

class _RefundDialog extends StatefulWidget {
  const _RefundDialog({required this.supplier, required this.user,
    required this.controller, required this.summary, required this.accounts,
    required this.financialRepository});
  final Supplier supplier;
  final AppUser user;
  final SupplierController controller;
  final SupplierAdvanceSummary summary;
  final List<FinancialAccount> accounts;
  final FinancialAccountRepository financialRepository;
  @override
  State<_RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<_RefundDialog> {
  final _amount = TextEditingController();
  late final String _requestId = _newRequestId('supplier-advance-refund');
  late final DateTime _date = DateTime.now();
  String? _accountId;
  int? _balance;
  bool _submitting = false;
  String? _error;
  FinancialAccount? get _account => _accountId == null ? null :
    widget.accounts.where((value) => value.id == _accountId).firstOrNull;
  @override
  void dispose() { _amount.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final parsed = _parse(_amount.text);
    return AlertDialog(
      title: Text('استرداد السلفة من المورد - ${widget.supplier.name}'),
      content: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('الرصيد المتاح: ${MoneyUtils.formatPiastersAsEgp(widget.summary.remainingQirsh)}'),
            const Text('سيُضاف المبلغ المسترد إلى الحساب المالي المحدد'),
            DropdownButtonFormField<String>(key: const Key('supplier-advance-refund-account'),
              value: _accountId, decoration: const InputDecoration(labelText: 'الحساب المالي *'),
              items: widget.accounts.map((value) => DropdownMenuItem(value: value.id,
                child: Text('${value.type.iconEmoji} ${value.name}'))).toList(),
              onChanged: _submitting ? null : _selectAccount),
            if (_balance != null) Text('رصيد الحساب الحالي: ${MoneyUtils.formatPiastersAsEgp(_balance!)}'),
            TextField(key: const Key('supplier-advance-refund-amount'), controller: _amount,
              enabled: !_submitting, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'مبلغ الاسترداد بالجنيه'),
              onChanged: (_) => setState(() {})),
            if (_account != null && parsed != null && parsed > 0)
              Text('تأكيد: سيضيف المورد ${widget.supplier.name} مبلغ ${MoneyUtils.formatPiastersAsEgp(parsed)} إلى حساب ${_account!.name}.',
                key: const Key('supplier-advance-refund-confirmation'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            if (_error != null) Text(_error!, key: const Key('supplier-advance-refund-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ]))),
      actions: [
        TextButton(onPressed: _submitting ? null : () => Navigator.pop(context, false), child: const Text('إلغاء')),
        FilledButton(key: const Key('supplier-advance-refund-submit'),
          onPressed: _submitting ? null : _submit,
          child: _submitting ? const SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2)) : const Text('تأكيد الاسترداد')),
      ]);
  }
  Future<void> _selectAccount(String? id) async {
    setState(() { _accountId = id; _balance = null; _error = null; });
    if (id == null) return;
    try {
      final value = await widget.financialRepository.currentBalanceForAccount(id);
      if (mounted && _accountId == id) setState(() => _balance = value);
    } on Object {
      if (mounted && _accountId == id) setState(() => _error = 'تعذر تحميل رصيد الحساب.');
    }
  }
  Future<void> _submit() async {
    if (_submitting) return;
    final account = _account;
    if (account == null) { setState(() => _error = 'اختر الحساب المالي أولًا.'); return; }
    final value = _validate(_amount.text, widget.summary.remainingQirsh);
    if (value.message != null) { setState(() => _error = value.message); return; }
    setState(() { _submitting = true; _error = null; });
    final result = await widget.controller.refundSupplierAdvance(user: widget.user,
      advance: widget.summary.advance, amountQirsh: value.amount!, date: _date,
      operationRequestId: _requestId, financialAccountId: account.id,
      paymentMethod: widget.summary.advance.paymentMethod);
    if (!mounted) return;
    if (result.isSuccess) { Navigator.pop(context, true); return; }
    setState(() { _submitting = false; _error = result.message; });
  }
}

class _Validation { const _Validation({this.amount, this.message}); final int? amount; final String? message; }
_Validation _validate(String text, int available) {
  if (text.trim().isEmpty) return const _Validation(message: 'أدخل المبلغ أولًا.');
  final amount = _parse(text);
  if (amount == null || amount <= 0) return const _Validation(message: 'المبلغ غير صالح ويجب أن يكون أكبر من صفر.');
  if (amount > available) return const _Validation(message: 'المبلغ يتجاوز الرصيد المتاح من السلفة.');
  return _Validation(amount: amount);
}
int? _parse(String value) { try { return MoneyUtils.parseEgpToPiasters(value, allowZero: true); } on Object { return null; } }
int _sequence = 0;
String _newRequestId(String prefix) => '$prefix-${DateTime.now().microsecondsSinceEpoch}-${++_sequence}';
String _date(DateTime value) => '${value.toLocal().year}-${value.toLocal().month.toString().padLeft(2, '0')}-${value.toLocal().day.toString().padLeft(2, '0')}';
