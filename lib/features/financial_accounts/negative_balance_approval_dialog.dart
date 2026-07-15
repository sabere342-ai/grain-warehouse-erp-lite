import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_service.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';

class NegativeBalanceApprovalDialog extends StatefulWidget {
  const NegativeBalanceApprovalDialog({
    super.key,
    required this.authRepository,
    required this.accountName,
    required this.currentBalanceQirsh,
    required this.requestedAmountQirsh,
    required this.operationDescription,
    this.approvalService,
    this.approvalDraft,
  });

  final AuthRepository authRepository;
  final String accountName;
  final int currentBalanceQirsh;
  final int requestedAmountQirsh;
  final String operationDescription;
  final NegativeBalanceApprovalService? approvalService;
  final NegativeBalanceApprovalDraft? approvalDraft;

  static Future<String?> show({
    required BuildContext context,
    required AuthRepository authRepository,
    required String accountName,
    required int currentBalanceQirsh,
    required int requestedAmountQirsh,
    required String operationDescription,
    NegativeBalanceApprovalService? approvalService,
    NegativeBalanceApprovalDraft? approvalDraft,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NegativeBalanceApprovalDialog(
        authRepository: authRepository,
        accountName: accountName,
        currentBalanceQirsh: currentBalanceQirsh,
        requestedAmountQirsh: requestedAmountQirsh,
        operationDescription: operationDescription,
        approvalService: approvalService,
        approvalDraft: approvalDraft,
      ),
    );
  }

  @override
  State<NegativeBalanceApprovalDialog> createState() =>
      _NegativeBalanceApprovalDialogState();
}

class _NegativeBalanceApprovalDialogState
    extends State<NegativeBalanceApprovalDialog> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  int get _projectedBalance =>
      widget.currentBalanceQirsh - widget.requestedAmountQirsh;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: colorScheme.error,
            size: 28,
          ),
          const SizedBox(width: 8),
          const Text('موافقة المالك مطلوبة'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.error.withAlpha(80),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.operationDescription,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildBalanceRow(
                    textTheme,
                    'الرصيد الحالي:',
                    widget.currentBalanceQirsh,
                    AppColors.mutedText,
                  ),
                  const SizedBox(height: 4),
                  _buildBalanceRow(
                    textTheme,
                    'المبلغ المطلوب:',
                    -widget.requestedAmountQirsh,
                    colorScheme.error,
                  ),
                  const Divider(height: 16),
                  _buildBalanceRow(
                    textTheme,
                    'الرصيد المتوقع:',
                    _projectedBalance,
                    _projectedBalance >= 0
                        ? AppColors.mutedText
                        : colorScheme.error,
                    isBold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'الحساب: ${widget.accountName}',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'للموافقة، يرجى تسجيل الدخول بصلاحيات المالك:',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف',
                hintText: '01xxxxxxxxx',
              ),
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'كلمة المرور',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              obscureText: _obscurePassword,
              textDirection: TextDirection.ltr,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withAlpha(80),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: colorScheme.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
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
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('موافقة'),
        ),
      ],
    );
  }

  Widget _buildBalanceRow(
    TextTheme textTheme,
    String label,
    int amount,
    Color color, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.mutedText,
            fontWeight: isBold ? FontWeight.w700 : null,
          ),
        ),
        Text(
          MoneyUtils.formatPiastersAsEgp(amount),
          style: textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (phone.isEmpty) {
      setState(() => _errorMessage = 'أدخل رقم الهاتف.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'أدخل كلمة المرور.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await widget.authRepository.verifyCredentials(
        phone: phone,
        password: password,
      );

      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'بيانات الدخول غير صحيحة.';
        });
        return;
      }

      if (!user.isActive) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'الحساب معطّل.';
        });
        return;
      }

      if (user.role != UserRole.owner) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'الموافقة متاحة للمالك فقط.';
        });
        return;
      }

      final service = widget.approvalService;
      final draft = widget.approvalDraft;
      if (service != null && draft != null) {
        final approvalId = await service.requestApproval(
          draft: NegativeBalanceApprovalDraft(
            requestedByUserId: draft.requestedByUserId,
            approvedByOwnerUserId: user.id,
            accountId: draft.accountId,
            amountQirsh: draft.amountQirsh,
            operationType: draft.operationType,
            sourceDocumentId: draft.sourceDocumentId,
            sourceDocumentType: draft.sourceDocumentType,
            balanceBeforeQirsh: draft.balanceBeforeQirsh,
            expectedBalanceAfterQirsh: draft.expectedBalanceAfterQirsh,
            reason: draft.reason,
            duration: draft.duration,
            authorizationContext: draft.authorizationContext,
          ),
          ownerPhone: phone,
          ownerPassword: password,
        );
        if (mounted) {
          Navigator.of(context).pop(approvalId);
        }
      } else {
        if (mounted) {
          Navigator.of(context).pop(user.id);
        }
      }
    } on Object {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'حدث خطأ أثناء التحقق.';
      });
    }
  }
}
