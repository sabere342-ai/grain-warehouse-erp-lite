import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_business_logo_query.dart';
import 'package:grain_warehouse_erp_lite/composition/application_scope.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_models.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_service.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';
import 'package:grain_warehouse_erp_lite/features/exports/financial_report_csv_exporter.dart';
import 'package:grain_warehouse_erp_lite/features/exports/financial_report_pdf_builder.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_page_header.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_state_view.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class ExpenseAnalysisReportScreen extends StatefulWidget {
  const ExpenseAnalysisReportScreen({super.key});

  @override
  State<ExpenseAnalysisReportScreen> createState() =>
      _ExpenseAnalysisReportScreenState();
}

class _ExpenseAnalysisReportScreenState
    extends State<ExpenseAnalysisReportScreen> {
  late final FinancialReportService _service;
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _accountIdFilter;
  PaymentMethod? _paymentMethodFilter;
  String _categorySearch = '';
  ExpenseAnalysisReport? _report;
  List<FinancialAccount> _accounts = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _service = FinancialReportService(
      repository: AppRepositories.financialAccountRepository,
      expenseRepository: AppRepositories.expenseRepository,
    );
    _loadAccounts();
    _applyFilters();
  }

  Future<void> _loadAccounts() async {
    final accounts = await AppRepositories.financialAccountRepository
        .listAccounts(includeInactive: true);
    if (mounted) setState(() => _accounts = accounts);
  }

  Future<void> _applyFilters() async {
    setState(() => _loading = true);
    try {
      _report = await _service.expenseAnalysisReport(
        fromDate: _fromDate,
        toDate: _toDate,
        accountIdFilter: _accountIdFilter,
        paymentMethodFilter: _paymentMethodFilter,
        categoryFilter:
            _categorySearch.trim().isEmpty ? null : _categorySearch.trim(),
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
      _accountIdFilter = null;
      _paymentMethodFilter = null;
      _categorySearch = '';
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

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          GhalalPageHeader(
            title: 'تقرير تحليل المصروفات',
            subtitle: 'تحليل المصروفات حسب التصنيف خلال الفترة المحددة.',
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
          if (_loading)
            const GhalalLoadingState(label: 'جاري تحميل التقرير...')
          else if (_report == null)
            GhalalErrorState(
              message: 'تعذر تحميل التقرير.',
              onRetry: _applyFilters,
            )
          else if (_report!.rows.isEmpty)
            const GhalalEmptyState(
              title: 'لا توجد مصروفات',
              message: 'لا توجد مصروفات في الفترة المحددة.',
              icon: Icons.receipt_long_rounded,
            )
          else ...[
            _buildSummaryCard(textTheme),
            const SizedBox(height: AppSpacing.md),
            _buildCategoryBreakdownCard(textTheme),
            const SizedBox(height: AppSpacing.md),
            Text('تفاصيل المصروفات', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._report!.allDetails.map((d) => _buildDetailCard(d, textTheme)),
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
          DropdownButtonFormField<String?>(
            value: _accountIdFilter,
            decoration: const InputDecoration(labelText: 'الحساب المالي'),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('جميع الحسابات'),
              ),
              for (final a in _accounts)
                DropdownMenuItem(
                  value: a.id,
                  child: Text(a.name),
                ),
            ],
            onChanged: (v) {
              setState(() => _accountIdFilter = v);
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<PaymentMethod?>(
            value: _paymentMethodFilter,
            decoration: const InputDecoration(labelText: 'وسيلة الدفع'),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('جميع وسائل الدفع'),
              ),
              for (final pm in PaymentMethod.values)
                DropdownMenuItem(
                  value: pm,
                  child: Text(pm.labelAr),
                ),
            ],
            onChanged: (v) {
              setState(() => _paymentMethodFilter = v);
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'بحث في التصنيف',
              hintText: 'أدخل نص البحث...',
            ),
            initialValue: _categorySearch,
            onChanged: (v) => _categorySearch = v,
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
    final r = _report!;
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الملخص', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              _summaryItem(
                'إجمالي المصروفات',
                MoneyUtils.formatPiastersAsEgp(r.totalQirsh),
              ),
              _summaryItem(
                'عدد المصروفات',
                '${r.grandCount}',
              ),
              _summaryItem(
                'عدد التصنيفات',
                '${r.rows.length}',
              ),
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

  Widget _buildCategoryBreakdownCard(TextTheme textTheme) {
    final rows = _report!.rows;
    if (rows.isEmpty) return const SizedBox.shrink();

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تحليل التصنيفات', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.category,
                          style: textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        '${r.percentageOfTotal.toStringAsFixed(1)}%',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _summaryItem(
                        'الإجمالي',
                        MoneyUtils.formatPiastersAsEgp(r.totalAmountQirsh),
                      ),
                      _summaryItem(
                        'العدد',
                        '${r.count}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(
      ExpenseAnalysisReportDetail detail, TextTheme textTheme) {
    return PremiumCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.receipt_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).colorScheme.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        detail.category,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        detail.accountName,
                        style: textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatDate(detail.date)} · ${detail.paymentMethodLabel}',
                  style:
                      textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
                ),
                if (detail.notes != null && detail.notes!.isNotEmpty)
                  Text(
                    detail.notes!,
                    style: textTheme.bodySmall
                        ?.copyWith(color: AppColors.mutedText),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(
            MoneyUtils.formatPiastersAsEgp(detail.amountQirsh),
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.error,
            ),
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
      final identity =
          await AppRepositories.businessIdentityRepository.loadIdentity();
      Uint8List? logoBytes;
      if (identity.hasLogo && identity.logo != null) {
        final result =
            // ignore: use_build_context_synchronously
            await ApplicationScope.of(context).queries.businessLogo.execute(
                  LoadBusinessLogoQuery(
                    managedFileName: identity.logo!.managedFileName,
                  ),
                );

        logoBytes = result.value;
      }
      final file = await FinancialReportPdfBuilder.buildExpenseAnalysisReport(
          report: _report!, businessIdentity: identity, logoBytes: logoBytes);
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
      final file = await FinancialReportCsvExporter.exportExpenseAnalysisReport(
          report: _report!);
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
