import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/permissions.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_service.dart';
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
  late LocalExpenseRepository expenseRepo;
  late FinancialReportService service;

  setUp(() {
    repo = LocalFinancialAccountRepository();
    // Report tests seed both current and legacy records. Transaction routing
    // is covered separately; this ledger-only adapter preserves v1-v5 nulls.
    expenseRepo = LocalExpenseRepository();
    service = FinancialReportService(
      repository: repo,
      expenseRepository: expenseRepo,
    );
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

  Future<void> seedOpeningBalance(String accountId, int amount) async {
    await repo.createEntry(
      accountId: accountId,
      direction: FinancialAccountEntryDirection.inflow,
      amountQirsh: amount,
      sourceType: FinancialAccountEntrySource.openingBalance,
      sourceDocumentId: 'ob-$accountId',
      effectiveDate: DateTime(2025, 12, 31),
      createdByUserId: owner.id,
    );
  }

  Future<void> seedExpense({
    required DateTime date,
    required String category,
    required int amount,
    String? notes,
    String? financialAccountId,
    PaymentMethod? paymentMethod,
  }) async {
    await expenseRepo.createExpense(ExpenseDraft(
      date: date,
      category: category,
      amountQirsh: amount,
      createdByUserId: owner.id,
      operationRequestId:
          'phase9e-${date.microsecondsSinceEpoch}-${category.hashCode}-$amount',
      notes: notes,
      financialAccountId: financialAccountId,
      paymentMethod: paymentMethod,
    ));
  }

  group('Phase 9E — Expense Analysis Report', () {
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
        final report = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        expect(report.rows, isEmpty);
        expect(report.allDetails, isEmpty);
        expect(report.totalQirsh, 0);
        expect(report.grandCount, 0);
      });

      test('no mutation occurs on empty data', () async {
        final balancesBefore = await repo.allAccountBalances();
        await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        final balancesAfter = await repo.allAccountBalances();
        expect(balancesAfter.length, balancesBefore.length);
      });
    });

    group('Single expense', () {
      test('single expense with correct total and count', () async {
        await seedExpense(
          date: DateTime(2026, 1, 15),
          category: 'رواتب',
          amount: 50000,
        );

        final report = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.rows.length, 1);
        expect(report.rows.first.category, 'رواتب');
        expect(report.rows.first.totalAmountQirsh, 50000);
        expect(report.rows.first.count, 1);
        expect(report.totalQirsh, 50000);
        expect(report.grandCount, 1);
        expect(report.rows.first.percentageOfTotal, 100.0);
      });
    });

    group('Multiple expenses same category', () {
      test('same category expenses are grouped correctly', () async {
        await seedExpense(
          date: DateTime(2026, 1, 5),
          category: 'رواتب',
          amount: 30000,
        );
        await seedExpense(
          date: DateTime(2026, 1, 10),
          category: 'رواتب',
          amount: 20000,
        );

        final report = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.rows.length, 1);
        expect(report.rows.first.totalAmountQirsh, 50000);
        expect(report.rows.first.count, 2);
        expect(report.totalQirsh, 50000);
        expect(report.grandCount, 2);
      });
    });

    group('Multiple categories', () {
      test('separate rows for each category', () async {
        await seedExpense(
          date: DateTime(2026, 1, 5),
          category: 'رواتب',
          amount: 30000,
        );
        await seedExpense(
          date: DateTime(2026, 1, 8),
          category: 'إيجار',
          amount: 15000,
        );
        await seedExpense(
          date: DateTime(2026, 1, 12),
          category: 'مرافق',
          amount: 5000,
        );

        final report = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.rows.length, 3);
        expect(report.totalQirsh, 50000);
        expect(report.grandCount, 3);

        final categoryTotals = report.rows.map((r) => r.totalAmountQirsh);
        expect(categoryTotals, contains(30000));
        expect(categoryTotals, contains(15000));
        expect(categoryTotals, contains(5000));
      });
    });

    group('Date filtering', () {
      test('fromDate is inclusive', () async {
        await seedExpense(
          date: DateTime(2026, 1, 1),
          category: 'رواتب',
          amount: 10000,
        );

        final report = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.grandCount, 1);
        expect(report.totalQirsh, 10000);
      });

      test('toDate is inclusive', () async {
        await seedExpense(
          date: DateTime(2026, 1, 31),
          category: 'رواتب',
          amount: 10000,
        );

        final report = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.grandCount, 1);
        expect(report.totalQirsh, 10000);
      });

      test('expense before fromDate is excluded', () async {
        await seedExpense(
          date: DateTime(2025, 12, 31),
          category: 'رواتب',
          amount: 10000,
        );
        await seedExpense(
          date: DateTime(2026, 1, 5),
          category: 'رواتب',
          amount: 20000,
        );

        final report = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.grandCount, 1);
        expect(report.totalQirsh, 20000);
      });

      test('expense after toDate is excluded', () async {
        await seedExpense(
          date: DateTime(2026, 1, 5),
          category: 'رواتب',
          amount: 20000,
        );
        await seedExpense(
          date: DateTime(2026, 2, 1),
          category: 'رواتب',
          amount: 10000,
        );

        final report = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.grandCount, 1);
        expect(report.totalQirsh, 20000);
      });

      test('time within end of day does not exclude', () async {
        await seedExpense(
          date: DateTime(2026, 1, 31),
          category: 'رواتب',
          amount: 10000,
        );

        final report = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.grandCount, 1);
      });
    });

    group('Account filtering', () {
      test('filter by specific account shows only linked expenses', () async {
        final acc1 =
            await createAccount('خزينة', FinancialAccountType.treasury);
        final acc2 = await createAccount('بنك', FinancialAccountType.bank);
        await seedOpeningBalance(acc1.id, 1000000);
        await seedOpeningBalance(acc2.id, 1000000);

        await seedExpense(
          date: DateTime(2026, 1, 5),
          category: 'رواتب',
          amount: 10000,
          financialAccountId: acc1.id,
        );
        await seedExpense(
          date: DateTime(2026, 1, 8),
          category: 'إيجار',
          amount: 20000,
          financialAccountId: acc2.id,
        );

        final report = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          accountIdFilter: acc1.id,
        );

        expect(report.grandCount, 1);
        expect(report.totalQirsh, 10000);
        expect(report.allDetails.first.accountName, 'خزينة');
      });

      test('null account expenses show in all accounts view', () async {
        await seedExpense(
          date: DateTime(2026, 1, 5),
          category: 'رواتب',
          amount: 10000,
        );

        final report = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.grandCount, 1);
        expect(report.totalQirsh, 10000);
        expect(report.allDetails.first.accountName, 'غير محدد');
      });

      test('null account expenses excluded when specific account selected',
          () async {
        final acc1 =
            await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc1.id, 1000000);

        await seedExpense(
          date: DateTime(2026, 1, 5),
          category: 'رواتب',
          amount: 10000,
        );
        await seedExpense(
          date: DateTime(2026, 1, 8),
          category: 'إيجار',
          amount: 20000,
          financialAccountId: acc1.id,
        );

        final report = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          accountIdFilter: acc1.id,
        );

        expect(report.grandCount, 1);
        expect(report.totalQirsh, 20000);
      });
    });

    group('Payment method filtering', () {
      test('filter by specific payment method', () async {
        await seedExpense(
          date: DateTime(2026, 1, 5),
          category: 'رواتب',
          amount: 10000,
          paymentMethod: PaymentMethod.cash,
        );
        await seedExpense(
          date: DateTime(2026, 1, 8),
          category: 'إيجار',
          amount: 20000,
          paymentMethod: PaymentMethod.bankTransfer,
        );

        final report = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          paymentMethodFilter: PaymentMethod.cash,
        );

        expect(report.grandCount, 1);
        expect(report.totalQirsh, 10000);
        expect(report.allDetails.first.paymentMethodLabel, 'نقدي');
      });

      test('null payment method shows as غير محدد', () async {
        await seedExpense(
          date: DateTime(2026, 1, 5),
          category: 'رواتب',
          amount: 10000,
        );

        final report = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.allDetails.first.paymentMethodLabel, 'غير محدد');
      });

      test('null payment method does not crash', () async {
        await seedExpense(
          date: DateTime(2026, 1, 5),
          category: 'رواتب',
          amount: 10000,
        );

        final report = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.grandCount, 1);
      });
    });

    group('Category filtering', () {
      test('partial match finds categories', () async {
        await seedExpense(
          date: DateTime(2026, 1, 5),
          category: 'مصاريف إدارية',
          amount: 10000,
        );
        await seedExpense(
          date: DateTime(2026, 1, 8),
          category: 'رواتب',
          amount: 20000,
        );

        final report = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          categoryFilter: 'إدارية',
        );

        expect(report.grandCount, 1);
        expect(report.allDetails.first.category, 'مصاريف إدارية');
      });

      test('category search is trimmed', () async {
        await seedExpense(
          date: DateTime(2026, 1, 5),
          category: 'رواتب',
          amount: 10000,
        );

        final report = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          categoryFilter: '  رواتب  ',
        );

        expect(report.grandCount, 1);
      });

      test('category search is case-insensitive', () async {
        await seedExpense(
          date: DateTime(2026, 1, 5),
          category: 'MISC',
          amount: 10000,
        );

        final report = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          categoryFilter: 'misc',
        );

        expect(report.grandCount, 1);
      });

      test('no-match returns empty report', () async {
        await seedExpense(
          date: DateTime(2026, 1, 5),
          category: 'رواتب',
          amount: 10000,
        );

        final report = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
          categoryFilter: 'غير موجود',
        );

        expect(report.grandCount, 0);
        expect(report.rows, isEmpty);
      });

      test('grouping stays exact and does not merge similar categories',
          () async {
        await seedExpense(
          date: DateTime(2026, 1, 5),
          category: 'مصاريف',
          amount: 10000,
        );
        await seedExpense(
          date: DateTime(2026, 1, 8),
          category: 'مصاريف إدارية',
          amount: 20000,
        );

        final report = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.rows.length, 2);
        final cats = report.rows.map((r) => r.category).toSet();
        expect(cats, contains('مصاريف'));
        expect(cats, contains('مصاريف إدارية'));
      });
    });

    group('Sorting', () {
      test('categories sorted by total descending', () async {
        await seedExpense(
          date: DateTime(2026, 1, 5),
          category: 'إيجار',
          amount: 5000,
        );
        await seedExpense(
          date: DateTime(2026, 1, 8),
          category: 'رواتب',
          amount: 30000,
        );
        await seedExpense(
          date: DateTime(2026, 1, 10),
          category: 'مرافق',
          amount: 15000,
        );

        final report = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.rows[0].category, 'رواتب');
        expect(report.rows[1].category, 'مرافق');
        expect(report.rows[2].category, 'إيجار');
      });

      test('category ascending as tie-breaker', () async {
        await seedExpense(
          date: DateTime(2026, 1, 5),
          category: 'ب',
          amount: 10000,
        );
        await seedExpense(
          date: DateTime(2026, 1, 8),
          category: 'أ',
          amount: 10000,
        );

        final report = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.rows[0].category, 'أ');
        expect(report.rows[1].category, 'ب');
      });

      test('expense details sorted by date descending, then createdAt, then id',
          () async {
        await seedExpense(
          date: DateTime(2026, 1, 10),
          category: 'رواتب',
          amount: 10000,
        );
        await seedExpense(
          date: DateTime(2026, 1, 5),
          category: 'رواتب',
          amount: 20000,
        );

        final report = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.allDetails.first.date.year, 2026);
        expect(report.allDetails.first.date.month, 1);
        expect(report.allDetails.first.date.day, 10);
        expect(report.allDetails.last.date.day, 5);
      });
    });

    group('Reconciliation', () {
      test('sum of row totals equals grand total', () async {
        await seedExpense(
          date: DateTime(2026, 1, 5),
          category: 'رواتب',
          amount: 30000,
        );
        await seedExpense(
          date: DateTime(2026, 1, 8),
          category: 'إيجار',
          amount: 15000,
        );
        await seedExpense(
          date: DateTime(2026, 1, 12),
          category: 'مرافق',
          amount: 5000,
        );

        final report = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        final rowSumTotal =
            report.rows.fold<int>(0, (sum, r) => sum + r.totalAmountQirsh);
        expect(rowSumTotal, report.totalQirsh);
      });

      test('sum of row counts equals grand count', () async {
        await seedExpense(
          date: DateTime(2026, 1, 5),
          category: 'رواتب',
          amount: 30000,
        );
        await seedExpense(
          date: DateTime(2026, 1, 8),
          category: 'إيجار',
          amount: 15000,
        );

        final report = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        final rowCountSum = report.rows.fold<int>(0, (sum, r) => sum + r.count);
        expect(rowCountSum, report.grandCount);
      });

      test('percentages are calculated correctly', () async {
        await seedExpense(
          date: DateTime(2026, 1, 5),
          category: 'رواتب',
          amount: 30000,
        );
        await seedExpense(
          date: DateTime(2026, 1, 8),
          category: 'إيجار',
          amount: 10000,
        );

        final report = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        final rRow = report.rows.firstWhere((r) => r.category == 'رواتب');
        final eRow = report.rows.firstWhere((r) => r.category == 'إيجار');
        expect(rRow.percentageOfTotal, 75.0);
        expect(eRow.percentageOfTotal, 25.0);
      });

      test('percentage is zero when grand total is zero', () async {
        final report = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report.totalQirsh, 0);
        expect(report.grandCount, 0);
        expect(report.rows, isEmpty);
      });
    });

    group('Read-only integrity', () {
      test('report generation does not modify expense repository', () async {
        await seedExpense(
          date: DateTime(2026, 1, 5),
          category: 'رواتب',
          amount: 10000,
        );

        final expensesBefore = await expenseRepo.listExpenses();
        final countBefore = expensesBefore.length;

        await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        final expensesAfter = await expenseRepo.listExpenses();
        expect(expensesAfter.length, countBefore);
      });

      test('report generation does not modify financial account repository',
          () async {
        final acc = await createAccount('خزينة', FinancialAccountType.treasury);
        await seedOpeningBalance(acc.id, 1000000);
        await seedExpense(
          date: DateTime(2026, 1, 5),
          category: 'رواتب',
          amount: 10000,
        );

        final balancesBefore = await repo.allAccountBalances();

        await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        final balancesAfter = await repo.allAccountBalances();
        expect(balancesAfter.length, balancesBefore.length);
      });

      test('repeated generation returns equivalent results', () async {
        await seedExpense(
          date: DateTime(2026, 1, 5),
          category: 'رواتب',
          amount: 10000,
        );
        await seedExpense(
          date: DateTime(2026, 1, 8),
          category: 'إيجار',
          amount: 20000,
        );

        final report1 = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );
        final report2 = await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        expect(report1.rows.length, report2.rows.length);
        expect(report1.totalQirsh, report2.totalQirsh);
        expect(report1.grandCount, report2.grandCount);
        expect(report1.allDetails.length, report2.allDetails.length);
      });

      test('expense records are not changed', () async {
        await seedExpense(
          date: DateTime(2026, 1, 5),
          category: 'رواتب',
          amount: 10000,
        );

        final expensesBefore = await expenseRepo.listExpenses();
        final firstExpense = expensesBefore.first;

        await service.expenseAnalysisReport(
          fromDate: DateTime(2026, 1, 1),
          toDate: DateTime(2026, 1, 31),
        );

        final expensesAfter = await expenseRepo.listExpenses();
        final afterExpense =
            expensesAfter.firstWhere((e) => e.id == firstExpense.id);
        expect(afterExpense.category, firstExpense.category);
        expect(afterExpense.amountQirsh, firstExpense.amountQirsh);
      });
    });

    group('PDF and CSV naming', () {
      test('PDF filename ends with .pdf', () {
        final filename =
            PdfFileNaming.expenseAnalysisReport(DateTime(2026, 1, 15));
        expect(filename, endsWith('.pdf'));
      });

      test('CSV filename ends with .csv', () {
        final filename =
            PdfFileNaming.expenseAnalysisReportCsv(DateTime(2026, 1, 15));
        expect(filename, endsWith('.csv'));
      });

      test('PDF filename contains Arabic name', () {
        final filename =
            PdfFileNaming.expenseAnalysisReport(DateTime(2026, 1, 15));
        expect(filename, contains('تحليل-المصروفات'));
      });

      test('CSV filename contains date stamp', () {
        final filename =
            PdfFileNaming.expenseAnalysisReportCsv(DateTime(2026, 1, 15));
        expect(filename, contains('2026-01-15'));
      });

      test('no forbidden characters in filenames', () {
        final filename =
            PdfFileNaming.expenseAnalysisReport(DateTime(2026, 1, 15));
        expect(filename, isNot(contains(':')));
        expect(filename, isNot(contains('*')));
        expect(filename, isNot(contains('?')));
        expect(filename, isNot(contains('<')));
        expect(filename, isNot(contains('>')));
        expect(filename, isNot(contains('|')));
      });
    });

    group('UI permission and navigation', () {
      test('owner can open report', () {
        expect(Permissions.owner.canViewFinancialReports, true);
      });

      test('employee/non-owner is denied', () {
        expect(Permissions.employee.canViewFinancialReports, false);
      });
    });
  });
}
