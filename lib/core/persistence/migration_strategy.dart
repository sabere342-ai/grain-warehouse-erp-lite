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
    };
