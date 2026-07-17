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

  group('Phase 9B — Customer Collections by Financial Account Report', () {
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
    });

    group('Empty state', () {
      test('empty repositories returns empty report with zero totals',
          () async {
        final report = await service.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.details, isEmpty);
        expect(report.accountSummaries, isEmpty);
        expect(report.customerSummaries, isEmpty);
        expect(report.totalGrossCollectionsQirsh, 0);
        expect(report.totalReversalsQirsh, 0);
        expect(report.totalNetCollectionsQirsh, 0);
      });
    });

    group('Single collection', () {
      test('one collection into one account', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        final entry = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 50000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'col-1',
        );

        final report = await service.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 1);
        expect(report.details.first.entryId, entry.id);
        expect(report.details.first.amountQirsh, 50000);
        expect(report.details.first.isReversal, false);
        expect(report.details.first.accountId, acc.id);
        expect(report.totalGrossCollectionsQirsh, 50000);
        expect(report.totalReversalsQirsh, 0);
        expect(report.totalNetCollectionsQirsh, 50000);
        expect(report.accountSummaries.length, 1);
        expect(report.accountSummaries.first.grossCollectionsQirsh, 50000);
      });
    });

    group('Multiple customers in one account', () {
      test('two customers collection in same account', () async {
        final acc = await createAccount('بنك', FinancialAccountType.bank);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 30000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'col-1',
          reference: 'Customer collection أحمد',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 20000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'col-2',
          reference: 'Customer collection سعيد',
        );

        final report = await service.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 2);
        expect(report.totalGrossCollectionsQirsh, 50000);
        expect(report.accountSummaries.length, 1);
        expect(report.accountSummaries.first.grossCollectionsQirsh, 50000);
      });
    });

    group('One customer across multiple accounts', () {
      test('same collection sourceDocumentId in two accounts', () async {
        final acc1 =
            await createAccount('خزينة', FinancialAccountType.treasury);
        final acc2 = await createAccount('بنك', FinancialAccountType.bank);
        await addEntry(
          accountId: acc1.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'col-1',
          reference: 'Customer collection محمد',
        );
        await addEntry(
          accountId: acc2.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 15000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'col-1',
          reference: 'Customer collection محمد',
        );

        final report = await service.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 2);
        expect(report.totalGrossCollectionsQirsh, 25000);
        expect(report.accountSummaries.length, 2);
      });
    });

    group('Multiple accounts and customers', () {
      test('correct breakdown across accounts and customers', () async {
        final acc1 =
            await createAccount('خزينة', FinancialAccountType.treasury);
        final acc2 = await createAccount('بنك', FinancialAccountType.bank);
        await addEntry(
          accountId: acc1.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'col-1',
        );
        await addEntry(
          accountId: acc1.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 20000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 8),
          sourceDocumentId: 'col-2',
        );
        await addEntry(
          accountId: acc2.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 30000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'col-3',
        );

        final report = await service.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 3);
        expect(report.totalGrossCollectionsQirsh, 60000);
        expect(report.accountSummaries.length, 2);
        expect(report.accountSummaries[0].grossCollectionsQirsh, 30000);
        expect(report.accountSummaries[1].grossCollectionsQirsh, 30000);
      });
    });

    group('Split-payment semantics', () {
      test('split collection counted once per account', () async {
        final acc1 =
            await createAccount('خزينة', FinancialAccountType.treasury);
        final acc2 = await createAccount('بنك', FinancialAccountType.bank);
        await addEntry(
          accountId: acc1.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'col-split',
        );
        await addEntry(
          accountId: acc2.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 15000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'col-split',
        );

        final report = await service.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 2);
        final sumDetails =
            report.details.fold<int>(0, (s, d) => s + d.amountQirsh);
        expect(sumDetails, 25000);
        expect(report.totalGrossCollectionsQirsh, 25000);
        expect(report.accountSummaries[0].grossCollectionsQirsh, 10000);
        expect(report.accountSummaries[1].grossCollectionsQirsh, 15000);
      });
    });

    group('Gross, reversal, and net semantics', () {
      test('reversal reduces net', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        final original = await addEntry(
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
          amount: 20000,
          source: FinancialAccountEntrySource.cancellationReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'cancel-1',
          reversalOf: original.id,
        );

        final report = await service.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.totalGrossCollectionsQirsh, 50000);
        expect(report.totalReversalsQirsh, 20000);
        expect(report.totalNetCollectionsQirsh, 30000);
        expect(report.details.length, 2);
        expect(report.details.any((d) => d.isReversal), true);
        expect(report.details.any((d) => !d.isReversal), true);
      });
    });

    group('Qualified cancellation reversal', () {
      test('linked cancellation reversal is counted', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        final original = await addEntry(
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
          amount: 50000,
          source: FinancialAccountEntrySource.cancellationReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'cancel-1',
          reversalOf: original.id,
        );

        final report = await service.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.totalGrossCollectionsQirsh, 50000);
        expect(report.totalReversalsQirsh, 50000);
        expect(report.totalNetCollectionsQirsh, 0);
      });
    });

    group('Unrelated cancellation reversal excluded', () {
      test('cancellation reversal without reversalOf is excluded', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
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
          sourceDocumentId: 'cancel-orphan',
        );

        final report = await service.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 1);
        expect(report.details.first.sourceType,
            FinancialAccountEntrySource.customerCollection);
        expect(report.totalGrossCollectionsQirsh, 50000);
        expect(report.totalReversalsQirsh, 0);
        expect(report.totalNetCollectionsQirsh, 50000);
      });
    });

    group('customerAdvanceRefundReversal', () {
      test('included in report', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 100000,
          source: FinancialAccountEntrySource.openingBalance,
          date: DateTime(2026, 1, 1),
          sourceDocumentId: 'opening-1',
        );
        final originalRefund = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 8000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'refund-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 8000,
          source: FinancialAccountEntrySource.customerAdvanceRefundReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'refund-rev-1',
          reversalOf: originalRefund.id,
        );

        final report = await service.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 1);
        expect(report.details.first.sourceType,
            FinancialAccountEntrySource.customerAdvanceRefundReversal);
        expect(report.details.first.isReversal, true);
        expect(report.totalGrossCollectionsQirsh, 0);
        expect(report.totalReversalsQirsh, 8000);
      });
    });

    group('customerAdvanceRefund exclusion', () {
      test('advance refund alone is excluded', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 100000,
          source: FinancialAccountEntrySource.openingBalance,
          date: DateTime(2026, 1, 1),
          sourceDocumentId: 'opening-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 8000,
          source: FinancialAccountEntrySource.customerAdvanceRefund,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'refund-1',
        );

        final report = await service.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details, isEmpty);
        expect(report.totalGrossCollectionsQirsh, 0);
        expect(report.totalReversalsQirsh, 0);
      });
    });

    group('Unrelated inflow sources excluded', () {
      test('sale payments and expenses excluded', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'sale-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 5000,
          source: FinancialAccountEntrySource.expense,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'exp-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 30000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 15),
          sourceDocumentId: 'col-1',
        );

        final report = await service.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 1);
        expect(report.totalGrossCollectionsQirsh, 30000);
      });
    });

    group('Account filter', () {
      test('filtering by account shows only that account', () async {
        final acc1 =
            await createAccount('خزينة', FinancialAccountType.treasury);
        final acc2 = await createAccount('بنك', FinancialAccountType.bank);
        await addEntry(
          accountId: acc1.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'col-1',
        );
        await addEntry(
          accountId: acc2.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 50000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'col-2',
        );

        final report = await service.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          accountIdFilter: acc1.id,
        );

        expect(report.details.length, 1);
        expect(report.totalGrossCollectionsQirsh, 10000);
        expect(report.accountSummaries.length, 1);
        expect(report.accountSummaries.first.account.id, acc1.id);
      });
    });

    group('Date boundaries', () {
      test('start-date boundary included', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 5000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 1),
          sourceDocumentId: 'col-1',
        );

        final report = await service.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 1);
        expect(report.totalGrossCollectionsQirsh, 5000);
      });

      test('end-date boundary included', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 4000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 31),
          sourceDocumentId: 'col-1',
        );

        final report = await service.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 1);
        expect(report.totalGrossCollectionsQirsh, 4000);
      });

      test('entries outside range excluded', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 5000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2025, 12, 31),
          sourceDocumentId: 'col-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 8000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 2, 1),
          sourceDocumentId: 'col-2',
        );

        final report = await service.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details, isEmpty);
        expect(report.totalGrossCollectionsQirsh, 0);
      });
    });

    group('Deterministic ordering', () {
      test('accounts sorted by name', () async {
        final acc1 = await createAccount('بنك', FinancialAccountType.bank);
        final acc2 =
            await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc2.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'col-1',
        );
        await addEntry(
          accountId: acc1.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 20000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'col-2',
        );

        final report = await service.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.accountSummaries[0].account.name, 'بنك');
        expect(report.accountSummaries[1].account.name, 'خزينة');
      });

      test('details sorted by account name then customer then timestamp desc',
          () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 1000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'col-early',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 2000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'col-late',
        );

        final report = await service.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details[0].timestamp, DateTime(2026, 1, 10));
        expect(report.details[1].timestamp, DateTime(2026, 1, 5));
      });

      test('deterministic entry ID tie-breaker', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 1000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'col-a',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 2000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'col-b',
        );

        final report = await service.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 2);
        final ids = report.details.map((d) => d.entryId).toList();
        expect(ids, ids.toList()..sort());
      });
    });

    group('Customer filter', () {
      test('filtering by customerId without lookup returns empty', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'col-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 20000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'col-2',
        );

        final report = await service.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          customerIdFilter: 'cust-1',
        );

        expect(report.details, isEmpty);
        expect(report.totalGrossCollectionsQirsh, 0);
      });

      test('filtering by null customerId includes all', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'col-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 20000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'col-2',
        );

        final report = await service.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 2);
        expect(report.totalGrossCollectionsQirsh, 30000);
      });
    });

    group('Reconciliation invariants', () {
      test('account totals reconcile with detailed entries', () async {
        final acc1 =
            await createAccount('خزينة', FinancialAccountType.treasury);
        final acc2 = await createAccount('بنك', FinancialAccountType.bank);
        await addEntry(
          accountId: acc1.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'col-1',
        );
        await addEntry(
          accountId: acc2.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 20000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'col-2',
        );

        final report = await service.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        final accountGrossSum = report.accountSummaries
            .fold<int>(0, (s, a) => s + a.grossCollectionsQirsh);
        expect(accountGrossSum, report.totalGrossCollectionsQirsh);
      });

      test('grand totals reconcile with account and customer summaries',
          () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        final original = await addEntry(
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
          sourceDocumentId: 'cancel-1',
          reversalOf: original.id,
        );

        final report = await service.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.totalNetCollectionsQirsh,
            report.totalGrossCollectionsQirsh - report.totalReversalsQirsh);
        expect(
            report.accountSummaries.first.netCollectionsQirsh,
            report.accountSummaries.first.grossCollectionsQirsh -
                report.accountSummaries.first.reversalsQirsh);
      });

      test('sum of detailed gross entries equals report gross', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        final original = await addEntry(
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
          sourceDocumentId: 'cancel-1',
          reversalOf: original.id,
        );

        final report = await service.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        final detailGross = report.details
            .where((d) => !d.isReversal)
            .fold<int>(0, (s, d) => s + d.amountQirsh);
        final detailRev = report.details
            .where((d) => d.isReversal)
            .fold<int>(0, (s, d) => s + d.amountQirsh);
        expect(detailGross, report.totalGrossCollectionsQirsh);
        expect(detailRev, report.totalReversalsQirsh);
      });

      test('no detailed entry appears more than once', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'col-1',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 20000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'col-2',
        );

        final report = await service.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        final ids = report.details.map((d) => d.entryId).toSet();
        expect(ids.length, report.details.length);
      });
    });

    group('Existing constructor compatibility', () {
      test('FinancialReportService with only repository still works', () async {
        final svc = FinancialReportService(repository: repo);
        final report = await svc.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.details, isEmpty);
        expect(report.totalGrossCollectionsQirsh, 0);
      });
    });

    group('Unresolved customer handling', () {
      test('without lookup all customers are unresolved', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 50000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'col-1',
        );

        final report = await service.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.first.customerName, 'غير محدد');
        expect(report.details.first.customerId, isNull);
        expect(report.customerSummaries.length, 1);
        expect(report.customerSummaries.first.isUnresolved, true);
        expect(report.customerSummaries.first.customerName, 'غير محدد');
      });
    });

    group('Reversal attribution', () {
      test('reversal of collection follows original linkage', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        final original = await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 50000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 5),
          sourceDocumentId: 'col-1',
          reference: 'Customer collection عميل أ',
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.cancellationReversal,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'cancel-1',
          reversalOf: original.id,
          reference: 'عكس التحصيل col-1',
        );

        final report = await service.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.details.length, 2);
        final originalDetail = report.details.firstWhere((d) => !d.isReversal);
        final reversalDetail = report.details.firstWhere((d) => d.isReversal);
        expect(reversalDetail.reversalOfEntryId, originalDetail.entryId);
        expect(report.totalNetCollectionsQirsh, 0);
      });
    });

    group('PdfFileNaming', () {
      test('customerCollectionsByAccountReport generates correct name', () {
        final name = PdfFileNaming.customerCollectionsByAccountReport(
            DateTime(2026, 3, 15));
        expect(name, endsWith('.pdf'));
        expect(name, contains('2026-03-15'));
      });

      test('customerCollectionsByAccountReportCsv generates correct name', () {
        final name = PdfFileNaming.customerCollectionsByAccountReportCsv(
            DateTime(2026, 3, 15));
        expect(name, endsWith('.csv'));
        expect(name, contains('2026-03-15'));
      });
    });

    group('Read-only integrity', () {
      test('generating report does not modify ledger', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 10),
          sourceDocumentId: 'col-1',
        );

        final balanceBefore = await repo.currentBalanceForAccount(acc.id);
        final statementBefore = await repo.statementForAccount(acc.id);

        await service.getCustomerCollectionsByAccount(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        final balanceAfter = await repo.currentBalanceForAccount(acc.id);
        final statementAfter = await repo.statementForAccount(acc.id);

        expect(balanceAfter, balanceBefore);
        expect(statementAfter.lines.length, statementBefore.lines.length);
      });
    });

    group('Model construction', () {
      test('CustomerCollectionsByAccountDetail model fields', () {
        final detail = CustomerCollectionsByAccountDetail(
          entryId: 'e1',
          sourceDocumentId: 'col-1',
          customerId: 'cust-1',
          customerName: 'أحمد',
          accountId: 'acc-1',
          accountName: 'خزينة',
          timestamp: DateTime(2026, 1, 10),
          isReversal: false,
          amountQirsh: 50000,
          sourceType: FinancialAccountEntrySource.customerCollection,
          reference: 'test',
          reversalOfEntryId: null,
        );
        expect(detail.entryId, 'e1');
        expect(detail.isReversal, false);
        expect(detail.amountQirsh, 50000);
      });

      test('CustomerCollectionsByAccountCustomerSummary isUnresolved', () {
        const unresolved = CustomerCollectionsByAccountCustomerSummary(
          customerId: null,
          customerName: 'غير محدد',
          grossCollectionsQirsh: 0,
          reversalsQirsh: 0,
          netCollectionsQirsh: 0,
        );
        expect(unresolved.isUnresolved, true);

        const resolved = CustomerCollectionsByAccountCustomerSummary(
          customerId: 'cust-1',
          customerName: 'أحمد',
          grossCollectionsQirsh: 50000,
          reversalsQirsh: 0,
          netCollectionsQirsh: 50000,
        );
        expect(resolved.isUnresolved, false);
      });
    });
  });
}
