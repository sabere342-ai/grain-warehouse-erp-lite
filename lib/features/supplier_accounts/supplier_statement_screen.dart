import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payment.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_supplier_statement_view.dart';
import 'package:grain_warehouse_erp_lite/features/supplier_accounts/supplier_payment_dialog.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_page_header.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_state_view.dart';

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
  bool _isRecordingPayment = false;
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل كشف الحساب.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final supplier = widget.supplier;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          GhalalPageHeader(
            title: 'كشف حساب ${supplier.name}',
            subtitle: 'عرض حركات الحساب والرصيد الحالي للمورد.',
            icon: Icons.account_balance_rounded,
            onBack: () => Navigator.of(context).maybePop(),
            actions: [
              if (_statement != null)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => PrintableSupplierStatementView(
                          statement: _statement!,
                          supplierName: supplier.name,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.preview_rounded),
                  label: const Text('معاينة كشف الحساب'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_isLoading)
            const GhalalLoadingState(label: 'جاري تحميل كشف المورد...')
          else if (_error != null)
            GhalalErrorState(message: _error!, onRetry: _load)
          else
            _buildContent(textTheme),
        ],
      ),
    );
  }

  Future<void> _recordPayment() async {
    if (_isRecordingPayment) return;
    final user = AuthScope.of(context).state.user;
    if (user == null) return;
    setState(() => _isRecordingPayment = true);
    final balance = _statement?.finalBalanceQirsh ?? 0;

    List<FinancialAccount> financialAccounts;
    try {
      financialAccounts =
          await AppRepositories.financialAccountRepository.listAccounts();
    } on Object {
      if (mounted) {
        setState(() => _isRecordingPayment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحميل الحسابات المالية.')),
        );
      }
      return;
    }
    if (!mounted) return;

    final result = await showDialog<SupplierPaymentResult>(
      context: context,
      builder: (_) => SupplierPaymentDialog(
        supplier: widget.supplier,
        balanceQirsh: balance,
        userId: user.id,
        financialAccounts: financialAccounts,
      ),
    );

    if (result == null) {
      if (mounted) setState(() => _isRecordingPayment = false);
      return;
    }

    final draft = SupplierPaymentDraft(
      supplierId: widget.supplier.id,
      date: result.date,
      amountQirsh: result.amountQirsh,
      createdByUserId: user.id,
      createdByUserName: user.name,
      notes: result.notes,
      financialAccountId: result.financialAccountId,
      paymentMethod: result.paymentMethod,
      operationRequestId: result.operationRequestId,
      overpaymentApprovalId: result.overpaymentApprovalId,
    );

    try {
      if (draft.overpaymentApprovalId != null) {
        await _repository.createPayment(draft);
        await _load();
        if (mounted) setState(() => _isRecordingPayment = false);
        return;
      }
      final result = await AppRepositories
          .negativeBalanceApprovalWorkflowService
          .submitSupplierPayment(requester: user, draft: draft);
      if (!mounted) return;
      if (result.isPending) {
        final request = result.request!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إنشاء طلب الموافقة ${request.id}. لم يُنفذ السداد بعد. '
              'الرصيد ${MoneyUtils.formatPiastersAsEgp(request.balanceAtRequestQirsh)}، '
              'والعجز ${MoneyUtils.formatPiastersAsEgp(request.deficitAtRequestQirsh)}.',
            ),
          ),
        );
      } else {
        await _load();
      }
    } catch (e) {
      if (!mounted) return;
      String message = 'تعذر تسجيل الدفع. تأكد من صحة البيانات.';
      if (e is StateError) {
        final msg = e.message;
        if (msg.contains('balance changed')) {
          message = 'تغيّر رصيد المورد أثناء الدفع. أعد المحاولة.';
        } else if (msg.contains('overpayment requires') ||
            msg.contains('approval')) {
          message = 'يجب اختيار حساب مالي وموافقة المالك لتسجيل السلفة.';
        } else if (msg.contains('already processed')) {
          message = 'تم تسجيل هذا الدفع مسبقاً.';
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _isRecordingPayment = false);
    }
  }

  Widget _buildContent(TextTheme textTheme) {
    final statement = _statement!;
    final user = AuthScope.of(context).state.user;
    final canRecordPayment = user?.permissions.canCreateSupplierPayment == true;

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
                    FilledButton.icon(
                      onPressed: canRecordPayment && !_isRecordingPayment
                          ? _recordPayment
                          : null,
                      icon: _isRecordingPayment
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.payments_rounded),
                      label: Text(_isRecordingPayment
                          ? 'جاري التسجيل...'
                          : 'تسجيل دفعة'),
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
      SupplierAccountEntryType.advanceApplication =>
        Icons.account_balance_wallet_rounded,
      SupplierAccountEntryType.advanceApplicationReversal => Icons.undo_rounded,
      SupplierAccountEntryType.advanceRefundReversal => Icons.undo_rounded,
      SupplierAccountEntryType.paymentCancellation => Icons.undo_rounded,
      SupplierAccountEntryType.openingBalance => Icons.account_balance_rounded,
    };
    final label = switch (entry.type) {
      SupplierAccountEntryType.purchase => 'مشتريات',
      SupplierAccountEntryType.payment => 'دفعة للمورد',
      SupplierAccountEntryType.paymentCancellation => 'عكس دفعة للمورد',
      SupplierAccountEntryType.openingBalance => 'رصيد افتتاحي',
      SupplierAccountEntryType.advanceApplication => 'تطبيق سلفة المورد',
      SupplierAccountEntryType.advanceApplicationReversal =>
        'عكس تطبيق سلفة المورد',
      SupplierAccountEntryType.advanceRefundReversal =>
        'عكس استرداد سلفة من المورد',
    };
    final amountText = switch (entry.type) {
      SupplierAccountEntryType.purchase ||
      SupplierAccountEntryType.openingBalance ||
      SupplierAccountEntryType.paymentCancellation =>
        MoneyUtils.formatPiastersAsEgp(entry.debitAmountQirsh),
      SupplierAccountEntryType.payment =>
        MoneyUtils.formatPiastersAsEgp(entry.creditAmountQirsh),
      SupplierAccountEntryType.advanceApplication =>
        MoneyUtils.formatPiastersAsEgp(entry.creditAmountQirsh),
      SupplierAccountEntryType.advanceApplicationReversal =>
        MoneyUtils.formatPiastersAsEgp(entry.debitAmountQirsh),
      SupplierAccountEntryType.advanceRefundReversal =>
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
            style: const TextStyle(fontSize: 11, color: AppColors.mutedText)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
