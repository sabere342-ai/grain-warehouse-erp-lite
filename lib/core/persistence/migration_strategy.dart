import 'package:drift/drift.dart';

import 'foundation_database.dart';

MigrationStrategy foundationMigrationStrategy(FoundationDatabase database) {
  return MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      for (var version = from + 1; version <= to; version++) {
        final step = _migrationSteps[version];
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

/// Version 1 uses onCreate. Future phases add one reviewed step per version.
const Map<int, _MigrationStep> _migrationSteps = {};
