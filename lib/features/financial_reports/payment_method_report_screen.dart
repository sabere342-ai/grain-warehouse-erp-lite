import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
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

class PaymentMethodReportScreen extends StatefulWidget {
  const PaymentMethodReportScreen({super.key});

  @override
  State<PaymentMethodReportScreen> createState() =>
      _PaymentMethodReportScreenState();
}

class _PaymentMethodReportScreenState extends State<PaymentMethodReportScreen> {
  late final FinancialReportService _service;
  DateTime? _fromDate;
  DateTime? _toDate;
  PaymentMethod? _paymentMethodFilter;
  FinancialAccountEntrySource? _sourceTypeFilter;
  String? _accountIdFilter;
  FinancialAccountEntryDirection? _directionFilter;
  PaymentMethodReport? _report;
  List<FinancialAccount> _accounts = const [];
  bool _loading = false;
  final Set<int> _expandedRows = {};

  @override
  void initState() {
    super.initState();
    _service = FinancialReportService(
        repository: AppRepositories.financialAccountRepository);
    _loadAccounts();
    _applyFilters();
  }

  Future<void> _loadAccounts() async {
    final accounts = await AppRepositories.financialAccountRepository
        .listAccounts(includeInactive: true);
    setState(() => _accounts = accounts);
  }

  Future<void> _applyFilters() async {
    setState(() => _loading = true);
    try {
      _report = await _service.paymentMethodReport(
        fromDate: _fromDate,
        toDate: _toDate,
        paymentMethodFilter: _paymentMethodFilter,
        sourceTypeFilter: _sourceTypeFilter,
        accountIdFilter: _accountIdFilter,
        directionFilter: _directionFilter,
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
      _paymentMethodFilter = null;
      _sourceTypeFilter = null;
      _accountIdFilter = null;
      _directionFilter = null;
      _expandedRows.clear();
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

    final rows = _report?.rows ?? [];

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          GhalalPageHeader(
            title: 'تقرير طرق الدفع',
            subtitle: 'إحصائيات العمليات حسب طريقة الدفع خلال الفترة المحددة.',
            icon: Icons.payments_rounded,
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
          else if (rows.isEmpty)
            const GhalalEmptyState(
              title: 'لا توجد عمليات',
              message: 'لا توجد عمليات في الفترة المحددة.',
              icon: Icons.payments_rounded,
            )
          else ...[
            _buildSummaryCard(textTheme),
            const SizedBox(height: AppSpacing.md),
            ...rows.asMap().entries.map(
                  (entry) =>
                      _buildMethodCard(entry.key, entry.value, textTheme),
                ),
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
          Row(
            children: [
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
              const SizedBox(width: 8),
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
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _accountIdFilter,
                  decoration: const InputDecoration(labelText: 'الحساب المالي'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('الكل'),
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
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<FinancialAccountEntryDirection?>(
                  value: _directionFilter,
                  decoration: const InputDecoration(labelText: 'الاتجاه'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('الكل'),
                    ),
                    for (final dir in FinancialAccountEntryDirection.values)
                      DropdownMenuItem(
                        value: dir,
                        child: Text(dir.labelAr),
                      ),
                  ],
                  onChanged: (v) {
                    setState(() => _directionFilter = v);
                  },
                ),
              ),
            ],
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
          Text('الإجمالي', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              _summaryItem('إجمالي الوارد',
                  MoneyUtils.formatPiastersAsEgp(_report!.totalInflowsQirsh)),
              _summaryItem('إجمالي الصادر',
                  MoneyUtils.formatPiastersAsEgp(_report!.totalOutflowsQirsh)),
              _summaryItem(
                  'الصافي',
                  MoneyUtils.formatPiastersAsEgp(
                      _report!.totalNetMovementQirsh)),
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

  Widget _buildMethodCard(
      int index, PaymentMethodReportRow row, TextTheme textTheme) {
    final isExpanded = _expandedRows.contains(index);
    final netColor =
        row.netMovementQirsh >= 0 ? Colors.green[800] : Colors.red[800];

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedRows.remove(index);
                } else {
                  _expandedRows.add(index);
                }
              });
            },
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.displayName, style: textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        '${row.operationCount} عملية',
                        style: textTheme.bodySmall
                            ?.copyWith(color: AppColors.mutedText),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      MoneyUtils.formatPiastersAsEgp(row.netMovementQirsh),
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: netColor,
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: AppColors.mutedText,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          Row(
            children: [
              _rowItem('وارد',
                  MoneyUtils.formatPiastersAsEgp(row.totalInflowsQirsh)),
              _rowItem('صادر',
                  MoneyUtils.formatPiastersAsEgp(row.totalOutflowsQirsh)),
              _rowItem(
                  'صافي', MoneyUtils.formatPiastersAsEgp(row.netMovementQirsh)),
            ],
          ),
          if (isExpanded && row.bySourceType.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('تفاصيل حسب نوع المصدر',
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedText,
                )),
            const SizedBox(height: 8),
            ...row.bySourceType.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key.labelAr,
                        style: textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      MoneyUtils.formatPiastersAsEgp(entry.value),
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rowItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppColors.mutedText)),
          const SizedBox(height: 2),
          Text(value,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
        logoBytes = await AppRepositories.businessIdentityRepository
            .loadLogoBytes(identity.logo!.managedFileName);
      }
      final file = await FinancialReportPdfBuilder.buildPaymentMethodReport(
        report: _report!,
        businessIdentity: identity,
        logoBytes: logoBytes,
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
      final file = await FinancialReportCsvExporter.exportPaymentMethodReport(
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
