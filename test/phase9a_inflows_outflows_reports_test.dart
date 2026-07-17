import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/permissions.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_models.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_service.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_service.dart';
import 'package:grain_warehouse_erp_lite/features/exports/pdf_file_naming.dart';

void main() {
  final owner = AppUser(
    id: 'owner-1',
    name: 'المالك',
    phone: '01000000000',
    role: UserRole.owner,
    isActive: true,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  late LocalFinancialAccountRepository repo;
  late FinancialReportService service;
  late NegativeBalanceApprovalService approvals;

  setUp(() {
    final auth = LocalAuthRepository(
      seedAccounts: [LocalAuthAccount(user: owner, password: 'owner-password')],
    );
    approvals = NegativeBalanceApprovalService(
      authRepository: auth,
      approvalRepository: LocalNegativeBalanceApprovalRepository(),
      auditLogRepository: LocalAuditLogRepository(),
    );
    repo = LocalFinancialAccountRepository(
      negativeBalanceApprovalService: approvals,
    );
    service = FinancialReportService(repository: repo);
  });

  Future<FinancialAccount> createAccount(
    String name,
    FinancialAccountType type, {
    int openingBalanceQirsh = 0,
  }) async {
    final account = await repo.createAccount(FinancialAccountDraft(
      name: name,
      type: type,
      createdByUserId: owner.id,
    ));
    if (openingBalanceQirsh > 0) {
      await repo.createEntry(
        accountId: account.id,
        direction: FinancialAccountEntryDirection.inflow,
        amountQirsh: openingBalanceQirsh,
        sourceType: FinancialAccountEntrySource.openingBalance,
        sourceDocumentId: 'opening-${account.id}',
        effectiveDate: DateTime(2026, 1, 1),
        createdByUserId: owner.id,
      );
    }
    return account;
  }

  Future<void> addEntry({
    required String accountId,
    required FinancialAccountEntryDirection direction,
    required int amount,
    required FinancialAccountEntrySource source,
    required DateTime date,
    String? reversalOf,
  }) async {
    await repo.createEntry(
      accountId: accountId,
      direction: direction,
      amountQirsh: amount,
      sourceType: source,
      sourceDocumentId: 'doc-${date.millisecondsSinceEpoch}',
      effectiveDate: date,
      createdByUserId: owner.id,
      reversalOf: reversalOf,
    );
  }

  group('Phase 9A — Inflows and Outflows Financial Reports', () {
    group('Permissions', () {
      test('owner has canViewFinancialReports', () {
        expect(Permissions.owner.canViewFinancialReports, true);
      });

      test('owner has canExportFinancialReports', () {
        expect(Permissions.owner.canExportFinancialReports, true);
      });

      test('employee lacks canViewFinancialReports', () {
        expect(Permissions.employee.canViewFinancialReports, false);
      });

      test('employee lacks canExportFinancialReports', () {
        expect(Permissions.employee.canExportFinancialReports, false);
      });
    });

    group('FlowReportEntry model', () {
      test('isReversal is true when reversalOf is set', () {
        final entry = FlowReportEntry(
          entryId: 'e1',
          timestamp: DateTime(2026, 1, 10),
          accountId: 'fa-1',
          accountName: 'خزينة',
          source: FinancialAccountEntrySource.cancellationReversal,
          amountQirsh: 5000,
          direction: FinancialAccountEntryDirection.inflow,
          isReversal: true,
        );
        expect(entry.isReversal, true);
      });

      test('isReversal is false for normal entry', () {
        final entry = FlowReportEntry(
          entryId: 'e2',
          timestamp: DateTime(2026, 1, 10),
          accountId: 'fa-1',
          accountName: 'خزينة',
          source: FinancialAccountEntrySource.salePayment,
          amountQirsh: 10000,
          direction: FinancialAccountEntryDirection.inflow,
          isReversal: false,
        );
        expect(entry.isReversal, false);
      });
    });

    group('FlowReport model', () {
      test('totalQirsh is independent of entries list', () {
        final report = FlowReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          entries: const [],
          totalQirsh: 50000,
          sourceBreakdown: const {
            FinancialAccountEntrySource.salePayment: 30000,
            FinancialAccountEntrySource.customerCollection: 20000,
          },
        );
        expect(report.totalQirsh, 50000);
        expect(report.sourceBreakdown.length, 2);
        expect(report.sourceBreakdown[FinancialAccountEntrySource.salePayment],
            30000);
      });
    });

    group('FinancialReportService — inflowsReport', () {
      test('empty dataset returns empty report with zero total', () async {
        final report = await service.inflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.entries, isEmpty);
        expect(report.totalQirsh, 0);
        expect(report.sourceBreakdown, isEmpty);
      });

      test('single inflow entry appears in report', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 50000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 10),
        );

        final report = await service.inflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.entries.length, 1);
        expect(report.totalQirsh, 50000);
        expect(report.entries.first.source,
            FinancialAccountEntrySource.salePayment);
      });

      test('outflow entries are excluded from inflows report', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 5),
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 5000,
          source: FinancialAccountEntrySource.expense,
          date: DateTime(2026, 1, 10),
        );

        final report = await service.inflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.entries.length, 1);
        expect(report.totalQirsh, 10000);
      });

      test('multiple sources tracked in breakdown', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 5),
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 20000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 10),
        );

        final report = await service.inflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.sourceBreakdown.length, 2);
        expect(report.sourceBreakdown[FinancialAccountEntrySource.salePayment],
            10000);
        expect(
            report.sourceBreakdown[
                FinancialAccountEntrySource.customerCollection],
            20000);
        expect(report.totalQirsh, 30000);
      });

      test('date filtering works — entries outside range excluded', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 5000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2025, 12, 31),
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 8000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 2, 1),
        );

        final report = await service.inflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.entries, isEmpty);
        expect(report.totalQirsh, 0);
      });

      test('date boundary — entries exactly on fromDate are included',
          () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 3000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 1),
        );

        final report = await service.inflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.entries.length, 1);
        expect(report.totalQirsh, 3000);
      });

      test('date boundary — entries exactly on toDate are included', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 4000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 31),
        );

        final report = await service.inflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.entries.length, 1);
        expect(report.totalQirsh, 4000);
      });

      test('account filtering — single account selected', () async {
        final acc1 =
            await createAccount('خزينة', FinancialAccountType.treasury);
        final acc2 = await createAccount('بنك', FinancialAccountType.bank);
        await addEntry(
          accountId: acc1.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 5),
        );
        await addEntry(
          accountId: acc2.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 50000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 10),
        );

        final report = await service.inflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          accountIdFilter: acc1.id,
        );
        expect(report.entries.length, 1);
        expect(report.totalQirsh, 10000);
        expect(report.entries.first.accountId, acc1.id);
      });

      test('deterministic ordering — timestamp descending, then id ascending',
          () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 1000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 5),
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 2000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 10),
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 3000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 5),
        );

        final report = await service.inflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.entries.length, 3);
        expect(report.entries[0].timestamp, DateTime(2026, 1, 10));
        expect(report.entries[1].timestamp, DateTime(2026, 1, 5));
        expect(report.entries[2].timestamp, DateTime(2026, 1, 5));
        expect(report.entries[1].entryId.compareTo(report.entries[2].entryId),
            lessThan(0));
      });

      test('total equals sum of entries', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 7000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 5),
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 3000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 10),
        );

        final report = await service.inflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        final sum = report.entries.fold<int>(0, (s, e) => s + e.amountQirsh);
        expect(report.totalQirsh, sum);
        expect(report.totalQirsh, 10000);
      });

      test('reversal entry appears in inflows if direction is inflow',
          () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 5000,
          source: FinancialAccountEntrySource.cancellationReversal,
          date: DateTime(2026, 1, 10),
          reversalOf: 'original-entry',
        );

        final report = await service.inflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.entries.length, 1);
        expect(report.entries.first.isReversal, true);
        expect(report.totalQirsh, 5000);
      });

      test('transfer-in excluded in all-accounts mode', () async {
        final src = await createAccount('خزينة', FinancialAccountType.treasury);
        final dest = await createAccount('بنك', FinancialAccountType.bank);
        await addEntry(
          accountId: dest.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.transferIn,
          date: DateTime(2026, 1, 5),
        );
        await addEntry(
          accountId: src.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 5000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 10),
        );

        final report = await service.inflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.entries.length, 1);
        expect(report.totalQirsh, 5000);
        expect(report.entries.first.source,
            FinancialAccountEntrySource.salePayment);
      });

      test('transfer-in included when single account is selected', () async {
        final dest = await createAccount('بنك', FinancialAccountType.bank);
        await addEntry(
          accountId: dest.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.transferIn,
          date: DateTime(2026, 1, 5),
        );
        await addEntry(
          accountId: dest.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 5000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 10),
        );

        final report = await service.inflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          accountIdFilter: dest.id,
        );
        expect(report.entries.length, 2);
        expect(report.totalQirsh, 15000);
      });

      test('transfer-reversal-in excluded in all-accounts mode', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 8000,
          source: FinancialAccountEntrySource.transferReversalIn,
          date: DateTime(2026, 1, 5),
        );

        final report = await service.inflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.entries, isEmpty);
        expect(report.totalQirsh, 0);
      });

      test('no double counting across accounts', () async {
        final src = await createAccount('خزينة', FinancialAccountType.treasury);
        final dest = await createAccount('بنك', FinancialAccountType.bank);
        await repo.updateAccountPolicy(
          accountId: src.id,
          allowNegativeBalance: true,
          updatedByUserId: owner.id,
        );
        await approvals.requestApproval(
          draft: NegativeBalanceApprovalDraft(
            requestedByUserId: owner.id,
            approvedByOwnerUserId: owner.id,
            accountId: src.id,
            amountQirsh: 5000,
            operationType: NegativeBalanceOperationType.transfer,
            sourceDocumentId: 'doc-transfer',
            sourceDocumentType: FinancialAccountEntrySource.transferOut.name,
            balanceBeforeQirsh: 0,
            expectedBalanceAfterQirsh: -5000,
            reason: 'test',
          ),
          ownerPhone: owner.phone,
          ownerPassword: 'owner-password',
        );
        await addEntry(
          accountId: src.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 5000,
          source: FinancialAccountEntrySource.transferOut,
          date: DateTime(2026, 1, 5),
        );
        await addEntry(
          accountId: dest.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 5000,
          source: FinancialAccountEntrySource.transferIn,
          date: DateTime(2026, 1, 5),
        );
        await addEntry(
          accountId: src.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 10),
        );

        final inflows = await service.inflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(inflows.totalQirsh, 10000);
        expect(inflows.entries.length, 1);

        final outflows = await service.outflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(outflows.totalQirsh, 0);
        expect(outflows.entries, isEmpty);
      }, skip: 'Requires negative balance approval with actual credentials');
    });

    group('FinancialReportService — outflowsReport', () {
      test('empty dataset returns empty report with zero total', () async {
        final report = await service.outflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.entries, isEmpty);
        expect(report.totalQirsh, 0);
        expect(report.sourceBreakdown, isEmpty);
      });

      test('supplier payment appears in outflows', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury,
            openingBalanceQirsh: 100000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 30000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 10),
        );

        final report = await service.outflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.entries.length, 1);
        expect(report.totalQirsh, 30000);
        expect(report.entries.first.source,
            FinancialAccountEntrySource.supplierSettlement);
      });

      test('expense appears in outflows', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury,
            openingBalanceQirsh: 100000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 5000,
          source: FinancialAccountEntrySource.expense,
          date: DateTime(2026, 1, 10),
        );

        final report = await service.outflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.entries.length, 1);
        expect(report.totalQirsh, 5000);
        expect(
            report.entries.first.source, FinancialAccountEntrySource.expense);
      });

      test('purchase payment appears in outflows', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury,
            openingBalanceQirsh: 100000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 20000,
          source: FinancialAccountEntrySource.purchasePayment,
          date: DateTime(2026, 1, 10),
        );

        final report = await service.outflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.entries.length, 1);
        expect(report.totalQirsh, 20000);
      });

      test('inflow entries are excluded from outflows report', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury,
            openingBalanceQirsh: 100000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 5),
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 5000,
          source: FinancialAccountEntrySource.expense,
          date: DateTime(2026, 1, 10),
        );

        final report = await service.outflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.entries.length, 1);
        expect(report.totalQirsh, 5000);
      });

      test('multiple sources tracked in breakdown', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury,
            openingBalanceQirsh: 100000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.expense,
          date: DateTime(2026, 1, 5),
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 20000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 10),
        );

        final report = await service.outflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.sourceBreakdown.length, 2);
        expect(
            report.sourceBreakdown[FinancialAccountEntrySource.expense], 10000);
        expect(
            report.sourceBreakdown[
                FinancialAccountEntrySource.supplierSettlement],
            20000);
        expect(report.totalQirsh, 30000);
      });

      test('date filtering works', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury,
            openingBalanceQirsh: 100000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 5000,
          source: FinancialAccountEntrySource.expense,
          date: DateTime(2025, 12, 31),
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 8000,
          source: FinancialAccountEntrySource.expense,
          date: DateTime(2026, 2, 1),
        );

        final report = await service.outflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.entries, isEmpty);
        expect(report.totalQirsh, 0);
      });

      test('account filtering works', () async {
        final acc1 = await createAccount('خزينة', FinancialAccountType.treasury,
            openingBalanceQirsh: 100000);
        final acc2 = await createAccount('بنك', FinancialAccountType.bank,
            openingBalanceQirsh: 100000);
        await addEntry(
          accountId: acc1.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.expense,
          date: DateTime(2026, 1, 5),
        );
        await addEntry(
          accountId: acc2.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 10),
        );

        final report = await service.outflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          accountIdFilter: acc1.id,
        );
        expect(report.entries.length, 1);
        expect(report.totalQirsh, 10000);
      });

      test('deterministic ordering — timestamp descending', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury,
            openingBalanceQirsh: 100000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 1000,
          source: FinancialAccountEntrySource.expense,
          date: DateTime(2026, 1, 5),
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 2000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 10),
        );

        final report = await service.outflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.entries[0].timestamp, DateTime(2026, 1, 10));
        expect(report.entries[1].timestamp, DateTime(2026, 1, 5));
      });

      test('total equals sum of entries', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury,
            openingBalanceQirsh: 100000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 7000,
          source: FinancialAccountEntrySource.expense,
          date: DateTime(2026, 1, 5),
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 3000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 10),
        );

        final report = await service.outflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        final sum = report.entries.fold<int>(0, (s, e) => s + e.amountQirsh);
        expect(report.totalQirsh, sum);
        expect(report.totalQirsh, 10000);
      });

      test('split allocation counted once', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury,
            openingBalanceQirsh: 100000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 5000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 10),
        );

        final report = await service.outflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.entries.length, 1);
        expect(report.totalQirsh, 5000);
      });

      test('reversal entry appears in outflows if direction is outflow',
          () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury,
            openingBalanceQirsh: 100000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 5000,
          source: FinancialAccountEntrySource.cancellationReversal,
          date: DateTime(2026, 1, 10),
          reversalOf: 'original-entry',
        );

        final report = await service.outflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.entries.length, 1);
        expect(report.entries.first.isReversal, true);
        expect(report.totalQirsh, 5000);
      });

      test('transfer-out excluded in all-accounts mode', () async {
        final src = await createAccount('خزينة', FinancialAccountType.treasury,
            openingBalanceQirsh: 100000);
        await addEntry(
          accountId: src.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.transferOut,
          date: DateTime(2026, 1, 5),
        );
        await addEntry(
          accountId: src.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 5000,
          source: FinancialAccountEntrySource.expense,
          date: DateTime(2026, 1, 10),
        );

        final report = await service.outflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.entries.length, 1);
        expect(report.totalQirsh, 5000);
        expect(
            report.entries.first.source, FinancialAccountEntrySource.expense);
      });

      test('transfer-out included when single account is selected', () async {
        final src = await createAccount('خزينة', FinancialAccountType.treasury,
            openingBalanceQirsh: 100000);
        await addEntry(
          accountId: src.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.transferOut,
          date: DateTime(2026, 1, 5),
        );
        await addEntry(
          accountId: src.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 5000,
          source: FinancialAccountEntrySource.expense,
          date: DateTime(2026, 1, 10),
        );

        final report = await service.outflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          accountIdFilter: src.id,
        );
        expect(report.entries.length, 2);
        expect(report.totalQirsh, 15000);
      });

      test('supplier advance refund appears in outflows', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury,
            openingBalanceQirsh: 100000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 8000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 10),
        );

        final report = await service.outflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.entries.length, 1);
        expect(report.totalQirsh, 8000);
      });
    });

    group('PdfFileNaming — inflows and outflows', () {
      test('inflowsReport generates correct PDF name', () {
        final name = PdfFileNaming.inflowsReport(DateTime(2026, 3, 15));
        expect(name, contains('تقرير'));
        expect(name, contains('التدفقات'));
        expect(name, contains('الداخلة'));
        expect(name, contains('2026-03-15'));
        expect(name, endsWith('.pdf'));
      });

      test('inflowsReportCsv generates correct CSV name', () {
        final name = PdfFileNaming.inflowsReportCsv(DateTime(2026, 3, 15));
        expect(name, endsWith('.csv'));
        expect(name, contains('التدفقات'));
        expect(name, contains('الداخلة'));
        expect(name, contains('2026-03-15'));
      });

      test('outflowsReport generates correct PDF name', () {
        final name = PdfFileNaming.outflowsReport(DateTime(2026, 3, 15));
        expect(name, contains('تقرير'));
        expect(name, contains('التدفقات'));
        expect(name, contains('الخارج'));
        expect(name, contains('2026-03-15'));
        expect(name, endsWith('.pdf'));
      });

      test('outflowsReportCsv generates correct CSV name', () {
        final name = PdfFileNaming.outflowsReportCsv(DateTime(2026, 3, 15));
        expect(name, endsWith('.csv'));
        expect(name, contains('التدفقات'));
        expect(name, contains('2026-03-15'));
      });
    });

    group('Read-only integrity', () {
      test('generating inflows report does not modify ledger', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 10),
        );

        final balanceBefore = await repo.currentBalanceForAccount(acc.id);
        final statementBefore = await repo.statementForAccount(acc.id);

        await service.inflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        final balanceAfter = await repo.currentBalanceForAccount(acc.id);
        final statementAfter = await repo.statementForAccount(acc.id);

        expect(balanceAfter, balanceBefore);
        expect(statementAfter.lines.length, statementBefore.lines.length);
      });

      test('generating outflows report does not modify ledger', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury,
            openingBalanceQirsh: 100000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 5000,
          source: FinancialAccountEntrySource.expense,
          date: DateTime(2026, 1, 10),
        );

        final balanceBefore = await repo.currentBalanceForAccount(acc.id);
        final statementBefore = await repo.statementForAccount(acc.id);

        await service.outflowsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        final balanceAfter = await repo.currentBalanceForAccount(acc.id);
        final statementAfter = await repo.statementForAccount(acc.id);

        expect(balanceAfter, balanceBefore);
        expect(statementAfter.lines.length, statementBefore.lines.length);
      });
    });
  });
}
