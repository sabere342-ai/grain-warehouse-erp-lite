import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';

void main() {
  group('Phase 71 — Unified Financial Accounts Foundation', () {
    group('FinancialAccount model', () {
      test('hasValidId returns true for non-empty id', () {
        final account = FinancialAccount(
          id: 'fa-1',
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'user-1',
          createdAt: DateTime(2026),
        );
        expect(account.hasValidId, true);
      });

      test('hasValidId returns false for empty id', () {
        final account = FinancialAccount(
          id: '  ',
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'user-1',
          createdAt: DateTime(2026),
        );
        expect(account.hasValidId, false);
      });

      test('defaults are applied correctly', () {
        final account = FinancialAccount(
          id: 'fa-1',
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'user-1',
          createdAt: DateTime(2026),
        );
        expect(account.isActive, true);
        expect(account.openingBalanceQirsh, 0);
        expect(account.openingBalanceDate, null);
        expect(account.referenceInfo, null);
        expect(account.notes, null);
      });

      test('FinancialAccountType labelAr returns Arabic labels', () {
        expect(FinancialAccountType.treasury.labelAr, 'خزينة');
        expect(FinancialAccountType.bank.labelAr, 'حساب بنكي');
        expect(
            FinancialAccountType.electronicWallet.labelAr, 'محفظة إلكترونية');
      });
    });

    group('FinancialAccountEntry model', () {
      test('hasValidId returns true for non-empty id', () {
        final entry = FinancialAccountEntry(
          id: 'fae-1',
          accountId: 'fa-1',
          direction: FinancialAccountEntryDirection.inflow,
          amountQirsh: 1000,
          sourceType: FinancialAccountEntrySource.openingBalance,
          sourceDocumentId: 'ob-1',
          effectiveDate: DateTime(2026),
          createdAt: DateTime(2026),
          createdByUserId: 'user-1',
        );
        expect(entry.hasValidId, true);
      });

      test('signedAmountQirsh is positive for inflow', () {
        final entry = FinancialAccountEntry(
          id: 'fae-1',
          accountId: 'fa-1',
          direction: FinancialAccountEntryDirection.inflow,
          amountQirsh: 5000,
          sourceType: FinancialAccountEntrySource.openingBalance,
          sourceDocumentId: 'ob-1',
          effectiveDate: DateTime(2026),
          createdAt: DateTime(2026),
          createdByUserId: 'user-1',
        );
        expect(entry.signedAmountQirsh, 5000);
      });

      test('signedAmountQirsh is negative for outflow', () {
        final entry = FinancialAccountEntry(
          id: 'fae-1',
          accountId: 'fa-1',
          direction: FinancialAccountEntryDirection.outflow,
          amountQirsh: 3000,
          sourceType: FinancialAccountEntrySource.manualCorrection,
          sourceDocumentId: 'mc-1',
          effectiveDate: DateTime(2026),
          createdAt: DateTime(2026),
          createdByUserId: 'user-1',
        );
        expect(entry.signedAmountQirsh, -3000);
      });

      test('FinancialAccountEntryDirection labelAr returns Arabic labels', () {
        expect(FinancialAccountEntryDirection.inflow.labelAr, 'وارد');
        expect(FinancialAccountEntryDirection.outflow.labelAr, 'صادر');
      });

      test('FinancialAccountEntrySource labelAr returns Arabic labels', () {
        expect(
            FinancialAccountEntrySource.openingBalance.labelAr, 'رصيد افتتاحي');
        expect(
            FinancialAccountEntrySource.manualCorrection.labelAr, 'تصحيح يدوي');
        expect(FinancialAccountEntrySource.restoreImport.labelAr,
            'استيراد/استرجاع');
      });
    });

    group('LocalFinancialAccountRepository', () {
      late LocalFinancialAccountRepository repo;

      setUp(() {
        repo = LocalFinancialAccountRepository();
      });

      test('starts empty', () async {
        final accounts = await repo.listAccounts(includeInactive: true);
        expect(accounts, isEmpty);
        final balances = await repo.allAccountBalances();
        expect(balances, isEmpty);
      });

      test('createAccount creates account with auto-generated id', () async {
        const draft = FinancialAccountDraft(
          name: 'خزينة المخزن',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
        );
        final account = await repo.createAccount(draft);
        expect(account.hasValidId, true);
        expect(account.name, 'خزينة المخزن');
        expect(account.type, FinancialAccountType.treasury);
        expect(account.isActive, true);
        expect(account.createdByUserId, 'owner');
      });

      test('createAccount rejects duplicate active name', () async {
        const draft = FinancialAccountDraft(
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
        );
        await repo.createAccount(draft);
        expect(() => repo.createAccount(draft), throwsStateError);
      });

      test('createAccount allows same name after deactivation', () async {
        const draft = FinancialAccountDraft(
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
        );
        final account = await repo.createAccount(draft);
        await repo.deactivateAccount(account.id, 'owner');
        const draft2 = FinancialAccountDraft(
          name: 'خزينة',
          type: FinancialAccountType.bank,
          createdByUserId: 'owner',
        );
        final account2 = await repo.createAccount(draft2);
        expect(account2.name, 'خزينة');
        expect(account2.type, FinancialAccountType.bank);
      });

      test('createAccount rejects empty name', () {
        const draft = FinancialAccountDraft(
          name: '  ',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
        );
        expect(() => repo.createAccount(draft), throwsArgumentError);
      });

      test('listAccounts excludes inactive by default', () async {
        const draft1 = FinancialAccountDraft(
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
        );
        const draft2 = FinancialAccountDraft(
          name: 'حساب بنكي',
          type: FinancialAccountType.bank,
          createdByUserId: 'owner',
        );
        final a1 = await repo.createAccount(draft1);
        await repo.createAccount(draft2);
        await repo.deactivateAccount(a1.id, 'owner');

        final active = await repo.listAccounts();
        expect(active.length, 1);
        expect(active.first.name, 'حساب بنكي');

        final all = await repo.listAccounts(includeInactive: true);
        expect(all.length, 2);
      });

      test('deactivateAccount sets isActive to false', () async {
        const draft = FinancialAccountDraft(
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
        );
        final account = await repo.createAccount(draft);
        await repo.deactivateAccount(account.id, 'owner');
        final updated = await repo.accountById(account.id);
        expect(updated.isActive, false);
      });

      test('deactivateAccount rejects already inactive account', () async {
        const draft = FinancialAccountDraft(
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
        );
        final account = await repo.createAccount(draft);
        await repo.deactivateAccount(account.id, 'owner');
        expect(
          () => repo.deactivateAccount(account.id, 'owner'),
          throwsStateError,
        );
      });

      test('reactivateAccount sets isActive to true', () async {
        const draft = FinancialAccountDraft(
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
        );
        final account = await repo.createAccount(draft);
        await repo.deactivateAccount(account.id, 'owner');
        await repo.reactivateAccount(account.id, 'owner');
        final updated = await repo.accountById(account.id);
        expect(updated.isActive, true);
      });

      test('reactivateAccount rejects already active account', () async {
        const draft = FinancialAccountDraft(
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
        );
        final account = await repo.createAccount(draft);
        expect(
          () => repo.reactivateAccount(account.id, 'owner'),
          throwsStateError,
        );
      });

      test('accountById throws for non-existent id', () {
        expect(() => repo.accountById('non-existent'), throwsStateError);
      });

      test('setOpeningBalance records opening balance entry', () async {
        const draft = FinancialAccountDraft(
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
        );
        final account = await repo.createAccount(draft);
        await repo.setOpeningBalance(
          accountId: account.id,
          amountQirsh: 500000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'owner',
        );

        final balance = await repo.currentBalanceForAccount(account.id);
        expect(balance, 500000);

        final statement = await repo.statementForAccount(account.id);
        expect(statement.lines.length, 1);
        expect(statement.openingBalanceQirsh, 500000);
        expect(statement.finalBalanceQirsh, 500000);
      });

      test('setOpeningBalance rejects if account already has opening balance',
          () async {
        const draft = FinancialAccountDraft(
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
        );
        final account = await repo.createAccount(draft);
        await repo.setOpeningBalance(
          accountId: account.id,
          amountQirsh: 500000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'owner',
        );
        expect(
          () => repo.setOpeningBalance(
            accountId: account.id,
            amountQirsh: 100000,
            effectiveDate: DateTime(2026, 1, 1),
            createdByUserId: 'owner',
          ),
          throwsStateError,
        );
      });

      test('setOpeningBalance rejects zero amount', () async {
        const draft = FinancialAccountDraft(
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
        );
        final account = await repo.createAccount(draft);
        expect(
          () => repo.setOpeningBalance(
            accountId: account.id,
            amountQirsh: 0,
            effectiveDate: DateTime(2026, 1, 1),
            createdByUserId: 'owner',
          ),
          throwsArgumentError,
        );
      });

      test('correctOpeningBalance creates correction entries', () async {
        const draft = FinancialAccountDraft(
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
        );
        final account = await repo.createAccount(draft);
        await repo.setOpeningBalance(
          accountId: account.id,
          amountQirsh: 500000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'owner',
        );

        await repo.correctOpeningBalance(OpeningBalanceCorrectionDraft(
          accountId: account.id,
          correctedOpeningBalanceQirsh: 750000,
          reason: 'خطأ في العد',
          createdByUserId: 'owner',
        ));

        final updatedAccount = await repo.accountById(account.id);
        expect(updatedAccount.openingBalanceQirsh, 750000);

        final balance = await repo.currentBalanceForAccount(account.id);
        expect(balance, 750000);

        final statement = await repo.statementForAccount(account.id);
        expect(statement.lines.length, 3);
      });

      test('correctOpeningBalance rejects when no opening balance exists',
          () async {
        const draft = FinancialAccountDraft(
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
        );
        final account = await repo.createAccount(draft);
        expect(
          () => repo.correctOpeningBalance(OpeningBalanceCorrectionDraft(
            accountId: account.id,
            correctedOpeningBalanceQirsh: 500000,
            reason: 'سبب',
            createdByUserId: 'owner',
          )),
          throwsStateError,
        );
      });

      test('correctOpeningBalance rejects negative amount', () async {
        const draft = FinancialAccountDraft(
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
        );
        final account = await repo.createAccount(draft);
        await repo.setOpeningBalance(
          accountId: account.id,
          amountQirsh: 500000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'owner',
        );
        expect(
          () => repo.correctOpeningBalance(OpeningBalanceCorrectionDraft(
            accountId: account.id,
            correctedOpeningBalanceQirsh: -100,
            reason: 'سبب',
            createdByUserId: 'owner',
          )),
          throwsArgumentError,
        );
      });

      test('allAccountBalances returns correct balances', () async {
        const draft1 = FinancialAccountDraft(
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
        );
        const draft2 = FinancialAccountDraft(
          name: 'حساب بنكي',
          type: FinancialAccountType.bank,
          createdByUserId: 'owner',
        );
        final a1 = await repo.createAccount(draft1);
        final a2 = await repo.createAccount(draft2);

        await repo.setOpeningBalance(
          accountId: a1.id,
          amountQirsh: 100000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'owner',
        );
        await repo.setOpeningBalance(
          accountId: a2.id,
          amountQirsh: 500000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'owner',
        );

        final balances = await repo.allAccountBalances();
        expect(balances.length, 2);
        final total =
            balances.fold<int>(0, (s, b) => s + b.currentBalanceQirsh);
        expect(total, 600000);
      });

      test('accountHasEntries returns false for new account', () async {
        const draft = FinancialAccountDraft(
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
        );
        final account = await repo.createAccount(draft);
        expect(await repo.accountHasEntries(account.id), false);
      });

      test('accountHasEntries returns true after opening balance', () async {
        const draft = FinancialAccountDraft(
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
        );
        final account = await repo.createAccount(draft);
        await repo.setOpeningBalance(
          accountId: account.id,
          amountQirsh: 100000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'owner',
        );
        expect(await repo.accountHasEntries(account.id), true);
      });

      test('statement filters by date range', () async {
        const draft = FinancialAccountDraft(
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
        );
        final account = await repo.createAccount(draft);
        await repo.setOpeningBalance(
          accountId: account.id,
          amountQirsh: 100000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'owner',
        );
        await repo.correctOpeningBalance(OpeningBalanceCorrectionDraft(
          accountId: account.id,
          correctedOpeningBalanceQirsh: 200000,
          reason: 'تصحيح',
          createdByUserId: 'owner',
        ));

        final fullStatement = await repo.statementForAccount(account.id);
        expect(fullStatement.lines.length, 3);

        final filteredStatement = await repo.statementForAccount(
          account.id,
          fromDate: DateTime(2026, 7, 1),
        );
        expect(filteredStatement.lines.length, 2);
      });
    });

    group('clearForOwnerDataWipe', () {
      test('clears all accounts and entries', () async {
        final repo = LocalFinancialAccountRepository();
        const draft = FinancialAccountDraft(
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
        );
        await repo.createAccount(draft);
        final accounts = await repo.listAccounts(includeInactive: true);
        expect(accounts.length, 1);

        await repo.clearForOwnerDataWipe();
        final after = await repo.listAccounts(includeInactive: true);
        expect(after, isEmpty);
      });
    });

    group('restoreFinancialAccountsIntoEmpty', () {
      test('restores accounts and entries', () async {
        final repo = LocalFinancialAccountRepository();
        final account = FinancialAccount(
          id: 'fa-restored',
          name: 'خزينة مسترجعة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
          createdAt: DateTime(2026),
        );
        final entry = FinancialAccountEntry(
          id: 'fae-restored',
          accountId: 'fa-restored',
          direction: FinancialAccountEntryDirection.inflow,
          amountQirsh: 100000,
          sourceType: FinancialAccountEntrySource.restoreImport,
          sourceDocumentId: 'import-1',
          effectiveDate: DateTime(2026),
          createdAt: DateTime(2026),
          createdByUserId: 'owner',
        );
        await repo.restoreFinancialAccountsIntoEmpty(
          accounts: [account],
          entries: [entry],
        );
        final accountsAfter = await repo.listAccounts(includeInactive: true);
        expect(accountsAfter.length, 1);
        expect(accountsAfter.first.name, 'خزينة مسترجعة');
        final balance = await repo.currentBalanceForAccount('fa-restored');
        expect(balance, 100000);
      });

      test('rejects restore into non-empty repository', () async {
        final repo = LocalFinancialAccountRepository();
        const draft = FinancialAccountDraft(
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
        );
        await repo.createAccount(draft);
        expect(
          () => repo.restoreFinancialAccountsIntoEmpty(
            accounts: const [],
            entries: const [],
          ),
          throwsStateError,
        );
      });

      test('rejects duplicate account ids', () {
        final repo = LocalFinancialAccountRepository();
        final account = FinancialAccount(
          id: 'fa-dup',
          name: 'حساب',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
          createdAt: DateTime(2026),
        );
        expect(
          () => repo.restoreFinancialAccountsIntoEmpty(
            accounts: [account, account],
            entries: const [],
          ),
          throwsStateError,
        );
      });

      test('rejects duplicate entry ids', () {
        final repo = LocalFinancialAccountRepository();
        final entry = FinancialAccountEntry(
          id: 'fae-dup',
          accountId: 'fa-1',
          direction: FinancialAccountEntryDirection.inflow,
          amountQirsh: 1000,
          sourceType: FinancialAccountEntrySource.openingBalance,
          sourceDocumentId: 'ob-1',
          effectiveDate: DateTime(2026),
          createdAt: DateTime(2026),
          createdByUserId: 'owner',
        );
        expect(
          () => repo.restoreFinancialAccountsIntoEmpty(
            accounts: const [],
            entries: [entry, entry],
          ),
          throwsStateError,
        );
      });
    });

    group('OpeningBalanceCorrectionDraft', () {
      test('holds all fields', () {
        const draft = OpeningBalanceCorrectionDraft(
          accountId: 'fa-1',
          correctedOpeningBalanceQirsh: 500000,
          reason: 'خطأ في العد',
          createdByUserId: 'owner',
        );
        expect(draft.accountId, 'fa-1');
        expect(draft.correctedOpeningBalanceQirsh, 500000);
        expect(draft.reason, 'خطأ في العد');
        expect(draft.createdByUserId, 'owner');
      });
    });

    group('FinancialAccountDraft', () {
      test('holds all fields', () {
        const draft = FinancialAccountDraft(
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          referenceInfo: 'فرع الرياض',
          notes: 'ملاحظة',
          createdByUserId: 'owner',
        );
        expect(draft.name, 'خزينة');
        expect(draft.type, FinancialAccountType.treasury);
        expect(draft.referenceInfo, 'فرع الرياض');
        expect(draft.notes, 'ملاحظة');
        expect(draft.createdByUserId, 'owner');
      });
    });

    group('Audit logging', () {
      test('createAccount records audit log', () async {
        final auditRepo = LocalAuditLogRepository();
        final repo = LocalFinancialAccountRepository(
          auditLogRepository: auditRepo,
        );
        const draft = FinancialAccountDraft(
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
        );
        await repo.createAccount(draft);
        final logs = await auditRepo.listLogs();
        expect(logs.length, 1);
        expect(logs.first.actionType, 'financial_account.created');
      });

      test('deactivateAccount records audit log', () async {
        final auditRepo = LocalAuditLogRepository();
        final repo = LocalFinancialAccountRepository(
          auditLogRepository: auditRepo,
        );
        const draft = FinancialAccountDraft(
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
        );
        final account = await repo.createAccount(draft);
        await repo.deactivateAccount(account.id, 'owner');
        final logs = await auditRepo.listLogs();
        expect(logs.length, 2);
        final deactivatedLog = logs.firstWhere(
          (l) => l.actionType == 'financial_account.deactivated',
        );
        expect(deactivatedLog.descriptionAr, contains('تعطيل'));
      });

      test('setOpeningBalance records audit log', () async {
        final auditRepo = LocalAuditLogRepository();
        final repo = LocalFinancialAccountRepository(
          auditLogRepository: auditRepo,
        );
        const draft = FinancialAccountDraft(
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
        );
        final account = await repo.createAccount(draft);
        await repo.setOpeningBalance(
          accountId: account.id,
          amountQirsh: 100000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'owner',
        );
        final logs = await auditRepo.listLogs();
        expect(logs.length, 2);
        final setLog = logs.firstWhere(
          (l) => l.actionType == 'financial_account.opening_balance.set',
        );
        expect(setLog.descriptionAr, contains('رصيد افتتاحي'));
      });

      test('correctOpeningBalance records audit log', () async {
        final auditRepo = LocalAuditLogRepository();
        final repo = LocalFinancialAccountRepository(
          auditLogRepository: auditRepo,
        );
        const draft = FinancialAccountDraft(
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
        );
        final account = await repo.createAccount(draft);
        await repo.setOpeningBalance(
          accountId: account.id,
          amountQirsh: 100000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'owner',
        );
        await repo.correctOpeningBalance(OpeningBalanceCorrectionDraft(
          accountId: account.id,
          correctedOpeningBalanceQirsh: 200000,
          reason: 'تصحيح',
          createdByUserId: 'owner',
        ));
        final logs = await auditRepo.listLogs();
        expect(logs.length, 3);
        final correctedLog = logs.firstWhere(
          (l) => l.actionType == 'financial_account.opening_balance.corrected',
        );
        expect(correctedLog.descriptionAr, contains('تصحيح'));
      });
    });

    group('Account type enum', () {
      test('iconEmoji returns correct emoji', () {
        expect(FinancialAccountType.treasury.iconEmoji, '\uD83D\uDCB0');
        expect(FinancialAccountType.bank.iconEmoji, '\uD83C\uDFE6');
        expect(FinancialAccountType.electronicWallet.iconEmoji, '\uD83D\uDCF1');
      });
    });

    group('Balance calculation edge cases', () {
      test('zero opening balance with no entries returns zero', () async {
        final repo = LocalFinancialAccountRepository();
        const draft = FinancialAccountDraft(
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
        );
        final account = await repo.createAccount(draft);
        final balance = await repo.currentBalanceForAccount(account.id);
        expect(balance, 0);
      });

      test('statement with no entries returns empty lines', () async {
        final repo = LocalFinancialAccountRepository();
        const draft = FinancialAccountDraft(
          name: 'خزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: 'owner',
        );
        final account = await repo.createAccount(draft);
        final statement = await repo.statementForAccount(account.id);
        expect(statement.lines, isEmpty);
        expect(statement.finalBalanceQirsh, 0);
        expect(statement.openingBalanceQirsh, 0);
      });
    });
  });
}
