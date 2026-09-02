import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_business_logo_query.dart';
import 'package:grain_warehouse_erp_lite/composition/application_scope.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_models.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_service.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';
import 'package:grain_warehouse_erp_lite/features/exports/financial_report_csv_exporter.dart';
import 'package:grain_warehouse_erp_lite/features/exports/financial_report_pdf_builder.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_page_header.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_state_view.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class _CustomerAdvanceRefundLookupAdapter
    implements CustomerCollectionReportLookup {
  _CustomerAdvanceRefundLookupAdapter({
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
    final refunds = await _customerAccountRepo.listAdvanceRefunds();
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
    for (final refund in refunds) {
      final faId = refund.financialAccountId;
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

class _SupplierSettlementLookupAdapter
    implements SupplierSettlementReportLookup {
  _SupplierSettlementLookupAdapter({
    required SupplierAccountRepository supplierAccountRepo,
    required SupplierDataRepository supplierRepo,
    required FinancialAccountRepository financialRepo,
  })  : _supplierAccountRepo = supplierAccountRepo,
        _supplierRepo = supplierRepo,
        _financialRepo = financialRepo;

  final SupplierAccountRepository _supplierAccountRepo;
  final SupplierDataRepository _supplierRepo;
  final FinancialAccountRepository _financialRepo;

  Map<String, String>? _advanceRefundSupplierMap;
  Map<String, FinancialAccountEntry>? _entryMap;

  Future<Map<String, String>> _getAdvanceRefundSupplierMap() async {
    if (_advanceRefundSupplierMap != null) return _advanceRefundSupplierMap!;
    final refunds = await _supplierAccountRepo.listAdvanceRefunds();
    _advanceRefundSupplierMap = {
      for (final refund in refunds)
        refund.operationRequestId: refund.supplierId,
    };
    return _advanceRefundSupplierMap!;
  }

  Future<Map<String, FinancialAccountEntry>> _getEntryMap() async {
    if (_entryMap != null) return _entryMap!;
    final refunds = await _supplierAccountRepo.listAdvanceRefunds();
    final entryMap = <String, FinancialAccountEntry>{};
    final seenAccounts = <String>{};
    for (final refund in refunds) {
      final faId = refund.financialAccountId;
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
  Future<String?> supplierIdForPayment(String operationRequestId) async {
    final map = await _getAdvanceRefundSupplierMap();
    return map[operationRequestId];
  }

  @override
  Future<String?> supplierIdForReversalEntry(
      FinancialAccountEntry reversalEntry) async {
    if (reversalEntry.reversalOf == null) return null;
    final entries = await _getEntryMap();
    final original = entries[reversalEntry.reversalOf];
    if (original == null) return null;
    if (original.sourceType == FinancialAccountEntrySource.supplierSettlement) {
      return supplierIdForPayment(original.sourceDocumentId);
    }
    return null;
  }

  @override
  Future<String> supplierNameForId(String supplierId) async {
    final suppliers = await _supplierRepo.listSuppliers();
    for (final s in suppliers) {
      if (s.id == supplierId) return s.name;
    }
    return 'مورد غير محدد';
  }
}

class AdvancesAndRefundsReportScreen extends StatefulWidget {
  const AdvancesAndRefundsReportScreen({super.key});

  @override
  State<AdvancesAndRefundsReportScreen> createState() =>
      _AdvancesAndRefundsReportScreenState();
}

class _AdvancesAndRefundsReportScreenState
    extends State<AdvancesAndRefundsReportScreen> {
  late final FinancialReportService _service;
  late final SupplierSettlementReportLookup _supplierLookup;
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _accountIdFilter;
  AdvancesAndRefundsPartyType? _partyTypeFilter;
  String? _entityIdFilter;
  AdvancesAndRefundsReport? _report;
  List<FinancialAccount> _accounts = const [];
  bool _loading = false;

  List<String> _customerNames = const [];
  List<String> _customerIds = const [];
  List<String> _supplierNames = const [];
  List<String> _supplierIds = const [];
  bool _hasLoadedAuthorizedData = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = AuthScope.of(context).state.user;
    if (user == null || !user.permissions.canViewFinancialReports) return;
    if (_hasLoadedAuthorizedData) return;
    _hasLoadedAuthorizedData = true;

    final customerLookup = _CustomerAdvanceRefundLookupAdapter(
      customerAccountRepo: AppRepositories.customerAccountRepository,
      customerRepo: AppRepositories.customerRepository,
      financialRepo: AppRepositories.financialAccountRepository,
    );
    _supplierLookup = _SupplierSettlementLookupAdapter(
      supplierAccountRepo: AppRepositories.supplierAccountRepository,
      supplierRepo: AppRepositories.supplierRepository,
      financialRepo: AppRepositories.financialAccountRepository,
    );
    _service = FinancialReportService(
      repository: AppRepositories.financialAccountRepository,
      customerLookup: customerLookup,
    );
    _loadAccounts();
    _loadEntities();
    _applyFilters();
  }

  Future<void> _loadAccounts() async {
    final accounts = await AppRepositories.financialAccountRepository
        .listAccounts(includeInactive: true);
    if (mounted) setState(() => _accounts = accounts);
  }

  Future<void> _loadEntities() async {
    final customers = await AppRepositories.customerRepository.listCustomers();
    final suppliers = await AppRepositories.supplierRepository.listSuppliers();
    if (mounted) {
      setState(() {
        _customerIds = customers.map((c) => c.id).toList();
        _customerNames = customers.map((c) => c.name).toList();
        _supplierIds = suppliers.map((s) => s.id).toList();
        _supplierNames = suppliers.map((s) => s.name).toList();
      });
    }
  }

  Future<void> _applyFilters() async {
    setState(() => _loading = true);
    try {
      _report = await _service.getAdvancesAndRefundsReport(
        fromDate: _fromDate,
        toDate: _toDate,
        accountIdFilter: _accountIdFilter,
        partyTypeFilter: _partyTypeFilter,
        entityIdFilter: _entityIdFilter,
        supplierLookup: _supplierLookup,
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
      _partyTypeFilter = null;
      _entityIdFilter = null;
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
            title: 'تقرير رد السلف وعكسها',
            subtitle: 'جميع عمليات رد السلف وعكسها خلال الفترة المحددة.',
            icon: Icons.replay_rounded,
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
          else if (_report!.details.isEmpty)
            const GhalalEmptyState(
              title: 'لا توجد عمليات',
              message: 'لا توجد عمليات رد سلف أو عكسها في الفترة المحددة.',
              icon: Icons.replay_rounded,
            )
          else ...[
            _buildSummaryCard(textTheme),
            const SizedBox(height: AppSpacing.md),
            _buildAccountBreakdownCard(textTheme),
            const SizedBox(height: AppSpacing.md),
            _buildCustomerBreakdownCard(textTheme),
            const SizedBox(height: AppSpacing.md),
            _buildSupplierBreakdownCard(textTheme),
            const SizedBox(height: AppSpacing.md),
            Text('التفاصيل', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._report!.details.map((d) => _buildDetailCard(d, textTheme)),
          ],
        ],
      ),
    );
  }

  Widget _buildFilters(TextTheme textTheme) {
    final bool isCustomer =
        _partyTypeFilter == AdvancesAndRefundsPartyType.customer;
    final bool isSupplier =
        _partyTypeFilter == AdvancesAndRefundsPartyType.supplier;

    final entityNames = isCustomer
        ? _customerNames
        : isSupplier
            ? _supplierNames
            : const <String>[];
    final entityIds = isCustomer
        ? _customerIds
        : isSupplier
            ? _supplierIds
            : const <String>[];

    if (_partyTypeFilter != null &&
        _entityIdFilter != null &&
        !entityIds.contains(_entityIdFilter)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _entityIdFilter = null);
      });
    }

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الفلاتر', style: textTheme.titleMedium),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;
              final buttonWidth = isNarrow
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: buttonWidth,
                    child: TextButton.icon(
                      onPressed: _pickFromDate,
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        _fromDate != null
                            ? 'من: ${_formatDate(_fromDate!)}'
                            : 'من تاريخ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: buttonWidth,
                    child: TextButton.icon(
                      onPressed: _pickToDate,
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        _toDate != null
                            ? 'إلى: ${_formatDate(_toDate!)}'
                            : 'إلى تاريخ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              );
            },
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
          DropdownButtonFormField<AdvancesAndRefundsPartyType?>(
            value: _partyTypeFilter,
            decoration: const InputDecoration(labelText: 'الطرف'),
            items: const [
              DropdownMenuItem(
                value: null,
                child: Text('الكل'),
              ),
              DropdownMenuItem(
                value: AdvancesAndRefundsPartyType.customer,
                child: Text('عميل'),
              ),
              DropdownMenuItem(
                value: AdvancesAndRefundsPartyType.supplier,
                child: Text('مورد'),
              ),
            ],
            onChanged: (v) {
              setState(() {
                _partyTypeFilter = v;
                _entityIdFilter = null;
              });
            },
          ),
          if (_partyTypeFilter != null) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: _entityIdFilter,
              decoration: InputDecoration(
                labelText: isCustomer ? 'العميل' : 'المورد',
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('الجميع'),
                ),
                for (int i = 0; i < entityNames.length; i++)
                  DropdownMenuItem(
                    value: entityIds[i],
                    child: Text(entityNames[i]),
                  ),
              ],
              onChanged: (v) {
                setState(() => _entityIdFilter = v);
              },
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _applyFilters,
                child: const Text('تطبيق'),
              ),
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
          Text('رد سلف العملاء',
              style: textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              )),
          const SizedBox(height: 4),
          Row(
            children: [
              _summaryItem(
                'إجمالي',
                MoneyUtils.formatPiastersAsEgp(
                    r.totalCustomerGrossRefundOutflow),
              ),
              _summaryItem(
                'إلغاءات',
                MoneyUtils.formatPiastersAsEgp(r.totalCustomerRefundReversals),
              ),
              _summaryItem(
                'صافي',
                MoneyUtils.formatPiastersAsEgp(r.totalCustomerNetRefundOutflow),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('ردود سلف الموردين',
              style: textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.tertiary,
              )),
          const SizedBox(height: 4),
          Row(
            children: [
              _summaryItem(
                'إجمالي',
                MoneyUtils.formatPiastersAsEgp(
                    r.totalSupplierGrossRefundInflow),
              ),
              _summaryItem(
                'إلغاءات',
                MoneyUtils.formatPiastersAsEgp(r.totalSupplierRefundReversals),
              ),
              _summaryItem(
                'صافي',
                MoneyUtils.formatPiastersAsEgp(r.totalSupplierNetRefundInflow),
              ),
            ],
          ),
          const Divider(height: 24),
          _summaryItem(
            'صافي الأثر النقدي',
            MoneyUtils.formatPiastersAsEgp(r.signedGrandCashEffect),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
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
          Text('رد السلف وعكسها حسب الحساب', style: textTheme.titleMedium),
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
                  const SizedBox(height: 4),
                  Text('العملاء',
                      style: textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _summaryItem(
                        'إجمالي',
                        MoneyUtils.formatPiastersAsEgp(
                            a.customerGrossRefundOutflow),
                      ),
                      _summaryItem(
                        'إلغاءات',
                        MoneyUtils.formatPiastersAsEgp(
                            a.customerRefundReversals),
                      ),
                      _summaryItem(
                        'صافي',
                        MoneyUtils.formatPiastersAsEgp(
                            a.customerNetRefundOutflow),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('الموردين',
                      style: textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.tertiary,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _summaryItem(
                        'إجمالي',
                        MoneyUtils.formatPiastersAsEgp(
                            a.supplierGrossRefundInflow),
                      ),
                      _summaryItem(
                        'إلغاءات',
                        MoneyUtils.formatPiastersAsEgp(
                            a.supplierRefundReversals),
                      ),
                      _summaryItem(
                        'صافي',
                        MoneyUtils.formatPiastersAsEgp(
                            a.supplierNetRefundInflow),
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
          Text('رد سلف العملاء حسب العميل', style: textTheme.titleMedium),
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
                        color: c.isUnresolved
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          c.entityName,
                          style: textTheme.titleSmall?.copyWith(
                            color: c.isUnresolved
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _summaryItem(
                        'إجمالي',
                        MoneyUtils.formatPiastersAsEgp(c.grossAmount),
                      ),
                      _summaryItem(
                        'إلغاءات',
                        MoneyUtils.formatPiastersAsEgp(c.reversalAmount),
                      ),
                      _summaryItem(
                        'صافي',
                        MoneyUtils.formatPiastersAsEgp(c.netAmount),
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

  Widget _buildSupplierBreakdownCard(TextTheme textTheme) {
    final suppliers = _report!.supplierSummaries;
    if (suppliers.isEmpty) return const SizedBox.shrink();

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ردود سلف الموردين حسب المورد', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          ...suppliers.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        s.isUnresolved
                            ? Icons.help_outline_rounded
                            : Icons.business_center_rounded,
                        size: 16,
                        color: s.isUnresolved
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.tertiary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          s.entityName,
                          style: textTheme.titleSmall?.copyWith(
                            color: s.isUnresolved
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.tertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _summaryItem(
                        'إجمالي',
                        MoneyUtils.formatPiastersAsEgp(s.grossAmount),
                      ),
                      _summaryItem(
                        'إلغاءات',
                        MoneyUtils.formatPiastersAsEgp(s.reversalAmount),
                      ),
                      _summaryItem(
                        'صافي',
                        MoneyUtils.formatPiastersAsEgp(s.netAmount),
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
      AdvancesAndRefundsDetail detail, TextTheme textTheme) {
    final isReversal = detail.isReversal;
    final isCustomer = detail.partyType == AdvancesAndRefundsPartyType.customer;
    final colorScheme = Theme.of(context).colorScheme;
    final partyColor = isCustomer ? colorScheme.primary : colorScheme.tertiary;
    final reversalColor = colorScheme.error;
    final partyLabel = detail.partyType.labelAr;

    return PremiumCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isReversal ? reversalColor : partyColor).withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isReversal ? Icons.undo_rounded : Icons.arrow_upward_rounded,
              color: isReversal ? reversalColor : partyColor,
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
                        color: partyColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        partyLabel,
                        style: TextStyle(fontSize: 10, color: partyColor),
                      ),
                    ),
                    const SizedBox(width: 6),
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
                          color: colorScheme.error.withAlpha(25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$partyLabel غير محدد',
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${detail.entityName} · ${detail.accountName}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  _formatDate(detail.timestamp),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            MoneyUtils.formatPiastersAsEgp(detail.amountQirsh),
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: isReversal ? reversalColor : partyColor,
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
      final file =
          await FinancialReportPdfBuilder.buildAdvancesAndRefundsReport(
              report: _report!,
              businessIdentity: identity,
              logoBytes: logoBytes);
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
          await FinancialReportCsvExporter.exportAdvancesAndRefundsReport(
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
