import 'package:drift/drift.dart';

import 'migration_strategy.dart';

part 'foundation_database.g.dart';

/// Technical-only table used to prove the Phase 8A database lifecycle.
class FoundationProbes extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [FoundationProbes])
class FoundationDatabase extends _$FoundationDatabase {
  FoundationDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => foundationMigrationStrategy(this);

  Future<T> inTransaction<T>(Future<T> Function() action) =>
      transaction(action);

  Future<void> writeProbe(String key, String value) =>
      into(foundationProbes).insertOnConflictUpdate(
        FoundationProbesCompanion.insert(key: key, value: value),
      );

  Future<String?> readProbe(String key) async {
    final row = await (select(foundationProbes)
          ..where((table) => table.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<int> probeCount() async {
    final count = foundationProbes.key.count();
    final row =
        await (selectOnly(foundationProbes)..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }
}
