import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payment.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/features/supplier_accounts/supplier_payment_dialog.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class SupplierStatementScreen extends StatefulWidget {
  const SupplierStatementScreen({super.key, required this.supplier});

  final Supplier supplier;

  @override
  State<SupplierStatementScreen> createState() =>
      _SupplierStatementScreenState();
}

class _SupplierStatementScreenState extends State<SupplierStatementScreen> {
  final SupplierAccountRepository _repository =
      AppRepositories.supplierAccountRepository;

  SupplierStatement? _statement;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final statement =
          await _repository.statementForSupplier(widget.supplier.id);
      if (!mounted) return;
      setState(() {
        _statement = statement;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final supplier = widget.supplier;

    return Scaffold(
      appBar: AppBar(
        title: Text('كشف حساب ${supplier.name}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('خطأ: $_error'))
              : _buildContent(textTheme),
    );
  }

  Future<void> _recordPayment() async {
    final user = AuthScope.of(context).state.user;
    if (user == null) return;
    final balance = _statement?.finalBalanceQirsh ?? 0;
    if (balance <= 0) return;

    final draft = await showDialog<SupplierPaymentDraft>(
      context: context,
      builder: (context) => SupplierPaymentDialog(
        supplier: widget.supplier,
        balanceQirsh: balance,
        userId: user.id,
      ),
    );

    if (draft == null) return;

    try {
      await _repository.createPayment(draft);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تسجيل الدفع: $e')),
      );
    }
  }

  Widget _buildContent(TextTheme textTheme) {
    final statement = _statement!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PremiumCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'الرصيد الحالي',
                        style: textTheme.titleMedium,
                      ),
                    ),
                    if (statement.finalBalanceQirsh > 0)
                      FilledButton.icon(
                        onPressed: _recordPayment,
                        icon: const Icon(Icons.payments_rounded),
                        label: const Text('تسجيل دفعة'),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  MoneyUtils.formatPiastersAsEgp(statement.finalBalanceQirsh),
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: statement.finalBalanceQirsh > 0
                        ? AppColors.text
                        : AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'المشتريات تزيد المبلغ المستحق للمورد، والدفعات تقلله.',
            style: TextStyle(color: AppColors.mutedText, fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
        ...statement.lines.map((line) => _buildLine(line, textTheme)),
      ],
    );
  }

  Widget _buildLine(SupplierStatementLine line, TextTheme textTheme) {
    final entry = line.entry;
    final icon = switch (entry.type) {
      SupplierAccountEntryType.purchase => Icons.shopping_cart_rounded,
      SupplierAccountEntryType.payment => Icons.payments_rounded,
      SupplierAccountEntryType.openingBalance => Icons.account_balance_rounded,
    };
    final label = switch (entry.type) {
      SupplierAccountEntryType.purchase => 'مشتريات',
      SupplierAccountEntryType.payment => 'دفعة للمورد',
      SupplierAccountEntryType.openingBalance => 'رصيد افتتاحي',
    };
    final amountText = switch (entry.type) {
      SupplierAccountEntryType.purchase ||
      SupplierAccountEntryType.openingBalance =>
        MoneyUtils.formatPiastersAsEgp(entry.debitAmountQirsh),
      SupplierAccountEntryType.payment =>
        MoneyUtils.formatPiastersAsEgp(entry.creditAmountQirsh),
    };
    return PremiumCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.olive),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.descriptionAr,
                    style: textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _labelValue(label, amountText),
                const SizedBox(width: 16),
                _labelValue('المتبقي',
                    MoneyUtils.formatPiastersAsEgp(line.runningBalanceQirsh)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _labelValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.mutedText)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
