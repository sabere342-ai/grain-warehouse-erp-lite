import 'package:drift/drift.dart';

import 'foundation_database.dart';

MigrationStrategy foundationMigrationStrategy(FoundationDatabase database) {
  return MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createNegativeBalancePendingSignatureIndex(database);
    },
    onUpgrade: (migrator, from, to) async {
      for (var version = from + 1; version <= to; version++) {
        final step = _migrationSteps(database)[version];
        if (step == null) {
          throw StateError(
            'No durable migration is registered for schema version $version.',
          );
        }
        await step(migrator);
      }
    },
    beforeOpen: (details) async {
      await database.customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

typedef _MigrationStep = Future<void> Function(Migrator migrator);

Map<int, _MigrationStep> _migrationSteps(FoundationDatabase database) => {
      2: (migrator) async {
        await migrator.createTable(database.products);
        await migrator.createTable(database.repositorySequences);
      },
      3: (migrator) => migrator.createTable(database.customers),
      4: (migrator) => migrator.createTable(database.suppliers),
      5: (migrator) => migrator.createTable(database.inventoryMovements),
      6: (migrator) => migrator.createTable(database.purchases),
      7: (migrator) => migrator.createTable(database.sales),
      8: (migrator) async {
        await migrator.createTable(database.financialAccounts);
        await migrator.createTable(database.financialAccountEntries);
        await migrator.createTable(database.financialTransfers);
        await migrator.createTable(database.financialClosings);
      },
      9: (migrator) => migrator.createTable(database.auditLogs),
      10: (migrator) => migrator.createTable(database.expenses),
      11: (migrator) async {
        await migrator.createTable(database.customerAccountEntries);
        await migrator.createTable(database.customerCollections);
        await migrator.createTable(database.customerAdvances);
        await migrator.createTable(database.customerAdvanceApplications);
        await migrator.createTable(database.customerAdvanceRefunds);
      },
      12: (migrator) async {
        await migrator.createTable(database.supplierAccountEntries);
        await migrator.createTable(database.supplierPayments);
        await migrator.createTable(database.supplierAdvances);
        await migrator.createTable(database.supplierAdvanceApplications);
        await migrator.createTable(database.supplierAdvanceRefunds);
      },
      13: (migrator) async {
        await migrator.createTable(database.authAccounts);
        // Some legacy v7/v8 fixtures predate the sequence table despite their
        // recorded user_version. Repair that additive foundation invariant
        // before reserving the auth namespace.
        await database.customStatement(
          'CREATE TABLE IF NOT EXISTS repository_sequences ('
          'repository TEXT NOT NULL PRIMARY KEY, '
          'next_value INTEGER NOT NULL)',
        );
        await database.customStatement(
          'INSERT INTO repository_sequences (repository, next_value) VALUES (?, ?) '
          'ON CONFLICT(repository) DO NOTHING',
          ['auth_accounts', 1],
        );
      },
      14: (migrator) async {
        if (!await _columnExists(database, 'audit_logs', 'actor_id')) {
          await migrator.addColumn(
            database.auditLogs,
            database.auditLogs.actorId,
          );
        }
        if (!await _columnExists(
          database,
          'expenses',
          'created_by_user_id',
        )) {
          await migrator.addColumn(
            database.expenses,
            database.expenses.createdByUserId,
          );
        }
        if (!await _columnExists(
          database,
          'expenses',
          'operation_request_id',
        )) {
          await migrator.addColumn(
            database.expenses,
            database.expenses.operationRequestId,
          );
        }
        if (!await _columnExists(
          database,
          'expenses',
          'operation_request_fingerprint',
        )) {
          await migrator.addColumn(
            database.expenses,
            database.expenses.operationRequestFingerprint,
          );
        }
        await database.customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS expenses_operation_request_uq '
          'ON expenses (operation_request_id)',
        );
        await migrator.createTable(database.negativeBalanceApprovalRequests);
        await migrator
            .createTable(database.negativeBalanceApprovalRequestTransitions);
        await _createNegativeBalancePendingSignatureIndex(database);
      },
      15: (migrator) async {
        // Phase 102B is intentionally additive. No legacy quantity, purchase,
        // reference cost, or sale data is converted into accounting cost.
        // Absence of an activation row means profitabilityNotActivated.
        await migrator.createTable(database.profitabilityActivations);
        await migrator.createTable(database.inventoryValuationStates);
        await migrator.createTable(database.inventoryValuationEvents);
        if (!await _columnExists(
          database,
          'expenses',
          'accounting_classification',
        )) {
          await migrator.addColumn(
            database.expenses,
            database.expenses.accountingClassification,
          );
        }
      },
      16: (migrator) async {
        await migrator.createTable(database.financialAccountCloudLinks);
        await migrator.createTable(database.expensePostingAttempts);
      },
    };

Future<void> _createNegativeBalancePendingSignatureIndex(
  FoundationDatabase database,
) =>
    database.customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS negative_balance_pending_signature_uq '
      'ON negative_balance_approval_requests ('
      'operation_type, source_document_id, financial_account_id, '
      'payment_method, amount_qirsh, payload_fingerprint) '
      "WHERE status = 'pending'",
    );

Future<bool> _columnExists(
  FoundationDatabase database,
  String tableName,
  String columnName,
) async {
  final columns =
      await database.customSelect('PRAGMA table_info("$tableName")').get();
  return columns.any((row) => row.data['name'] == columnName);
}
