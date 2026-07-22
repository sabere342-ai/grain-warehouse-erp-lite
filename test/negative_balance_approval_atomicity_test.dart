import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_service.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';

void main() {
  group('Negative-balance approval atomicity', () {
    late LocalAuthRepository auth;
    late LocalNegativeBalanceApprovalRepository approvals;
    late LocalFinancialAccountRepository accounts;
    late NegativeBalanceApprovalService service;
    late FinancialAccount account;

    setUp(() async {
      final now = DateTime(2026, 1, 1);
      final owner = AppUser(
        id: 'owner-1',
        name: 'Owner',
        phone: '01000000000',
        role: UserRole.owner,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
      final employee = AppUser(
        id: 'employee-1',
        name: 'Employee',
        phone: '01100000000',
        role: UserRole.employee,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
      auth = LocalAuthRepository(
        seedAccounts: [
          LocalAuthAccount(user: owner, password: 'owner-password'),
          LocalAuthAccount(user: employee, password: 'employee-password'),
        ],
      );
      approvals = LocalNegativeBalanceApprovalRepository();
      service = NegativeBalanceApprovalService(
        authRepository: auth,
        approvalRepository: approvals,
        auditLogRepository: LocalAuditLogRepository(),
      );
      accounts = LocalFinancialAccountRepository(
        auditLogRepository: LocalAuditLogRepository(),
        negativeBalanceApprovalService: service,
      );
      account = await accounts.createAccount(
        const FinancialAccountDraft(
          name: 'Treasury',
          type: FinancialAccountType.treasury,
          allowNegativeBalance: true,
          createdByUserId: 'owner-1',
        ),
      );
      await accounts.setOpeningBalance(
        accountId: account.id,
        amountQirsh: 1000,
        effectiveDate: now,
        createdByUserId: 'owner-1',
      );
    });

    Future<String> approve({
      int amountQirsh = 1500,
      String sourceDocumentId = 'expense-request-1',
      String requesterUserId = 'employee-1',
    }) async {
      final before = await accounts.currentBalanceForAccount(account.id);
      return service.requestApproval(
        draft: NegativeBalanceApprovalDraft(
          requestedByUserId: requesterUserId,
          // The service authenticates this id again; it is never trusted from
          // the caller.
          approvedByOwnerUserId: 'owner-1',
          accountId: account.id,
          amountQirsh: amountQirsh,
          operationType: NegativeBalanceOperationType.expense,
          sourceDocumentId: sourceDocumentId,
          sourceDocumentType: FinancialAccountEntrySource.expense.name,
          balanceBeforeQirsh: before,
          expectedBalanceAfterQirsh: before - amountQirsh,
          reason: 'Cash is required before the next deposit.',
        ),
        ownerPhone: '01000000000',
        ownerPassword: 'owner-password',
      );
    }

    test('consumes an exact approval once and leaves the session unchanged',
        () async {
      await auth.signIn(phone: '01100000000', password: 'employee-password');
      final approvalId = await approve();

      final entry = await accounts.createEntry(
        accountId: account.id,
        direction: FinancialAccountEntryDirection.outflow,
        amountQirsh: 1500,
        sourceType: FinancialAccountEntrySource.expense,
        sourceDocumentId: 'expense-request-1',
        effectiveDate: DateTime(2026, 1, 2),
        createdByUserId: 'employee-1',
        negativeBalanceApprovalId: approvalId,
      );

      expect(entry.negativeBalanceApprovalId, approvalId);
      expect((await auth.currentUser())!.id, 'employee-1');
      expect((await approvals.findById(approvalId))!.status,
          NegativeBalanceApprovalStatus.consumed);
      await expectLater(
        accounts.createEntry(
          accountId: account.id,
          direction: FinancialAccountEntryDirection.outflow,
          amountQirsh: 1,
          sourceType: FinancialAccountEntrySource.expense,
          sourceDocumentId: 'expense-request-1',
          effectiveDate: DateTime(2026, 1, 2),
          createdByUserId: 'employee-1',
          negativeBalanceApprovalId: approvalId,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects a changed amount without consuming the approval', () async {
      final approvalId = await approve();

      await expectLater(
        accounts.createEntry(
          accountId: account.id,
          direction: FinancialAccountEntryDirection.outflow,
          amountQirsh: 1501,
          sourceType: FinancialAccountEntrySource.expense,
          sourceDocumentId: 'expense-request-1',
          effectiveDate: DateTime(2026, 1, 2),
          createdByUserId: 'employee-1',
          negativeBalanceApprovalId: approvalId,
        ),
        throwsA(isA<StateError>()),
      );

      expect((await approvals.findById(approvalId))!.status,
          NegativeBalanceApprovalStatus.pending);
      expect(await accounts.currentBalanceForAccount(account.id), 1000);
    });

    test('rejects owner credentials without creating an approval', () async {
      final before = await approvals.listAll();
      await expectLater(
        service.requestApproval(
          draft: NegativeBalanceApprovalDraft(
            requestedByUserId: 'employee-1',
            approvedByOwnerUserId: 'owner-1',
            accountId: account.id,
            amountQirsh: 1500,
            operationType: NegativeBalanceOperationType.expense,
            sourceDocumentId: 'expense-request-1',
            sourceDocumentType: FinancialAccountEntrySource.expense.name,
            balanceBeforeQirsh: 1000,
            expectedBalanceAfterQirsh: -500,
            reason: 'Required.',
          ),
          ownerPhone: '01000000000',
          ownerPassword: 'wrong-password',
        ),
        throwsA(isA<StateError>()),
      );
      expect(await approvals.listAll(), before);
    });

    test(
        'rolls back expense, entry, approval consumption, and audit on failure',
        () async {
      final failingAudit = _FailOnActionAudit('expense.created');
      service = NegativeBalanceApprovalService(
        authRepository: auth,
        approvalRepository: approvals,
        auditLogRepository: failingAudit,
      );
      accounts = LocalFinancialAccountRepository(
        auditLogRepository: failingAudit,
        negativeBalanceApprovalService: service,
      );
      account = await accounts.createAccount(
        const FinancialAccountDraft(
          name: 'Atomic treasury',
          type: FinancialAccountType.treasury,
          allowNegativeBalance: true,
          createdByUserId: 'owner-1',
        ),
      );
      await accounts.setOpeningBalance(
        accountId: account.id,
        amountQirsh: 1000,
        effectiveDate: DateTime(2026, 1, 1),
        createdByUserId: 'owner-1',
      );
      final approvalId = await approve(
        requesterUserId: 'system',
        sourceDocumentId: 'expense-request-atomic',
      );
      final expenses = LocalExpenseRepository(
        auditLogRepository: failingAudit,
        financialAccountRepository: accounts,
      );

      await expectLater(
        expenses.createExpense(
          ExpenseDraft(
            date: DateTime(2026, 1, 2),
            category: 'Utilities',
            amountQirsh: 1500,
            createdByUserId: 'system',
            financialAccountId: account.id,
            paymentMethod: PaymentMethod.cash,
            negativeBalanceApprovalId: approvalId,
            operationRequestId: 'expense-request-atomic',
          ),
        ),
        throwsA(isA<StateError>()),
      );

      expect(await expenses.listExpenses(), isEmpty);
      expect(await accounts.currentBalanceForAccount(account.id), 1000);
      expect((await approvals.findById(approvalId))!.status,
          NegativeBalanceApprovalStatus.pending);
    });

    test('approval snapshot restores immutable lifecycle state', () async {
      final approvalId = await approve();
      final snapshot = approvals.createTransactionSnapshot();
      snapshot.capture();
      await approvals.consumeApproval(
        approvalId: approvalId,
        consumedByTransactionId: 'transaction-1',
      );
      snapshot.rollback();

      final restored = (await approvals.findById(approvalId))!;
      expect(restored.status, NegativeBalanceApprovalStatus.pending);
      expect(restored.consumedAt, isNull);
      expect(restored.consumedByTransactionId, isNull);
    });

    test('nested repository boundaries participate in the outer rollback',
        () async {
      final values = <int>[1];
      await expectLater(
        RepositoryTransaction.execute([ListSnapshot(values)], () async {
          values.add(2);
          await RepositoryTransaction.execute([ListSnapshot(values)], () async {
            values.add(3);
          });
          throw StateError('outer failure');
        }),
        throwsStateError,
      );
      expect(values, [1]);
    });

    test('serializes concurrent transaction boundaries', () async {
      final started = Completer<void>();
      final release = Completer<void>();
      var secondRan = false;
      final first = RepositoryTransaction.execute(<SnapshotHolder>[], () async {
        started.complete();
        await release.future;
        return 1;
      });
      await started.future;
      final second =
          RepositoryTransaction.execute(<SnapshotHolder>[], () async {
        secondRan = true;
        return 2;
      });
      await Future<void>.delayed(Duration.zero);
      expect(secondRan, isFalse);
      release.complete();
      expect(await first, 1);
      expect(await second, 2);
      expect(secondRan, isTrue);
    });
  });
}

class _FailOnActionAudit extends LocalAuditLogRepository {
  _FailOnActionAudit(this.actionToFail);

  final String actionToFail;

  @override
  Future<AuditLogEntry> record(AuditLogDraft draft) {
    if (draft.actionType == actionToFail) {
      throw StateError('Injected audit failure.');
    }
    return super.record(draft);
  }
}
