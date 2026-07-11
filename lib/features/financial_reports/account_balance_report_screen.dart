import 'dart:io';
import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_models.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_service.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/features/exports/financial_report_pdf_builder.dart';
import 'package:grain_warehouse_erp_lite/features/exports/financial_report_csv_exporter.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class AccountBalanceReportScreen extends StatefulWidget {
  const AccountBalanceReportScreen({super.key});

  @override
  State<AccountBalanceReportScreen> createState() =>
      _AccountBalanceReportScreenState();
}

class _AccountBalanceReportScreenState
    extends State<AccountBalanceReportScreen> {
  late final FinancialReportService _service;
  DateTime? _fromDate;
  DateTime? _toDate;
  FinancialAccountType? _typeFilter;
  String? _accountIdFilter;
  AccountBalanceReport? _report;
  List<FinancialAccount> _accounts = const [];
  bool _loading = false;
  String _searchQuery = '';

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
      _report = await _service.accountBalanceReport(
        fromDate: _fromDate,
        toDate: _toDate,
        typeFilter: _typeFilter,
        accountIdFilter: _accountIdFilter,
        includeInactive: true,
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
      _typeFilter = null;
      _accountIdFilter = null;
      _searchQuery = '';
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

    final filteredRows = _report?.rows.where((row) {
      if (_searchQuery.isEmpty) return true;
      return row.account.name.contains(_searchQuery);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('أرصدة الحسابات'),
        actions: [
          if (user.permissions.canExportFinancialReports) ...[
            IconButton(
              tooltip: 'تصدير PDF',
              onPressed: _report != null ? _exportPdf : null,
              icon: const Icon(Icons.picture_as_pdf_rounded),
            ),
            IconButton(
              tooltip: 'تصدير CSV',
              onPressed: _report != null ? _exportCsv : null,
              icon: const Icon(Icons.table_chart_rounded),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFilters(textTheme),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_report == null)
            const PremiumCard(child: Text('تعذر تحميل التقرير.'))
          else if (filteredRows == null || filteredRows.isEmpty)
            PremiumCard(
              child: Text(
                'لا توجد حسابات${_searchQuery.isNotEmpty ? ' تطابق البحث' : ''}.',
              ),
            )
          else ...[
            _buildSummaryCard(textTheme),
            const SizedBox(height: 16),
            ...filteredRows.map((row) => _buildRowCard(row, textTheme)),
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
                child: DropdownButtonFormField<FinancialAccountType?>(
                  value: _typeFilter,
                  decoration: const InputDecoration(labelText: 'نوع الحساب'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('الكل'),
                    ),
                    for (final type in FinancialAccountType.values)
                      DropdownMenuItem(
                        value: type,
                        child: Text(type.labelAr),
                      ),
                  ],
                  onChanged: (v) {
                    setState(() => _typeFilter = v);
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _accountIdFilter,
                  decoration: const InputDecoration(labelText: 'حساب محدد'),
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
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              labelText: 'بحث باسم الحساب',
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
          Text('الإجمالي', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              _summaryItem('الرصيد الافتتاحي',
                  MoneyUtils.formatPiastersAsEgp(_report!.totalOpeningQirsh)),
              _summaryItem('الوارد',
                  MoneyUtils.formatPiastersAsEgp(_report!.totalInflowsQirsh)),
              _summaryItem('الصادر',
                  MoneyUtils.formatPiastersAsEgp(_report!.totalOutflowsQirsh)),
              _summaryItem(
                  'الصافي',
                  MoneyUtils.formatPiastersAsEgp(
                      _report!.totalNetMovementQirsh)),
              _summaryItem('الرصيد الختامي',
                  MoneyUtils.formatPiastersAsEgp(_report!.totalClosingQirsh)),
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

  Widget _buildRowCard(AccountBalanceReportRow row, TextTheme textTheme) {
    final closingColor =
        row.closingBalanceQirsh >= 0 ? Colors.green[800] : Colors.red[800];

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(row.account.type.iconEmoji,
                  style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.account.name, style: textTheme.titleSmall),
                    Text(
                      '${row.account.type.labelAr} · ${row.account.isActive ? 'نشط' : 'معطّل'}',
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppColors.mutedText),
                    ),
                  ],
                ),
              ),
              Text(
                MoneyUtils.formatPiastersAsEgp(row.closingBalanceQirsh),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: closingColor,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              _rowItem('افتتاحي',
                  MoneyUtils.formatPiastersAsEgp(row.openingBalanceQirsh)),
              _rowItem('وارد',
                  MoneyUtils.formatPiastersAsEgp(row.totalInflowsQirsh)),
              _rowItem('صادر',
                  MoneyUtils.formatPiastersAsEgp(row.totalOutflowsQirsh)),
              _rowItem(
                  'صافي', MoneyUtils.formatPiastersAsEgp(row.netMovementQirsh)),
            ],
          ),
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
      _applyFilters();
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
      _applyFilters();
    }
  }

  Future<void> _exportPdf() async {
    if (_report == null) return;
    try {
      final file = await FinancialReportPdfBuilder.buildAccountBalanceReport(
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
      final file = await FinancialReportCsvExporter.exportAccountBalanceReport(
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
