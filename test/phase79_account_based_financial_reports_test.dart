import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/permissions.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_models.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_service.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_transfer.dart';
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
    repo = LocalFinancialAccountRepository();
    service = FinancialReportService(repository: repo);
  });

  Future<FinancialAccount> createAccount(
      String name, FinancialAccountType type) {
    return repo.createAccount(FinancialAccountDraft(
      name: name,
      type: type,
      createdByUserId: owner.id,
    ));
  }

  Future<void> addEntry({
    required String accountId,
    required FinancialAccountEntryDirection direction,
    required int amount,
    required FinancialAccountEntrySource source,
    required DateTime date,
    PaymentMethod? paymentMethod,
    String? reversalOf,
    String? reference,
    String? approvedByUserId,
  }) async {
    await repo.createEntry(
      accountId: accountId,
      direction: direction,
      amountQirsh: amount,
      sourceType: source,
      sourceDocumentId: 'doc-${date.millisecondsSinceEpoch}',
      effectiveDate: date,
      createdByUserId: owner.id,
      paymentMethod: paymentMethod,
      reversalOf: reversalOf,
      reference: reference,
      approvedByUserId: approvedByUserId,
    );
  }

  group('Phase 79 — Account-Based Financial Reports', () {
    group('Permissions', () {
      test('owner has canViewFinancialReports', () {
        expect(Permissions.owner.canViewFinancialReports, true);
      });

      test('owner has canExportFinancialReports', () {
        expect(Permissions.owner.canExportFinancialReports, true);
      });

      test('employee defaults canViewFinancialReports to false', () {
        expect(Permissions.employee.canViewFinancialReports, false);
      });

      test('employee defaults canExportFinancialReports to false', () {
        expect(Permissions.employee.canExportFinancialReports, false);
      });

      test('custom Permissions defaults canViewFinancialReports to false', () {
        const perms = Permissions(
          canCreateSale: true,
          canCreatePurchase: true,
          canCreateCustomerPayment: true,
          canCreateSupplierPayment: true,
          canCreateExpense: true,
          canCreateStockAdjustment: true,
          canManageSuppliers: true,
          canCreatePurchaseIntake: true,
          canCancelInvoice: true,
          canManageProducts: true,
          canViewReports: true,
          canViewAuditLogs: true,
          canAccessSettings: true,
          canExportBackups: true,
          canWipeBusinessData: true,
          canApproveBelowMinimumPrice: true,
        );
        expect(perms.canViewFinancialReports, false);
        expect(perms.canExportFinancialReports, false);
      });

      test('owner has full access including new flags', () {
        expect(Permissions.owner.hasFullAccess, true);
      });

      test('employee does not have full access', () {
        expect(Permissions.employee.hasFullAccess, false);
      });

      test('Permissions.forRole(owner) has canViewFinancialReports', () {
        expect(
            Permissions.forRole(UserRole.owner).canViewFinancialReports, true);
        expect(Permissions.forRole(UserRole.owner).canExportFinancialReports,
            true);
      });

      test('Permissions.forRole(employee) lacks financial report flags', () {
        expect(Permissions.forRole(UserRole.employee).canViewFinancialReports,
            false);
        expect(Permissions.forRole(UserRole.employee).canExportFinancialReports,
            false);
      });
    });

    group('AccountBalanceReportRow model', () {
      test('netMovementQirsh computes inflows minus outflows', () {
        final account = FinancialAccount(
          id: 'fa-1',
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'u',
          createdAt: DateTime(2026),
        );
        final row = AccountBalanceReportRow(
          account: account,
          openingBalanceQirsh: 10000,
          totalInflowsQirsh: 30000,
          totalOutflowsQirsh: 20000,
          entryCount: 5,
        );
        expect(row.netMovementQirsh, 10000);
        expect(row.closingBalanceQirsh, 20000);
      });

      test('closingBalance with negative opening', () {
        final account = FinancialAccount(
          id: 'fa-2',
          name: 'بنك',
          type: FinancialAccountType.bank,
          createdByUserId: 'u',
          createdAt: DateTime(2026),
        );
        final row = AccountBalanceReportRow(
          account: account,
          openingBalanceQirsh: -5000,
          totalInflowsQirsh: 2000,
          totalOutflowsQirsh: 1000,
          entryCount: 3,
        );
        expect(row.netMovementQirsh, 1000);
        expect(row.closingBalanceQirsh, -4000);
      });
    });

    group('AccountStatementReportLine model', () {
      test('reversalStatus returns reversal for reversal entry', () {
        final entry = FinancialAccountEntry(
          id: 'e1',
          accountId: 'fa-1',
          direction: FinancialAccountEntryDirection.inflow,
          amountQirsh: 5000,
          sourceType: FinancialAccountEntrySource.transferIn,
          sourceDocumentId: 'doc1',
          effectiveDate: DateTime(2026),
          createdAt: DateTime(2026),
          createdByUserId: 'u',
          reversalOf: 'original-e1',
        );
        final line =
            AccountStatementReportLine(entry: entry, runningBalanceQirsh: 5000);
        expect(line.reversalStatus, 'reversal');
      });

      test('reversalStatus returns original for normal entry', () {
        final entry = FinancialAccountEntry(
          id: 'e2',
          accountId: 'fa-1',
          direction: FinancialAccountEntryDirection.outflow,
          amountQirsh: 3000,
          sourceType: FinancialAccountEntrySource.expense,
          sourceDocumentId: 'doc2',
          effectiveDate: DateTime(2026),
          createdAt: DateTime(2026),
          createdByUserId: 'u',
        );
        final line =
            AccountStatementReportLine(entry: entry, runningBalanceQirsh: 2000);
        expect(line.reversalStatus, 'original');
      });
    });

    group('PaymentMethodReportRow model', () {
      test('netMovementQirsh computes inflows minus outflows', () {
        const row = PaymentMethodReportRow(
          paymentMethod: PaymentMethod.cash,
          operationCount: 10,
          totalInflowsQirsh: 50000,
          totalOutflowsQirsh: 30000,
          bySourceType: {},
        );
        expect(row.netMovementQirsh, 20000);
      });

      test('displayName shows Arabic label for cash', () {
        const row = PaymentMethodReportRow(
          paymentMethod: PaymentMethod.cash,
          operationCount: 5,
          totalInflowsQirsh: 0,
          totalOutflowsQirsh: 0,
          bySourceType: {},
        );
        expect(row.displayName, 'نقدي');
      });

      test('displayName shows غير محدد for null payment method', () {
        const row = PaymentMethodReportRow(
          paymentMethod: null,
          operationCount: 3,
          totalInflowsQirsh: 0,
          totalOutflowsQirsh: 0,
          bySourceType: {},
        );
        expect(row.displayName, 'غير محدد');
      });
    });

    group('AccountBalanceReport model', () {
      test('totalNetMovementQirsh computes correctly', () {
        final report = AccountBalanceReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          rows: const [],
          totalOpeningQirsh: 10000,
          totalInflowsQirsh: 50000,
          totalOutflowsQirsh: 30000,
          totalClosingQirsh: 30000,
        );
        expect(report.totalNetMovementQirsh, 20000);
      });
    });

    group('PaymentMethodReport model', () {
      test('totalNetMovementQirsh computes correctly', () {
        final report = PaymentMethodReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          rows: const [],
          totalInflowsQirsh: 100000,
          totalOutflowsQirsh: 60000,
        );
        expect(report.totalNetMovementQirsh, 40000);
      });
    });

    group('FinancialReportService — accountBalanceReport', () {
      test('empty accounts returns empty report', () async {
        final report = await service.accountBalanceReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.rows, isEmpty);
        expect(report.totalOpeningQirsh, 0);
        expect(report.totalInflowsQirsh, 0);
        expect(report.totalOutflowsQirsh, 0);
        expect(report.totalClosingQirsh, 0);
      });

      test('single account with inflows and outflows', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 50000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 10),
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 20000,
          source: FinancialAccountEntrySource.expense,
          date: DateTime(2026, 1, 15),
        );

        final report = await service.accountBalanceReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.rows.length, 1);
        expect(report.rows.first.totalInflowsQirsh, 50000);
        expect(report.rows.first.totalOutflowsQirsh, 20000);
        expect(report.rows.first.netMovementQirsh, 30000);
        expect(report.rows.first.openingBalanceQirsh, 0);
        expect(report.rows.first.closingBalanceQirsh, 30000);
        expect(report.totalClosingQirsh, 30000);
      });

      test('entries before period count as opening balance', () async {
        final acc = await createAccount('بنك', FinancialAccountType.bank);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 100000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2025, 12, 15),
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.expense,
          date: DateTime(2026, 1, 5),
        );

        final report = await service.accountBalanceReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.rows.length, 1);
        expect(report.rows.first.openingBalanceQirsh, 100000);
        expect(report.rows.first.totalOutflowsQirsh, 10000);
        expect(report.rows.first.closingBalanceQirsh, 90000);
        expect(report.totalOpeningQirsh, 100000);
      });

      test('typeFilter excludes non-matching accounts', () async {
        await createAccount('خزينة', FinancialAccountType.treasury);
        await createAccount('بنك', FinancialAccountType.bank);

        final report = await service.accountBalanceReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          typeFilter: FinancialAccountType.treasury,
        );
        expect(report.rows.length, 1);
        expect(report.rows.first.account.type, FinancialAccountType.treasury);
      });

      test('accountIdFilter includes only matching account', () async {
        final acc1 =
            await createAccount('خزينة', FinancialAccountType.treasury);
        await createAccount('بنك', FinancialAccountType.bank);
        await addEntry(
          accountId: acc1.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 5000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 10),
        );

        final report = await service.accountBalanceReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          accountIdFilter: acc1.id,
        );
        expect(report.rows.length, 1);
        expect(report.rows.first.account.id, acc1.id);
      });

      test('multiple accounts aggregate totals correctly', () async {
        final acc1 =
            await createAccount('خزينة', FinancialAccountType.treasury);
        final acc2 = await createAccount('بنك', FinancialAccountType.bank);
        await addEntry(
          accountId: acc1.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 30000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 5),
        );
        await addEntry(
          accountId: acc2.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 70000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 10),
        );
        await addEntry(
          accountId: acc1.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 10000,
          source: FinancialAccountEntrySource.expense,
          date: DateTime(2026, 1, 15),
        );

        final report = await service.accountBalanceReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.rows.length, 2);
        expect(report.totalInflowsQirsh, 100000);
        expect(report.totalOutflowsQirsh, 10000);
        expect(report.totalClosingQirsh, 90000);
      });
    });

    group('FinancialReportService — accountStatementReport', () {
      test('empty account returns empty lines', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        final report = await service.accountStatementReport(
          accountId: acc.id,
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.lines, isEmpty);
        expect(report.openingBalanceQirsh, 0);
        expect(report.closingBalanceQirsh, 0);
      });

      test('entries are sorted by effectiveDate then id', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 5000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 10),
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 2000,
          source: FinancialAccountEntrySource.expense,
          date: DateTime(2026, 1, 10),
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 8000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 5),
        );

        final report = await service.accountStatementReport(
          accountId: acc.id,
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.lines.length, 3);
        expect(report.lines[0].entry.effectiveDate, DateTime(2026, 1, 5));
        expect(report.lines[1].entry.effectiveDate, DateTime(2026, 1, 10));
        expect(report.lines[2].entry.effectiveDate, DateTime(2026, 1, 10));
        expect(report.lines[1].entry.id.compareTo(report.lines[2].entry.id),
            lessThan(0));
      });

      test('running balance is computed correctly', () async {
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
          amount: 3000,
          source: FinancialAccountEntrySource.expense,
          date: DateTime(2026, 1, 10),
        );

        final report = await service.accountStatementReport(
          accountId: acc.id,
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.openingBalanceQirsh, 0);
        expect(report.lines[0].runningBalanceQirsh, 10000);
        expect(report.lines[1].runningBalanceQirsh, 7000);
        expect(report.closingBalanceQirsh, 7000);
      });

      test('opening balance from pre-period entries', () async {
        final acc = await createAccount('بنك', FinancialAccountType.bank);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 100000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2025, 12, 20),
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 5000,
          source: FinancialAccountEntrySource.expense,
          date: DateTime(2026, 1, 5),
        );

        final report = await service.accountStatementReport(
          accountId: acc.id,
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.openingBalanceQirsh, 100000);
        expect(report.lines.length, 1);
        expect(report.lines[0].runningBalanceQirsh, 95000);
        expect(report.closingBalanceQirsh, 95000);
      });

      test('sourceTypeFilter works', () async {
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

        final report = await service.accountStatementReport(
          accountId: acc.id,
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          sourceTypeFilter: FinancialAccountEntrySource.salePayment,
        );
        expect(report.lines.length, 1);
        expect(report.lines[0].entry.sourceType,
            FinancialAccountEntrySource.salePayment);
      });

      test('paymentMethodFilter works', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 5000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 5),
          paymentMethod: PaymentMethod.cash,
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 15000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 10),
          paymentMethod: PaymentMethod.bankTransfer,
        );

        final report = await service.accountStatementReport(
          accountId: acc.id,
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          paymentMethodFilter: PaymentMethod.cash,
        );
        expect(report.lines.length, 1);
        expect(report.lines[0].entry.paymentMethod, PaymentMethod.cash);
      });

      test('reversalFilter=reversal shows only reversal entries', () async {
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
          amount: 10000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 10),
          reversalOf: 'original-sale',
        );

        final report = await service.accountStatementReport(
          accountId: acc.id,
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          reversalFilter: 'reversal',
        );
        expect(report.lines.length, 1);
        expect(report.lines[0].reversalStatus, 'reversal');
      });

      test('reversalFilter=original shows only original entries', () async {
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
          amount: 10000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 10),
          reversalOf: 'original-sale',
        );

        final report = await service.accountStatementReport(
          accountId: acc.id,
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          reversalFilter: 'original',
        );
        expect(report.lines.length, 1);
        expect(report.lines[0].reversalStatus, 'original');
      });
    });

    group('FinancialReportService — paymentMethodReport', () {
      test('excludes transfer entries from report', () async {
        final source =
            await createAccount('خزينة', FinancialAccountType.treasury);
        final dest = await createAccount('بنك', FinancialAccountType.bank);
        await repo.updateAccountPolicy(
          accountId: source.id,
          allowNegativeBalance: true,
          updatedByUserId: owner.id,
        );
        await addEntry(
          accountId: source.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 5000,
          source: FinancialAccountEntrySource.transferOut,
          date: DateTime(2026, 1, 5),
          approvedByUserId: owner.id,
        );
        await addEntry(
          accountId: dest.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 5000,
          source: FinancialAccountEntrySource.transferIn,
          date: DateTime(2026, 1, 5),
        );
        await addEntry(
          accountId: source.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 10),
          paymentMethod: PaymentMethod.cash,
        );

        final report = await service.paymentMethodReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.totalInflowsQirsh, 10000);
        expect(report.totalOutflowsQirsh, 0);
        expect(report.rows.length, 1);
        expect(report.rows.first.displayName, 'نقدي');
      });

      test('groups by payment method correctly', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 5),
          paymentMethod: PaymentMethod.cash,
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 20000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 10),
          paymentMethod: PaymentMethod.bankTransfer,
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 5000,
          source: FinancialAccountEntrySource.expense,
          date: DateTime(2026, 1, 15),
          paymentMethod: PaymentMethod.cash,
        );

        final report = await service.paymentMethodReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.rows.length, 2);
        expect(report.totalInflowsQirsh, 30000);
        expect(report.totalOutflowsQirsh, 5000);
      });

      test('paymentMethodFilter isolates single method', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 5),
          paymentMethod: PaymentMethod.cash,
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 20000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 10),
          paymentMethod: PaymentMethod.bankTransfer,
        );

        final report = await service.paymentMethodReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          paymentMethodFilter: PaymentMethod.cash,
        );
        expect(report.rows.length, 1);
        expect(report.totalInflowsQirsh, 10000);
      });

      test('directionFilter works', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 5),
          paymentMethod: PaymentMethod.cash,
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 5000,
          source: FinancialAccountEntrySource.expense,
          date: DateTime(2026, 1, 10),
          paymentMethod: PaymentMethod.cash,
        );

        final report = await service.paymentMethodReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          directionFilter: FinancialAccountEntryDirection.inflow,
        );
        expect(report.totalInflowsQirsh, 10000);
        expect(report.totalOutflowsQirsh, 0);
      });

      test('accountIdFilter restricts to single account', () async {
        final acc1 =
            await createAccount('خزينة', FinancialAccountType.treasury);
        final acc2 = await createAccount('بنك', FinancialAccountType.bank);
        await addEntry(
          accountId: acc1.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 5),
          paymentMethod: PaymentMethod.cash,
        );
        await addEntry(
          accountId: acc2.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 50000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 10),
          paymentMethod: PaymentMethod.bankTransfer,
        );

        final report = await service.paymentMethodReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          accountIdFilter: acc1.id,
        );
        expect(report.totalInflowsQirsh, 10000);
      });

      test('transferReversal entries are excluded', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 5000,
          source: FinancialAccountEntrySource.transferReversalIn,
          date: DateTime(2026, 1, 5),
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 5000,
          source: FinancialAccountEntrySource.transferReversalOut,
          date: DateTime(2026, 1, 5),
        );

        final report = await service.paymentMethodReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.totalInflowsQirsh, 0);
        expect(report.totalOutflowsQirsh, 0);
        expect(report.rows, isEmpty);
      });

      test('bySourceType breakdown tracks amounts', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 5),
          paymentMethod: PaymentMethod.cash,
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 20000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 10),
          paymentMethod: PaymentMethod.cash,
        );

        final report = await service.paymentMethodReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          paymentMethodFilter: PaymentMethod.cash,
        );
        expect(
            report.rows.first
                .bySourceType[FinancialAccountEntrySource.salePayment],
            10000);
        expect(
            report.rows.first
                .bySourceType[FinancialAccountEntrySource.customerCollection],
            20000);
      });

      test('rows sorted by totalInflows descending', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 5000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 5),
          paymentMethod: PaymentMethod.cash,
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 50000,
          source: FinancialAccountEntrySource.customerCollection,
          date: DateTime(2026, 1, 10),
          paymentMethod: PaymentMethod.bankTransfer,
        );

        final report = await service.paymentMethodReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.rows[0].totalInflowsQirsh, 50000);
        expect(report.rows[1].totalInflowsQirsh, 5000);
      });
    });

    group('FinancialReportService — transferReport', () {
      test('empty transfers returns empty report', () async {
        final report = await service.transferReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.rows, isEmpty);
        expect(report.totalAmountQirsh, 0);
      });

      test('single transfer shows correctly', () async {
        final source =
            await createAccount('خزينة', FinancialAccountType.treasury);
        final dest = await createAccount('بنك', FinancialAccountType.bank);
        await repo.setOpeningBalance(
          accountId: source.id,
          amountQirsh: 100000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: owner.id,
        );
        final transfer = await repo.createTransfer(
          user: owner,
          draft: FinancialTransferDraft(
            clientRequestId: 'req-1',
            transferReference: 'TR-001',
            sourceAccountId: source.id,
            destinationAccountId: dest.id,
            amountQirsh: 25000,
            effectiveDate: DateTime(2026, 1, 10),
            createdByUserId: owner.id,
          ),
        );

        final report = await service.transferReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.rows.length, 1);
        expect(report.totalAmountQirsh, 25000);
        expect(report.rows.first.displayNumber, transfer.displayNumber);
        expect(report.rows.first.sourceAccountName, 'خزينة');
        expect(report.rows.first.destinationAccountName, 'بنك');
      });

      test('reversed transfer shows linked reversal display number', () async {
        final source =
            await createAccount('خزينة', FinancialAccountType.treasury);
        final dest = await createAccount('بنك', FinancialAccountType.bank);
        await repo.setOpeningBalance(
          accountId: source.id,
          amountQirsh: 100000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: owner.id,
        );
        final transfer = await repo.createTransfer(
          user: owner,
          draft: FinancialTransferDraft(
            clientRequestId: 'req-1',
            transferReference: 'TR-001',
            sourceAccountId: source.id,
            destinationAccountId: dest.id,
            amountQirsh: 25000,
            effectiveDate: DateTime(2026, 1, 10),
            createdByUserId: owner.id,
          ),
        );
        final reversal = await repo.reverseTransfer(
          user: owner,
          transferId: transfer.id,
          reason: 'خطأ في المبلغ',
        );

        final report = await service.transferReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime.now(),
        );
        expect(report.rows.length, 2);

        final originalRow = report.rows.firstWhere((r) => !r.isReversal);
        expect(originalRow.isReversed, true);
        expect(originalRow.reversalDisplayNumber, reversal.displayNumber);

        final reversalRow = report.rows.firstWhere((r) => r.isReversal);
        expect(reversalRow.isReversal, true);
        expect(reversalRow.isReversed, false);
      });

      test('reversalFilter=reversal shows only reversal transfers', () async {
        final source =
            await createAccount('خزينة', FinancialAccountType.treasury);
        final dest = await createAccount('بنك', FinancialAccountType.bank);
        await repo.setOpeningBalance(
          accountId: source.id,
          amountQirsh: 100000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: owner.id,
        );
        final transfer = await repo.createTransfer(
          user: owner,
          draft: FinancialTransferDraft(
            clientRequestId: 'req-1',
            transferReference: 'TR-001',
            sourceAccountId: source.id,
            destinationAccountId: dest.id,
            amountQirsh: 25000,
            effectiveDate: DateTime(2026, 1, 10),
            createdByUserId: owner.id,
          ),
        );
        await repo.reverseTransfer(
          user: owner,
          transferId: transfer.id,
          reason: 'خطأ',
        );

        final report = await service.transferReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime.now(),
          reversalFilter: 'reversal',
        );
        expect(report.rows.length, 1);
        expect(report.rows.first.isReversal, true);
      });

      test('reversalFilter=original shows only original transfers', () async {
        final source =
            await createAccount('خزينة', FinancialAccountType.treasury);
        final dest = await createAccount('بنك', FinancialAccountType.bank);
        await repo.setOpeningBalance(
          accountId: source.id,
          amountQirsh: 100000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: owner.id,
        );
        final transfer = await repo.createTransfer(
          user: owner,
          draft: FinancialTransferDraft(
            clientRequestId: 'req-1',
            transferReference: 'TR-001',
            sourceAccountId: source.id,
            destinationAccountId: dest.id,
            amountQirsh: 25000,
            effectiveDate: DateTime(2026, 1, 10),
            createdByUserId: owner.id,
          ),
        );
        await repo.reverseTransfer(
          user: owner,
          transferId: transfer.id,
          reason: 'خطأ',
        );

        final report = await service.transferReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          reversalFilter: 'original',
        );
        expect(report.rows.length, 1);
        expect(report.rows.first.isReversal, false);
      });

      test('reversalFilter=reversed shows only reversed transfers', () async {
        final source =
            await createAccount('خزينة', FinancialAccountType.treasury);
        final dest = await createAccount('بنك', FinancialAccountType.bank);
        await repo.setOpeningBalance(
          accountId: source.id,
          amountQirsh: 100000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: owner.id,
        );
        final transfer = await repo.createTransfer(
          user: owner,
          draft: FinancialTransferDraft(
            clientRequestId: 'req-1',
            transferReference: 'TR-001',
            sourceAccountId: source.id,
            destinationAccountId: dest.id,
            amountQirsh: 25000,
            effectiveDate: DateTime(2026, 1, 10),
            createdByUserId: owner.id,
          ),
        );
        await repo.reverseTransfer(
          user: owner,
          transferId: transfer.id,
          reason: 'خطأ',
        );

        final report = await service.transferReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          reversalFilter: 'reversed',
        );
        expect(report.rows.length, 1);
        expect(report.rows.first.isReversed, true);
      });

      test('sourceAccountId filter works', () async {
        final src1 =
            await createAccount('خزينة', FinancialAccountType.treasury);
        final dest1 = await createAccount('بنك', FinancialAccountType.bank);
        final src2 =
            await createAccount('محفظة', FinancialAccountType.electronicWallet);
        final dest2 = await createAccount('حساب2', FinancialAccountType.bank);
        await repo.setOpeningBalance(
          accountId: src1.id,
          amountQirsh: 100000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: owner.id,
        );
        await repo.setOpeningBalance(
          accountId: src2.id,
          amountQirsh: 100000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: owner.id,
        );

        await repo.createTransfer(
          user: owner,
          draft: FinancialTransferDraft(
            clientRequestId: 'req-1',
            transferReference: 'TR-001',
            sourceAccountId: src1.id,
            destinationAccountId: dest1.id,
            amountQirsh: 10000,
            effectiveDate: DateTime(2026, 1, 10),
            createdByUserId: owner.id,
          ),
        );
        await repo.createTransfer(
          user: owner,
          draft: FinancialTransferDraft(
            clientRequestId: 'req-2',
            transferReference: 'TR-002',
            sourceAccountId: src2.id,
            destinationAccountId: dest2.id,
            amountQirsh: 20000,
            effectiveDate: DateTime(2026, 1, 15),
            createdByUserId: owner.id,
          ),
        );

        final report = await service.transferReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          sourceAccountId: src1.id,
        );
        expect(report.rows.length, 1);
        expect(report.totalAmountQirsh, 10000);
      });

      test('anyAccountId filter includes both source and destination',
          () async {
        final src1 =
            await createAccount('خزينة', FinancialAccountType.treasury);
        final dest1 = await createAccount('بنك', FinancialAccountType.bank);
        final src2 =
            await createAccount('محفظة', FinancialAccountType.electronicWallet);
        final dest2 = await createAccount('حساب2', FinancialAccountType.bank);
        await repo.setOpeningBalance(
          accountId: src1.id,
          amountQirsh: 100000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: owner.id,
        );
        await repo.setOpeningBalance(
          accountId: src2.id,
          amountQirsh: 100000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: owner.id,
        );

        await repo.createTransfer(
          user: owner,
          draft: FinancialTransferDraft(
            clientRequestId: 'req-1',
            transferReference: 'TR-001',
            sourceAccountId: src1.id,
            destinationAccountId: dest1.id,
            amountQirsh: 10000,
            effectiveDate: DateTime(2026, 1, 10),
            createdByUserId: owner.id,
          ),
        );
        await repo.createTransfer(
          user: owner,
          draft: FinancialTransferDraft(
            clientRequestId: 'req-2',
            transferReference: 'TR-002',
            sourceAccountId: src2.id,
            destinationAccountId: dest2.id,
            amountQirsh: 20000,
            effectiveDate: DateTime(2026, 1, 15),
            createdByUserId: owner.id,
          ),
        );

        final report = await service.transferReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          anyAccountId: dest1.id,
        );
        expect(report.rows.length, 1);
        expect(report.rows.first.destinationAccountName, 'بنك');
      });

      test('rows sorted by effectiveDate descending', () async {
        final src = await createAccount('خزينة', FinancialAccountType.treasury);
        final dest = await createAccount('بنك', FinancialAccountType.bank);
        await repo.setOpeningBalance(
          accountId: src.id,
          amountQirsh: 100000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: owner.id,
        );

        await repo.createTransfer(
          user: owner,
          draft: FinancialTransferDraft(
            clientRequestId: 'req-1',
            transferReference: 'TR-001',
            sourceAccountId: src.id,
            destinationAccountId: dest.id,
            amountQirsh: 10000,
            effectiveDate: DateTime(2026, 1, 5),
            createdByUserId: owner.id,
          ),
        );
        await repo.createTransfer(
          user: owner,
          draft: FinancialTransferDraft(
            clientRequestId: 'req-2',
            transferReference: 'TR-002',
            sourceAccountId: src.id,
            destinationAccountId: dest.id,
            amountQirsh: 20000,
            effectiveDate: DateTime(2026, 1, 20),
            createdByUserId: owner.id,
          ),
        );

        final report = await service.transferReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.rows[0].effectiveDate, DateTime(2026, 1, 20));
        expect(report.rows[1].effectiveDate, DateTime(2026, 1, 5));
      });
    });

    group('PdfFileNaming — financial report names', () {
      test('accountBalanceReport generates correct name', () {
        final name = PdfFileNaming.accountBalanceReport(DateTime(2026, 3, 15));
        expect(name, contains('تقرير'));
        expect(name, contains('أرصدة'));
        expect(name, contains('2026-03-15'));
        expect(name, endsWith('.pdf'));
      });

      test('accountStatementReport generates correct name with account', () {
        final name = PdfFileNaming.accountStatementReport(
            'خزينة', DateTime(2026, 3, 15));
        expect(name, contains('كشف'));
        expect(name, contains('حساب'));
        expect(name, contains('خزينة'));
        expect(name, contains('2026-03-15'));
        expect(name, endsWith('.pdf'));
      });

      test('paymentMethodReport generates correct name', () {
        final name = PdfFileNaming.paymentMethodReport(DateTime(2026, 3, 15));
        expect(name, contains('تقرير'));
        expect(name, contains('طرق'));
        expect(name, contains('الدفع'));
        expect(name, contains('2026-03-15'));
        expect(name, endsWith('.pdf'));
      });

      test('transferReport generates correct name', () {
        final name = PdfFileNaming.transferReport(DateTime(2026, 3, 15));
        expect(name, contains('تقرير'));
        expect(name, contains('التحويلات'));
        expect(name, contains('2026-03-15'));
        expect(name, endsWith('.pdf'));
      });

      test('accountBalanceReportCsv generates correct name', () {
        final name =
            PdfFileNaming.accountBalanceReportCsv(DateTime(2026, 3, 15));
        expect(name, endsWith('.csv'));
        expect(name, contains('2026-03-15'));
      });

      test('accountStatementReportCsv generates correct name', () {
        final name = PdfFileNaming.accountStatementReportCsv(
            'بنك', DateTime(2026, 3, 15));
        expect(name, endsWith('.csv'));
        expect(name, contains('بنك'));
      });

      test('paymentMethodReportCsv generates correct name', () {
        final name =
            PdfFileNaming.paymentMethodReportCsv(DateTime(2026, 3, 15));
        expect(name, endsWith('.csv'));
        expect(name, contains('طرق'));
      });

      test('transferReportCsv generates correct name', () {
        final name = PdfFileNaming.transferReportCsv(DateTime(2026, 3, 15));
        expect(name, endsWith('.csv'));
        expect(name, contains('التحويلات'));
      });

      test('account names with forbidden chars are sanitized', () {
        final name = PdfFileNaming.accountStatementReport(
          'حساب: خاص/عام',
          DateTime(2026, 3, 15),
        );
        expect(name, isNot(contains(':')));
        expect(name, isNot(contains('/')));
      });
    });

    group('Edge cases — zero amounts', () {
      test('account balance report handles single inflow only', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 1,
          source: FinancialAccountEntrySource.manualCorrection,
          date: DateTime(2026, 1, 5),
        );

        final report = await service.accountBalanceReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.rows.length, 1);
        expect(report.totalClosingQirsh, 1);
      });
    });

    group('Edge cases — date boundary', () {
      test('entries exactly on fromDate are included', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 5000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 1),
        );

        final report = await service.accountBalanceReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.totalInflowsQirsh, 5000);
      });

      test('entries exactly on toDate are included', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 5000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 31),
        );

        final report = await service.accountBalanceReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.totalInflowsQirsh, 5000);
      });

      test('entries outside date range are excluded', () async {
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

        final report = await service.accountBalanceReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.totalInflowsQirsh, 0);
      });
    });

    group('Transfer report — integer arithmetic integrity', () {
      test('large amounts are handled correctly', () async {
        final src = await createAccount('خزينة', FinancialAccountType.treasury);
        final dest = await createAccount('بنك', FinancialAccountType.bank);
        await repo.setOpeningBalance(
          accountId: src.id,
          amountQirsh: 999999999,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: owner.id,
        );
        await repo.createTransfer(
          user: owner,
          draft: FinancialTransferDraft(
            clientRequestId: 'req-1',
            transferReference: 'TR-001',
            sourceAccountId: src.id,
            destinationAccountId: dest.id,
            amountQirsh: 999999999,
            effectiveDate: DateTime(2026, 1, 10),
            createdByUserId: owner.id,
          ),
        );

        final report = await service.transferReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.totalAmountQirsh, 999999999);
      });

      test('negative net movement on payment method', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await repo.updateAccountPolicy(
          accountId: acc.id,
          allowNegativeBalance: true,
          updatedByUserId: owner.id,
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.outflow,
          amount: 50000,
          source: FinancialAccountEntrySource.expense,
          date: DateTime(2026, 1, 5),
          paymentMethod: PaymentMethod.cash,
          approvedByUserId: owner.id,
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 10000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 10),
          paymentMethod: PaymentMethod.cash,
        );

        final report = await service.paymentMethodReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.rows.first.netMovementQirsh, -40000);
        expect(report.totalNetMovementQirsh, -40000);
      });
    });

    group('Multiple payment methods with mixed data', () {
      test('all payment methods and null are tracked separately', () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 1000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 5),
          paymentMethod: PaymentMethod.cash,
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 2000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 6),
          paymentMethod: PaymentMethod.bankTransfer,
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 3000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 7),
          paymentMethod: PaymentMethod.mobileWallet,
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 4000,
          source: FinancialAccountEntrySource.salePayment,
          date: DateTime(2026, 1, 8),
          paymentMethod: PaymentMethod.check,
        );
        await addEntry(
          accountId: acc.id,
          direction: FinancialAccountEntryDirection.inflow,
          amount: 5000,
          source: FinancialAccountEntrySource.expense,
          date: DateTime(2026, 1, 9),
        );

        final report = await service.paymentMethodReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.rows.length, 5);
        expect(report.totalInflowsQirsh, 15000);
      });
    });
  });
}
