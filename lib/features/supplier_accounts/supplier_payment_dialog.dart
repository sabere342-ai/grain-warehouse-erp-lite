import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payment.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';

class SupplierPaymentDialog extends StatefulWidget {
  const SupplierPaymentDialog({
    super.key,
    required this.supplier,
    required this.balanceQirsh,
    required this.userId,
  });

  final Supplier supplier;
  final int balanceQirsh;
  final String userId;

  @override
  State<SupplierPaymentDialog> createState() => _SupplierPaymentDialogState();
}

class _SupplierPaymentDialogState extends State<SupplierPaymentDialog> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balance = widget.balanceQirsh;
    return AlertDialog(
      title: Text('تسجيل دفعة لـ ${widget.supplier.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الرصيد المستحق: ${MoneyUtils.formatPiastersAsEgp(balance)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'المبلغ المدفوع بالجنيه',
                helperText: 'اكتب المبلغ المدفوع للمورد.',
              ),
              textDirection: TextDirection.ltr,
            ),
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
          child: const Text('تسجيل الدفع'),
        ),
      ],
    );
  }

  void _submit() {
    final amount = _tryParseAmount(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = 'اكتب المبلغ المدفوع بالجنيه بشكل صحيح.');
      return;
    }
    if (amount > widget.balanceQirsh) {
      setState(() => _errorMessage = 'المبلغ يتجاوز الرصيد المستحق.');
      return;
    }

    Navigator.of(context).pop(
      SupplierPaymentDraft(
        supplierId: widget.supplier.id,
        date: DateTime.now(),
        amountQirsh: amount,
        createdByUserId: widget.userId,
        notes: _notesController.text,
      ),
    );
  }

  int? _tryParseAmount(String value) {
    try {
      return MoneyUtils.parseEgpToPiasters(value, allowZero: false);
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }
}
