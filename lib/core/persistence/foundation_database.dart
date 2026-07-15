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

class Products extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get normalizedName => text().unique()();
  TextColumn get code => text().nullable()();
  TextColumn get normalizedCode => text().nullable().unique()();
  TextColumn get unit => text()();
  BoolColumn get isActive => boolean()();
  IntColumn get defaultSalePricePiastersPerKg => integer().nullable()();
  IntColumn get minimumSalePricePiastersPerKg => integer().nullable()();
  IntColumn get referenceCostPricePiastersPerKg => integer().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class RepositorySequences extends Table {
  TextColumn get repository => text()();
  IntColumn get nextValue => integer()();

  @override
  Set<Column<Object>> get primaryKey => {repository};
}

class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get normalizedName => text().unique()();
  TextColumn get phone => text().nullable()();
  TextColumn get normalizedPhone => text().nullable().unique()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
    tables: [FoundationProbes, Products, RepositorySequences, Customers])
class FoundationDatabase extends _$FoundationDatabase {
  FoundationDatabase(super.executor);

  @override
  int get schemaVersion => 3;

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
