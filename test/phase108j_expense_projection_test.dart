import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/application/expenses/confirmed_expense_projection_writer.dart';
import 'package:grain_warehouse_erp_lite/application/expenses/expense_posting_attempt_store.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/drift_confirmed_expense_projection_writer.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/drift_expense_posting_attempt_store.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/drift_financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

const businessId = '11111111-1111-4111-8111-111111111111';
const serverAccountId = '22222222-2222-4222-8222-222222222222';
const commandId = '018f7f65-8d31-7b84-bb46-4f47d82c1f70';

void main() {
  test('v15 to v16 is additive and preserves existing rows', () async {
    final directory = await Directory.systemTemp.createTemp('phase108j-v15-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });

    var database = openDatabaseFile(file);
    await database.writeProbe('preserved', 'yes');
    await database.close();
    final legacy = sqlite3.open(file.path);
    legacy.execute('DROP TABLE financial_account_cloud_links');
    legacy.execute('DROP TABLE expense_posting_attempts');
    legacy.execute('PRAGMA user_version = 15');
    legacy.dispose();

    database = openDatabaseFile(file);
    expect(await database.readProbe('preserved'), 'yes');
    expect(database.schemaVersion, 16);
    expect(await database.select(database.financialAccountCloudLinks).get(),
        isEmpty);
    expect(
        await database.select(database.expensePostingAttempts).get(), isEmpty);
    await database.close();
  });

  test('attempt and exact canonical payload survive close and reopen',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('phase108j-attempt-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    var database = openDatabaseFile(file);
    var accounts = await DriftFinancialAccountRepository.open(database);
    var store = DriftExpensePostingAttemptStore(
      database,
      financialAccountRepository: accounts,
    );
    await store.prepare(
      commandId: commandId,
      businessId: businessId,
      canonicalPayloadJson: '{"exact":true}',
      localFingerprint: 'fingerprint',
    );
    await database.close();

    database = openDatabaseFile(file);
    accounts = await DriftFinancialAccountRepository.open(database);
    store = DriftExpensePostingAttemptStore(
      database,
      financialAccountRepository: accounts,
    );
    final restored = await store.load(commandId);
    expect(restored?.commandId, commandId);
    expect(restored?.canonicalPayloadJson, '{"exact":true}');
    expect(restored?.state, ExpensePostingAttemptState.queued);
    await database.close();
  });

  test(
      'confirmed projection is atomic, exact, replay-safe and refreshes balance',
      () async {
    final fixture = await _Fixture.open();
    addTearDown(fixture.close);
    final projection = fixture.projection();

    await fixture.writer.project(projection);

    expect(await fixture.database.select(fixture.database.expenses).get(),
        hasLength(1));
    expect(
      await fixture.database
          .select(fixture.database.financialAccountEntries)
          .get(),
      hasLength(2),
      reason: 'one opening inflow plus one server-confirmed expense outflow',
    );
    expect(await fixture.database.select(fixture.database.auditLogs).get(),
        hasLength(2));
    expect(
      await fixture.accounts.currentBalanceForAccount(fixture.localAccountId),
      8750,
    );
    expect((await fixture.store.load(commandId))?.state,
        ExpensePostingAttemptState.confirmed);

    await fixture.writer.project(projection);

    expect(await fixture.database.select(fixture.database.expenses).get(),
        hasLength(1));
    expect(
        await fixture.database
            .select(fixture.database.financialAccountEntries)
            .get(),
        hasLength(2));
    expect(await fixture.database.select(fixture.database.auditLogs).get(),
        hasLength(2));
    expect(
      await fixture.accounts.currentBalanceForAccount(fixture.localAccountId),
      8750,
    );
  });

  test('injected projection failure rolls back every local projection row',
      () async {
    final fixture = await _Fixture.open(
      failureInjector: (stage) async {
        if (stage == ConfirmedExpenseProjectionStage.afterEntry) {
          throw StateError('injected local projection failure');
        }
      },
    );
    addTearDown(fixture.close);

    await expectLater(
      fixture.writer.project(fixture.projection()),
      throwsStateError,
    );

    expect(await fixture.database.select(fixture.database.expenses).get(),
        isEmpty);
    expect(
      await fixture.database
          .select(fixture.database.financialAccountEntries)
          .get(),
      hasLength(1),
      reason: 'the pre-existing opening entry is preserved',
    );
    expect(await fixture.database.select(fixture.database.auditLogs).get(),
        isEmpty);
    expect(
      await fixture.accounts.currentBalanceForAccount(fixture.localAccountId),
      10000,
    );
    expect((await fixture.store.load(commandId))?.state,
        ExpensePostingAttemptState.queued);
  });

  test('cloud link uniqueness and readiness mismatch fail closed', () async {
    final fixture = await _Fixture.open();
    addTearDown(fixture.close);
    expect(
      await fixture.store.readyLinkForLocalAccount(
        localAccountId: fixture.localAccountId,
        businessId: businessId,
      ),
      isNotNull,
    );

    await fixture.accounts.createEntry(
      accountId: fixture.localAccountId,
      direction: FinancialAccountEntryDirection.outflow,
      amountQirsh: 1,
      sourceType: FinancialAccountEntrySource.expense,
      sourceDocumentId: 'unreconciled-local-change',
      effectiveDate: DateTime(2026, 8, 23),
      createdByUserId: 'local-owner',
      paymentMethod: PaymentMethod.cash,
    );

    expect(
      await fixture.store.readyLinkForLocalAccount(
        localAccountId: fixture.localAccountId,
        businessId: businessId,
      ),
      isNull,
    );
  });
}

final class _Fixture {
  _Fixture({
    required this.database,
    required this.accounts,
    required this.store,
    required this.writer,
    required this.localAccountId,
  });

  final FoundationDatabase database;
  final DriftFinancialAccountRepository accounts;
  final DriftExpensePostingAttemptStore store;
  final DriftConfirmedExpenseProjectionWriter writer;
  final String localAccountId;

  static Future<_Fixture> open({
    Future<void> Function(ConfirmedExpenseProjectionStage stage)?
        failureInjector,
  }) async {
    final database = openInMemoryTestDatabase();
    final accounts = await DriftFinancialAccountRepository.open(database);
    final account = await accounts.createAccount(
      const FinancialAccountDraft(
        name: 'Cloud Treasury',
        type: FinancialAccountType.treasury,
        createdByUserId: 'local-owner',
      ),
    );
    await accounts.createEntry(
      accountId: account.id,
      direction: FinancialAccountEntryDirection.inflow,
      amountQirsh: 10000,
      sourceType: FinancialAccountEntrySource.openingBalance,
      sourceDocumentId: 'pilot-opening',
      effectiveDate: DateTime(2026, 8, 1),
      createdByUserId: 'local-owner',
      paymentMethod: PaymentMethod.cash,
    );
    final store = DriftExpensePostingAttemptStore(
      database,
      financialAccountRepository: accounts,
    );
    await store.saveVerifiedCloudLink(
      FinancialAccountCloudLink(
        localAccountId: account.id,
        businessId: businessId,
        serverAccountUuid: serverAccountId,
        reconciledServerBalanceQirsh: 10000,
        reconciledAtUtc: DateTime.utc(2026, 8, 23, 9),
        reconciliationVersion: 1,
        readyAtUtc: DateTime.utc(2026, 8, 23, 9),
      ),
    );
    await store.prepare(
      commandId: commandId,
      businessId: businessId,
      canonicalPayloadJson: '{"command":"post_expense"}',
      localFingerprint: 'local-fingerprint',
    );
    return _Fixture(
      database: database,
      accounts: accounts,
      store: store,
      writer: DriftConfirmedExpenseProjectionWriter(
        database,
        financialAccountRepository: accounts,
        failureInjector: failureInjector,
      ),
      localAccountId: account.id,
    );
  }

  ConfirmedExpenseProjection projection() => ConfirmedExpenseProjection(
        commandId: commandId,
        localFingerprint: 'local-fingerprint',
        businessId: businessId,
        serverAccountId: serverAccountId,
        expenseId: '55555555-5555-4555-8555-555555555555',
        financialEntryId: '66666666-6666-4666-8666-666666666666',
        auditEventIds: const [
          '77777777-7777-4777-8777-777777777777',
          '88888888-8888-4888-8888-888888888888',
        ],
        serverAcceptedAtUtc: DateTime.utc(2026, 8, 23, 10),
        businessDate: '2026-08-23',
        category: 'نقل',
        amountQirsh: 1250,
        notes: null,
        paymentMethod: PaymentMethod.cash,
        accountingClassification: ExpenseAccountingClassification.operating,
        actorAuthUserId: '33333333-3333-4333-8333-333333333333',
        balanceAfterQirsh: 8750,
      );

  Future<void> close() => database.close();
}
