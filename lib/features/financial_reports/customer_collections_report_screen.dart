import 'dart:io';
import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_models.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_service.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/features/exports/financial_report_csv_exporter.dart';
import 'package:grain_warehouse_erp_lite/features/exports/financial_report_pdf_builder.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class _CustomerCollectionLookupAdapter
    implements CustomerCollectionReportLookup {
  _CustomerCollectionLookupAdapter({
    required CustomerAccountRepository customerAccountRepo,
    required CustomerDataRepository customerRepo,
    required FinancialAccountRepository financialRepo,
  })  : _customerAccountRepo = customerAccountRepo,
        _customerRepo = customerRepo,
        _financialRepo = financialRepo;

  final CustomerAccountRepository _customerAccountRepo;
  final CustomerDataRepository _customerRepo;
  final FinancialAccountRepository _financialRepo;

  Map<String, String>? _collectionCustomerMap;
  Map<String, String>? _advanceRefundCustomerMap;
  Map<String, FinancialAccountEntry>? _entryMap;

  Future<Map<String, String>> _getCollectionCustomerMap() async {
    if (_collectionCustomerMap != null) return _collectionCustomerMap!;
    final collections = await _customerAccountRepo.listCollections();
    _collectionCustomerMap = {
      for (final c in collections) c.id: c.customerId,
    };
    return _collectionCustomerMap!;
  }

  Future<Map<String, FinancialAccountEntry>> _getEntryMap() async {
    if (_entryMap != null) return _entryMap!;
    final collections = await _customerAccountRepo.listCollections();
    final entryMap = <String, FinancialAccountEntry>{};
    final seenAccounts = <String>{};
    for (final c in collections) {
      final faId = c.financialAccountId;
      if (faId == null || faId.trim().isEmpty) continue;
      if (!seenAccounts.add(faId)) continue;
      try {
        final statement = await _financialRepo.statementForAccount(faId);
        for (final line in statement.lines) {
          entryMap[line.entry.id] = line.entry;
        }
      } catch (_) {}
    }
    _entryMap = entryMap;
    return _entryMap!;
  }

  @override
  Future<String?> customerIdForCollection(String collectionId) async {
    final map = await _getCollectionCustomerMap();
    return map[collectionId];
  }

  @override
  Future<String?> customerIdForReversalEntry(
      FinancialAccountEntry reversalEntry) async {
    if (reversalEntry.reversalOf == null) return null;
    final entries = await _getEntryMap();
    final original = entries[reversalEntry.reversalOf];
    if (original == null) return null;
    if (original.sourceType == FinancialAccountEntrySource.customerCollection) {
      return customerIdForCollection(original.sourceDocumentId);
    }
    return null;
  }

  @override
  Future<String?> customerIdForAdvanceRefundReversalEntry(
      FinancialAccountEntry reversalEntry) async {
    if (reversalEntry.reversalOf == null) return null;
    final entries = await _getEntryMap();
    final original = entries[reversalEntry.reversalOf];
    if (original == null) return null;
    return _customerIdForAdvanceRefund(original.sourceDocumentId);
  }

  Future<String?> _customerIdForAdvanceRefund(String operationRequestId) async {
    if (_advanceRefundCustomerMap == null) {
      final refunds = await _customerAccountRepo.listAdvanceRefunds();
      _advanceRefundCustomerMap = {
        for (final r in refunds) r.operationRequestId: r.customerId,
      };
    }
    return _advanceRefundCustomerMap![operationRequestId];
  }

  @override
  Future<String> customerNameForId(String customerId) async {
    final customers = await _customerRepo.listCustomers();
    for (final c in customers) {
      if (c.id == customerId) return c.name;
    }
    return 'غير محدد';
  }
}

class CustomerCollectionsReportScreen extends StatefulWidget {
  const CustomerCollectionsReportScreen({super.key});

  @override
  State<CustomerCollectionsReportScreen> createState() =>
      _CustomerCollectionsReportScreenState();
}

