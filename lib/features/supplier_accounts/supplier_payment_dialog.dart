import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/payment_routing_policy.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/features/financial_accounts/negative_balance_approval_dialog.dart';

class SupplierPaymentDialog extends StatefulWidget {
  const SupplierPaymentDialog({
    super.key,
    required this.supplier,
    required this.balanceQirsh,
    required this.userId,
    required this.financialAccounts,
  });

  final Supplier supplier;
  final int balanceQirsh;
  final String userId;
  final List<FinancialAccount> financialAccounts;

  @override
  State<SupplierPaymentDialog> createState() => _SupplierPaymentDialogState();
}

class SupplierPaymentResult {
  const SupplierPaymentResult({
    required this.amountQirsh,
    required this.date,
    this.notes,
    this.financialAccountId,
    this.paymentMethod,
    this.operationRequestId,
    this.overpaymentApprovalId,
  });

  final int amountQirsh;
  final DateTime date;
  final String? notes;
  final String? financialAccountId;
  final PaymentMethod? paymentMethod;
  final String? operationRequestId;
  final String? overpaymentApprovalId;
}

class _SupplierPaymentDialogState extends State<SupplierPaymentDialog> {
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

    return AlertDialog(
      title: Text('تسجيل دفعة لـ ${widget.supplier.name}'),
      content: SingleChildScrollView(
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الرصيد المستحق: ${MoneyUtils.formatPiastersAsEgp(widget.balanceQirsh)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: Text('تاريخ الدفع: ${_formatDate(_date)}'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'المبلغ المدفوع بالجنيه',
                    helperText:
                        'يمكن تسجيل دفعة أكبر من الرصيد — سيُنشأ سلفة للمورد.',
                  ),
                  textDirection: TextDirection.ltr,
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PaymentMethod>(
                  value: _selectedPaymentMethod,
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
                    setDialogState(() {
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
                      : (accountId) => setDialogState(
                            () => _selectedAccountId = accountId,
                          ),
                ),
                if (isOverpayment) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
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
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات اختيارية',
                    helperText: 'مثال: طريقة الدفع أو مرجع التحويل.',
                  ),
                  maxLines: 2,
                  textDirection: TextDirection.rtl,
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
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
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
              : const Text('تسجيل الدفع'),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
      setState(() => _errorMessage = 'اكتب المبلغ المدفوع بالجنيه بشكل صحيح.');
      return;
    }

    if (_selectedPaymentMethod == null) {
      setState(() => _errorMessage = 'اختر طريقة الدفع.');
      return;
    }
    if (_selectedAccountId == null) {
      setState(() => _errorMessage = 'اختر الحساب المالي للسداد.');
      return;
    }

    final isOverpayment = amount > widget.balanceQirsh;
    final operationRequestId =
        'supplier-payment-ui-${DateTime.now().microsecondsSinceEpoch}-${widget.userId}';

    if (isOverpayment) {
      if (_selectedAccountId == null) {
        setState(
            () => _errorMessage = 'اختر الحساب المالي الذي ستُسحب منه السلفة.');
        return;
      }
      final approved = await _requestApproval(amount);
      if (approved == null || !mounted) return;
      Navigator.of(context).pop(SupplierPaymentResult(
        amountQirsh: amount,
        date: _date,
        notes: _notesController.text,
        financialAccountId: _selectedAccountId,
        paymentMethod: _selectedPaymentMethod,
        operationRequestId: approved.requestId,
        overpaymentApprovalId: approved.approvalId,
      ));
    } else {
      Navigator.of(context).pop(SupplierPaymentResult(
        amountQirsh: amount,
        date: _date,
        notes: _notesController.text,
        financialAccountId: _selectedAccountId,
        paymentMethod: _selectedPaymentMethod,
        operationRequestId: operationRequestId,
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
        // ignore: use_build_context_synchronously
        context: context,
        authRepository: AppRepositories.authRepository,
        accountName: account.name,
        currentBalanceQirsh: accountBalance,
        requestedAmountQirsh: amount,
        operationDescription: 'تسجيل سلفة للمورد ${widget.supplier.name}',
        approvalService: AppRepositories.negativeBalanceApprovalService,
        approvalDraft: NegativeBalanceApprovalDraft(
          requestedByUserId: widget.userId,
          approvedByOwnerUserId: '',
          accountId: account.id,
          amountQirsh: amount - widget.balanceQirsh,
          operationType: NegativeBalanceOperationType.supplierOverpayment,
          sourceDocumentId: requestId,
          sourceDocumentType: 'supplierOverpayment',
          balanceBeforeQirsh: accountBalance,
          expectedBalanceAfterQirsh: accountBalance - amount,
          reason: 'دفعة تتجاوز الرصيد المستحق للمورد',
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
