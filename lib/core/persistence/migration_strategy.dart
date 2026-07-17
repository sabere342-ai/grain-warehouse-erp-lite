import 'package:drift/drift.dart';

import 'foundation_database.dart';

MigrationStrategy foundationMigrationStrategy(FoundationDatabase database) {
  return MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
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
    };