class _CustomerCollectionsReportScreenState
    extends State<CustomerCollectionsReportScreen> {
  late final FinancialReportService _service;
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _accountIdFilter;
  CustomerCollectionsByAccountReport? _report;
  List<FinancialAccount> _accounts = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final lookup = _CustomerCollectionLookupAdapter(
      customerAccountRepo: AppRepositories.customerAccountRepository,
      customerRepo: AppRepositories.customerRepository,
      financialRepo: AppRepositories.financialAccountRepository,
    );
    _service = FinancialReportService(
      repository: AppRepositories.financialAccountRepository,
      customerLookup: lookup,
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
      _report = await _service.getCustomerCollectionsByAccount(
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
      appBar: AppBar(
        title: const Text('تحصيلات العملاء حسب الحساب'),
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
          else if (_report!.details.isEmpty)
            const PremiumCard(
              child: Text('لا توجد تحصيلات في الفترة المحددة.'),
            )
          else ...[
            _buildSummaryCard(textTheme),
            const SizedBox(height: 16),
            _buildAccountBreakdownCard(textTheme),
            const SizedBox(height: 16),
            _buildCustomerBreakdownCard(textTheme),
            const SizedBox(height: 16),
            Text('التفاصيل', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._report!.details.map((d) => _buildDetailCard(d, textTheme)),
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
    final r = _report!;
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الإجمالي', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              _summaryItem(
                'إجمالي التحصيلات',
                MoneyUtils.formatPiastersAsEgp(r.totalGrossCollectionsQirsh),
              ),
              _summaryItem(
                'إجمالي المرتجعات',
                MoneyUtils.formatPiastersAsEgp(r.totalReversalsQirsh),
              ),
              _summaryItem(
                'صافي التحصيلات',
                MoneyUtils.formatPiastersAsEgp(r.totalNetCollectionsQirsh),
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

  Widget _buildAccountBreakdownCard(TextTheme textTheme) {
    final accounts = _report!.accountSummaries;
    if (accounts.isEmpty) return const SizedBox.shrink();

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('التحصيلات حسب الحساب', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          ...accounts.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${a.account.name} (${a.account.type.labelAr})',
                    style: textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _summaryItem(
                        'تحصيلات',
                        MoneyUtils.formatPiastersAsEgp(a.grossCollectionsQirsh),
                      ),
                      _summaryItem(
                        'مرتجعات',
                        MoneyUtils.formatPiastersAsEgp(a.reversalsQirsh),
                      ),
                      _summaryItem(
                        'صافي',
                        MoneyUtils.formatPiastersAsEgp(a.netCollectionsQirsh),
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

  Widget _buildCustomerBreakdownCard(TextTheme textTheme) {
    final customers = _report!.customerSummaries;
    if (customers.isEmpty) return const SizedBox.shrink();

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('التحصيلات حسب العميل', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          ...customers.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        c.isUnresolved
                            ? Icons.help_outline_rounded
                            : Icons.person_rounded,
                        size: 16,
                        color: c.isUnresolved ? Colors.orange : null,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          c.customerName,
                          style: textTheme.titleSmall?.copyWith(
                            color: c.isUnresolved ? Colors.orange : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _summaryItem(
                        'تحصيلات',
                        MoneyUtils.formatPiastersAsEgp(c.grossCollectionsQirsh),
                      ),
                      _summaryItem(
                        'مرتجعات',
                        MoneyUtils.formatPiastersAsEgp(c.reversalsQirsh),
                      ),
                      _summaryItem(
                        'صافي',
                        MoneyUtils.formatPiastersAsEgp(c.netCollectionsQirsh),
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
      CustomerCollectionsByAccountDetail detail, TextTheme textTheme) {
    final isReversal = detail.isReversal;
    return PremiumCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isReversal ? Colors.orange : Colors.green).withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isReversal ? Icons.undo_rounded : Icons.arrow_downward_rounded,
              color: isReversal ? Colors.orange : Colors.green,
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
                    Expanded(
                      child: Text(
                        detail.sourceType.labelAr,
                        style: textTheme.titleSmall,
                      ),
                    ),
                    if (detail.isUnresolved)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'عميل غير محدد',
                          style: TextStyle(fontSize: 10, color: Colors.orange),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${detail.customerName} · ${detail.accountName}',
                  style:
                      textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
                ),
                Text(
                  _formatDate(detail.timestamp),
                  style:
                      textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
                ),
              ],
            ),
          ),
          Text(
            MoneyUtils.formatPiastersAsEgp(detail.amountQirsh),
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: isReversal ? Colors.orange[800] : Colors.green[800],
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
      final file = await FinancialReportPdfBuilder
          .buildCustomerCollectionsByAccountReport(report: _report!);
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
      final file = await FinancialReportCsvExporter
          .exportCustomerCollectionsByAccountReport(report: _report!);
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
