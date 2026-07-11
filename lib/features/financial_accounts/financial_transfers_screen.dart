import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_controller.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_transfer.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';

class FinancialTransfersScreen extends StatefulWidget {
  const FinancialTransfersScreen({super.key, required this.user});
  final AppUser user;
  @override
  State<FinancialTransfersScreen> createState() =>
      _FinancialTransfersScreenState();
}

class _FinancialTransfersScreenState extends State<FinancialTransfersScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late final FinancialAccountController _controller;
  List<FinancialAccount> _accounts = const [];
  List<FinancialTransfer> _transfers = const [];
  String? _sourceId;
  String? _destinationId;
  DateTime _date = DateTime.now();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = FinancialAccountController(
        repository: AppRepositories.financialAccountRepository);
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _controller.loadAccounts(widget.user);
    final accounts =
        await AppRepositories.financialAccountRepository.listAccounts();
    final transfers =
        await AppRepositories.financialAccountRepository.listTransfers();
    if (mounted) {
      setState(() {
        _accounts = accounts;
        _transfers = transfers.reversed.toList();
        _loading = false;
      });
    }
  }

  FinancialAccount? _account(String? id) {
    if (id == null) return null;
    for (final account in _accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user.role != UserRole.owner) {
      return const Scaffold(
          body: Center(child: Text('التحويلات المالية متاحة للمالك فقط.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('التحويلات المالية')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Text('تحويل جديد', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _accountPicker('الحساب المصدر', _sourceId,
                  (v) => setState(() => _sourceId = v)),
              const SizedBox(height: 10),
              _accountPicker('الحساب الوجهة', _destinationId,
                  (v) => setState(() => _destinationId = v)),
              const SizedBox(height: 10),
              TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'المبلغ بالقرش')),
              const SizedBox(height: 10),
              ListTile(
                  title: const Text('تاريخ التحويل'),
                  subtitle: Text(
                      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _pickDate),
              TextField(
                  controller: _note,
                  decoration:
                      const InputDecoration(labelText: 'ملاحظة (اختيارية)')),
              const SizedBox(height: 14),
              FilledButton.icon(
                  onPressed: _review,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('مراجعة التحويل')),
              const Divider(height: 36),
              Text('سجل التحويلات',
                  style: Theme.of(context).textTheme.titleLarge),
              if (_transfers.isEmpty)
                const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('لا توجد تحويلات مسجلة.')),
              ..._transfers.map(_transferTile),
            ]),
    );
  }

  Widget _accountPicker(
          String label, String? value, ValueChanged<String?> change) =>
      DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(labelText: label),
          items: _accounts
              .map((a) => DropdownMenuItem(
                  value: a.id,
                  child: Text(
                      '${a.name} — ${MoneyUtils.formatPiastersAsEgp(_balance(a.id))}')))
              .toList(),
          onChanged: change);
  int _balance(String id) => _controller.balances
      .where((b) => b.account.id == id)
      .fold(0, (_, b) => b.currentBalanceQirsh);
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: DateTime(2000),
        lastDate: DateTime.now());
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Widget _transferTile(FinancialTransfer transfer) {
    final source =
        _account(transfer.sourceAccountId)?.name ?? transfer.sourceAccountId;
    final destination = _account(transfer.destinationAccountId)?.name ??
        transfer.destinationAccountId;
    return Card(
        child: ListTile(
            title: Text('${transfer.displayNumber}: $source ← $destination'),
            subtitle: Text(
                '${MoneyUtils.formatPiastersAsEgp(transfer.amountQirsh)} · ${transfer.effectiveDate.toLocal().toIso8601String().substring(0, 10)}${transfer.isReversal ? ' · عكس' : transfer.isReversed ? ' · تم عكسه' : ''}'),
            trailing: !transfer.isReversal && !transfer.isReversed
                ? TextButton(
                    onPressed: () => _reverse(transfer),
                    child: const Text('عكس'))
                : null));
  }

  Future<void> _review() async {
    final source = _account(_sourceId);
    final destination = _account(_destinationId);
    final value = int.tryParse(_amount.text.trim());
    if (source == null ||
        destination == null ||
        value == null ||
        value <= 0 ||
        source.id == destination.id) {
      _message('أكمل الحسابين المختلفين والمبلغ الموجب.');
      return;
    }
    final approved = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('مراجعة قبل التنفيذ'),
                content: Text(
                    'من: ${source.name}\nإلى: ${destination.name}\nالمبلغ: ${MoneyUtils.formatPiastersAsEgp(value)}\nالتاريخ: ${_date.toLocal().toIso8601String().substring(0, 10)}\nالملاحظة: ${_note.text.trim().isEmpty ? '—' : _note.text.trim()}\nرصيد المصدر الحالي: ${MoneyUtils.formatPiastersAsEgp(_balance(source.id))}\nرصيد الوجهة الحالي: ${MoneyUtils.formatPiastersAsEgp(_balance(destination.id))}'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('إلغاء')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('تأكيد نهائي'))
                ]));
    if (approved != true) {
      return;
    }
    final now = DateTime.now().microsecondsSinceEpoch;
    final transfer = await _controller.createTransfer(
        user: widget.user,
        draft: FinancialTransferDraft(
            clientRequestId: 'transfer-$now',
            transferReference: 'TR-$now',
            sourceAccountId: source.id,
            destinationAccountId: destination.id,
            amountQirsh: value,
            effectiveDate: _date,
            createdByUserId: widget.user.id,
            note: _note.text));
    if (transfer == null) {
      _message(_controller.errorMessage ?? 'تعذر إنشاء التحويل.');
    } else {
      _amount.clear();
      _note.clear();
      await _load();
    }
  }

  Future<void> _reverse(FinancialTransfer transfer) async {
    final reason = TextEditingController();
    final result = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('عكس التحويل'),
                content: TextField(
                    controller: reason,
                    decoration:
                        const InputDecoration(labelText: 'سبب العكس (إلزامي)')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, reason.text),
                      child: const Text('تأكيد العكس'))
                ]));
    reason.dispose();
    if (result == null) {
      return;
    }
    final reversed = await _controller.reverseTransfer(
        user: widget.user, transferId: transfer.id, reason: result);
    if (reversed == null) {
      _message(_controller.errorMessage ?? 'تعذر عكس التحويل.');
    } else {
      await _load();
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
