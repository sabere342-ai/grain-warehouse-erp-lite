import 'dart:io';
import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_models.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_service.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/features/exports/financial_report_csv_exporter.dart';
import 'package:grain_warehouse_erp_lite/features/exports/financial_report_pdf_builder.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_page_header.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_state_view.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class AccountStatementReportScreen extends StatefulWidget {
  const AccountStatementReportScreen({super.key});

  @override
  State<AccountStatementReportScreen> createState() =>
      _AccountStatementReportScreenState();
}

class _AccountStatementReportScreenState
    extends State<AccountStatementReportScreen> {
  late final FinancialReportService _service;
  String? _selectedAccountId;
  DateTime? _fromDate;
  DateTime? _toDate;
  FinancialAccountEntrySource? _sourceTypeFilter;
  PaymentMethod? _paymentMethodFilter;
  String? _reversalFilter;
  AccountStatementReport? _report;
  List<FinancialAccount> _accounts = const [];
  bool _loading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _service = FinancialReportService(
        repository: AppRepositories.financialAccountRepository);
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await AppRepositories.financialAccountRepository
        .listAccounts(includeInactive: true);
    setState(() => _accounts = accounts);
  }

  Future<void> _applyFilters() async {
    if (_selectedAccountId == null) return;
    setState(() => _loading = true);
    try {
      _report = await _service.accountStatementReport(
        accountId: _selectedAccountId!,
        fromDate: _fromDate,
        toDate: _toDate,
        sourceTypeFilter: _sourceTypeFilter,
        paymentMethodFilter: _paymentMethodFilter,
        reversalFilter: _reversalFilter,
      );
    } catch (e) {
      _report = null;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _resetFilters() {
    setState(() {
      _fromDate = null;
      _toDate = null;
      _sourceTypeFilter = null;
      _paymentMethodFilter = null;
      _reversalFilter = null;
      _searchQuery = '';
      _report = null;
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).state.user;
    final textTheme = Theme.of(context).textTheme;

    if (user == null || !user.permissions.canViewFinancialReports) {
      return const Scaffold(
        body: Center(child: Text('ليس لديك صلاحية عرض التقارير المالية.')),
      );
    }

    final filteredLines = _report?.lines.where((line) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery;
      if (line.entry.sourceDocumentId.contains(query)) return true;
      if (line.entry.sourceDocumentNumber != null &&
          line.entry.sourceDocumentNumber!.contains(query)) {
        return true;
      }
      if (line.entry.note != null && line.entry.note!.contains(query)) {
        return true;
      }
      return false;
    }).toList();

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          GhalalPageHeader(
            title: 'كشف حساب مالي',
            subtitle: 'عرض حركات حساب مالي محدد مع الرصيد الجاري.',
            icon: Icons.receipt_long_rounded,
            onBack: () => Navigator.of(context).maybePop(),
            actions: [
              if (user.permissions.canExportFinancialReports) ...[
                OutlinedButton.icon(
                  onPressed: _report != null ? _exportPdf : null,
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('PDF'),
                ),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _report != null ? _exportCsv : null,
                  icon: const Icon(Icons.table_chart_rounded),
                  label: const Text('CSV'),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildFilters(textTheme),
          const SizedBox(height: AppSpacing.md),
          if (_selectedAccountId == null)
            const GhalalEmptyState(
              title: 'اختر حساباً مالياً',
              message: 'اختر حساباً مالياً من الفلاتر أعلاه لعرض كشف الحساب.',
              icon: Icons.account_balance_rounded,
            )
          else if (_loading)
            const GhalalLoadingState(label: 'جاري تحميل التقرير...')
          else if (_report == null)
            GhalalErrorState(
              message: 'تعذر تحميل التقرير.',
              onRetry: _applyFilters,
            )
          else if (filteredLines == null || filteredLines.isEmpty)
            GhalalEmptyState(
              title: 'لا توجد بيانات',
              message:
                  'لا توجد حركات${_searchQuery.isNotEmpty ? ' تطابق البحث' : ''} في الفترة المحددة.',
              icon: Icons.receipt_long_rounded,
            )
          else ...[
            _buildSummaryCard(textTheme),
            const SizedBox(height: AppSpacing.md),
            ...filteredLines.map((line) => _buildEntryCard(line, textTheme)),
          ],
        ],
      ),
    );
  }

  Widget _buildFilters(TextTheme textTheme) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الفلاتر', style: textTheme.titleMedium),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedAccountId,
            decoration: const InputDecoration(
              labelText: 'الحساب المالي *',
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('اختر حساباً'),
              ),
              for (final a in _accounts)
                DropdownMenuItem(
                  value: a.id,
                  child: Text('${a.type.iconEmoji} ${a.name}'),
                ),
            ],
            onChanged: (v) {
              setState(() => _selectedAccountId = v);
              if (v != null) _applyFilters();
            },
          ),
          const SizedBox(height: 12),
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
              const SizedBox(width: 8),
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
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<FinancialAccountEntrySource?>(
                  value: _sourceTypeFilter,
                  decoration: const InputDecoration(labelText: 'نوع المصدر'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('الكل'),
                    ),
                    for (final source in FinancialAccountEntrySource.values)
                      DropdownMenuItem(
                        value: source,
                        child: Text(source.labelAr),
                      ),
                  ],
                  onChanged: (v) {
                    setState(() => _sourceTypeFilter = v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<PaymentMethod?>(
                  value: _paymentMethodFilter,
                  decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('الكل'),
                    ),
                    for (final method in PaymentMethod.values)
                      DropdownMenuItem(
                        value: method,
                        child: Text(method.labelAr),
                      ),
                  ],
                  onChanged: (v) {
                    setState(() => _paymentMethodFilter = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            value: _reversalFilter,
            decoration: const InputDecoration(labelText: 'حالة العكس'),
            items: const [
              DropdownMenuItem(
                value: null,
                child: Text('الكل'),
              ),
              DropdownMenuItem(
                value: 'original',
                child: Text('أصلي فقط'),
              ),
              DropdownMenuItem(
                value: 'reversal',
                child: Text('عكس فقط'),
              ),
            ],
            onChanged: (v) {
              setState(() => _reversalFilter = v);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              labelText: 'بحث برقم المستند أو الملاحظة',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(
                onPressed: _applyFilters,
                child: const Text('تطبيق'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _resetFilters,
                child: const Text('إعادة تعيين'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(TextTheme textTheme) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_report!.account.type.iconEmoji} ${_report!.account.name}',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _summaryItem('الرصيد الافتتاحي',
                  MoneyUtils.formatPiastersAsEgp(_report!.openingBalanceQirsh)),
              _summaryItem('عدد الحركات', '${_report!.lines.length}'),
              _summaryItem('الرصيد الختامي',
                  MoneyUtils.formatPiastersAsEgp(_report!.closingBalanceQirsh)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.mutedText)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildEntryCard(AccountStatementReportLine line, TextTheme textTheme) {
    final entry = line.entry;
    final isReversal = entry.reversalOf != null;
    final signedAmount = entry.signedAmountQirsh;
    final amountColor = signedAmount >= 0 ? Colors.green[800] : Colors.red[800];

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      entry.sourceType.labelAr,
                      style: textTheme.titleSmall,
                    ),
                    if (isReversal) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'عكس',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange[800],
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                _formatDate(entry.effectiveDate),
                style:
                    textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entry.sourceDocumentNumber != null)
                      Text(
                        'رقم المستند: ${entry.sourceDocumentNumber}',
                        style: textTheme.bodySmall
                            ?.copyWith(color: AppColors.mutedText),
                      ),
                    if (entry.paymentMethod != null)
                      Text(
                        'طريقة الدفع: ${entry.paymentMethod!.labelAr}',
                        style: textTheme.bodySmall
                            ?.copyWith(color: AppColors.mutedText),
                      ),
                    if (entry.note != null && entry.note!.isNotEmpty)
                      Text(
                        entry.note!,
                        style: textTheme.bodySmall
                            ?.copyWith(color: AppColors.mutedText),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${signedAmount >= 0 ? '+' : ''}${MoneyUtils.formatPiastersAsEgp(signedAmount)}',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'الرصيد: ${MoneyUtils.formatPiastersAsEgp(line.runningBalanceQirsh)}',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
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
    }
  }

  Future<void> _exportPdf() async {
    if (_report == null) return;
    try {
      final file = await FinancialReportPdfBuilder.buildAccountStatementReport(
        report: _report!,
      );
      await _showExportResult(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر إنشاء ملف PDF.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportCsv() async {
    if (_report == null) return;
    try {
      final file =
          await FinancialReportCsvExporter.exportAccountStatementReport(
        report: _report!,
      );
      await _showExportResult(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر إنشاء ملف CSV.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showExportResult(File file) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم حفظ الملف بنجاح.\n${file.path}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}
