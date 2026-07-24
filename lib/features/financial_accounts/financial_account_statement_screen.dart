import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_controller.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_page_header.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_state_view.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class FinancialAccountStatementScreen extends StatefulWidget {
  const FinancialAccountStatementScreen({
    super.key,
    required this.accountId,
    this.controller,
  });

  final String accountId;
  final FinancialAccountController? controller;

  @override
  State<FinancialAccountStatementScreen> createState() =>
      _FinancialAccountStatementScreenState();
}

class _FinancialAccountStatementScreenState
    extends State<FinancialAccountStatementScreen> {
  late final FinancialAccountController _controller;
  late final bool _ownsController;
  FinancialAccount? _account;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        FinancialAccountController(
            repository: AppRepositories.financialAccountRepository);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = AuthScope.of(context).state.user;
    if (user == null) return;

    try {
      _account = await AppRepositories.financialAccountRepository
          .accountById(widget.accountId);
    } catch (_) {
      _account = null;
    }
    await _controller.loadStatement(
      user,
      widget.accountId,
      fromDate: _fromDate,
      toDate: _toDate,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).state.user;
    final textTheme = Theme.of(context).textTheme;

    if (user == null) {
      return const PremiumCard(
        child: Text('يجب تسجيل الدخول لعرض كشف الحساب.'),
      );
    }

    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final statement = _controller.statement;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              GhalalPageHeader(
                title: 'كشف حساب - ${_account?.name ?? ''}',
                icon: Icons.account_balance_rounded,
                onBack: () => Navigator.of(context).maybePop(),
              ),
              if (_account != null) ...[
                PremiumCard(
                  child: Row(
                    children: [
                      Text(
                        _account!.type.iconEmoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_account!.name, style: textTheme.titleLarge),
                            Text(
                              _account!.type.labelAr,
                              style: textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _pickFromDate,
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        _fromDate != null
                            ? 'من: ${_formatDate(_fromDate!)}'
                            : 'من تاريخ',
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _pickToDate,
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        _toDate != null
                            ? 'إلى: ${_formatDate(_toDate!)}'
                            : 'إلى تاريخ',
                      ),
                    ),
                  ),
                  if (_fromDate != null || _toDate != null)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _fromDate = null;
                          _toDate = null;
                        });
                        _loadData();
                      },
                      child: const Text('مسح'),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              if (_controller.isLoading)
                const GhalalLoadingState(label: 'جاري تحميل كشف الحساب...')
              else if (statement == null)
                GhalalErrorState(
                    message: 'تعذر تحميل كشف الحساب.', onRetry: _loadData)
              else if (statement.lines.isEmpty)
                GhalalEmptyState(
                  title: 'لا توجد حركات مالية',
                  message: _fromDate != null || _toDate != null
                      ? 'لا توجد حركات في الفترة المحددة.'
                      : 'لا توجد حركات مالية مسجلة في هذا الحساب.',
                  icon: Icons.receipt_long_rounded,
                )
              else ...[
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الرصيد الافتتاحي: ${MoneyUtils.formatPiastersAsEgp(statement.openingBalanceQirsh)}',
                        style: textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'الرصيد الحالي: ${MoneyUtils.formatPiastersAsEgp(statement.finalBalanceQirsh)}',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'عدد الحركات: ${statement.lines.length}',
                        style: textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...statement.lines.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: _StatementLineCard(line: line),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickFromDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('ar'),
    );
    if (selected != null) {
      setState(() => _fromDate = selected);
      _loadData();
    }
  }

  Future<void> _pickToDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('ar'),
    );
    if (selected != null) {
      setState(() => _toDate = selected);
      _loadData();
    }
  }

  String _formatDate(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}

class _StatementLineCard extends StatelessWidget {
  const _StatementLineCard({required this.line});

  final FinancialAccountStatementLine line;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final entry = line.entry;
    final isIn = entry.direction == FinancialAccountEntryDirection.inflow;
    final amountColor = isIn ? Colors.green[800] : Colors.red[800];

    return PremiumCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color:
                  isIn ? Colors.green.withAlpha(30) : Colors.red.withAlpha(30),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              isIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: amountColor,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.sourceType.labelAr,
                  style: textTheme.titleSmall,
                ),
                Text(
                  _formatDate(entry.effectiveDate),
                  style: textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (entry.note != null)
                  Text(
                    entry.note!,
                    style: textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (entry.correctionGroup != null)
                  Text(
                    'تصحيح',
                    style: textTheme.labelSmall?.copyWith(
                      color: Colors.orange[800],
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIn ? '+' : '-'}${MoneyUtils.formatPiastersAsEgp(entry.amountQirsh)}',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: amountColor,
                ),
              ),
              Text(
                'الرصيد: ${MoneyUtils.formatPiastersAsEgp(line.runningBalanceQirsh)}',
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}
