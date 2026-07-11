import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_controller.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_transfer.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payment.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

void main() {
  final owner = AppUser(
    id: 'owner-1',
    name: 'Owner',
    phone: '0',
    role: UserRole.owner,
    isActive: true,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  final employee = AppUser(
    id: 'emp-1',
    name: 'Employee',
    phone: '1',
    role: UserRole.employee,
    isActive: true,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  group('DC-U007 — Negative-Balance Controls', () {
    group('FinancialAccount.allowNegativeBalance', () {
      test('defaults to false when not specified', () {
        final account = FinancialAccount(
          id: 'a1',
          name: 'test',
          type: FinancialAccountType.treasury,
          createdByUserId: 'u',
          createdAt: DateTime(2026),
        );
        expect(account.allowNegativeBalance, false);
      });

      test('can be set to true in constructor', () {
        final account = FinancialAccount(
          id: 'a1',
          name: 'test',
          type: FinancialAccountType.treasury,
          allowNegativeBalance: true,
          createdByUserId: 'u',
          createdAt: DateTime(2026),
        );
        expect(account.allowNegativeBalance, true);
      });
    });

    group('FinancialAccountDraft.allowNegativeBalance', () {
      test('defaults to false when not specified', () {
        final draft = FinancialAccountDraft(
          name: 'test',
          type: FinancialAccountType.treasury,
          createdByUserId: 'u',
        );
        expect(draft.allowNegativeBalance, false);
      });

      test('can be set to true in constructor', () {
        final draft = FinancialAccountDraft(
          name: 'test',
          type: FinancialAccountType.treasury,
          allowNegativeBalance: true,
          createdByUserId: 'u',
        );
        expect(draft.allowNegativeBalance, true);
      });
    });

    group('createAccount preserves allowNegativeBalance', () {
      test('account created with default has allowNegativeBalance false',
          () async {
        final repo = LocalFinancialAccountRepository();
        final account = await repo.createAccount(
          const FinancialAccountDraft(
            name: 'خزينة',
            type: FinancialAccountType.treasury,
            createdByUserId: 'u1',
          ),
        );
        expect(account.allowNegativeBalance, false);
      });

      test('account created with allowNegativeBalance true preserves it',
          () async {
        final repo = LocalFinancialAccountRepository();
        final account = await repo.createAccount(
          const FinancialAccountDraft(
            name: 'خزينة',
            type: FinancialAccountType.treasury,
            allowNegativeBalance: true,
            createdByUserId: 'u1',
          ),
        );
        expect(account.allowNegativeBalance, true);
      });
    });

    group('updateAccountPolicy', () {
      test('toggles allowNegativeBalance on an account', () async {
        final repo = LocalFinancialAccountRepository();
        final account = await repo.createAccount(
          const FinancialAccountDraft(
            name: 'حساب',
            type: FinancialAccountType.bank,
            createdByUserId: 'u1',
          ),
        );
        expect(account.allowNegativeBalance, false);
        await repo.updateAccountPolicy(
          accountId: account.id,
          allowNegativeBalance: true,
          updatedByUserId: 'u1',
        );
        final updated = await repo.accountById(account.id);
        expect(updated.allowNegativeBalance, true);
      });

      test('can toggle back to false', () async {
        final repo = LocalFinancialAccountRepository();
        final account = await repo.createAccount(
          const FinancialAccountDraft(
            name: 'حساب',
            type: FinancialAccountType.bank,
            allowNegativeBalance: true,
            createdByUserId: 'u1',
          ),
        );
        await repo.updateAccountPolicy(
          accountId: account.id,
          allowNegativeBalance: false,
          updatedByUserId: 'u1',
        );
        final updated = await repo.accountById(account.id);
        expect(updated.allowNegativeBalance, false);
      });

      test('is no-op when setting same value', () async {
        final repo = LocalFinancialAccountRepository();
        final account = await repo.createAccount(
          const FinancialAccountDraft(
            name: 'حساب',
            type: FinancialAccountType.bank,
            createdByUserId: 'u1',
          ),
        );
        final before = await repo.listAccounts();
        await repo.updateAccountPolicy(
          accountId: account.id,
          allowNegativeBalance: false,
          updatedByUserId: 'u1',
        );
        final after = await repo.listAccounts();
        expect(after.length, before.length);
      });

      test('throws for non-existent account', () async {
        final repo = LocalFinancialAccountRepository();
        expect(
          () => repo.updateAccountPolicy(
            accountId: 'nonexistent',
            allowNegativeBalance: true,
            updatedByUserId: 'u1',
          ),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('Balance guard — policy false blocks ALL users', () {
      late LocalFinancialAccountRepository repo;
      late FinancialAccount account;

      setUp(() async {
        repo = LocalFinancialAccountRepository();
        account = await repo.createAccount(
          const FinancialAccountDraft(
            name: 'خزينة',
            type: FinancialAccountType.treasury,
            createdByUserId: 'u1',
          ),
        );
        await repo.setOpeningBalance(
          accountId: account.id,
          amountQirsh: 10000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'u1',
        );
      });

      test('allows outflow up to current balance', () async {
        final entry = await repo.createEntry(
          accountId: account.id,
          direction: FinancialAccountEntryDirection.outflow,
          amountQirsh: 10000,
          sourceType: FinancialAccountEntrySource.expense,
          sourceDocumentId: 'exp-1',
          effectiveDate: DateTime(2026, 1, 2),
          createdByUserId: 'u1',
        );
        expect(entry.amountQirsh, 10000);
        expect(await repo.currentBalanceForAccount(account.id), 0);
      });

      test('blocks outflow that would make balance negative', () async {
        expect(
          () => repo.createEntry(
            accountId: account.id,
            direction: FinancialAccountEntryDirection.outflow,
            amountQirsh: 10001,
            sourceType: FinancialAccountEntrySource.expense,
            sourceDocumentId: 'exp-2',
            effectiveDate: DateTime(2026, 1, 2),
            createdByUserId: 'u1',
          ),
          throwsA(isA<StateError>()),
        );
        expect(await repo.currentBalanceForAccount(account.id), 10000);
      });

      test('blocks outflow when balance is already zero', () async {
        await repo.createEntry(
          accountId: account.id,
          direction: FinancialAccountEntryDirection.outflow,
          amountQirsh: 10000,
          sourceType: FinancialAccountEntrySource.expense,
          sourceDocumentId: 'exp-3',
          effectiveDate: DateTime(2026, 1, 2),
          createdByUserId: 'u1',
        );
        expect(
          () => repo.createEntry(
            accountId: account.id,
            direction: FinancialAccountEntryDirection.outflow,
            amountQirsh: 1,
            sourceType: FinancialAccountEntrySource.expense,
            sourceDocumentId: 'exp-4',
            effectiveDate: DateTime(2026, 1, 3),
            createdByUserId: 'u1',
          ),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('Balance guard — policy true WITHOUT approval blocks ALL users', () {
      late LocalFinancialAccountRepository repo;
      late FinancialAccount account;

      setUp(() async {
        repo = LocalFinancialAccountRepository();
        account = await repo.createAccount(
          const FinancialAccountDraft(
            name: 'خزينة',
            type: FinancialAccountType.treasury,
            createdByUserId: 'u1',
          ),
        );
        await repo.setOpeningBalance(
          accountId: account.id,
          amountQirsh: 10000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'u1',
        );
        await repo.updateAccountPolicy(
          accountId: account.id,
          allowNegativeBalance: true,
          updatedByUserId: 'u1',
        );
      });

      test(
          'policy true + owner without approval → blocked',
          () async {
        expect(
          () => repo.createEntry(
            accountId: account.id,
            direction: FinancialAccountEntryDirection.outflow,
            amountQirsh: 15000,
            sourceType: FinancialAccountEntrySource.expense,
            sourceDocumentId: 'exp-6',
            effectiveDate: DateTime(2026, 1, 2),
            createdByUserId: 'u1',
          ),
          throwsA(isA<StateError>()),
        );
      });

      test(
          'policy true + non-owner without approval → blocked',
          () async {
        expect(
          () => repo.createEntry(
            accountId: account.id,
            direction: FinancialAccountEntryDirection.outflow,
            amountQirsh: 15000,
            sourceType: FinancialAccountEntrySource.expense,
            sourceDocumentId: 'exp-7',
            effectiveDate: DateTime(2026, 1, 2),
            createdByUserId: 'emp-1',
          ),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('Balance guard — policy true WITH owner approval succeeds', () {
      late LocalFinancialAccountRepository repo;
      late FinancialAccount account;

      setUp(() async {
        repo = LocalFinancialAccountRepository();
        account = await repo.createAccount(
          const FinancialAccountDraft(
            name: 'خزينة',
            type: FinancialAccountType.treasury,
            createdByUserId: 'u1',
          ),
        );
        await repo.setOpeningBalance(
          accountId: account.id,
          amountQirsh: 10000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'u1',
        );
        await repo.updateAccountPolicy(
          accountId: account.id,
          allowNegativeBalance: true,
          updatedByUserId: 'u1',
        );
      });

      test('policy true + owner approval → succeeds', () async {
        final entry = await repo.createEntry(
          accountId: account.id,
          direction: FinancialAccountEntryDirection.outflow,
          amountQirsh: 15000,
          sourceType: FinancialAccountEntrySource.expense,
          sourceDocumentId: 'exp-5',
          effectiveDate: DateTime(2026, 1, 2),
          createdByUserId: 'emp-1',
          approvedByUserId: 'owner-1',
        );
        expect(entry.amountQirsh, 15000);
        expect(entry.approvedByUserId, 'owner-1');
        expect(await repo.currentBalanceForAccount(account.id), -5000);
      });

      test('policy true + multiple outflows each need approval', () async {
        await repo.createEntry(
          accountId: account.id,
          direction: FinancialAccountEntryDirection.outflow,
          amountQirsh: 15000,
          sourceType: FinancialAccountEntrySource.expense,
          sourceDocumentId: 'exp-10',
          effectiveDate: DateTime(2026, 1, 2),
          createdByUserId: 'u1',
          approvedByUserId: 'owner-1',
        );
        expect(await repo.currentBalanceForAccount(account.id), -5000);

        await repo.createEntry(
          accountId: account.id,
          direction: FinancialAccountEntryDirection.outflow,
          amountQirsh: 5000,
          sourceType: FinancialAccountEntrySource.expense,
          sourceDocumentId: 'exp-11',
          effectiveDate: DateTime(2026, 1, 3),
          createdByUserId: 'u1',
          approvedByUserId: 'owner-1',
        );
        expect(await repo.currentBalanceForAccount(account.id), -10000);
      });

      test('second outflow without new approval → blocked', () async {
        await repo.createEntry(
          accountId: account.id,
          direction: FinancialAccountEntryDirection.outflow,
          amountQirsh: 15000,
          sourceType: FinancialAccountEntrySource.expense,
          sourceDocumentId: 'exp-12',
          effectiveDate: DateTime(2026, 1, 2),
          createdByUserId: 'u1',
          approvedByUserId: 'owner-1',
        );
        expect(
          () => repo.createEntry(
            accountId: account.id,
            direction: FinancialAccountEntryDirection.outflow,
            amountQirsh: 5000,
            sourceType: FinancialAccountEntrySource.expense,
            sourceDocumentId: 'exp-13',
            effectiveDate: DateTime(2026, 1, 3),
            createdByUserId: 'u1',
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('approval with empty string is treated as no approval', () async {
        expect(
          () => repo.createEntry(
            accountId: account.id,
            direction: FinancialAccountEntryDirection.outflow,
            amountQirsh: 15000,
            sourceType: FinancialAccountEntrySource.expense,
            sourceDocumentId: 'exp-14',
            effectiveDate: DateTime(2026, 1, 2),
            createdByUserId: 'u1',
            approvedByUserId: '  ',
          ),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('Balance guard does not affect inflows', () {
      test('inflow is always allowed regardless of policy', () async {
        final repo = LocalFinancialAccountRepository();
        final account = await repo.createAccount(
          const FinancialAccountDraft(
            name: 'خزينة',
            type: FinancialAccountType.treasury,
            createdByUserId: 'u1',
          ),
        );
        final entry = await repo.createEntry(
          accountId: account.id,
          direction: FinancialAccountEntryDirection.inflow,
          amountQirsh: 10000,
          sourceType: FinancialAccountEntrySource.salePayment,
          sourceDocumentId: 'sale-1',
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'u1',
        );
        expect(entry.signedAmountQirsh, 10000);
        expect(await repo.currentBalanceForAccount(account.id), 10000);
      });
    });

    group('Re-disable blocks again', () {
      test('after toggling off, outflows are blocked again', () async {
        final repo = LocalFinancialAccountRepository();
        final account = await repo.createAccount(
          const FinancialAccountDraft(
            name: 'خزينة',
            type: FinancialAccountType.treasury,
            createdByUserId: 'u1',
          ),
        );
        await repo.setOpeningBalance(
          accountId: account.id,
          amountQirsh: 10000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'u1',
        );

        await repo.updateAccountPolicy(
          accountId: account.id,
          allowNegativeBalance: true,
          updatedByUserId: 'u1',
        );
        await repo.createEntry(
          accountId: account.id,
          direction: FinancialAccountEntryDirection.outflow,
          amountQirsh: 15000,
          sourceType: FinancialAccountEntrySource.expense,
          sourceDocumentId: 'exp-8',
          effectiveDate: DateTime(2026, 1, 2),
          createdByUserId: 'u1',
          approvedByUserId: 'owner-1',
        );
        expect(await repo.currentBalanceForAccount(account.id), -5000);

        await repo.updateAccountPolicy(
          accountId: account.id,
          allowNegativeBalance: false,
          updatedByUserId: 'u1',
        );

        expect(
          () => repo.createEntry(
            accountId: account.id,
            direction: FinancialAccountEntryDirection.outflow,
            amountQirsh: 1,
            sourceType: FinancialAccountEntrySource.expense,
            sourceDocumentId: 'exp-9',
            effectiveDate: DateTime(2026, 1, 3),
            createdByUserId: 'u1',
          ),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('Transfer respects allowNegativeBalance', () {
      test('blocks transfer when source balance insufficient and policy off',
          () async {
        final repo = LocalFinancialAccountRepository();
        final source = await repo.createAccount(
          const FinancialAccountDraft(
            name: 'مصدر',
            type: FinancialAccountType.treasury,
            createdByUserId: 'u1',
          ),
        );
        final dest = await repo.createAccount(
          const FinancialAccountDraft(
            name: 'وجهة',
            type: FinancialAccountType.bank,
            createdByUserId: 'u1',
          ),
        );
        await repo.setOpeningBalance(
          accountId: source.id,
          amountQirsh: 5000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'u1',
        );
        expect(
          () => repo.createTransfer(
            user: owner,
            draft: FinancialTransferDraft(
              clientRequestId: 'tr-1',
              transferReference: 'ref-1',
              sourceAccountId: source.id,
              destinationAccountId: dest.id,
              amountQirsh: 10000,
              effectiveDate: DateTime(2026, 1, 2),
              createdByUserId: 'owner-1',
            ),
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('allows transfer when source allows negative balance', () async {
        final repo = LocalFinancialAccountRepository();
        final source = await repo.createAccount(
          const FinancialAccountDraft(
            name: 'مصدر',
            type: FinancialAccountType.treasury,
            createdByUserId: 'u1',
          ),
        );
        final dest = await repo.createAccount(
          const FinancialAccountDraft(
            name: 'وجهة',
            type: FinancialAccountType.bank,
            createdByUserId: 'u1',
          ),
        );
        await repo.setOpeningBalance(
          accountId: source.id,
          amountQirsh: 5000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'u1',
        );
        await repo.updateAccountPolicy(
          accountId: source.id,
          allowNegativeBalance: true,
          updatedByUserId: 'u1',
        );
        final transfer = await repo.createTransfer(
          user: owner,
          draft: FinancialTransferDraft(
            clientRequestId: 'tr-2',
            transferReference: 'ref-2',
            sourceAccountId: source.id,
            destinationAccountId: dest.id,
            amountQirsh: 10000,
            effectiveDate: DateTime(2026, 1, 2),
            createdByUserId: 'owner-1',
          ),
        );
        expect(transfer.amountQirsh, 10000);
        expect(await repo.currentBalanceForAccount(source.id), -5000);
        expect(await repo.currentBalanceForAccount(dest.id), 10000);
      });
    });

    group('Audit trail for negative-balance approval', () {
      test('negative-balance outflow records approval audit', () async {
        final auditRepo = LocalAuditLogRepository();
        final repo = LocalFinancialAccountRepository(auditLogRepository: auditRepo);
        final account = await repo.createAccount(
          const FinancialAccountDraft(
            name: 'خزينة',
            type: FinancialAccountType.treasury,
            createdByUserId: 'u1',
          ),
        );
        await repo.setOpeningBalance(
          accountId: account.id,
          amountQirsh: 5000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'u1',
        );
        await repo.updateAccountPolicy(
          accountId: account.id,
          allowNegativeBalance: true,
          updatedByUserId: 'u1',
        );
        await repo.createEntry(
          accountId: account.id,
          direction: FinancialAccountEntryDirection.outflow,
          amountQirsh: 10000,
          sourceType: FinancialAccountEntrySource.expense,
          sourceDocumentId: 'exp-audit-1',
          effectiveDate: DateTime(2026, 1, 2),
          createdByUserId: 'emp-1',
          approvedByUserId: 'owner-1',
        );
        final logs = await auditRepo.listLogs();
        final approvalLogs = logs
            .where((l) =>
                l.actionType ==
                'financial_account.entry.negative_balance_approved')
            .toList();
        expect(approvalLogs.length, 1);
        expect(approvalLogs.first.referenceId, isNotNull);
      });

      test('normal outflow does NOT record approval audit', () async {
        final auditRepo = LocalAuditLogRepository();
        final repo = LocalFinancialAccountRepository(auditLogRepository: auditRepo);
        final account = await repo.createAccount(
          const FinancialAccountDraft(
            name: 'خزينة',
            type: FinancialAccountType.treasury,
            createdByUserId: 'u1',
          ),
        );
        await repo.setOpeningBalance(
          accountId: account.id,
          amountQirsh: 10000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'u1',
        );
        await repo.createEntry(
          accountId: account.id,
          direction: FinancialAccountEntryDirection.outflow,
          amountQirsh: 5000,
          sourceType: FinancialAccountEntrySource.expense,
          sourceDocumentId: 'exp-audit-2',
          effectiveDate: DateTime(2026, 1, 2),
          createdByUserId: 'u1',
        );
        final logs = await auditRepo.listLogs();
        final approvalLogs = logs
            .where((l) =>
                l.actionType ==
                'financial_account.entry.negative_balance_approved')
            .toList();
        expect(approvalLogs.length, 0);
      });

      test('blocked operation does NOT create any ledger entry', () async {
        final repo = LocalFinancialAccountRepository();
        final account = await repo.createAccount(
          const FinancialAccountDraft(
            name: 'خزينة',
            type: FinancialAccountType.treasury,
            createdByUserId: 'u1',
          ),
        );
        final entriesBefore = (await repo.statementForAccount(account.id))
            .lines
            .length;
        expect(
          () => repo.createEntry(
            accountId: account.id,
            direction: FinancialAccountEntryDirection.outflow,
            amountQirsh: 1000,
            sourceType: FinancialAccountEntrySource.expense,
            sourceDocumentId: 'exp-audit-3',
            effectiveDate: DateTime(2026, 1, 1),
            createdByUserId: 'u1',
          ),
          throwsA(isA<StateError>()),
        );
        final entriesAfter = (await repo.statementForAccount(account.id))
            .lines
            .length;
        expect(entriesAfter, entriesBefore);
      });
    });

    group('ExpenseRepository integration', () {
      test('expense posting blocked when balance insufficient', () async {
        final faRepo = LocalFinancialAccountRepository();
        final expenseRepo = LocalExpenseRepository(
          financialAccountRepository: faRepo,
        );
        final account = await faRepo.createAccount(
          const FinancialAccountDraft(
            name: 'خزينة',
            type: FinancialAccountType.treasury,
            createdByUserId: 'u1',
          ),
        );
        await faRepo.setOpeningBalance(
          accountId: account.id,
          amountQirsh: 1000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'u1',
        );

        expect(
          () => expenseRepo.createExpense(ExpenseDraft(
            date: DateTime(2026, 1, 2),
            category: 'نقل',
            amountQirsh: 5000,
            financialAccountId: account.id,
          )),
          throwsA(isA<StateError>()),
        );
      });

      test('expense posting allowed when account permits negative with approval',
          () async {
        final faRepo = LocalFinancialAccountRepository();
        final expenseRepo = LocalExpenseRepository(
          financialAccountRepository: faRepo,
        );
        final account = await faRepo.createAccount(
          const FinancialAccountDraft(
            name: 'خزينة',
            type: FinancialAccountType.treasury,
            createdByUserId: 'u1',
          ),
        );
        await faRepo.setOpeningBalance(
          accountId: account.id,
          amountQirsh: 1000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'u1',
        );
        await faRepo.updateAccountPolicy(
          accountId: account.id,
          allowNegativeBalance: true,
          updatedByUserId: 'u1',
        );

        final expense = await expenseRepo.createExpense(ExpenseDraft(
          date: DateTime(2026, 1, 2),
          category: 'نقل',
          amountQirsh: 5000,
          financialAccountId: account.id,
          approvedByUserId: 'owner-1',
        ));
        expect(expense.amountQirsh, 5000);
        expect(await faRepo.currentBalanceForAccount(account.id), -4000);
      });

      test('expense posting blocked when policy true but no approval', () async {
        final faRepo = LocalFinancialAccountRepository();
        final expenseRepo = LocalExpenseRepository(
          financialAccountRepository: faRepo,
        );
        final account = await faRepo.createAccount(
          const FinancialAccountDraft(
            name: 'خزينة',
            type: FinancialAccountType.treasury,
            createdByUserId: 'u1',
          ),
        );
        await faRepo.setOpeningBalance(
          accountId: account.id,
          amountQirsh: 1000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'u1',
        );
        await faRepo.updateAccountPolicy(
          accountId: account.id,
          allowNegativeBalance: true,
          updatedByUserId: 'u1',
        );

        expect(
          () => expenseRepo.createExpense(ExpenseDraft(
            date: DateTime(2026, 1, 2),
            category: 'نقل',
            amountQirsh: 5000,
            financialAccountId: account.id,
          )),
          throwsA(isA<StateError>()),
        );
      });

      test('expense without financial account is not affected', () async {
        final faRepo = LocalFinancialAccountRepository();
        final expenseRepo = LocalExpenseRepository(
          financialAccountRepository: faRepo,
        );
        final expense = await expenseRepo.createExpense(ExpenseDraft(
          date: DateTime(2026, 1, 2),
          category: 'نقل',
          amountQirsh: 5000,
        ));
        expect(expense.amountQirsh, 5000);
      });
    });

    group('SupplierAccountRepository integration', () {
      test('supplier payment blocked when balance insufficient', () async {
        final faRepo = LocalFinancialAccountRepository();
        final supplierRepo = LocalSupplierRepository();
        final supplierAccountRepo = LocalSupplierAccountRepository(
          supplierRepository: supplierRepo,
          financialAccountRepository: faRepo,
        );
        final supplier = await supplierRepo.createSupplier(
          SupplierDraft(name: 'مورد', phone: '0'),
        );
        final account = await faRepo.createAccount(
          const FinancialAccountDraft(
            name: 'خزينة',
            type: FinancialAccountType.treasury,
            createdByUserId: 'u1',
          ),
        );
        await faRepo.setOpeningBalance(
          accountId: account.id,
          amountQirsh: 1000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'u1',
        );
        await supplierAccountRepo.createOpeningBalanceEntry(
          supplierId: supplier.id,
          amountQirsh: 10000,
          createdByUserId: 'u1',
        );

        expect(
          () => supplierAccountRepo.createPayment(
            SupplierPaymentDraft(
              supplierId: supplier.id,
              date: DateTime(2026, 1, 2),
              amountQirsh: 5000,
              createdByUserId: 'u1',
              financialAccountId: account.id,
            ),
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('supplier payment allowed when account permits negative with approval',
          () async {
        final faRepo = LocalFinancialAccountRepository();
        final supplierRepo = LocalSupplierRepository();
        final supplierAccountRepo = LocalSupplierAccountRepository(
          supplierRepository: supplierRepo,
          financialAccountRepository: faRepo,
        );
        final supplier = await supplierRepo.createSupplier(
          SupplierDraft(name: 'مورد', phone: '0'),
        );
        final account = await faRepo.createAccount(
          const FinancialAccountDraft(
            name: 'خزينة',
            type: FinancialAccountType.treasury,
            createdByUserId: 'u1',
          ),
        );
        await faRepo.setOpeningBalance(
          accountId: account.id,
          amountQirsh: 1000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'u1',
        );
        await faRepo.updateAccountPolicy(
          accountId: account.id,
          allowNegativeBalance: true,
          updatedByUserId: 'u1',
        );
        await supplierAccountRepo.createOpeningBalanceEntry(
          supplierId: supplier.id,
          amountQirsh: 10000,
          createdByUserId: 'u1',
        );

        final payment = await supplierAccountRepo.createPayment(
          SupplierPaymentDraft(
            supplierId: supplier.id,
            date: DateTime(2026, 1, 2),
            amountQirsh: 5000,
            createdByUserId: 'u1',
            financialAccountId: account.id,
            approvedByUserId: 'owner-1',
          ),
        );
        expect(payment.amountQirsh, 5000);
        expect(await faRepo.currentBalanceForAccount(account.id), -4000);
      });

      test('supplier payment blocked when policy true but no approval', () async {
        final faRepo = LocalFinancialAccountRepository();
        final supplierRepo = LocalSupplierRepository();
        final supplierAccountRepo = LocalSupplierAccountRepository(
          supplierRepository: supplierRepo,
          financialAccountRepository: faRepo,
        );
        final supplier = await supplierRepo.createSupplier(
          SupplierDraft(name: 'مورد', phone: '0'),
        );
        final account = await faRepo.createAccount(
          const FinancialAccountDraft(
            name: 'خزينة',
            type: FinancialAccountType.treasury,
            createdByUserId: 'u1',
          ),
        );
        await faRepo.setOpeningBalance(
          accountId: account.id,
          amountQirsh: 1000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'u1',
        );
        await faRepo.updateAccountPolicy(
          accountId: account.id,
          allowNegativeBalance: true,
          updatedByUserId: 'u1',
        );
        await supplierAccountRepo.createOpeningBalanceEntry(
          supplierId: supplier.id,
          amountQirsh: 10000,
          createdByUserId: 'u1',
        );

        expect(
          () => supplierAccountRepo.createPayment(
            SupplierPaymentDraft(
              supplierId: supplier.id,
              date: DateTime(2026, 1, 2),
              amountQirsh: 5000,
              createdByUserId: 'u1',
              financialAccountId: account.id,
            ),
          ),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('Backup roundtrip — entry preserves approvedByUserId', () {
      test('entry with approvedByUserId survives in-memory roundtrip', () async {
        final repo = LocalFinancialAccountRepository();
        final account = await repo.createAccount(
          const FinancialAccountDraft(
            name: 'خزينة',
            type: FinancialAccountType.treasury,
            allowNegativeBalance: true,
            createdByUserId: 'u1',
          ),
        );
        await repo.setOpeningBalance(
          accountId: account.id,
          amountQirsh: 5000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'u1',
        );
        final entry = await repo.createEntry(
          accountId: account.id,
          direction: FinancialAccountEntryDirection.outflow,
          amountQirsh: 10000,
          sourceType: FinancialAccountEntrySource.expense,
          sourceDocumentId: 'exp-bk',
          effectiveDate: DateTime(2026, 1, 2),
          createdByUserId: 'emp-1',
          approvedByUserId: 'owner-1',
        );
        expect(entry.approvedByUserId, 'owner-1');
        final statement = await repo.statementForAccount(account.id);
        final outflow = statement.lines
            .where((l) => l.entry.sourceDocumentId == 'exp-bk')
            .first
            .entry;
        expect(outflow.approvedByUserId, 'owner-1');
      });
    });

    group('Controller integration', () {
      test('updateNegativeBalancePolicy requires owner', () async {
        final repo = LocalFinancialAccountRepository();
        final controller = FinancialAccountController(
          repository: repo,
        );
        await controller.createAccount(
          user: owner,
          draft: const FinancialAccountDraft(
            name: 'حساب',
            type: FinancialAccountType.bank,
            createdByUserId: 'owner-1',
          ),
        );
        await controller.loadAccounts(owner);
        final balances = controller.balances;
        expect(balances.length, 1);

        final result = await controller.updateNegativeBalancePolicy(
          user: employee,
          accountId: balances.first.account.id,
          allowNegativeBalance: true,
        );
        expect(result, false);
      });

      test('updateNegativeBalancePolicy succeeds for owner', () async {
        final repo = LocalFinancialAccountRepository();
        final controller = FinancialAccountController(
          repository: repo,
        );
        await controller.createAccount(
          user: owner,
          draft: const FinancialAccountDraft(
            name: 'حساب',
            type: FinancialAccountType.bank,
            createdByUserId: 'owner-1',
          ),
        );
        await controller.loadAccounts(owner);
        final balances = controller.balances;
        expect(balances.length, 1);

        final result = await controller.updateNegativeBalancePolicy(
          user: owner,
          accountId: balances.first.account.id,
          allowNegativeBalance: true,
        );
        expect(result, true);
        final updated = await repo.accountById(balances.first.account.id);
        expect(updated.allowNegativeBalance, true);
      });
    });

    group('Entry approvedByUserId field', () {
      test('non-negative-balance entry has null approvedByUserId', () async {
        final repo = LocalFinancialAccountRepository();
        final account = await repo.createAccount(
          const FinancialAccountDraft(
            name: 'خزينة',
            type: FinancialAccountType.treasury,
            createdByUserId: 'u1',
          ),
        );
        final entry = await repo.createEntry(
          accountId: account.id,
          direction: FinancialAccountEntryDirection.inflow,
          amountQirsh: 5000,
          sourceType: FinancialAccountEntrySource.salePayment,
          sourceDocumentId: 'sale-1',
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'u1',
        );
        expect(entry.approvedByUserId, isNull);
      });

      test('negative-balance entry stores approvedByUserId', () async {
        final repo = LocalFinancialAccountRepository();
        final account = await repo.createAccount(
          const FinancialAccountDraft(
            name: 'خزينة',
            type: FinancialAccountType.treasury,
            allowNegativeBalance: true,
            createdByUserId: 'u1',
          ),
        );
        await repo.setOpeningBalance(
          accountId: account.id,
          amountQirsh: 5000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'u1',
        );
        final entry = await repo.createEntry(
          accountId: account.id,
          direction: FinancialAccountEntryDirection.outflow,
          amountQirsh: 10000,
          sourceType: FinancialAccountEntrySource.expense,
          sourceDocumentId: 'exp-100',
          effectiveDate: DateTime(2026, 1, 2),
          createdByUserId: 'emp-1',
          approvedByUserId: 'owner-1',
        );
        expect(entry.approvedByUserId, 'owner-1');
      });
    });
  });
}
