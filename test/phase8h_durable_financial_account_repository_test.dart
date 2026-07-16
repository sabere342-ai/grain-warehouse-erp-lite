import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/drift_financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_closing.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_transfer.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

final _owner = AppUser(
    id: 'owner',
    phone: '01000000000',
    name: 'Owner',
    role: UserRole.owner,
    isActive: true,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026));

void main() {
  test('schema v8 opens and account, policy and ledger survive restart',
      () async {
    final d = await Directory.systemTemp.createTemp('phase8h-restart-');
    final f = File('${d.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (d.existsSync()) await d.delete(recursive: true);
    });
    var db = openDatabaseFile(f);
    var repo = await DriftFinancialAccountRepository.open(db);
    final a = await repo.createAccount(const FinancialAccountDraft(
        name: 'Treasury',
        type: FinancialAccountType.treasury,
        createdByUserId: 'owner'));
    await repo.updateAccountPolicy(
        accountId: a.id, allowNegativeBalance: true, updatedByUserId: 'owner');
    await repo.createEntry(
        accountId: a.id,
        direction: FinancialAccountEntryDirection.inflow,
        amountQirsh: 1200,
        sourceType: FinancialAccountEntrySource.salePayment,
        sourceDocumentId: 'sale-1',
        effectiveDate: DateTime(2026, 7, 1),
        createdByUserId: 'owner',
        paymentMethod: PaymentMethod.cash,
        correctionGroup: 'cg-1');
    await db.close();
    db = openDatabaseFile(f);
    repo = await DriftFinancialAccountRepository.open(db);
    expect((await repo.accountById(a.id)).allowNegativeBalance, isTrue);
    expect(await repo.currentBalanceForAccount(a.id), 1200);
    expect(
        (await repo.statementForAccount(a.id))
            .lines
            .single
            .entry
            .correctionGroup,
        'cg-1');
    await db.close();
  });

  test('balance is derived from append-only signed entries', () async {
    final db = openInMemoryTestDatabase();
    addTearDown(db.close);
    final r = await DriftFinancialAccountRepository.open(db);
    final a = await r.createAccount(const FinancialAccountDraft(
        name: 'Bank',
        type: FinancialAccountType.bank,
        allowNegativeBalance: true,
        createdByUserId: 'owner'));
    await r.createEntry(
        accountId: a.id,
        direction: FinancialAccountEntryDirection.inflow,
        amountQirsh: 1000,
        sourceType: FinancialAccountEntrySource.salePayment,
        sourceDocumentId: 's',
        effectiveDate: DateTime(2026),
        createdByUserId: 'owner');
    await r.createEntry(
        accountId: a.id,
        direction: FinancialAccountEntryDirection.outflow,
        amountQirsh: 250,
        sourceType: FinancialAccountEntrySource.expense,
        sourceDocumentId: 'e',
        effectiveDate: DateTime(2026, 1, 2),
        createdByUserId: 'owner');
    expect(await r.currentBalanceForAccount(a.id), 750);
    expect(
        (await r.statementForAccount(a.id))
            .lines
            .map((e) => e.runningBalanceQirsh),
        [1000, 750]);
  });

  test('transfer, idempotency and closing persist', () async {
    final db = openInMemoryTestDatabase();
    addTearDown(db.close);
    final r = await DriftFinancialAccountRepository.open(db);
    final a = await r.createAccount(const FinancialAccountDraft(
        name: 'A',
        type: FinancialAccountType.treasury,
        createdByUserId: 'owner'));
    final b = await r.createAccount(const FinancialAccountDraft(
        name: 'B', type: FinancialAccountType.bank, createdByUserId: 'owner'));
    await r.createEntry(
        accountId: a.id,
        direction: FinancialAccountEntryDirection.inflow,
        amountQirsh: 500,
        sourceType: FinancialAccountEntrySource.openingBalance,
        sourceDocumentId: 'seed',
        effectiveDate: DateTime(2026),
        createdByUserId: 'owner');
    final draft = FinancialTransferDraft(
        clientRequestId: 'req-1',
        transferReference: 'ref-1',
        sourceAccountId: a.id,
        destinationAccountId: b.id,
        amountQirsh: 200,
        effectiveDate: DateTime(2026, 1, 2),
        createdByUserId: 'owner');
    final first = await r.createTransfer(user: _owner, draft: draft);
    expect((await r.createTransfer(user: _owner, draft: draft)).id, first.id);
    await r.createClosing(
        user: _owner,
        draft: FinancialClosingDraft(
            kind: FinancialClosingKind.daily,
            fromDate: DateTime(2026, 1, 2),
            toDate: DateTime(2026, 1, 2),
            actualBalancesQirsh: {a.id: 300, b.id: 200}));
    expect(await r.listTransfers(), hasLength(1));
    expect(await r.listClosings(), hasLength(1));
  });

  test('repository snapshot rollback restores durable rows', () async {
    final db = openInMemoryTestDatabase();
    addTearDown(db.close);
    final r = await DriftFinancialAccountRepository.open(db);
    await expectLater(
        RepositoryTransaction.execute([r.createTransactionSnapshot()],
            () async {
          await r.createAccount(const FinancialAccountDraft(
              name: 'Rolled',
              type: FinancialAccountType.treasury,
              createdByUserId: 'owner'));
          throw const FormatException('injected');
        }),
        throwsFormatException);
    expect(await r.listAccounts(), isEmpty);
    expect(await db.select(db.financialAccounts).get(), isEmpty);
  });

  test('concurrent creates serialize without loss', () async {
    final db = openInMemoryTestDatabase();
    addTearDown(db.close);
    final r = await DriftFinancialAccountRepository.open(db);
    await Future.wait(List.generate(
        8,
        (i) => r.createAccount(FinancialAccountDraft(
            name: 'A$i',
            type: FinancialAccountType.treasury,
            createdByUserId: 'owner'))));
    expect(await r.listAccounts(), hasLength(8));
    expect(await db.select(db.financialAccounts).get(), hasLength(8));
  });

  test('v7 populated database upgrades non-destructively to v8', () async {
    final d = await Directory.systemTemp.createTemp('phase8h-migration-');
    final f = File('${d.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (d.existsSync()) await d.delete(recursive: true);
    });
    final legacy = sqlite3.open(f.path);
    legacy.execute(
        'CREATE TABLE foundation_probes (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)');
    legacy.execute("INSERT INTO foundation_probes VALUES ('legacy','kept')");
    legacy.execute('PRAGMA user_version=7');
    legacy.dispose();
    final db = openDatabaseFile(f);
    expect(await db.readProbe('legacy'), 'kept');
    final r = await DriftFinancialAccountRepository.open(db);
    expect(
        await r.createAccount(const FinancialAccountDraft(
            name: 'After',
            type: FinancialAccountType.treasury,
            createdByUserId: 'owner')),
        isA<FinancialAccount>());
    await db.close();
  });

  test('wipe clears durable financial data and permits safe restart', () async {
    final db = openInMemoryTestDatabase();
    addTearDown(db.close);
    final r = await DriftFinancialAccountRepository.open(db);
    await r.createAccount(const FinancialAccountDraft(
        name: 'Wipe',
        type: FinancialAccountType.treasury,
        createdByUserId: 'owner'));
    await r.clearForOwnerDataWipe();
    expect(await r.listAccounts(), isEmpty);
    expect((await DriftFinancialAccountRepository.open(db)).listAccounts(),
        completion(isEmpty));
  });
}
