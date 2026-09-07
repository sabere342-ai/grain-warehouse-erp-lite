import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/application/expenses/expense_posting_attempt_store.dart';
import 'package:grain_warehouse_erp_lite/application/financial_transfers/confirmed_internal_transfer_projection_writer.dart';
import 'package:grain_warehouse_erp_lite/application/financial_transfers/internal_transfer_posting_attempt_store.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/drift_expense_posting_attempt_store.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/drift_confirmed_internal_transfer_projection_writer.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/drift_financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/drift_internal_transfer_posting_attempt_store.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

const businessId = '11111111-1111-4111-8111-111111111111';
const sourceServerId = '22222222-2222-4222-8222-222222222222';
const destinationServerId = '33333333-3333-4333-8333-333333333333';
const commandId = '018f7f65-8d31-7b84-bb46-4f47d82c1f70';

void main() {
  test('v16 to v17 adds only the transfer attempt table and preserves rows',
      () async {
    final directory = await Directory.systemTemp.createTemp('transfer-v16-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    var database = openDatabaseFile(file);
    await database.writeProbe('preserved', 'yes');
    await database.close();
    final legacy = sqlite3.open(file.path);
    legacy.execute('DROP TABLE internal_transfer_posting_attempts');
    legacy.execute('PRAGMA user_version = 16');
    legacy.dispose();

    database = openDatabaseFile(file);
    expect(database.schemaVersion, 17);
    expect(await database.readProbe('preserved'), 'yes');
    expect(
      await database.select(database.internalTransferPostingAttempts).get(),
      isEmpty,
    );
    await database.close();
  });

  test('attempt payload and unknown outcome survive close and reopen',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('transfer-attempt-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    var database = openDatabaseFile(file);
    var store = DriftInternalTransferPostingAttemptStore(database);
    await store.prepare(
      commandId: commandId,
      businessId: businessId,
      canonicalPayloadJson: '{"exact":true}',
      localFingerprint: 'fingerprint',
    );
    await store.markSending(commandId);
    await store.markFailure(
      commandId,
      state: InternalTransferPostingAttemptState.unknownOutcome,
      errorCode: 'serverUnavailable',
    );
    await database.close();

    database = openDatabaseFile(file);
    store = DriftInternalTransferPostingAttemptStore(database);
    final restored = await store.load(commandId);
    expect(restored?.canonicalPayloadJson, '{"exact":true}');
    expect(restored?.state, InternalTransferPostingAttemptState.unknownOutcome);
    expect(restored?.attemptCount, 1);
    expect(await store.loadIncompleteForBusiness(businessId), hasLength(1));
    await database.close();
  });

  test('confirmed projection atomically writes header, two legs and audits',
      () async {
    final fixture = await _Fixture.open();
    addTearDown(fixture.close);
    final value = fixture.projection();

    await fixture.writer.project(value);
    expect(
        await fixture.database
            .select(fixture.database.financialTransfers)
            .get(),
        hasLength(1));
    expect(
      await fixture.database
          .select(fixture.database.financialAccountEntries)
          .get(),
      hasLength(4),
      reason: 'two opening balances plus two authoritative transfer legs',
    );
    expect(await fixture.database.select(fixture.database.auditLogs).get(),
        hasLength(3));
    expect(await fixture.accounts.currentBalanceForAccount(fixture.sourceId),
        8750);
    expect(
      await fixture.accounts.currentBalanceForAccount(fixture.destinationId),
      6250,
    );
    expect((await fixture.store.load(commandId))?.state,
        InternalTransferPostingAttemptState.confirmed);

    final linksBefore = await fixture.database
        .select(fixture.database.financialAccountCloudLinks)
        .get();
    await fixture.writer.project(value);
    final linksAfter = await fixture.database
        .select(fixture.database.financialAccountCloudLinks)
        .get();
    expect(
        await fixture.database
            .select(fixture.database.financialTransfers)
            .get(),
        hasLength(1));
    expect(await fixture.database.select(fixture.database.auditLogs).get(),
        hasLength(3));
    expect(
      linksAfter.map((link) => link.reconciliationVersion),
      linksBefore.map((link) => link.reconciliationVersion),
      reason: 'exact projection replay is a complete no-op',
    );
  });

  test('injected projection failure rolls back both balances and all rows',
      () async {
    final fixture = await _Fixture.open(
      failureInjector: (stage) async {
        if (stage ==
            ConfirmedInternalTransferProjectionStage.afterDestinationEntry) {
          throw StateError('injected');
        }
      },
    );
    addTearDown(fixture.close);

    await expectLater(
      fixture.writer.project(fixture.projection()),
      throwsStateError,
    );
    expect(
        await fixture.database
            .select(fixture.database.financialTransfers)
            .get(),
        isEmpty);
    expect(
      await fixture.database
          .select(fixture.database.financialAccountEntries)
          .get(),
      hasLength(2),
    );
    expect(await fixture.database.select(fixture.database.auditLogs).get(),
        isEmpty);
    expect(await fixture.accounts.currentBalanceForAccount(fixture.sourceId),
        10000);
    expect(
      await fixture.accounts.currentBalanceForAccount(fixture.destinationId),
      5000,
    );
  });
}

final class _Fixture {
  _Fixture({
    required this.database,
    required this.accounts,
    required this.store,
    required this.writer,
    required this.sourceId,
    required this.destinationId,
  });

  final FoundationDatabase database;
  final DriftFinancialAccountRepository accounts;
  final DriftInternalTransferPostingAttemptStore store;
  final DriftConfirmedInternalTransferProjectionWriter writer;
  final String sourceId;
  final String destinationId;

  static Future<_Fixture> open({
    Future<void> Function(ConfirmedInternalTransferProjectionStage stage)?
        failureInjector,
  }) async {
    final database = openInMemoryTestDatabase();
    final accounts = await DriftFinancialAccountRepository.open(database);
    final source = await accounts.createAccount(
      const FinancialAccountDraft(
        name: 'Source Treasury',
        type: FinancialAccountType.treasury,
        createdByUserId: 'local-owner',
      ),
    );
    final destination = await accounts.createAccount(
      const FinancialAccountDraft(
        name: 'Destination Bank',
        type: FinancialAccountType.bank,
        createdByUserId: 'local-owner',
      ),
    );
    await accounts.createEntry(
      accountId: source.id,
      direction: FinancialAccountEntryDirection.inflow,
      amountQirsh: 10000,
      sourceType: FinancialAccountEntrySource.openingBalance,
      sourceDocumentId: 'source-opening',
      effectiveDate: DateTime(2026, 9, 1),
      createdByUserId: 'local-owner',
      paymentMethod: PaymentMethod.cash,
    );
    await accounts.createEntry(
      accountId: destination.id,
      direction: FinancialAccountEntryDirection.inflow,
      amountQirsh: 5000,
      sourceType: FinancialAccountEntrySource.openingBalance,
      sourceDocumentId: 'destination-opening',
      effectiveDate: DateTime(2026, 9, 1),
      createdByUserId: 'local-owner',
      paymentMethod: PaymentMethod.bankTransfer,
    );
    final linkStore = DriftExpensePostingAttemptStore(
      database,
      financialAccountRepository: accounts,
    );
    await linkStore.saveVerifiedCloudLink(
      FinancialAccountCloudLink(
        localAccountId: source.id,
        businessId: businessId,
        serverAccountUuid: sourceServerId,
        reconciledServerBalanceQirsh: 10000,
        reconciledAtUtc: DateTime.utc(2026, 9, 6, 9),
        reconciliationVersion: 1,
        readyAtUtc: DateTime.utc(2026, 9, 6, 9),
      ),
    );
    await linkStore.saveVerifiedCloudLink(
      FinancialAccountCloudLink(
        localAccountId: destination.id,
        businessId: businessId,
        serverAccountUuid: destinationServerId,
        reconciledServerBalanceQirsh: 5000,
        reconciledAtUtc: DateTime.utc(2026, 9, 6, 9),
        reconciliationVersion: 1,
        readyAtUtc: DateTime.utc(2026, 9, 6, 9),
      ),
    );
    final store = DriftInternalTransferPostingAttemptStore(database);
    await store.prepare(
      commandId: commandId,
      businessId: businessId,
      canonicalPayloadJson: '{"command":"post_internal_transfer"}',
      localFingerprint: 'local-fingerprint',
    );
    return _Fixture(
      database: database,
      accounts: accounts,
      store: store,
      writer: DriftConfirmedInternalTransferProjectionWriter(
        database,
        financialAccountRepository: accounts,
        failureInjector: failureInjector,
      ),
      sourceId: source.id,
      destinationId: destination.id,
    );
  }

  ConfirmedInternalTransferProjection projection() =>
      ConfirmedInternalTransferProjection(
        commandId: commandId,
        localFingerprint: 'local-fingerprint',
        businessId: businessId,
        sourceServerAccountId: sourceServerId,
        destinationServerAccountId: destinationServerId,
        transferId: '55555555-5555-4555-8555-555555555555',
        displayNumber: 'TR-000001',
        transferReference: '018f7f65-8d31-7b84-bb46-4f47d82c1f71',
        sourceEntryId: '66666666-6666-4666-8666-666666666666',
        destinationEntryId: '77777777-7777-4777-8777-777777777777',
        auditEventIds: const [
          '88888888-8888-4888-8888-888888888888',
          '99999999-9999-4999-8999-999999999999',
          'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        ],
        serverAcceptedAtUtc: DateTime.utc(2026, 9, 6, 10),
        effectiveBusinessDate: '2026-09-06',
        amountQirsh: 1250,
        note: null,
        actorAuthUserId: '44444444-4444-4444-8444-444444444444',
        sourceBalanceAfterQirsh: 8750,
        destinationBalanceAfterQirsh: 6250,
      );

  Future<void> close() => database.close();
}
