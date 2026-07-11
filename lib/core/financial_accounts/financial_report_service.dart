import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_models.dart';

class FinancialReportService {
  const FinancialReportService({required FinancialAccountRepository repository})
      : _repository = repository;

  final FinancialAccountRepository _repository;

  static bool _isInRange(DateTime value, DateTime start, DateTime end) {
    return !value.isBefore(start) && !value.isAfter(end);
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
}
