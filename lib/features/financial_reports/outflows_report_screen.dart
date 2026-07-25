import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
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

class OutflowsReportScreen extends StatefulWidget {
  const OutflowsReportScreen({super.key});

  @override
  State<OutflowsReportScreen> createState() => _OutflowsReportScreenState();
}

class _OutflowsReportScreenState extends State<OutflowsReportScreen> {
  late final FinancialReportService _service;
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _accountIdFilter;
  FlowReport? _report;
  List<FinancialAccount> _accounts = const [];
  bool _loading = false;
  final Set<int> _expandedBreakdown = {};

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
      _report = await _service.outflowsReport(
        fromDate: _fromDate,
        toDate: _toDate,
        accountIdFilter: _accountIdFilter,
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
      _expandedBreakdown.clear();
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

    final entries = _report?.entries ?? [];

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          GhalalPageHeader(
            title: 'تقرير التدفقات الخارجة',
            subtitle: 'جميع الحركات المالية الصادرة خلال الفترة المحددة.',
            icon: Icons.arrow_upward_rounded,
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
          else if (entries.isEmpty)
            const GhalalEmptyState(
              title: 'لا توجد تدفقات خارجة',
              message: 'لا توجد حركات مالية صادرة في الفترة المحددة.',
              icon: Icons.arrow_upward_rounded,
            )
          else ...[
            _buildSummaryCard(textTheme),
            const SizedBox(height: AppSpacing.md),
            _buildBreakdownCard(textTheme),
            const SizedBox(height: AppSpacing.md),
            ...entries.map((e) => _buildEntryCard(e, textTheme)),
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
              _summaryItem('إجمالي التدفقات الخارجة',
                  MoneyUtils.formatPiastersAsEgp(_report!.totalQirsh)),
              _summaryItem('عدد الحركات', '${_report!.entries.length}'),
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

  Widget _buildBreakdownCard(TextTheme textTheme) {
    final breakdown = _report!.sourceBreakdown;
    if (breakdown.isEmpty) return const SizedBox.shrink();

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('التصنيف حسب المصدر', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          ...breakdown.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.key.labelAr,
                      style: textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    MoneyUtils.formatPiastersAsEgp(entry.value),
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(FlowReportEntry entry, TextTheme textTheme) {
    return PremiumCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.arrow_upward_rounded,
                color: Colors.red, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.source.labelAr, style: textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${entry.accountName} · ${_formatDate(entry.timestamp)}',
                  style:
                      textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
                ),
                if (entry.description != null &&
                    entry.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.description!,
                    style: textTheme.bodySmall
                        ?.copyWith(color: AppColors.mutedText),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Text(
            MoneyUtils.formatPiastersAsEgp(entry.amountQirsh),
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.red[800],
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
        logoBytes = await AppRepositories.businessIdentityRepository
            .loadLogoBytes(identity.logo!.managedFileName);
      }
      final accountLabel = _accountIdFilter != null
          ? _accounts
              .where((a) => a.id == _accountIdFilter)
              .map((a) => a.name)
              .firstOrNull
          : null;
      final file = await FinancialReportPdfBuilder.buildOutflowsReport(
        report: _report!,
        accountLabel: accountLabel,
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
      final file = await FinancialReportCsvExporter.exportOutflowsReport(
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
