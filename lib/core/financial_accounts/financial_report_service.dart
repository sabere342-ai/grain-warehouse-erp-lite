import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_closing.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_models.dart';

abstract class CustomerCollectionReportLookup {
  Future<String?> customerIdForCollection(String collectionId);
  Future<String?> customerIdForReversalEntry(
      FinancialAccountEntry reversalEntry);
  Future<String?> customerIdForAdvanceRefundReversalEntry(
      FinancialAccountEntry reversalEntry);
  Future<String> customerNameForId(String customerId);
}

class FinancialReportService {
  const FinancialReportService({
    required FinancialAccountRepository repository,
    CustomerCollectionReportLookup? customerLookup,
    ExpenseRepository? expenseRepository,
  })  : _repository = repository,
        _customerLookup = customerLookup,
        _expenseRepository = expenseRepository;

  final FinancialAccountRepository _repository;
  final CustomerCollectionReportLookup? _customerLookup;
  final ExpenseRepository? _expenseRepository;

  static bool _isInRange(DateTime value, DateTime start, DateTime end) {
    return !value.isBefore(start) && !value.isAfter(end);
  }

  /// Returns the Phase 80 closing and reconciliation history without changing
  /// its ordering, values, or repository state.
  Future<FinancialClosingReconciliationReport>
      closingReconciliationReport() async {
    final accounts = await _repository.listAccounts(includeInactive: true);
    final closings = await _repository.listClosings();
    final accountsById = <String, FinancialAccount>{
      for (final account in accounts) account.id: account,
    };

    return FinancialClosingReconciliationReport(
      closings: closings
          .map(
            (closing) => FinancialClosingReconciliationSummary(
              closingId: closing.id,
              kind: closing.kind,
              fromDate: closing.fromDate,
              toDate: closing.toDate,
              createdAt: closing.createdAt,
              createdByUserId: closing.createdByUserId,
              note: closing.note,
              isOpen: closing.isOpen,
              reopenedAt: closing.reopenedAt,
              reopenedByUserId: closing.reopenedByUserId,
              reopenReason: closing.reopenReason,
              totalDifferenceQirsh: closing.totalDifferenceQirsh,
              accountRows: closing.lines
                  .map(
                    (line) => _closingReconciliationAccountRow(
                      line: line,
                      accountsById: accountsById,
                    ),
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
  }

  FinancialClosingReconciliationAccountRow _closingReconciliationAccountRow({
    required FinancialClosingLine line,
    required Map<String, FinancialAccount> accountsById,
  }) {
    final account = accountsById[line.accountId];
    if (account == null) {
      throw StateError(
        'Financial closing references an unavailable financial account.',
      );
    }
    return FinancialClosingReconciliationAccountRow(
      accountId: account.id,
      accountName: account.name,
      accountType: account.type,
      isAccountActive: account.isActive,
      expectedBalanceQirsh: line.expectedBalanceQirsh,
      actualBalanceQirsh: line.actualBalanceQirsh,
      differenceQirsh: line.differenceQirsh,
    );
  }

  Future<AccountBalanceReport> accountBalanceReport({
    DateTime? fromDate,
    DateTime? toDate,
    FinancialAccountType? typeFilter,
    String? accountIdFilter,
    bool includeInactive = true,
  }) async {
    final effectiveFrom =
        fromDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    final effectiveTo = toDate ?? DateTime.now();

    final accounts =
        await _repository.listAccounts(includeInactive: includeInactive);
    final balances =
        await _repository.allAccountBalances(includeInactive: includeInactive);
    final balanceMap = {
      for (final b in balances) b.account.id: b,
    };

    final rows = <AccountBalanceReportRow>[];
    var totalOpening = 0;
    var totalInflows = 0;
    var totalOutflows = 0;

    for (final account in accounts) {
      if (typeFilter != null && account.type != typeFilter) continue;
      if (accountIdFilter != null && account.id != accountIdFilter) continue;

      final allEntries = await _entriesForAccount(account.id);

      final entriesBeforePeriod =
          allEntries.where((e) => e.effectiveDate.isBefore(effectiveFrom));
      final openingBalance = entriesBeforePeriod.fold<int>(
        0,
        (sum, e) => sum + e.signedAmountQirsh,
      );

      final entriesInPeriod = allEntries
          .where((e) => _isInRange(e.effectiveDate, effectiveFrom, effectiveTo))
          .toList();

      var periodInflows = 0;
      var periodOutflows = 0;
      for (final entry in entriesInPeriod) {
        if (entry.direction == FinancialAccountEntryDirection.inflow) {
          periodInflows += entry.amountQirsh;
        } else {
          periodOutflows += entry.amountQirsh;
        }
      }

      final entryCount = balanceMap[account.id]?.entryCount ?? 0;

      rows.add(AccountBalanceReportRow(
        account: account,
        openingBalanceQirsh: openingBalance,
        totalInflowsQirsh: periodInflows,
        totalOutflowsQirsh: periodOutflows,
        entryCount: entryCount,
      ));

      totalOpening += openingBalance;
      totalInflows += periodInflows;
      totalOutflows += periodOutflows;
    }

    return AccountBalanceReport(
      fromDate: effectiveFrom,
      toDate: effectiveTo,
      rows: rows,
      totalOpeningQirsh: totalOpening,
      totalInflowsQirsh: totalInflows,
      totalOutflowsQirsh: totalOutflows,
      totalClosingQirsh: totalOpening + totalInflows - totalOutflows,
    );
  }

  Future<AccountStatementReport> accountStatementReport({
    required String accountId,
    DateTime? fromDate,
    DateTime? toDate,
    FinancialAccountEntrySource? sourceTypeFilter,
    PaymentMethod? paymentMethodFilter,
    String? reversalFilter,
  }) async {
    final effectiveFrom =
        fromDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    final effectiveTo = toDate ?? DateTime.now();

    final account = await _repository.accountById(accountId);
    final allEntries = await _entriesForAccount(accountId);

    final entriesBeforePeriod =
        allEntries.where((e) => e.effectiveDate.isBefore(effectiveFrom));
    final openingBalance = entriesBeforePeriod.fold<int>(
      0,
      (sum, e) => sum + e.signedAmountQirsh,
    );

    var entriesInPeriod = allEntries
        .where((e) => _isInRange(e.effectiveDate, effectiveFrom, effectiveTo))
        .toList();

    if (sourceTypeFilter != null) {
      entriesInPeriod = entriesInPeriod
          .where((e) => e.sourceType == sourceTypeFilter)
          .toList();
    }
    if (paymentMethodFilter != null) {
      entriesInPeriod = entriesInPeriod
          .where((e) => e.paymentMethod == paymentMethodFilter)
          .toList();
    }
    if (reversalFilter != null) {
      if (reversalFilter == 'reversal') {
        entriesInPeriod =
            entriesInPeriod.where((e) => e.reversalOf != null).toList();
      } else if (reversalFilter == 'original') {
        entriesInPeriod =
            entriesInPeriod.where((e) => e.reversalOf == null).toList();
      }
    }

    entriesInPeriod.sort((a, b) {
      final date = a.effectiveDate.compareTo(b.effectiveDate);
      if (date != 0) return date;
      return a.id.compareTo(b.id);
    });

    var running = openingBalance;
    final lines = <AccountStatementReportLine>[];
    for (final entry in entriesInPeriod) {
      running += entry.signedAmountQirsh;
      lines.add(AccountStatementReportLine(
        entry: entry,
        runningBalanceQirsh: running,
      ));
    }

    return AccountStatementReport(
      account: account,
      fromDate: effectiveFrom,
      toDate: effectiveTo,
      lines: lines,
      openingBalanceQirsh: openingBalance,
      closingBalanceQirsh: running,
    );
  }

  Future<PaymentMethodReport> paymentMethodReport({
    DateTime? fromDate,
    DateTime? toDate,
    PaymentMethod? paymentMethodFilter,
    FinancialAccountEntrySource? sourceTypeFilter,
    String? accountIdFilter,
    FinancialAccountEntryDirection? directionFilter,
  }) async {
    final effectiveFrom =
        fromDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    final effectiveTo = toDate ?? DateTime.now();

    final accounts = await _repository.listAccounts(includeInactive: true);
    final transferSourceTypes = {
      FinancialAccountEntrySource.transferOut,
      FinancialAccountEntrySource.transferIn,
      FinancialAccountEntrySource.transferReversalOut,
      FinancialAccountEntrySource.transferReversalIn,
    };

    final allEntries = <FinancialAccountEntry>[];
    for (final account in accounts) {
      if (accountIdFilter != null && account.id != accountIdFilter) continue;
      final entries = await _entriesForAccount(account.id);
      allEntries.addAll(entries);
    }

    var filtered = allEntries
        .where((e) => _isInRange(e.effectiveDate, effectiveFrom, effectiveTo))
        .where((e) => !transferSourceTypes.contains(e.sourceType))
        .toList();

    if (paymentMethodFilter != null) {
      filtered = filtered
          .where((e) => e.paymentMethod == paymentMethodFilter)
          .toList();
    }
    if (sourceTypeFilter != null) {
      filtered =
          filtered.where((e) => e.sourceType == sourceTypeFilter).toList();
    }
    if (directionFilter != null) {
      filtered = filtered.where((e) => e.direction == directionFilter).toList();
    }

    final grouped = <PaymentMethod?, List<FinancialAccountEntry>>{};
    for (final entry in filtered) {
      grouped.putIfAbsent(entry.paymentMethod, () => []).add(entry);
    }

    final rows = <PaymentMethodReportRow>[];
    var totalInflows = 0;
    var totalOutflows = 0;

    for (final entry in grouped.entries) {
      var inflows = 0;
      var outflows = 0;
      final bySource = <FinancialAccountEntrySource, int>{};
      for (final e in entry.value) {
        if (e.direction == FinancialAccountEntryDirection.inflow) {
          inflows += e.amountQirsh;
        } else {
          outflows += e.amountQirsh;
        }
        bySource[e.sourceType] = (bySource[e.sourceType] ?? 0) + e.amountQirsh;
      }

      rows.add(PaymentMethodReportRow(
        paymentMethod: entry.key,
        operationCount: entry.value.length,
        totalInflowsQirsh: inflows,
        totalOutflowsQirsh: outflows,
        bySourceType: bySource,
      ));

      totalInflows += inflows;
      totalOutflows += outflows;
    }

    rows.sort((a, b) => b.totalInflowsQirsh.compareTo(a.totalInflowsQirsh));

    return PaymentMethodReport(
      fromDate: effectiveFrom,
      toDate: effectiveTo,
      rows: rows,
      totalInflowsQirsh: totalInflows,
      totalOutflowsQirsh: totalOutflows,
    );
  }

  Future<TransferReport> transferReport({
    DateTime? fromDate,
    DateTime? toDate,
    String? sourceAccountId,
    String? destinationAccountId,
    String? anyAccountId,
    String? reversalFilter,
  }) async {
    final effectiveFrom =
        fromDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    final effectiveTo = toDate ?? DateTime.now();

    final transfers = await _repository.listTransfers();
    final accounts = await _repository.listAccounts(includeInactive: true);
    final accountMap = {for (final a in accounts) a.id: a.name};

    final reversedIds = <String, String>{};
    final reversalDates = <String, DateTime>{};
    final reversalReasons = <String, String>{};
    for (final t in transfers) {
      if (t.isReversal && t.originalTransferId != null) {
        reversedIds[t.originalTransferId!] = t.displayNumber;
        reversalDates[t.originalTransferId!] = t.effectiveDate;
        reversalReasons[t.originalTransferId!] = t.reversalReason ?? '';
      }
    }

    var filtered = transfers
        .where((t) => _isInRange(t.effectiveDate, effectiveFrom, effectiveTo))
        .toList();

    if (sourceAccountId != null) {
      filtered =
          filtered.where((t) => t.sourceAccountId == sourceAccountId).toList();
    }
    if (destinationAccountId != null) {
      filtered = filtered
          .where((t) => t.destinationAccountId == destinationAccountId)
          .toList();
    }
    if (anyAccountId != null) {
      filtered = filtered
          .where((t) =>
              t.sourceAccountId == anyAccountId ||
              t.destinationAccountId == anyAccountId)
          .toList();
    }
    if (reversalFilter == 'reversal') {
      filtered = filtered.where((t) => t.isReversal).toList();
    } else if (reversalFilter == 'original') {
      filtered = filtered.where((t) => !t.isReversal).toList();
    } else if (reversalFilter == 'reversed') {
      filtered = filtered.where((t) => t.isReversed).toList();
    }

    final rows = <TransferReportRow>[];
    var totalAmount = 0;

    for (final t in filtered) {
      rows.add(TransferReportRow(
        transferId: t.id,
        displayNumber: t.displayNumber,
        effectiveDate: t.effectiveDate,
        sourceAccountName: accountMap[t.sourceAccountId] ?? t.sourceAccountId,
        destinationAccountName:
            accountMap[t.destinationAccountId] ?? t.destinationAccountId,
        amountQirsh: t.amountQirsh,
        reference: t.transferReference,
        note: t.note,
        isReversal: t.isReversal,
        isReversed: t.isReversed,
        reversalDisplayNumber: reversedIds[t.id],
        reversalDate: reversalDates[t.id],
        reversalReason: reversalReasons[t.id],
        createdByUserId: t.createdByUserId,
      ));
      totalAmount += t.amountQirsh;
    }

    rows.sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));

    return TransferReport(
      fromDate: effectiveFrom,
      toDate: effectiveTo,
      rows: rows,
      totalAmountQirsh: totalAmount,
    );
  }

  Future<List<FinancialAccountEntry>> _entriesForAccount(
      String accountId) async {
    final statement = await _repository.statementForAccount(accountId);
    return statement.lines.map((l) => l.entry).toList();
  }

  static const _transferSourceTypes = {
    FinancialAccountEntrySource.transferOut,
    FinancialAccountEntrySource.transferIn,
    FinancialAccountEntrySource.transferReversalOut,
    FinancialAccountEntrySource.transferReversalIn,
  };

  Future<FlowReport> inflowsReport({
    DateTime? fromDate,
    DateTime? toDate,
    String? accountIdFilter,
  }) async {
    return _flowReport(
      fromDate: fromDate,
      toDate: toDate,
      accountIdFilter: accountIdFilter,
      direction: FinancialAccountEntryDirection.inflow,
    );
  }

  Future<FlowReport> outflowsReport({
    DateTime? fromDate,
    DateTime? toDate,
    String? accountIdFilter,
  }) async {
    return _flowReport(
      fromDate: fromDate,
      toDate: toDate,
      accountIdFilter: accountIdFilter,
      direction: FinancialAccountEntryDirection.outflow,
    );
  }

  Future<FlowReport> _flowReport({
    required DateTime? fromDate,
    required DateTime? toDate,
    required String? accountIdFilter,
    required FinancialAccountEntryDirection direction,
  }) async {
    final effectiveFrom =
        fromDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    final effectiveTo = toDate ?? DateTime.now();

    final accounts = await _repository.listAccounts(includeInactive: true);
    final accountMap = {for (final a in accounts) a.id: a.name};

    final allEntries = <FinancialAccountEntry>[];
    for (final account in accounts) {
      if (accountIdFilter != null && account.id != accountIdFilter) continue;
      final entries = await _entriesForAccount(account.id);
      allEntries.addAll(entries);
    }

    var filtered = allEntries
        .where((e) => _isInRange(e.effectiveDate, effectiveFrom, effectiveTo))
        .where((e) => e.direction == direction)
        .toList();

    if (accountIdFilter == null) {
      filtered = filtered
          .where((e) => !_transferSourceTypes.contains(e.sourceType))
          .toList();
    }

    final entries = <FlowReportEntry>[];
    var total = 0;
    final breakdown = <FinancialAccountEntrySource, int>{};

    for (final e in filtered) {
      entries.add(FlowReportEntry(
        entryId: e.id,
        timestamp: e.effectiveDate,
        accountId: e.accountId,
        accountName: accountMap[e.accountId] ?? e.accountId,
        source: e.sourceType,
        referenceId: e.sourceDocumentNumber,
        description: e.note,
        amountQirsh: e.amountQirsh,
        direction: e.direction,
        isReversal: e.reversalOf != null,
      ));
      total += e.amountQirsh;
      breakdown[e.sourceType] = (breakdown[e.sourceType] ?? 0) + e.amountQirsh;
    }

    entries.sort((a, b) {
      final cmp = b.timestamp.compareTo(a.timestamp);
      if (cmp != 0) return cmp;
      return a.entryId.compareTo(b.entryId);
    });

    return FlowReport(
      fromDate: effectiveFrom,
      toDate: effectiveTo,
      entries: entries,
      totalQirsh: total,
      sourceBreakdown: breakdown,
    );
  }

  static const _qualifiedCollectionSources = {
    FinancialAccountEntrySource.customerCollection,
  };

  static const _qualifiedReversalSources = {
    FinancialAccountEntrySource.cancellationReversal,
  };

  static const _qualifiedAdvanceRefundReversalSources = {
    FinancialAccountEntrySource.customerAdvanceRefundReversal,
  };

  Future<CustomerCollectionsByAccountReport> getCustomerCollectionsByAccount({
    DateTime? fromDate,
    DateTime? toDate,
    String? accountIdFilter,
    String? customerIdFilter,
  }) async {
    final effectiveFrom =
        fromDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    final effectiveTo = toDate ?? DateTime.now();

    final accounts = await _repository.listAccounts(includeInactive: true);
    final accountMap = {for (final a in accounts) a.id: a.name};

    final allEntries = <FinancialAccountEntry>[];
    for (final account in accounts) {
      if (accountIdFilter != null && account.id != accountIdFilter) continue;
      final entries = await _entriesForAccount(account.id);
      allEntries.addAll(entries);
    }

    final filtered = allEntries
        .where((e) => _isInRange(e.effectiveDate, effectiveFrom, effectiveTo))
        .where((e) {
      if (_qualifiedCollectionSources.contains(e.sourceType)) return true;
      if (_qualifiedReversalSources.contains(e.sourceType)) {
        return e.reversalOf != null;
      }
      if (_qualifiedAdvanceRefundReversalSources.contains(e.sourceType)) {
        return e.reversalOf != null;
      }
      return false;
    }).toList();

    final entryCustomerCache = <String, _ResolvedCustomer>{};

    Future<_ResolvedCustomer> resolveCustomer(
        FinancialAccountEntry entry) async {
      if (entryCustomerCache.containsKey(entry.id)) {
        return entryCustomerCache[entry.id]!;
      }

      final lookup = _customerLookup;
      if (lookup == null) {
        const unresolved = _ResolvedCustomer(null, null);
        entryCustomerCache[entry.id] = unresolved;
        return unresolved;
      }

      String? customerId;

      if (_qualifiedCollectionSources.contains(entry.sourceType)) {
        customerId =
            await lookup.customerIdForCollection(entry.sourceDocumentId);
      } else if (_qualifiedAdvanceRefundReversalSources
          .contains(entry.sourceType)) {
        customerId =
            await lookup.customerIdForAdvanceRefundReversalEntry(entry);
      } else if (_qualifiedReversalSources.contains(entry.sourceType)) {
        customerId = await lookup.customerIdForReversalEntry(entry);
      }

      if (customerId != null) {
        final name = await lookup.customerNameForId(customerId);
        final resolved = _ResolvedCustomer(customerId, name);
        entryCustomerCache[entry.id] = resolved;
        return resolved;
      }

      const unresolved = _ResolvedCustomer(null, null);
      entryCustomerCache[entry.id] = unresolved;
      return unresolved;
    }

    final details = <CustomerCollectionsByAccountDetail>[];
    for (final entry in filtered) {
      final resolved = await resolveCustomer(entry);
      final isReversal = entry.reversalOf != null;
      details.add(CustomerCollectionsByAccountDetail(
        entryId: entry.id,
        sourceDocumentId: entry.sourceDocumentId,
        customerId: resolved.customerId,
        customerName: resolved.customerName ?? 'غير محدد',
        accountId: entry.accountId,
        accountName: accountMap[entry.accountId] ?? entry.accountId,
        timestamp: entry.effectiveDate,
        isReversal: isReversal,
        amountQirsh: entry.amountQirsh,
        sourceType: entry.sourceType,
        reference: entry.reference,
        reversalOfEntryId: entry.reversalOf,
      ));
    }

    details.sort((a, b) {
      final cmp = a.accountName.compareTo(b.accountName);
      if (cmp != 0) return cmp;
      final cmp2 = a.customerName.compareTo(b.customerName);
      if (cmp2 != 0) return cmp2;
      final cmp3 = b.timestamp.compareTo(a.timestamp);
      if (cmp3 != 0) return cmp3;
      return a.entryId.compareTo(b.entryId);
    });

    if (customerIdFilter != null) {
      details.removeWhere((d) => d.customerId != customerIdFilter);
    }

    final accountGross = <String, int>{};
    final accountRev = <String, int>{};
    for (final d in details) {
      if (d.isReversal) {
        accountRev[d.accountId] =
            (accountRev[d.accountId] ?? 0) + d.amountQirsh;
      } else {
        accountGross[d.accountId] =
            (accountGross[d.accountId] ?? 0) + d.amountQirsh;
      }
    }

    final accountSummaries = <CustomerCollectionsByAccountAccountSummary>[];
    for (final account in accounts) {
      if (accountIdFilter != null && account.id != accountIdFilter) continue;
      final gross = accountGross[account.id] ?? 0;
      final rev = accountRev[account.id] ?? 0;
      if (gross == 0 && rev == 0) continue;
      accountSummaries.add(CustomerCollectionsByAccountAccountSummary(
        account: account,
        grossCollectionsQirsh: gross,
        reversalsQirsh: rev,
        netCollectionsQirsh: gross - rev,
      ));
    }

    final custGross = <String?, int>{};
    final custRev = <String?, int>{};
    final custNames = <String?, String>{};
    for (final d in details) {
      if (d.isReversal) {
        custRev[d.customerId] = (custRev[d.customerId] ?? 0) + d.amountQirsh;
      } else {
        custGross[d.customerId] =
            (custGross[d.customerId] ?? 0) + d.amountQirsh;
      }
      custNames[d.customerId] = d.customerName;
    }

    final customerSummaries = <CustomerCollectionsByAccountCustomerSummary>[];
    for (final custId in custGross.keys) {
      final gross = custGross[custId] ?? 0;
      final rev = custRev[custId] ?? 0;
      customerSummaries.add(
        CustomerCollectionsByAccountCustomerSummary(
          customerId: custId,
          customerName: custNames[custId] ?? 'غير محدد',
          grossCollectionsQirsh: gross,
          reversalsQirsh: rev,
          netCollectionsQirsh: gross - rev,
        ),
      );
    }
    for (final custId in custRev.keys) {
      if (!custGross.containsKey(custId)) {
        final rev = custRev[custId]!;
        customerSummaries.add(
          CustomerCollectionsByAccountCustomerSummary(
            customerId: custId,
            customerName: custNames[custId] ?? 'غير محدد',
            grossCollectionsQirsh: 0,
            reversalsQirsh: rev,
            netCollectionsQirsh: -rev,
          ),
        );
      }
    }

    customerSummaries.sort((a, b) {
      final cmp = a.customerName.compareTo(b.customerName);
      if (cmp != 0) return cmp;
      final aId = a.customerId ?? '';
      final bId = b.customerId ?? '';
      return aId.compareTo(bId);
    });

    var totalGross = 0;
    var totalRev = 0;
    for (final d in details) {
      if (d.isReversal) {
        totalRev += d.amountQirsh;
      } else {
        totalGross += d.amountQirsh;
      }
    }

    return CustomerCollectionsByAccountReport(
      fromDate: effectiveFrom,
      toDate: effectiveTo,
      accountSummaries: accountSummaries,
      customerSummaries: customerSummaries,
      details: details,
      totalGrossCollectionsQirsh: totalGross,
      totalReversalsQirsh: totalRev,
      totalNetCollectionsQirsh: totalGross - totalRev,
    );
  }

  static const _qualifiedSettlementSources = {
    FinancialAccountEntrySource.supplierSettlement,
  };

  static const _qualifiedSettlementReversalSources = {
    FinancialAccountEntrySource.cancellationReversal,
  };

  Future<SupplierSettlementsByAccountReport> getSupplierSettlementsByAccount({
    DateTime? fromDate,
    DateTime? toDate,
    String? accountIdFilter,
    String? supplierIdFilter,
    SupplierSettlementReportLookup? supplierLookup,
  }) async {
    final effectiveFrom =
        fromDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    final effectiveTo = toDate ?? DateTime.now();

    final accounts = await _repository.listAccounts(includeInactive: true);
    final accountMap = {for (final a in accounts) a.id: a.name};

    final allEntries = <FinancialAccountEntry>[];
    for (final account in accounts) {
      if (accountIdFilter != null && account.id != accountIdFilter) continue;
      final entries = await _entriesForAccount(account.id);
      allEntries.addAll(entries);
    }

    final entryById = <String, FinancialAccountEntry>{};
    for (final e in allEntries) {
      entryById[e.id] = e;
    }

    final filtered = allEntries
        .where((e) => _isInRange(e.effectiveDate, effectiveFrom, effectiveTo))
        .where((e) {
      if (_qualifiedSettlementSources.contains(e.sourceType)) return true;
      if (_qualifiedSettlementReversalSources.contains(e.sourceType)) {
        if (e.reversalOf == null) return false;
        final original = entryById[e.reversalOf];
        if (original == null) return false;
        return _qualifiedSettlementSources.contains(original.sourceType);
      }
      return false;
    }).toList();

    final entrySupplierCache = <String, _ResolvedSupplier>{};

    Future<_ResolvedSupplier> resolveSupplier(
        FinancialAccountEntry entry) async {
      if (entrySupplierCache.containsKey(entry.id)) {
        return entrySupplierCache[entry.id]!;
      }

      if (supplierLookup == null) {
        const unresolved = _ResolvedSupplier(null, null);
        entrySupplierCache[entry.id] = unresolved;
        return unresolved;
      }

      String? supplierId;

      if (_qualifiedSettlementSources.contains(entry.sourceType)) {
        supplierId =
            await supplierLookup.supplierIdForPayment(entry.sourceDocumentId);
      } else if (_qualifiedSettlementReversalSources
              .contains(entry.sourceType) &&
          entry.reversalOf != null) {
        supplierId = await supplierLookup.supplierIdForReversalEntry(entry);
      }

      if (supplierId != null) {
        final name = await supplierLookup.supplierNameForId(supplierId);
        final resolved = _ResolvedSupplier(supplierId, name);
        entrySupplierCache[entry.id] = resolved;
        return resolved;
      }

      const unresolved = _ResolvedSupplier(null, null);
      entrySupplierCache[entry.id] = unresolved;
      return unresolved;
    }

    final details = <SupplierSettlementsByAccountDetail>[];
    for (final entry in filtered) {
      final resolved = await resolveSupplier(entry);
      final isReversal = entry.reversalOf != null;
      details.add(SupplierSettlementsByAccountDetail(
        entryId: entry.id,
        sourceDocumentId: entry.sourceDocumentId,
        supplierId: resolved.supplierId,
        supplierName: resolved.supplierName ?? 'مورد غير محدد',
        accountId: entry.accountId,
        accountName: accountMap[entry.accountId] ?? entry.accountId,
        timestamp: entry.effectiveDate,
        isReversal: isReversal,
        amountQirsh: entry.amountQirsh,
        sourceType: entry.sourceType,
        reference: entry.reference,
        reversalOfEntryId: entry.reversalOf,
      ));
    }

    details.sort((a, b) {
      final cmp = a.accountName.compareTo(b.accountName);
      if (cmp != 0) return cmp;
      final cmp2 = a.supplierName.compareTo(b.supplierName);
      if (cmp2 != 0) return cmp2;
      final cmp3 = b.timestamp.compareTo(a.timestamp);
      if (cmp3 != 0) return cmp3;
      return a.entryId.compareTo(b.entryId);
    });

    if (supplierIdFilter != null) {
      details.removeWhere((d) => d.supplierId != supplierIdFilter);
    }

    final accountGross = <String, int>{};
    final accountRev = <String, int>{};
    for (final d in details) {
      if (d.isReversal) {
        accountRev[d.accountId] =
            (accountRev[d.accountId] ?? 0) + d.amountQirsh;
      } else {
        accountGross[d.accountId] =
            (accountGross[d.accountId] ?? 0) + d.amountQirsh;
      }
    }

    final accountSummaries = <SupplierSettlementsByAccountAccountSummary>[];
    for (final account in accounts) {
      if (accountIdFilter != null && account.id != accountIdFilter) continue;
      final gross = accountGross[account.id] ?? 0;
      final rev = accountRev[account.id] ?? 0;
      if (gross == 0 && rev == 0) continue;
      accountSummaries.add(SupplierSettlementsByAccountAccountSummary(
        account: account,
        grossSettlementsQirsh: gross,
        reversalsQirsh: rev,
        netSettlementsQirsh: gross - rev,
      ));
    }

    final suppGross = <String?, int>{};
    final suppRev = <String?, int>{};
    final suppNames = <String?, String>{};
    for (final d in details) {
      if (d.isReversal) {
        suppRev[d.supplierId] = (suppRev[d.supplierId] ?? 0) + d.amountQirsh;
      } else {
        suppGross[d.supplierId] =
            (suppGross[d.supplierId] ?? 0) + d.amountQirsh;
      }
      suppNames[d.supplierId] = d.supplierName;
    }

    final supplierSummaries = <SupplierSettlementsByAccountSupplierSummary>[];
    for (final suppId in suppGross.keys) {
      final gross = suppGross[suppId] ?? 0;
      final rev = suppRev[suppId] ?? 0;
      supplierSummaries.add(
        SupplierSettlementsByAccountSupplierSummary(
          supplierId: suppId,
          supplierName: suppNames[suppId] ?? 'مورد غير محدد',
          grossSettlementsQirsh: gross,
          reversalsQirsh: rev,
          netSettlementsQirsh: gross - rev,
        ),
      );
    }
    for (final suppId in suppRev.keys) {
      if (!suppGross.containsKey(suppId)) {
        final rev = suppRev[suppId]!;
        supplierSummaries.add(
          SupplierSettlementsByAccountSupplierSummary(
            supplierId: suppId,
            supplierName: suppNames[suppId] ?? 'مورد غير محدد',
            grossSettlementsQirsh: 0,
            reversalsQirsh: rev,
            netSettlementsQirsh: -rev,
          ),
        );
      }
    }

    supplierSummaries.sort((a, b) {
      final cmp = a.supplierName.compareTo(b.supplierName);
      if (cmp != 0) return cmp;
      final aId = a.supplierId ?? '';
      final bId = b.supplierId ?? '';
      return aId.compareTo(bId);
    });

    var totalGross = 0;
    var totalRev = 0;
    for (final d in details) {
      if (d.isReversal) {
        totalRev += d.amountQirsh;
      } else {
        totalGross += d.amountQirsh;
      }
    }

    return SupplierSettlementsByAccountReport(
      fromDate: effectiveFrom,
      toDate: effectiveTo,
      accountSummaries: accountSummaries,
      supplierSummaries: supplierSummaries,
      details: details,
      totalGrossSettlementsQirsh: totalGross,
      totalReversalsQirsh: totalRev,
      totalNetSettlementsQirsh: totalGross - totalRev,
    );
  }

  static const _qualifiedCustomerRefundSources = {
    FinancialAccountEntrySource.customerAdvanceRefund,
  };

  static const _qualifiedCustomerRefundReversalSources = {
    FinancialAccountEntrySource.customerAdvanceRefundReversal,
  };

  static const _qualifiedSupplierRefundSources = {
    FinancialAccountEntrySource.supplierAdvanceRefund,
  };

  static const _qualifiedSupplierRefundReversalSources = {
    FinancialAccountEntrySource.supplierAdvanceRefundReversal,
  };

  Future<AdvancesAndRefundsReport> getAdvancesAndRefundsReport({
    DateTime? fromDate,
    DateTime? toDate,
    String? accountIdFilter,
    AdvancesAndRefundsPartyType? partyTypeFilter,
    String? entityIdFilter,
    SupplierSettlementReportLookup? supplierLookup,
  }) async {
    final effectiveFrom =
        fromDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    final effectiveTo = toDate ?? DateTime.now();

    final accounts = await _repository.listAccounts(includeInactive: true);
    final accountMap = {for (final a in accounts) a.id: a.name};

    final allEntries = <FinancialAccountEntry>[];
    for (final account in accounts) {
      if (accountIdFilter != null && account.id != accountIdFilter) continue;
      final entries = await _entriesForAccount(account.id);
      allEntries.addAll(entries);
    }

    final entryById = <String, FinancialAccountEntry>{};
    for (final e in allEntries) {
      entryById[e.id] = e;
    }

    final filtered = allEntries
        .where((e) => _isInRange(e.effectiveDate, effectiveFrom, effectiveTo))
        .where((e) {
      if (_qualifiedCustomerRefundSources.contains(e.sourceType)) return true;
      if (_qualifiedSupplierRefundSources.contains(e.sourceType)) return true;
      if (_qualifiedCustomerRefundReversalSources.contains(e.sourceType)) {
        if (e.reversalOf == null) return false;
        final original = entryById[e.reversalOf];
        if (original == null) return false;
        return _qualifiedCustomerRefundSources.contains(original.sourceType);
      }
      if (_qualifiedSupplierRefundReversalSources.contains(e.sourceType)) {
        if (e.reversalOf == null) return false;
        final original = entryById[e.reversalOf];
        if (original == null) return false;
        return _qualifiedSupplierRefundSources.contains(original.sourceType);
      }
      return false;
    }).toList();

    final entryCustomerCache = <String, _ResolvedCustomer>{};

    Future<_ResolvedCustomer> resolveCustomer(
        FinancialAccountEntry entry) async {
      if (entryCustomerCache.containsKey(entry.id)) {
        return entryCustomerCache[entry.id]!;
      }

      final lookup = _customerLookup;
      if (lookup == null) {
        const unresolved = _ResolvedCustomer(null, null);
        entryCustomerCache[entry.id] = unresolved;
        return unresolved;
      }

      String? customerId;

      if (_qualifiedCustomerRefundSources.contains(entry.sourceType)) {
        customerId =
            await lookup.customerIdForCollection(entry.sourceDocumentId);
      } else if (_qualifiedCustomerRefundReversalSources
              .contains(entry.sourceType) &&
          entry.reversalOf != null) {
        customerId =
            await lookup.customerIdForAdvanceRefundReversalEntry(entry);
      }

      if (customerId != null) {
        final name = await lookup.customerNameForId(customerId);
        final resolved = _ResolvedCustomer(customerId, name);
        entryCustomerCache[entry.id] = resolved;
        return resolved;
      }

      const unresolved = _ResolvedCustomer(null, null);
      entryCustomerCache[entry.id] = unresolved;
      return unresolved;
    }

    final entrySupplierCache = <String, _ResolvedSupplier>{};

    Future<_ResolvedSupplier> resolveSupplier(
        FinancialAccountEntry entry) async {
      if (entrySupplierCache.containsKey(entry.id)) {
        return entrySupplierCache[entry.id]!;
      }

      if (supplierLookup == null) {
        const unresolved = _ResolvedSupplier(null, null);
        entrySupplierCache[entry.id] = unresolved;
        return unresolved;
      }

      String? supplierId;

      if (_qualifiedSupplierRefundSources.contains(entry.sourceType)) {
        supplierId =
            await supplierLookup.supplierIdForPayment(entry.sourceDocumentId);
      } else if (_qualifiedSupplierRefundReversalSources
              .contains(entry.sourceType) &&
          entry.reversalOf != null) {
        supplierId = await supplierLookup.supplierIdForReversalEntry(entry);
      }

      if (supplierId != null) {
        final name = await supplierLookup.supplierNameForId(supplierId);
        final resolved = _ResolvedSupplier(supplierId, name);
        entrySupplierCache[entry.id] = resolved;
        return resolved;
      }

      const unresolved = _ResolvedSupplier(null, null);
      entrySupplierCache[entry.id] = unresolved;
      return unresolved;
    }

    final details = <AdvancesAndRefundsDetail>[];
    for (final entry in filtered) {
      final isCustomerSource = _qualifiedCustomerRefundSources
              .contains(entry.sourceType) ||
          _qualifiedCustomerRefundReversalSources.contains(entry.sourceType);
      final isReversal = entry.reversalOf != null;

      if (isCustomerSource) {
        final resolved = await resolveCustomer(entry);
        details.add(AdvancesAndRefundsDetail(
          entryId: entry.id,
          accountId: entry.accountId,
          accountName: accountMap[entry.accountId] ?? entry.accountId,
          partyType: AdvancesAndRefundsPartyType.customer,
          entityId: resolved.customerId,
          entityName: resolved.customerName ?? 'عميل غير محدد',
          timestamp: entry.effectiveDate,
          sourceType: entry.sourceType,
          isReversal: isReversal,
          amountQirsh: entry.amountQirsh,
          signedCashEffect: -entry.amountQirsh,
          reference: entry.reference,
          sourceDocumentId: entry.sourceDocumentId,
          reversalOfEntryId: entry.reversalOf,
        ));
      } else {
        final resolved = await resolveSupplier(entry);
        details.add(AdvancesAndRefundsDetail(
          entryId: entry.id,
          accountId: entry.accountId,
          accountName: accountMap[entry.accountId] ?? entry.accountId,
          partyType: AdvancesAndRefundsPartyType.supplier,
          entityId: resolved.supplierId,
          entityName: resolved.supplierName ?? 'مورد غير محدد',
          timestamp: entry.effectiveDate,
          sourceType: entry.sourceType,
          isReversal: isReversal,
          amountQirsh: entry.amountQirsh,
          signedCashEffect: entry.amountQirsh,
          reference: entry.reference,
          sourceDocumentId: entry.sourceDocumentId,
          reversalOfEntryId: entry.reversalOf,
        ));
      }
    }

    details.sort((a, b) {
      final cmp = a.accountName.compareTo(b.accountName);
      if (cmp != 0) return cmp;
      final cmp2 = a.partyType.index.compareTo(b.partyType.index);
      if (cmp2 != 0) return cmp2;
      final cmp3 = a.entityName.compareTo(b.entityName);
      if (cmp3 != 0) return cmp3;
      final cmp4 = b.timestamp.compareTo(a.timestamp);
      if (cmp4 != 0) return cmp4;
      return a.entryId.compareTo(b.entryId);
    });

    if (partyTypeFilter != null) {
      details.removeWhere((d) => d.partyType != partyTypeFilter);
    }
    if (entityIdFilter != null) {
      details.removeWhere((d) => d.entityId != entityIdFilter);
    }

    var totalCustomerGross = 0;
    var totalCustomerRev = 0;
    var totalSupplierGross = 0;
    var totalSupplierRev = 0;

    for (final d in details) {
      if (d.partyType == AdvancesAndRefundsPartyType.customer) {
        if (d.isReversal) {
          totalCustomerRev += d.amountQirsh;
        } else {
          totalCustomerGross += d.amountQirsh;
        }
      } else {
        if (d.isReversal) {
          totalSupplierRev += d.amountQirsh;
        } else {
          totalSupplierGross += d.amountQirsh;
        }
      }
    }

    final accountCustomerGross = <String, int>{};
    final accountCustomerRev = <String, int>{};
    final accountSupplierGross = <String, int>{};
    final accountSupplierRev = <String, int>{};
    final accountDetailCount = <String, int>{};

    for (final d in details) {
      accountDetailCount[d.accountId] =
          (accountDetailCount[d.accountId] ?? 0) + 1;
      if (d.partyType == AdvancesAndRefundsPartyType.customer) {
        if (d.isReversal) {
          accountCustomerRev[d.accountId] =
              (accountCustomerRev[d.accountId] ?? 0) + d.amountQirsh;
        } else {
          accountCustomerGross[d.accountId] =
              (accountCustomerGross[d.accountId] ?? 0) + d.amountQirsh;
        }
      } else {
        if (d.isReversal) {
          accountSupplierRev[d.accountId] =
              (accountSupplierRev[d.accountId] ?? 0) + d.amountQirsh;
        } else {
          accountSupplierGross[d.accountId] =
              (accountSupplierGross[d.accountId] ?? 0) + d.amountQirsh;
        }
      }
    }

    final accountSummaries = <AdvancesAndRefundsAccountSummary>[];
    for (final account in accounts) {
      if (accountIdFilter != null && account.id != accountIdFilter) continue;
      final cGross = accountCustomerGross[account.id] ?? 0;
      final cRev = accountCustomerRev[account.id] ?? 0;
      final sGross = accountSupplierGross[account.id] ?? 0;
      final sRev = accountSupplierRev[account.id] ?? 0;
      final count = accountDetailCount[account.id] ?? 0;
      if (count == 0) continue;
      final cNet = cGross - cRev;
      final sNet = sGross - sRev;
      accountSummaries.add(AdvancesAndRefundsAccountSummary(
        account: account,
        customerGrossRefundOutflow: cGross,
        customerRefundReversals: cRev,
        customerNetRefundOutflow: cNet,
        supplierGrossRefundInflow: sGross,
        supplierRefundReversals: sRev,
        supplierNetRefundInflow: sNet,
        signedNetCashEffect: sNet - cNet,
        detailCount: count,
      ));
    }

    final entityData = <String, _EntityAggregator>{};
    for (final d in details) {
      final key = '${d.partyType.index}|${d.entityId ?? ''}';
      final agg = entityData.putIfAbsent(
        key,
        () => _EntityAggregator(d.partyType, d.entityId),
      );
      agg.names.add(d.entityName);
      agg.accountIds.add(d.accountId);
      if (d.isReversal) {
        agg.reversalAmount += d.amountQirsh;
      } else {
        agg.grossAmount += d.amountQirsh;
      }
      agg.detailCount++;
    }

    final customerSummaries = <AdvancesAndRefundsEntitySummary>[];
    final supplierSummaries = <AdvancesAndRefundsEntitySummary>[];

    for (final agg in entityData.values) {
      final resolvedName =
          agg.names.reduce((a, b) => a.length >= b.length ? a : b);
      final summary = AdvancesAndRefundsEntitySummary(
        partyType: agg.partyType,
        entityId: agg.resolvedEntityId,
        entityName: resolvedName,
        grossAmount: agg.grossAmount,
        reversalAmount: agg.reversalAmount,
        netAmount: agg.grossAmount - agg.reversalAmount,
        accountCount: agg.accountIds.length,
        detailCount: agg.detailCount,
      );
      if (agg.partyType == AdvancesAndRefundsPartyType.customer) {
        customerSummaries.add(summary);
      } else {
        supplierSummaries.add(summary);
      }
    }

    customerSummaries.sort((a, b) {
      final cmp = a.entityName.compareTo(b.entityName);
      if (cmp != 0) return cmp;
      final aId = a.entityId ?? '';
      final bId = b.entityId ?? '';
      return aId.compareTo(bId);
    });

    supplierSummaries.sort((a, b) {
      final cmp = a.entityName.compareTo(b.entityName);
      if (cmp != 0) return cmp;
      final aId = a.entityId ?? '';
      final bId = b.entityId ?? '';
      return aId.compareTo(bId);
    });

    return AdvancesAndRefundsReport(
      fromDate: effectiveFrom,
      toDate: effectiveTo,
      details: details,
      accountSummaries: accountSummaries,
      customerSummaries: customerSummaries,
      supplierSummaries: supplierSummaries,
      totalCustomerGrossRefundOutflow: totalCustomerGross,
      totalCustomerRefundReversals: totalCustomerRev,
      totalCustomerNetRefundOutflow: totalCustomerGross - totalCustomerRev,
      totalSupplierGrossRefundInflow: totalSupplierGross,
      totalSupplierRefundReversals: totalSupplierRev,
      totalSupplierNetRefundInflow: totalSupplierGross - totalSupplierRev,
      signedGrandCashEffect: (totalSupplierGross - totalSupplierRev) -
          (totalCustomerGross - totalCustomerRev),
    );
  }

  Future<ExpenseAnalysisReport> expenseAnalysisReport({
    DateTime? fromDate,
    DateTime? toDate,
    String? accountIdFilter,
    PaymentMethod? paymentMethodFilter,
    String? categoryFilter,
  }) async {
    final effectiveFrom =
        fromDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    final effectiveTo = toDate ?? DateTime.now();

    final expenseRepo = _expenseRepository;
    if (expenseRepo == null) {
      return ExpenseAnalysisReport(
        fromDate: effectiveFrom,
        toDate: effectiveTo,
        rows: const [],
        totalQirsh: 0,
        grandCount: 0,
        allDetails: const [],
      );
    }

    final expenses = await expenseRepo.listExpenses();
    final accounts = await _repository.listAccounts(includeInactive: true);
    final accountMap = {for (final a in accounts) a.id: a.name};

    var filtered = expenses
        .where((e) => _isInRange(e.date, effectiveFrom, effectiveTo))
        .toList();

    if (accountIdFilter != null) {
      filtered = filtered
          .where((e) => e.financialAccountId == accountIdFilter)
          .toList();
    }

    if (paymentMethodFilter != null) {
      filtered = filtered
          .where((e) => e.paymentMethod == paymentMethodFilter)
          .toList();
    }

    if (categoryFilter != null && categoryFilter.trim().isNotEmpty) {
      final searchLower = categoryFilter.trim().toLowerCase();
      filtered = filtered.where((e) {
        return e.category.toLowerCase().contains(searchLower);
      }).toList();
    }

    final details = <ExpenseAnalysisReportDetail>[];
    for (final expense in filtered) {
      details.add(ExpenseAnalysisReportDetail(
        expenseId: expense.id,
        date: expense.date,
        createdAt: expense.createdAt,
        category: expense.category,
        amountQirsh: expense.amountQirsh,
        paymentMethodLabel: expense.paymentMethod?.labelAr ?? 'غير محدد',
        accountName: expense.financialAccountId != null
            ? (accountMap[expense.financialAccountId] ?? 'غير محدد')
            : 'غير محدد',
        notes: expense.notes,
      ));
    }

    details.sort((a, b) {
      final cmp = b.date.compareTo(a.date);
      if (cmp != 0) return cmp;
      final cmp2 = b.createdAt.compareTo(a.createdAt);
      if (cmp2 != 0) return cmp2;
      return a.expenseId.compareTo(b.expenseId);
    });

    final grouped = <String, List<ExpenseAnalysisReportDetail>>{};
    for (final detail in details) {
      grouped.putIfAbsent(detail.category, () => []).add(detail);
    }

    var totalQirsh = 0;
    var grandCount = 0;
    for (final detail in details) {
      totalQirsh += detail.amountQirsh;
      grandCount++;
    }

    final rows = <ExpenseAnalysisReportRow>[];
    for (final entry in grouped.entries) {
      var catTotal = 0;
      var catCount = 0;
      for (final d in entry.value) {
        catTotal += d.amountQirsh;
        catCount++;
      }
      final pct = totalQirsh > 0 ? catTotal / totalQirsh * 100.0 : 0.0;
      rows.add(ExpenseAnalysisReportRow(
        category: entry.key,
        totalAmountQirsh: catTotal,
        count: catCount,
        percentageOfTotal: pct,
        details: entry.value,
      ));
    }

    rows.sort((a, b) {
      final cmp = b.totalAmountQirsh.compareTo(a.totalAmountQirsh);
      if (cmp != 0) return cmp;
      return a.category.compareTo(b.category);
    });

    return ExpenseAnalysisReport(
      fromDate: effectiveFrom,
      toDate: effectiveTo,
      rows: rows,
      totalQirsh: totalQirsh,
      grandCount: grandCount,
      allDetails: details,
    );
  }
}

class _ResolvedCustomer {
  const _ResolvedCustomer(this.customerId, this.customerName);
  final String? customerId;
  final String? customerName;
}

abstract class SupplierSettlementReportLookup {
  Future<String?> supplierIdForPayment(String paymentId);
  Future<String?> supplierIdForReversalEntry(
      FinancialAccountEntry reversalEntry);
  Future<String> supplierNameForId(String supplierId);
}

class _ResolvedSupplier {
  const _ResolvedSupplier(this.supplierId, this.supplierName);
  final String? supplierId;
  final String? supplierName;
}

class _EntityAggregator {
  _EntityAggregator(this.partyType, this._entityId);
  final AdvancesAndRefundsPartyType partyType;
  final String? _entityId;
  final Set<String> names = {};
  final Set<String> accountIds = {};
  int grossAmount = 0;
  int reversalAmount = 0;
  int detailCount = 0;

  String? get resolvedEntityId => _entityId;
}
