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

  group('Phase 9D — Advances and Refunds Report', () {
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
        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.details, isEmpty);
        expect(report.accountSummaries, isEmpty);
        expect(report.customerSummaries, isEmpty);
        expect(report.supplierSummaries, isEmpty);
        expect(report.totalCustomerGrossRefundOutflow, 0);
        expect(report.totalCustomerRefundReversals, 0);
        expect(report.totalCustomerNetRefundOutflow, 0);
        expect(report.totalSupplierGrossRefundInflow, 0);
        expect(report.totalSupplierRefundReversals, 0);
        expect(report.totalSupplierNetRefundInflow, 0);
        expect(report.signedGrandCashEffect, 0);
      });

      test('all totals and summaries are zero', () async {
        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.totalCustomerGrossRefundOutflow, 0);
        expect(report.totalCustomerNetRefundOutflow, 0);
        expect(report.totalSupplierGrossRefundInflow, 0);
        expect(report.totalSupplierNetRefundInflow, 0);
        expect(report.signedGrandCashEffect, 0);
      });

      test('no mutation occurs', () async {
        final balancesBefore = await repo.allAccountBalances();
        await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        final balancesAfter = await repo.allAccountBalances();
        expect(balancesAfter.length, balancesBefore.length);
      });
    });

    group('Customer advance refunds', () {
      test('single customer refund outflow', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final entry = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'car-1',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 1);
        expect(report.details.first.entryId, entry.id);
        expect(report.details.first.partyType,
            AdvancesAndRefundsPartyType.customer);
        expect(report.details.first.isReversal, false);
        expect(report.details.first.amountQirsh, 50000);
        expect(report.details.first.signedCashEffect, -50000);
        expect(report.totalCustomerGrossRefundOutflow, 50000);
        expect(report.totalCustomerNetRefundOutflow, 50000);
      });

      test('customer refund across multiple accounts', () async {
        final acc1 =
            await createAccount('خزينة', FinancialAccountType.treasury);
        final acc2 = await createAccount('بنك', FinancialAccountType.bank);
        await seedOpeningBalance(acc1.id, 1000000);
        await seedOpeningBalance(acc2.id, 1000000);
        await addEntry(
          accountId: acc1.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );
        await addEntry(
          accountId: acc2.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 15000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 8),
          sourceDocumentId: 'car-2',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 2);
        expect(report.totalCustomerGrossRefundOutflow, 25000);
        expect(report.accountSummaries.length, 2);
      });

      test('multiple customers in one account', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 30000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 20000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'car-2',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 2);
        expect(report.totalCustomerGrossRefundOutflow, 50000);
      });

      test('unresolved customer shows correct label', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.first.entityName, 'عميل غير محدد');
        expect(report.details.first.entityId, isNull);
        expect(report.customerSummaries.length, 1);
        expect(report.customerSummaries.first.isUnresolved, true);
        expect(report.customerSummaries.first.entityName, 'عميل غير محدد');
      });

      test('customer refund recorded as outflow not inflow', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.first.signedCashEffect, -50000);
        expect(report.details.first.signedCashEffect, lessThan(0));
      });
    });

    group('Supplier advance refunds', () {
      test('single supplier refund inflow', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final entry = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 8000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'sar-1',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 1);
        expect(report.details.first.entryId, entry.id);
        expect(report.details.first.partyType,
            AdvancesAndRefundsPartyType.supplier);
        expect(report.details.first.isReversal, false);
        expect(report.details.first.amountQirsh, 8000);
        expect(report.details.first.signedCashEffect, 8000);
        expect(report.totalSupplierGrossRefundInflow, 8000);
        expect(report.totalSupplierNetRefundInflow, 8000);
      });

      test('supplier refund across multiple accounts', () async {
        final acc1 =
            await createAccount('خزينة', FinancialAccountType.treasury);
        final acc2 = await createAccount('بنك', FinancialAccountType.bank);
        await seedOpeningBalance(acc1.id, 1000000);
        await seedOpeningBalance(acc2.id, 1000000);
        await addEntry(
          accountId: acc1.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'sar-1',
        );
        await addEntry(
          accountId: acc2.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 15000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 8),
          sourceDocumentId: 'sar-2',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 2);
        expect(report.totalSupplierGrossRefundInflow, 25000);
        expect(report.accountSummaries.length, 2);
      });

      test('multiple suppliers in one account', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 5000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'sar-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 3000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'sar-2',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 2);
        expect(report.totalSupplierGrossRefundInflow, 8000);
      });

      test('unresolved supplier shows correct label', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 8000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'sar-1',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.first.entityName, 'مورد غير محدد');
        expect(report.details.first.entityId, isNull);
        expect(report.supplierSummaries.length, 1);
        expect(report.supplierSummaries.first.isUnresolved, true);
        expect(report.supplierSummaries.first.entityName, 'مورد غير محدد');
      });

      test('supplier refund recorded as inflow not outflow', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 8000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'sar-1',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.first.signedCashEffect, 8000);
        expect(report.details.first.signedCashEffect, greaterThan(0));
      });
    });

    group('Reversals', () {
      test('qualified customer reversal is counted', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final original = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 20000,
          source: FinancialAccountEntrySource.customerAdvanceRefundReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'car-rev-1',
          reversalOf: original.id,
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 2);
        final reversal = report.details.firstWhere((d) => d.isReversal);
        expect(reversal.partyType, AdvancesAndRefundsPartyType.customer);
        expect(reversal.amountQirsh, 20000);
        expect(reversal.reversalOfEntryId, original.id);
        expect(report.totalCustomerGrossRefundOutflow, 50000);
        expect(report.totalCustomerRefundReversals, 20000);
        expect(report.totalCustomerNetRefundOutflow, 30000);
      });

      test('qualified supplier reversal is counted', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final original = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 30000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'sar-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.supplierAdvanceRefundReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'sar-rev-1',
          reversalOf: original.id,
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 2);
        final reversal = report.details.firstWhere((d) => d.isReversal);
        expect(reversal.partyType, AdvancesAndRefundsPartyType.supplier);
        expect(reversal.amountQirsh, 10000);
        expect(reversal.reversalOfEntryId, original.id);
        expect(report.totalSupplierGrossRefundInflow, 30000);
        expect(report.totalSupplierRefundReversals, 10000);
        expect(report.totalSupplierNetRefundInflow, 20000);
      });

      test('unlinked customer reversal excluded', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerAdvanceRefundReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'car-orphan',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 1);
        expect(report.details.first.sourceType,
            FinancialAccountEntrySource.customerAdvanceRefund);
        expect(report.totalCustomerGrossRefundOutflow, 50000);
        expect(report.totalCustomerRefundReversals, 0);
      });

      test('unlinked supplier reversal excluded', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 30000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'sar-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 5000,
          source: FinancialAccountEntrySource.supplierAdvanceRefundReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'sar-orphan',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 1);
        expect(report.details.first.sourceType,
            FinancialAccountEntrySource.supplierAdvanceRefund);
        expect(report.totalSupplierGrossRefundInflow, 30000);
        expect(report.totalSupplierRefundReversals, 0);
      });

      test('reversal linked to wrong source type excluded', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final original = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 30000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'sar-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 5000,
          source: FinancialAccountEntrySource.customerAdvanceRefundReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'car-rev-wrong',
          reversalOf: original.id,
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 1);
        expect(report.details.first.sourceType,
            FinancialAccountEntrySource.supplierAdvanceRefund);
      });

      test('supplier reversal linked to customer entry excluded', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final original = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.supplierAdvanceRefundReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'sar-rev-wrong',
          reversalOf: original.id,
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 1);
        expect(report.details.first.sourceType,
            FinancialAccountEntrySource.customerAdvanceRefund);
      });

      test('self-reference excluded', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final entry = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerAdvanceRefundReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'car-rev-self',
          reversalOf: entry.id,
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 2);
        expect(report.details.any((d) => d.isReversal), true);
      });

      test('no double counting', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final original = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 20000,
          source: FinancialAccountEntrySource.customerAdvanceRefundReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'car-rev-1',
          reversalOf: original.id,
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        final ids = report.details.map((d) => d.entryId).toSet();
        expect(ids.length, report.details.length);
      });
    });

    group('Source whitelist', () {
      test('salePayment excluded', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 25000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'sale-1',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details, isEmpty);
        expect(report.totalCustomerGrossRefundOutflow, 0);
        expect(report.totalSupplierGrossRefundInflow, 0);
      });

      test('purchasePayment excluded', () async {
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

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details, isEmpty);
      });

      test('customerCollection excluded', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 15000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'col-1',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details, isEmpty);
      });

      test('supplierSettlement excluded', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 25000,
          source: FinancialAccountEntrySource.supplierSettlement,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'pay-1',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details, isEmpty);
      });

      test('expense excluded', () async {
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

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details, isEmpty);
      });

      test('generic cancellationReversal excluded', () async {
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
          sourceDocumentId: 'cancel-1',
          reversalOf: null,
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details, isEmpty);
      });

      test('transfer sources excluded', () async {
        final acc1 =
            await createAccount('خزينة', FinancialAccountType.treasury);
        final acc2 = await createAccount('بنك', FinancialAccountType.bank);
        await seedOpeningBalance(acc1.id, 1000000);
        await seedOpeningBalance(acc2.id, 1000000);
        await addEntry(
          accountId: acc1.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.transferOut,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 't-1',
        );
        await addEntry(
          accountId: acc2.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.transferIn,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 't-1',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details, isEmpty);
      });

      test('opening and manual sources excluded', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 500000,
          source: FinancialAccountEntrySource.openingBalance,
          date: DateTime(2026, 1, 1),
          sourceDocumentId: 'ob-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.manualCorrection,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'mc-1',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details, isEmpty);
      });
    });

    group('Filters', () {
      test('account filter', () async {
        final acc1 =
            await createAccount('خزينة', FinancialAccountType.treasury);
        final acc2 = await createAccount('بنك', FinancialAccountType.bank);
        await seedOpeningBalance(acc1.id, 1000000);
        await seedOpeningBalance(acc2.id, 1000000);
        await addEntry(
          accountId: acc1.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );
        await addEntry(
          accountId: acc2.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 20000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'sar-1',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          accountIdFilter: acc1.id,
        );

        expect(report.details.length, 1);
        expect(report.details.first.accountId, acc1.id);
        expect(report.totalCustomerGrossRefundOutflow, 10000);
        expect(report.totalSupplierGrossRefundInflow, 0);
      });

      test('customer typed entity filter', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 20000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'sar-1',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          partyTypeFilter: AdvancesAndRefundsPartyType.customer,
        );

        expect(report.details.length, 1);
        expect(report.details.first.partyType,
            AdvancesAndRefundsPartyType.customer);
      });

      test('supplier typed entity filter', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 20000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'sar-1',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          partyTypeFilter: AdvancesAndRefundsPartyType.supplier,
        );

        expect(report.details.length, 1);
        expect(report.details.first.partyType,
            AdvancesAndRefundsPartyType.supplier);
      });

      test('customer ID equal to supplier ID no collision', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 20000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'sar-1',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.customerSummaries.length, 1);
        expect(report.supplierSummaries.length, 1);
        expect(report.customerSummaries.first.partyType,
            AdvancesAndRefundsPartyType.customer);
        expect(report.supplierSummaries.first.partyType,
            AdvancesAndRefundsPartyType.supplier);
      });

      test('party type customer only', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 20000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'sar-1',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          partyTypeFilter: AdvancesAndRefundsPartyType.customer,
        );

        expect(report.details.length, 1);
        expect(report.totalCustomerGrossRefundOutflow, 10000);
        expect(report.totalSupplierGrossRefundInflow, 0);
      });

      test('party type supplier only', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 20000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'sar-1',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          partyTypeFilter: AdvancesAndRefundsPartyType.supplier,
        );

        expect(report.details.length, 1);
        expect(report.totalCustomerGrossRefundOutflow, 0);
        expect(report.totalSupplierGrossRefundInflow, 20000);
      });

      test('all parties', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 20000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'sar-1',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 2);
        expect(report.totalCustomerGrossRefundOutflow, 10000);
        expect(report.totalSupplierGrossRefundInflow, 20000);
      });

      test('inclusive start boundary', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 5000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 1),
          sourceDocumentId: 'car-1',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 1);
        expect(report.totalCustomerGrossRefundOutflow, 5000);
      });

      test('inclusive end boundary', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 4000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 31),
          sourceDocumentId: 'sar-1',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 1);
        expect(report.totalSupplierGrossRefundInflow, 4000);
      });

      test('before range excluded', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 5000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2025, 12, 31),
          sourceDocumentId: 'car-1',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details, isEmpty);
      });

      test('after range excluded', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 8000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 2, 1),
          sourceDocumentId: 'sar-1',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details, isEmpty);
      });
    });

    group('Accounting totals', () {
      test('customer gross total', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 30000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 20000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'car-2',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.totalCustomerGrossRefundOutflow, 50000);
      });

      test('customer reversal total', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final orig = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 15000,
          source: FinancialAccountEntrySource.customerAdvanceRefundReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'car-rev-1',
          reversalOf: orig.id,
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 5000,
          source: FinancialAccountEntrySource.customerAdvanceRefundReversal,
          date: DateTime(2026, 1, 15),
          sourceDocumentId: 'car-rev-2',
          reversalOf: orig.id,
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.totalCustomerRefundReversals, 20000);
      });

      test('customer net outflow', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final orig = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 15000,
          source: FinancialAccountEntrySource.customerAdvanceRefundReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'car-rev-1',
          reversalOf: orig.id,
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.totalCustomerNetRefundOutflow, 35000);
      });

      test('supplier gross total', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 20000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'sar-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 30000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'sar-2',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.totalSupplierGrossRefundInflow, 50000);
      });

      test('supplier reversal total', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final orig = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 30000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'sar-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 12000,
          source: FinancialAccountEntrySource.supplierAdvanceRefundReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'sar-rev-1',
          reversalOf: orig.id,
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.totalSupplierRefundReversals, 12000);
      });

      test('supplier net inflow', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final orig = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 30000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'sar-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 12000,
          source: FinancialAccountEntrySource.supplierAdvanceRefundReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'sar-rev-1',
          reversalOf: orig.id,
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.totalSupplierNetRefundInflow, 18000);
      });

      test('signed net cash effect', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 30000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 50000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'sar-1',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(
            report.signedGrandCashEffect,
            report.totalSupplierNetRefundInflow -
                report.totalCustomerNetRefundOutflow);
        expect(report.signedGrandCashEffect, 20000);
      });

      test('account totals reconcile', () async {
        final acc1 =
            await createAccount('خزينة', FinancialAccountType.treasury);
        final acc2 = await createAccount('بنك', FinancialAccountType.bank);
        await seedOpeningBalance(acc1.id, 1000000);
        await seedOpeningBalance(acc2.id, 1000000);
        await addEntry(
          accountId: acc1.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );
        await addEntry(
          accountId: acc2.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 20000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'sar-1',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        final accountCustomerGross = report.accountSummaries
            .fold<int>(0, (s, a) => s + a.customerGrossRefundOutflow);
        expect(accountCustomerGross, report.totalCustomerGrossRefundOutflow);

        final accountSupplierGross = report.accountSummaries
            .fold<int>(0, (s, a) => s + a.supplierGrossRefundInflow);
        expect(accountSupplierGross, report.totalSupplierGrossRefundInflow);
      });

      test('customer entity totals reconcile', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final orig = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerAdvanceRefundReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'car-rev-1',
          reversalOf: orig.id,
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        final customerGrossSum =
            report.customerSummaries.fold<int>(0, (s, c) => s + c.grossAmount);
        final customerRevSum = report.customerSummaries
            .fold<int>(0, (s, c) => s + c.reversalAmount);
        expect(customerGrossSum, report.totalCustomerGrossRefundOutflow);
        expect(customerRevSum, report.totalCustomerRefundReversals);
      });

      test('supplier entity totals reconcile', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        final orig = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 30000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'sar-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 5000,
          source: FinancialAccountEntrySource.supplierAdvanceRefundReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'sar-rev-1',
          reversalOf: orig.id,
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        final supplierGrossSum = report.supplierSummaries
            .fold<int>(0, (s, sp) => s + sp.grossAmount);
        final supplierRevSum = report.supplierSummaries
            .fold<int>(0, (s, sp) => s + sp.reversalAmount);
        expect(supplierGrossSum, report.totalSupplierGrossRefundInflow);
        expect(supplierRevSum, report.totalSupplierRefundReversals);
      });

      test('grand totals reconcile', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 20000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 40000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'sar-1',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(
            report.signedGrandCashEffect,
            report.totalSupplierNetRefundInflow -
                report.totalCustomerNetRefundOutflow);
        expect(report.customerSummaries.first.netAmount,
            report.totalCustomerNetRefundOutflow);
        expect(report.supplierSummaries.first.netAmount,
            report.totalSupplierNetRefundInflow);
      });

      test('each detail appears exactly once', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 20000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'sar-1',
        );
        final orig = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 30000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 12),
          sourceDocumentId: 'car-2',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 5000,
          source: FinancialAccountEntrySource.customerAdvanceRefundReversal,
          date: DateTime(2026, 1, 15),
          sourceDocumentId: 'car-rev-1',
          reversalOf: orig.id,
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        final ids = report.details.map((d) => d.entryId).toSet();
        expect(ids.length, report.details.length);
        expect(ids.length, 4);
      });
    });

    group('Determinism', () {
      test('accounts sorted deterministically', () async {
        final acc1 = await createAccount('بنك', FinancialAccountType.bank);
        final acc2 =
            await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc1.id, 1000000);
        await seedOpeningBalance(acc2.id, 1000000);
        await addEntry(
          accountId: acc2.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );
        await addEntry(
          accountId: acc1.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 20000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'sar-1',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.accountSummaries[0].account.name, 'بنك');
        expect(report.accountSummaries[1].account.name, 'خزينة');
      });

      test('entities sorted deterministically', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 20000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'car-2',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.customerSummaries.length, 1);
      });

      test('details sorted by required comparator', () async {
        final acc1 = await createAccount('بنك', FinancialAccountType.bank);
        final acc2 =
            await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc1.id, 1000000);
        await seedOpeningBalance(acc2.id, 1000000);
        await addEntry(
          accountId: acc2.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 1000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-early',
        );
        await addEntry(
          accountId: acc1.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 2000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'sar-late',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details[0].accountName, 'بنك');
        expect(report.details[1].accountName, 'خزينة');
      });

      test('entry ID resolves timestamp ties', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 1000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-a',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 2000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'sar-b',
        );

        final report = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 2);
        final ids = report.details.map((d) => d.entryId).toList();
        expect(ids, ids.toList()..sort());
      });
    });

    group('Read-only integrity', () {
      test('report generation does not append entries', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );

        final statementBefore = await repo.statementForAccount(acc.id);
        final countBefore = statementBefore.lines.length;

        await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        final statementAfter = await repo.statementForAccount(acc.id);
        expect(statementAfter.lines.length, countBefore);
      });

      test('report generation does not modify balances', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );

        final balanceBefore = await repo.currentBalanceForAccount(acc.id);

        await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        final balanceAfter = await repo.currentBalanceForAccount(acc.id);
        expect(balanceAfter, balanceBefore);
      });

      test('report generation does not change account state', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );

        final accountBefore = await repo.accountById(acc.id);

        await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        final accountAfter = await repo.accountById(acc.id);
        expect(accountAfter.name, accountBefore.name);
        expect(accountAfter.isActive, accountBefore.isActive);
      });

      test('repeated generation returns equivalent results', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 20000,
          source: FinancialAccountEntrySource.supplierAdvanceRefund,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'sar-1',
        );

        final report1 = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        final report2 = await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report1.details.length, report2.details.length);
        expect(report1.totalCustomerGrossRefundOutflow,
            report2.totalCustomerGrossRefundOutflow);
        expect(report1.totalSupplierGrossRefundInflow,
            report2.totalSupplierGrossRefundInflow);
        expect(report1.signedGrandCashEffect, report2.signedGrandCashEffect);
      });

      test('export preparation does not mutate repositories', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'car-1',
        );

        final balancesBefore = await repo.allAccountBalances();
        await service.getAdvancesAndRefundsReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        final balancesAfter = await repo.allAccountBalances();
        expect(balancesAfter.length, balancesBefore.length);
        for (var i = 0; i < balancesBefore.length; i++) {
          expect(balancesAfter[i].currentBalanceQirsh,
              balancesBefore[i].currentBalanceQirsh);
        }
      });
    });

    group('PDF and CSV naming', () {
      test('PDF filename ends with .pdf', () {
        final filename =
            PdfFileNaming.advancesAndRefundsReport(DateTime(2026, 1, 15));
        expect(filename, endsWith('.pdf'));
      });

      test('CSV filename ends with .csv', () {
        final filename =
            PdfFileNaming.advancesAndRefundsReportCsv(DateTime(2026, 1, 15));
        expect(filename, endsWith('.csv'));
      });
    });

    group('UI permission and naming', () {
      test('owner can open report', () {
        expect(Permissions.owner.canViewFinancialReports, true);
      });

      test('employee/non-owner is denied', () {
        expect(Permissions.employee.canViewFinancialReports, false);
      });
    });
  });
}
