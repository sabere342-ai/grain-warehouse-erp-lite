import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_responsive_dialog.dart';

enum OpeningBalanceParty {
  customer,
  supplier,
}

class OpeningBalanceAmountDialog extends StatefulWidget {
  const OpeningBalanceAmountDialog({
    super.key,
    required this.party,
  });

  final OpeningBalanceParty party;

  @override
  State<OpeningBalanceAmountDialog> createState() =>
      _OpeningBalanceAmountDialogState();
}

class _OpeningBalanceAmountDialogState
    extends State<OpeningBalanceAmountDialog> {
  static const int _maxCanonicalQirsh = 0x7fffffffffffffff;

  final _amountController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.party) {
      OpeningBalanceParty.customer => 'رصيد افتتاحي للعميل',
      OpeningBalanceParty.supplier => 'رصيد افتتاحي للمورد',
    };
    final description = switch (widget.party) {
      OpeningBalanceParty.customer =>
        'أدخل المبلغ المستحق على العميل كرصيد افتتاحي بالجنيه.',
      OpeningBalanceParty.supplier =>
        'أدخل المبلغ المستحق لهذا المورد كرصيد افتتاحي بالجنيه.',
    };

    return GhalalResponsiveDialog(
      isDirty: _isDirty,
      isBusy: _isLoading,
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(description),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('opening-balance-egp-input'),
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'الرصيد الافتتاحي (جنيه)',
              helperText:
                  'أدخل المبلغ بالجنيه، ويمكن استخدام خانتين عشريتين (مثال: 1250.50).',
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
              : const Text('حفظ الرصيد الافتتاحي'),
        ),
      ],
    );
  }

  bool get _isDirty => _amountController.text.trim().isNotEmpty;

  void _submit() {
    try {
      final amountQirsh = MoneyUtils.parseEgpToPiasters(
        _amountController.text,
        allowZero: false,
      );
      if (amountQirsh > _maxCanonicalQirsh) {
        throw const FormatException('Opening balance exceeds storage range.');
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      Navigator.of(context).pop(amountQirsh);
    } on FormatException {
      setState(() {
        _errorMessage =
            'أدخل مبلغًا صحيحًا بالجنيه أكبر من صفر وبحد أقصى خانتان عشريتان.';
      });
    }
  }
}
