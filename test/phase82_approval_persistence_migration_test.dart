import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/drift_financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_request.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_request_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('fresh schema v14 contains durable request tables and indexes',
      () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    expect(database.schemaVersion, 16);
    final objects = (await database
            .customSelect(
              "SELECT name, type FROM sqlite_master WHERE name LIKE 'negative_balance_%' OR name = 'expenses_operation_request_uq'",
            )
            .get())
        .map((row) => row.read<String>('name'))
        .toSet();
    expect(
      objects,
      containsAll({
        'negative_balance_approval_requests',
        'negative_balance_approval_request_transitions',
        'negative_balance_pending_signature_uq',
        'expenses_operation_request_uq',
      }),
    );
  });

  test('populated v13 migrates additively and preserves old rows', () async {
    final directory = await Directory.systemTemp.createTemp('phase82-v13-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    final legacy = sqlite3.open(file.path);
    legacy.execute('''
      CREATE TABLE financial_accounts (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        is_active INTEGER NOT NULL,
        allow_negative_balance INTEGER NOT NULL,
        opening_balance_qirsh INTEGER NOT NULL,
        opening_balance_date INTEGER NULL,
        reference_info TEXT NULL,
        notes TEXT NULL,
        created_by_user_id TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    legacy.execute('''
      CREATE TABLE audit_logs (
        id TEXT NOT NULL PRIMARY KEY,
        timestamp INTEGER NOT NULL,
        action_type TEXT NOT NULL,
        description_ar TEXT NOT NULL,
        reference_id TEXT NULL,
        metadata_json TEXT NOT NULL
      )
    ''');
    legacy.execute('''
      CREATE TABLE expenses (
        id TEXT NOT NULL PRIMARY KEY,
        date INTEGER NOT NULL,
        category TEXT NOT NULL,
        amount_qirsh INTEGER NOT NULL,
        notes TEXT NULL,
        created_at INTEGER NOT NULL,
        financial_account_id TEXT NULL,
        payment_method TEXT NULL
      )
    ''');
    legacy.execute('''
      CREATE TABLE repository_sequences (
        repository TEXT NOT NULL PRIMARY KEY,
        next_value INTEGER NOT NULL
      )
    ''');
    legacy.execute(
      "INSERT INTO audit_logs VALUES ('audit-old', 1, 'legacy', 'legacy row', NULL, '{}')",
    );
    legacy.execute(
      "INSERT INTO expenses VALUES ('expense-old', 1, 'legacy expense', 100, NULL, 1, NULL, NULL)",
    );
    legacy.execute('PRAGMA user_version = 13');
    legacy.dispose();

    final upgraded = openDatabaseFile(file);
    addTearDown(upgraded.close);
    expect(upgraded.schemaVersion, 16);
    final audit = await upgraded
        .customSelect(
          "SELECT actor_id FROM audit_logs WHERE id = 'audit-old'",
        )
        .getSingle();
    expect(audit.data['actor_id'], isNull);
    final expense = await upgraded
        .customSelect(
          "SELECT created_by_user_id, operation_request_id, operation_request_fingerprint FROM expenses WHERE id = 'expense-old'",
        )
        .getSingle();
    expect(expense.data.values, everyElement(isNull));
    expect(
        await upgraded.negativeBalanceApprovalRequests.count().getSingle(), 0);
    expect(
      await upgraded.negativeBalanceApprovalRequestTransitions
          .count()
          .getSingle(),
      0,
    );
  });

  test('pending and terminal request state survives database reopen', () async {
    final directory = await Directory.systemTemp.createTemp('phase82-reopen-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    var database = openDatabaseFile(file);
    final accounts = await DriftFinancialAccountRepository.open(database);
    final account = await accounts.createAccount(
      const FinancialAccountDraft(
        name: 'Persistent treasury',
        type: FinancialAccountType.treasury,
        allowNegativeBalance: true,
        createdByUserId: 'owner-1',
      ),
    );
    final repository = DriftNegativeBalanceApprovalRequestRepository(database);
    final pending = await repository.createRequest(
      NegativeBalanceApprovalRequestDraft(
        idempotencyKey: 'persist-pending',
        operationType: NegativeBalanceApprovalRequestOperationType.expense,
        financialAccountId: account.id,
        paymentMethod: PaymentMethod.cash,
        amountQirsh: 500,
        sourceDocumentId: 'persist-pending',
        payloadJson: '{"amountQirsh":500}',
        payloadFingerprint: 'fingerprint-pending',
        requesterActorId: 'employee-1',
        balanceAtRequestQirsh: 100,
        expectedBalanceAtRequestQirsh: -400,
        deficitAtRequestQirsh: 400,
        reason: 'persistent pending test',
      ),
    );
    final terminalDraft = NegativeBalanceApprovalRequestDraft(
      idempotencyKey: 'persist-terminal',
      operationType: NegativeBalanceApprovalRequestOperationType.expense,
      financialAccountId: account.id,
      paymentMethod: PaymentMethod.cash,
      amountQirsh: 600,
      sourceDocumentId: 'persist-terminal',
      payloadJson: '{"amountQirsh":600}',
      payloadFingerprint: 'fingerprint-terminal',
      requesterActorId: 'employee-1',
      balanceAtRequestQirsh: 100,
      expectedBalanceAtRequestQirsh: -500,
      deficitAtRequestQirsh: 500,
      reason: 'persistent terminal test',
    );
    final terminal = await repository.createRequest(terminalDraft);
    await repository.resolveRequest(
      requestId: terminal.id,
      status: NegativeBalanceApprovalRequestStatus.rejected,
      resolverActorId: 'owner-1',
      reason: 'rejected persistently',
    );
    await database.close();

    database = openDatabaseFile(file);
    addTearDown(database.close);
    final reopened = DriftNegativeBalanceApprovalRequestRepository(database);
    expect((await reopened.findById(pending.id))!.status,
        NegativeBalanceApprovalRequestStatus.pending);
    expect((await reopened.findById(terminal.id))!.status,
        NegativeBalanceApprovalRequestStatus.rejected);
    expect(await reopened.listTransitions(requestId: pending.id), hasLength(1));
    expect(
        await reopened.listTransitions(requestId: terminal.id), hasLength(2));
  });
}
