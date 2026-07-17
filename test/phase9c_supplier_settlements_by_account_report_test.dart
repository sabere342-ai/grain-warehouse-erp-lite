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
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_service.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_repository.dart';
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

  setUp(() {
    final auth = LocalAuthRepository(
      seedAccounts: [LocalAuthAccount(user: owner, password: 'owner-password')],
    );
    final approvals = NegativeBalanceApprovalService(
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
    FinancialAccountType type,
  ) async {
    return repo.createAccount(FinancialAccountDraft(
      name: name,
      type: type,
      createdByUserId: owner.id,
    ));
  }

  Future<FinancialAccountEntry> addEntry({
    required String accountId,
    required FinancialAccountEntryDirection direction,
    required int amount,
    required FinancialAccountEntrySource source,
    required DateTime date,
    required String sourceDocumentId,
    String? reversalOf,
    String? reference,
  }) async {
    return repo.createEntry(
      accountId: accountId,
      direction: direction,
      amountQirsh: amount,
      sourceType: source,
      sourceDocumentId: sourceDocumentId,
      effectiveDate: date,
      createdByUserId: owner.id,
      reversalOf: reversalOf,
      reference: reference,
    );
  }

  Future<void> seedOpeningBalance(String accountId, int amount) async {
    await addEntry(
      accountId: accountId,
      direction: FinancialAccountEntryDirection.inflow,
      amount: amount,
      source: FinancialAccountEntrySource.openingBalance,
      date: DateTime(2025, 12, 31),
      sourceDocumentId: 'opening-balance',
    );
  }

  group('Phase 9C — Supplier Settlements by Financial Account Report', () {
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

    group('Empty state', () {
      test('empty repositories returns empty report with zero totals',
          () async {
        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.details, isEmpty);
        expect(report.accountSummaries, isEmpty);
        expect(report.supplierSummaries, isEmpty);
        expect(report.totalGrossSettlementsQirsh, 0);
        expect(report.totalReversalsQirsh, 0);
        expect(report.totalNetSettlementsQirsh, 0);
      });
    });

    group('Single supplier settlement', () {
      test('one settlement in one account', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final entry = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'pay-1',
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 1);
        expect(report.details.first.entryId, entry.id);
        expect(report.details.first.amountQirsh, 50000);
        expect(report.details.first.isReversal, false);
        expect(report.details.first.accountId, acc.id);
        expect(report.totalGrossSettlementsQirsh, 50000);
        expect(report.totalReversalsQirsh, 0);
        expect(report.totalNetSettlementsQirsh, 50000);
        expect(report.accountSummaries.length, 1);
        expect(report.accountSummaries.first.grossSettlementsQirsh, 50000);
      });
    });

    group('Multiple suppliers in one account', () {
      test('two suppliers settlement in same account', () async {
        final acc = await createAccount('بنك', FinancialAccountType.bank);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 30000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 20000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'pay-2',
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 2);
        expect(report.totalGrossSettlementsQirsh, 50000);
        expect(report.accountSummaries.length, 1);
        expect(report.accountSummaries.first.grossSettlementsQirsh, 50000);
      });
    });

    group('One supplier with multiple settlements across accounts', () {
      test('same supplier across multiple financial accounts', () async {
        final acc1 =
            await createAccount('خزينة', FinancialAccountType.treasury);
        final acc2 = await createAccount('بنك', FinancialAccountType.bank);
        await seedOpeningBalance(acc1.id, 1000000);
        await seedOpeningBalance(acc2.id, 1000000);
        await addEntry(
          accountId: acc1.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-1',
        );
        await addEntry(
          accountId: acc2.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 15000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 8),
          sourceDocumentId: 'pay-2',
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 2);
        expect(report.totalGrossSettlementsQirsh, 25000);
        expect(report.accountSummaries.length, 2);
      });
    });

    group('Multiple suppliers and multiple accounts', () {
      test('correct breakdown across accounts and suppliers', () async {
        final acc1 =
            await createAccount('خزينة', FinancialAccountType.treasury);
        final acc2 = await createAccount('بنك', FinancialAccountType.bank);
        await seedOpeningBalance(acc1.id, 1000000);
        await seedOpeningBalance(acc2.id, 1000000);
        await addEntry(
          accountId: acc1.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-1',
        );
        await addEntry(
          accountId: acc1.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 20000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 8),
          sourceDocumentId: 'pay-2',
        );
        await addEntry(
          accountId: acc2.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 30000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'pay-3',
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 3);
        expect(report.totalGrossSettlementsQirsh, 60000);
        expect(report.accountSummaries.length, 2);
        expect(report.accountSummaries[0].grossSettlementsQirsh, 30000);
        expect(report.accountSummaries[1].grossSettlementsQirsh, 30000);
      });
    });

    group('Each entry counted exactly once', () {
      test('no fabricated split-payment grouping', () async {
        final acc1 =
            await createAccount('خزينة', FinancialAccountType.treasury);
        final acc2 = await createAccount('بنك', FinancialAccountType.bank);
        await seedOpeningBalance(acc1.id, 1000000);
        await seedOpeningBalance(acc2.id, 1000000);
        await addEntry(
          accountId: acc1.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-split',
        );
        await addEntry(
          accountId: acc2.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 15000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-split',
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 2);
        final sumDetails =
            report.details.fold<int>(0, (s, d) => s + d.amountQirsh);
        expect(sumDetails, 25000);
        expect(report.totalGrossSettlementsQirsh, 25000);
        expect(report.accountSummaries[0].grossSettlementsQirsh, 10000);
        expect(report.accountSummaries[1].grossSettlementsQirsh, 15000);
      });
    });

    group('Gross settlement total', () {
      test('gross equals sum of all settlement entries', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 30000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 20000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'pay-2',
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.totalGrossSettlementsQirsh, 50000);
      });
    });

    group('Partial cancellation reversal', () {
      test('partial reversal reduces net correctly', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final original = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 20000,
          source: FinancialAccountEntrySource.cancellationReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'cancel-1',
          reversalOf: original.id,
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.totalGrossSettlementsQirsh, 50000);
        expect(report.totalReversalsQirsh, 20000);
        expect(report.totalNetSettlementsQirsh, 30000);
        expect(report.details.length, 2);
        expect(report.details.any((d) => d.isReversal), true);
        expect(report.details.any((d) => !d.isReversal), true);
      });
    });

    group('Full cancellation reversal', () {
      test('full reversal zeroes net', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final original = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 50000,
          source: FinancialAccountEntrySource.cancellationReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'cancel-1',
          reversalOf: original.id,
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.totalGrossSettlementsQirsh, 50000);
        expect(report.totalReversalsQirsh, 50000);
        expect(report.totalNetSettlementsQirsh, 0);
      });
    });

    group('Net equals gross minus reversal', () {
      test('arithmetic invariant holds', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final original = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 80000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 30000,
          source: FinancialAccountEntrySource.cancellationReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'cancel-1',
          reversalOf: original.id,
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.totalNetSettlementsQirsh,
            report.totalGrossSettlementsQirsh - report.totalReversalsQirsh);
      });
    });

    group('Qualified cancellation reversal linked to settlement', () {
      test('cancellation reversal linked to original settlement is counted',
          () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final original = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 50000,
          source: FinancialAccountEntrySource.cancellationReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'cancel-1',
          reversalOf: original.id,
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.totalGrossSettlementsQirsh, 50000);
        expect(report.totalReversalsQirsh, 50000);
        expect(report.totalNetSettlementsQirsh, 0);
      });
    });

    group('Generic unlinked cancellation reversal excluded', () {
      test('cancellation reversal without reversalOf is excluded', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.cancellationReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'cancel-orphan',
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 1);
        expect(report.details.first.sourceType,
            FinancialAccountEntrySource.supplierSettlement);
        expect(report.totalGrossSettlementsQirsh, 50000);
        expect(report.totalReversalsQirsh, 0);
        expect(report.totalNetSettlementsQirsh, 50000);
      });
    });

    group('Cancellation reversal linked to non-supplier source excluded', () {
      test('cancellation reversal linked to customer collection excluded',
          () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final originalCol = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 50000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'col-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.cancellationReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'cancel-col',
          reversalOf: originalCol.id,
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 30000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 15),
          sourceDocumentId: 'pay-1',
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 1);
        expect(report.details.first.sourceType,
            FinancialAccountEntrySource.supplierSettlement);
        expect(report.totalGrossSettlementsQirsh, 30000);
        expect(report.totalReversalsQirsh, 0);
      });
    });

    group('supplierAdvanceRefund excluded', () {
      test('supplier advance refund alone is excluded', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 8000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'saref-1',
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details, isEmpty);
        expect(report.totalGrossSettlementsQirsh, 0);
        expect(report.totalReversalsQirsh, 0);
      });
    });

    group('supplierAdvanceRefundReversal excluded', () {
      test('supplier advance refund reversal is excluded', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final originalRefund = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 8000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'saref-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 8000,
          source: FinancialAccountEntrySource.supplierAdvanceRefundReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'saref-rev-1',
          reversalOf: originalRefund.id,
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details, isEmpty);
        expect(report.totalGrossSettlementsQirsh, 0);
        expect(report.totalReversalsQirsh, 0);
      });
    });

    group('purchasePayment excluded', () {
      test('purchase payment is excluded', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 25000,
          source: FinancialAccountEntrySource.purchasePayment,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'ppay-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 15000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'pay-1',
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 1);
        expect(report.totalGrossSettlementsQirsh, 15000);
      });
    });

    group('Expense and unrelated sources excluded', () {
      test('expenses and sale payments excluded', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 5000,
          source: FinancialAccountEntrySource.expense,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'exp-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 8),
          sourceDocumentId: 'sale-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 30000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 15),
          sourceDocumentId: 'pay-1',
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 1);
        expect(report.totalGrossSettlementsQirsh, 30000);
      });
    });

    group('Account filter', () {
      test('filtering by account shows only that account', () async {
        final acc1 =
            await createAccount('خزينة', FinancialAccountType.treasury);
        final acc2 = await createAccount('بنك', FinancialAccountType.bank);
        await seedOpeningBalance(acc1.id, 1000000);
        await seedOpeningBalance(acc2.id, 1000000);
        await addEntry(
          accountId: acc1.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-1',
        );
        await addEntry(
          accountId: acc2.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'pay-2',
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          accountIdFilter: acc1.id,
        );

        expect(report.details.length, 1);
        expect(report.totalGrossSettlementsQirsh, 10000);
        expect(report.accountSummaries.length, 1);
        expect(report.accountSummaries.first.account.id, acc1.id);
      });
    });

    group('Supplier filter', () {
      test('filtering by supplierId without lookup returns empty', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 20000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'pay-2',
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          supplierIdFilter: 'sup-1',
        );

        expect(report.details, isEmpty);
        expect(report.totalGrossSettlementsQirsh, 0);
      });

      test('filtering by null supplierId includes all', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 20000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'pay-2',
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 2);
        expect(report.totalGrossSettlementsQirsh, 30000);
      });
    });

    group('Unresolved supplier handling', () {
      test('without lookup all suppliers are unresolved', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-1',
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.first.supplierName, 'مورد غير محدد');
        expect(report.details.first.supplierId, isNull);
        expect(report.supplierSummaries.length, 1);
        expect(report.supplierSummaries.first.isUnresolved, true);
        expect(report.supplierSummaries.first.supplierName, 'مورد غير محدد');
      });

      test('unresolved supplier excluded from a resolved supplier filter',
          () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-1',
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          supplierIdFilter: 'sup-1',
        );

        expect(report.details, isEmpty);
        expect(report.totalGrossSettlementsQirsh, 0);
      });
    });

    group('Date boundaries', () {
      test('start-date boundary included', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 5000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 1),
          sourceDocumentId: 'pay-1',
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 1);
        expect(report.totalGrossSettlementsQirsh, 5000);
      });

      test('end-date boundary included', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 4000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 31),
          sourceDocumentId: 'pay-1',
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 1);
        expect(report.totalGrossSettlementsQirsh, 4000);
      });

      test('entries outside range excluded', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 5000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2025, 12, 31),
          sourceDocumentId: 'pay-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 8000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 2, 1),
          sourceDocumentId: 'pay-2',
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details, isEmpty);
        expect(report.totalGrossSettlementsQirsh, 0);
      });
    });

    group('Reversal inherits supplier identity from original settlement', () {
      test('reversal of supplier settlement follows original linkage',
          () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final original = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-1',
          reference: 'تسوية مع مورد أحمد',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 50000,
          source: FinancialAccountEntrySource.cancellationReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'cancel-1',
          reversalOf: original.id,
          reference: 'عكس التسوية pay-1',
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 2);
        final originalDetail = report.details.firstWhere((d) => !d.isReversal);
        final reversalDetail = report.details.firstWhere((d) => d.isReversal);
        expect(reversalDetail.reversalOfEntryId, originalDetail.entryId);
        expect(report.totalNetSettlementsQirsh, 0);
      });
    });

    group('Existing constructor compatibility', () {
      test('FinancialReportService with only repository still works', () async {
        final svc = FinancialReportService(repository: repo);
        final report = await svc.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.details, isEmpty);
        expect(report.totalGrossSettlementsQirsh, 0);
      });
    });

    group('Deterministic ordering', () {
      test('accounts sorted by name', () async {
        final acc1 = await createAccount('بنك', FinancialAccountType.bank);
        final acc2 =
            await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc1.id, 1000000);
        await seedOpeningBalance(acc2.id, 1000000);
        await addEntry(
          accountId: acc2.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-1',
        );
        await addEntry(
          accountId: acc1.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 20000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'pay-2',
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.accountSummaries[0].account.name, 'بنك');
        expect(report.accountSummaries[1].account.name, 'خزينة');
      });

      test('details sorted by account name then supplier then timestamp desc',
          () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 1000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-early',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 2000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'pay-late',
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details[0].timestamp, DateTime(2026, 1, 10));
        expect(report.details[1].timestamp, DateTime(2026, 1, 5));
      });

      test('deterministic entry ID tie-breaker', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 1000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-a',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 2000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-b',
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 2);
        final ids = report.details.map((d) => d.entryId).toList();
        expect(ids, ids.toList()..sort());
      });

      test('deterministic supplier ordering with duplicate names', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 1000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 2000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'pay-2',
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.supplierSummaries.length, 1);
      });
    });

    group('Reconciliation invariants', () {
      test('account totals reconcile with detailed entries', () async {
        final acc1 =
            await createAccount('خزينة', FinancialAccountType.treasury);
        final acc2 = await createAccount('بنك', FinancialAccountType.bank);
        await seedOpeningBalance(acc1.id, 1000000);
        await seedOpeningBalance(acc2.id, 1000000);
        await addEntry(
          accountId: acc1.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-1',
        );
        await addEntry(
          accountId: acc2.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 20000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'pay-2',
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        final accountGrossSum = report.accountSummaries
            .fold<int>(0, (s, a) => s + a.grossSettlementsQirsh);
        expect(accountGrossSum, report.totalGrossSettlementsQirsh);
      });

      test('account reversals reconcile', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final original = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.cancellationReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'cancel-1',
          reversalOf: original.id,
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        final accountRevSum = report.accountSummaries
            .fold<int>(0, (s, a) => s + a.reversalsQirsh);
        expect(accountRevSum, report.totalReversalsQirsh);
      });

      test('account net reconcile', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final original = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.cancellationReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'cancel-1',
          reversalOf: original.id,
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        final accountNetSum = report.accountSummaries
            .fold<int>(0, (s, a) => s + a.netSettlementsQirsh);
        expect(accountNetSum, report.totalNetSettlementsQirsh);
      });

      test('grand totals reconcile with account and supplier summaries',
          () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final original = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.cancellationReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'cancel-1',
          reversalOf: original.id,
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.totalNetSettlementsQirsh,
            report.totalGrossSettlementsQirsh - report.totalReversalsQirsh);
        expect(
            report.accountSummaries.first.netSettlementsQirsh,
            report.accountSummaries.first.grossSettlementsQirsh -
                report.accountSummaries.first.reversalsQirsh);
      });

      test('supplier summary reconciliation', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final original = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.cancellationReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'cancel-1',
          reversalOf: original.id,
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        final supplierGrossSum = report.supplierSummaries
            .fold<int>(0, (s, sp) => s + sp.grossSettlementsQirsh);
        final supplierRevSum = report.supplierSummaries
            .fold<int>(0, (s, sp) => s + sp.reversalsQirsh);
        final supplierNetSum = report.supplierSummaries
            .fold<int>(0, (s, sp) => s + sp.netSettlementsQirsh);
        expect(supplierGrossSum, report.totalGrossSettlementsQirsh);
        expect(supplierRevSum, report.totalReversalsQirsh);
        expect(supplierNetSum, report.totalNetSettlementsQirsh);
      });

      test('sum of detailed gross entries equals report gross', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final original = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.cancellationReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'cancel-1',
          reversalOf: original.id,
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        final detailGross = report.details
            .where((d) => !d.isReversal)
            .fold<int>(0, (s, d) => s + d.amountQirsh);
        final detailRev = report.details
            .where((d) => d.isReversal)
            .fold<int>(0, (s, d) => s + d.amountQirsh);
        expect(detailGross, report.totalGrossSettlementsQirsh);
        expect(detailRev, report.totalReversalsQirsh);
      });

      test('no detailed entry appears more than once', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 20000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'pay-2',
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        final ids = report.details.map((d) => d.entryId).toSet();
        expect(ids.length, report.details.length);
      });

      test('every included reversal has a qualified original settlement',
          () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final original = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.cancellationReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'cancel-1',
          reversalOf: original.id,
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        final reversals = report.details.where((d) => d.isReversal).toList();
        expect(reversals.length, 1);
        expect(reversals.first.reversalOfEntryId, original.id);
      });

      test('every included entry contributes to exactly one account bucket',
          () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-1',
        );

        final report = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        for (final d in report.details) {
          final matchingAccount =
              report.accountSummaries.where((a) => a.account.id == d.accountId);
          expect(matchingAccount.length, 1);
        }
      });

      test('filtering does not alter classification semantics', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final original = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 20000,
          source: FinancialAccountEntrySource.cancellationReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'cancel-1',
          reversalOf: original.id,
        );

        final unfiltered = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        final filtered = await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          accountIdFilter: acc.id,
        );

        expect(unfiltered.details.where((d) => d.isReversal).length,
            filtered.details.where((d) => d.isReversal).length);
      });
    });

    group('PdfFileNaming', () {
      test('supplierSettlementsByAccountReport generates correct name', () {
        final name = PdfFileNaming.supplierSettlementsByAccountReport(
            DateTime(2026, 3, 15));
        expect(name, endsWith('.pdf'));
        expect(name, contains('2026-03-15'));
      });

      test('supplierSettlementsByAccountReportCsv generates correct name', () {
        final name = PdfFileNaming.supplierSettlementsByAccountReportCsv(
            DateTime(2026, 3, 15));
        expect(name, endsWith('.csv'));
        expect(name, contains('2026-03-15'));
      });
    });

    group('Model construction', () {
      test('SupplierSettlementsByAccountDetail model fields', () {
        final detail = SupplierSettlementsByAccountDetail(
          entryId: 'e1',
          sourceDocumentId: 'pay-1',
          supplierId: 'sup-1',
          supplierName: 'أحمد',
          accountId: 'acc-1',
          accountName: 'خزينة',
          timestamp: DateTime(2026, 1, 10),
          isReversal: false,
          amountQirsh: 50000,
          sourceType: FinancialAccountEntrySource.supplierSettlement,
          reference: 'test',
          reversalOfEntryId: null,
        );
        expect(detail.entryId, 'e1');
        expect(detail.isReversal, false);
        expect(detail.amountQirsh, 50000);
        expect(detail.isUnresolved, false);
      });

      test('SupplierSettlementsByAccountSupplierSummary isUnresolved', () {
        const unresolved = SupplierSettlementsByAccountSupplierSummary(
          supplierId: null,
          supplierName: 'مورد غير محدد',
          grossSettlementsQirsh: 0,
          reversalsQirsh: 0,
          netSettlementsQirsh: 0,
        );
        expect(unresolved.isUnresolved, true);

        const resolved = SupplierSettlementsByAccountSupplierSummary(
          supplierId: 'sup-1',
          supplierName: 'أحمد',
          grossSettlementsQirsh: 50000,
          reversalsQirsh: 0,
          netSettlementsQirsh: 50000,
        );
        expect(resolved.isUnresolved, false);
      });
    });

    group('Read-only integrity', () {
      test('generating report does not modify ledger', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'pay-1',
        );

        final balanceBefore = await repo.currentBalanceForAccount(acc.id);
        final statementBefore = await repo.statementForAccount(acc.id);

        await service.getSupplierSettlementsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        final balanceAfter = await repo.currentBalanceForAccount(acc.id);
        final statementAfter = await repo.statementForAccount(acc.id);

        expect(balanceAfter, balanceBefore);
        expect(statementAfter.lines.length, statementBefore.lines.length);
      });
    });

    group('Permission expansion', () {
      test('no new permission required beyond existing ones', () {
        expect(Permissions.owner.canViewFinancialReports, true);
        expect(Permissions.owner.canExportFinancialReports, true);
        expect(Permissions.employee.canViewFinancialReports, false);
        expect(Permissions.employee.canExportFinancialReports, false);
      });
    });
  });
}
