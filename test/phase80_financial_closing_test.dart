import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_closing.dart';

void main() {
  final owner = AppUser(
      id: 'owner',
      phone: '01000000000',
      name: 'Owner',
      role: UserRole.owner,
      isActive: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026));
  final employee = AppUser(
      id: 'employee',
      phone: '01111111111',
      name: 'Employee',
      role: UserRole.employee,
      isActive: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026));
  late LocalFinancialAccountRepository repo;
  late FinancialAccount treasury;

  setUp(() async {
    repo = LocalFinancialAccountRepository();
    treasury = await repo.createAccount(const FinancialAccountDraft(
        name: 'الخزنة',
        type: FinancialAccountType.treasury,
        createdByUserId: 'owner'));
    await repo.createEntry(
        accountId: treasury.id,
        direction: FinancialAccountEntryDirection.inflow,
        amountQirsh: 1000,
        sourceType: FinancialAccountEntrySource.salePayment,
        sourceDocumentId: 'sale-1',
        effectiveDate: DateTime(2026, 7, 10),
        createdByUserId: 'owner');
  });

  test('daily closing records explicit difference without mutating ledger',
      () async {
    final close = await repo.createClosing(
        user: owner,
        draft: FinancialClosingDraft(
            kind: FinancialClosingKind.daily,
            fromDate: DateTime(2026, 7, 10),
            toDate: DateTime(2026, 7, 10),
            actualBalancesQirsh: {treasury.id: 950}));
    expect(close.lines.single.expectedBalanceQirsh, 1000);
    expect(close.lines.single.differenceQirsh, -50);
    expect(await repo.currentBalanceForAccount(treasury.id), 1000);
  });

  test('approved period blocks posting and duplicate overlapping close',
      () async {
    await repo.createClosing(
        user: owner,
        draft: FinancialClosingDraft(
            kind: FinancialClosingKind.period,
            fromDate: DateTime(2026, 7, 1),
            toDate: DateTime(2026, 7, 10),
            actualBalancesQirsh: {treasury.id: 1000}));
    await expectLater(
        repo.createEntry(
            accountId: treasury.id,
            direction: FinancialAccountEntryDirection.inflow,
            amountQirsh: 1,
            sourceType: FinancialAccountEntrySource.customerCollection,
            sourceDocumentId: 'c-1',
            effectiveDate: DateTime(2026, 7, 5),
            createdByUserId: 'owner'),
        throwsStateError);
    await expectLater(
        repo.createClosing(
            user: owner,
            draft: FinancialClosingDraft(
                kind: FinancialClosingKind.daily,
                fromDate: DateTime(2026, 7, 10),
                toDate: DateTime(2026, 7, 10),
                actualBalancesQirsh: {treasury.id: 1000})),
        throwsStateError);
  });

  test('owner-only reopen unlocks period and preserves reconciliation',
      () async {
    final close = await repo.createClosing(
        user: owner,
        draft: FinancialClosingDraft(
            kind: FinancialClosingKind.daily,
            fromDate: DateTime(2026, 7, 10),
            toDate: DateTime(2026, 7, 10),
            actualBalancesQirsh: {treasury.id: 1000}));
    await expectLater(
        repo.reopenClosing(
            user: employee, closingId: close.id, reason: 'تصحيح'),
        throwsStateError);
    final reopened = await repo.reopenClosing(
        user: owner, closingId: close.id, reason: 'تصحيح موثق');
    expect(reopened.isOpen, isTrue);
    expect(reopened.lines.single.expectedBalanceQirsh, 1000);
    await repo.createEntry(
        accountId: treasury.id,
        direction: FinancialAccountEntryDirection.inflow,
        amountQirsh: 1,
        sourceType: FinancialAccountEntrySource.customerCollection,
        sourceDocumentId: 'c-2',
        effectiveDate: DateTime(2026, 7, 10),
        createdByUserId: 'owner');
  });

  test('requires all active accounts, rejects future and inactive posting',
      () async {
    await repo.createAccount(const FinancialAccountDraft(
        name: 'البنك',
        type: FinancialAccountType.bank,
        createdByUserId: 'owner'));
    await expectLater(
        repo.createClosing(
            user: owner,
            draft: FinancialClosingDraft(
                kind: FinancialClosingKind.daily,
                fromDate: DateTime.now().add(const Duration(days: 1)),
                toDate: DateTime.now().add(const Duration(days: 1)),
                actualBalancesQirsh: {treasury.id: 1000})),
        throwsArgumentError);
    await expectLater(
        repo.createClosing(
            user: owner,
            draft: FinancialClosingDraft(
                kind: FinancialClosingKind.daily,
                fromDate: DateTime(2026, 7, 10),
                toDate: DateTime(2026, 7, 10),
                actualBalancesQirsh: {treasury.id: 1000})),
        throwsStateError);
  });

  test('backup restore preserves closing and old backup default is empty',
      () async {
    final close = await repo.createClosing(
        user: owner,
        draft: FinancialClosingDraft(
            kind: FinancialClosingKind.daily,
            fromDate: DateTime(2026, 7, 10),
            toDate: DateTime(2026, 7, 10),
            actualBalancesQirsh: {treasury.id: 975}));
    final accounts = await repo.listAccounts(includeInactive: true);
    final entries = (await repo.statementForAccount(treasury.id))
        .lines
        .map((line) => line.entry)
        .toList();
    final restored = LocalFinancialAccountRepository();
    await restored.restoreFinancialAccountsIntoEmpty(
        accounts: accounts, entries: entries, closings: [close]);
    final restoredClose = (await restored.listClosings()).single;
    expect(restoredClose.lines.single.differenceQirsh, -25);
    await expectLater(
        restored.createEntry(
            accountId: treasury.id,
            direction: FinancialAccountEntryDirection.inflow,
            amountQirsh: 1,
            sourceType: FinancialAccountEntrySource.customerCollection,
            sourceDocumentId: 'locked',
            effectiveDate: DateTime(2026, 7, 10),
            createdByUserId: 'owner'),
        throwsStateError);
    final oldBackupRestore = LocalFinancialAccountRepository();
    await oldBackupRestore.restoreFinancialAccountsIntoEmpty(
        accounts: accounts, entries: entries);
    expect(await oldBackupRestore.listClosings(), isEmpty);
  });
}
