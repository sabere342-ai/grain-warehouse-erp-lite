import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_controller.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';
import 'package:grain_warehouse_erp_lite/features/financial_accounts/financial_account_statement_screen.dart';
import 'package:grain_warehouse_erp_lite/features/financial_accounts/financial_transfers_screen.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_page_header.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_state_view.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_status_badge.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class FinancialAccountsScreen extends StatefulWidget {
  const FinancialAccountsScreen({super.key, this.controller});

  final FinancialAccountController? controller;

  @override
  State<FinancialAccountsScreen> createState() =>
      _FinancialAccountsScreenState();
}

class _FinancialAccountsScreenState extends State<FinancialAccountsScreen> {
  late final FinancialAccountController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        FinancialAccountController(
            repository: AppRepositories.financialAccountRepository);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = AuthScope.of(context).state.user;
      if (user != null) {
        _controller.loadAccounts(user);
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
      return const PremiumCard(
        child: Text('يجب تسجيل الدخول لعرض الحسابات المالية.'),
      );
    }

    final isOwner = user.role == UserRole.owner;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final summaries = _controller.balances;
        final totalBalance = summaries.fold<int>(
          0,
          (sum, s) => sum + s.currentBalanceQirsh,
        );

        return ListView(
          children: [
            GhalalPageHeader(
              title: 'الحسابات المالية',
              subtitle: 'إدارة الخزائن والحسابات البنكية والمحافظ الإلكترونية.',
              icon: Icons.account_balance_wallet_rounded,
              actions: [
                if (isOwner)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                FinancialTransfersScreen(user: user))),
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text('تحويل مالي'),
                  ),
                if (isOwner)
                  FilledButton.icon(
                    onPressed: () =>
                        _showCreateAccountDialog(context, user: user),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('إضافة حساب'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_controller.errorMessage != null)
              GhalalErrorState(
                message: _controller.errorMessage!,
                onRetry: () => _controller.loadAccounts(user),
              )
            else ...[
              PremiumCard(
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'الرصيد الإجمالي: ${MoneyUtils.formatPiastersAsEgp(totalBalance)}',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_controller.isLoading)
                const GhalalLoadingState(
                    label: 'جاري تحميل الحسابات المالية...')
              else if (summaries.isEmpty)
                const GhalalEmptyState(
                  title: 'لا توجد حسابات مالية',
                  message: 'أضف خزينة أو حسابًا بنكيًا أو محفظة للبدء.',
                  icon: Icons.account_balance_wallet_outlined,
                )
              else
                ...summaries.map(
                  (summary) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AccountCard(
                      summary: summary,
                      isOwner: isOwner,
                      onToggleActive: () => _toggleActive(
                        context,
                        user: user,
                        account: summary.account,
                      ),
                      onViewStatement: () => _viewStatement(
                        context,
                        user: user,
                        accountId: summary.account.id,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _showCreateAccountDialog(
    BuildContext context, {
    required AppUser user,
  }) async {
    final draft = await showDialog<FinancialAccountDraft>(
      context: context,
      builder: (context) => _CreateAccountDialog(createdByUserId: user.id),
    );
    if (draft == null) return;
    await _controller.createAccount(user: user, draft: draft);
  }

  Future<void> _toggleActive(
    BuildContext context, {
    required AppUser user,
    required FinancialAccount account,
  }) async {
    if (account.isActive) {
      await _controller.deactivateAccount(user: user, accountId: account.id);
    } else {
      await _controller.reactivateAccount(user: user, accountId: account.id);
    }
  }

  void _viewStatement(
    BuildContext context, {
    required AppUser user,
    required String accountId,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FinancialAccountStatementScreen(
          accountId: accountId,
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.summary,
    required this.isOwner,
    required this.onToggleActive,
    required this.onViewStatement,
  });

  final FinancialAccountBalanceSummary summary;
  final bool isOwner;
  final VoidCallback onToggleActive;
  final VoidCallback onViewStatement;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final account = summary.account;
    final balanceColor = summary.currentBalanceQirsh >= 0
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).colorScheme.error;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final accountIdentity = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.type.iconEmoji,
                      style: const TextStyle(fontSize: AppIconSizes.md)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(account.name, style: textTheme.titleLarge),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          account.type.labelAr,
                          style: textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        GhalalStatusBadge(
                          label: account.isActive ? 'نشط' : 'معطّل',
                          icon: account.isActive
                              ? Icons.check_circle_rounded
                              : Icons.block_rounded,
                          tone: account.isActive
                              ? GhalalStatusTone.success
                              : GhalalStatusTone.error,
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final amount = Semantics(
                label:
                    'رصيد الحساب ${MoneyUtils.formatPiastersAsEgp(summary.currentBalanceQirsh)}',
                child: Text(
                  MoneyUtils.formatPiastersAsEgp(
                    summary.currentBalanceQirsh,
                  ),
                  textDirection: TextDirection.ltr,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: balanceColor,
                  ),
                ),
              );
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    accountIdentity,
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: amount,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: accountIdentity),
                  const SizedBox(width: AppSpacing.md),
                  amount,
                ],
              );
            },
          ),
          if (account.referenceInfo != null || account.notes != null) ...[
            const SizedBox(height: 8),
            if (account.referenceInfo != null)
              Text(
                'مرجع: ${account.referenceInfo}',
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            if (account.notes != null)
              Text(
                account.notes!,
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              TextButton.icon(
                onPressed: onViewStatement,
                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                label: const Text('كشف حساب'),
              ),
              if (isOwner)
                TextButton.icon(
                  onPressed: onToggleActive,
                  icon: Icon(
                    account.isActive
                        ? Icons.block_rounded
                        : Icons.check_circle_rounded,
                    size: 18,
                  ),
                  label: Text(account.isActive ? 'تعطيل' : 'تنشيط'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateAccountDialog extends StatefulWidget {
  const _CreateAccountDialog({required this.createdByUserId});

  final String createdByUserId;

  @override
  State<_CreateAccountDialog> createState() => _CreateAccountDialogState();
}

class _CreateAccountDialogState extends State<_CreateAccountDialog> {
  final _nameController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  FinancialAccountType _selectedType = FinancialAccountType.treasury;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة حساب مالي'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'اسم الحساب'),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<FinancialAccountType>(
              value: _selectedType,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'نوع الحساب'),
              items: FinancialAccountType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text('${type.iconEmoji} ${type.labelAr}'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedType = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _referenceController,
              decoration: const InputDecoration(
                labelText: 'معلومات المرجع (اختياري)',
                hintText: 'رقم الحساب، فرع البنك...',
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration:
                  const InputDecoration(labelText: 'ملاحظات (اختيارية)'),
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
        FilledButton(onPressed: _submit, child: const Text('إضافة')),
      ],
    );
  }

  void _submit() {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'أدخل اسم الحساب.');
      return;
    }
    Navigator.of(context).pop(
      FinancialAccountDraft(
        name: _nameController.text.trim(),
        type: _selectedType,
        referenceInfo: _referenceController.text,
        notes: _notesController.text,
        createdByUserId: widget.createdByUserId,
      ),
    );
  }
}
