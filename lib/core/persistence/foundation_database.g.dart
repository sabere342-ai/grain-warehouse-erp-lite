// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'foundation_database.dart';

// ignore_for_file: type=lint
class $FoundationProbesTable extends FoundationProbes
    with TableInfo<$FoundationProbesTable, FoundationProbe> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoundationProbesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'foundation_probes';
  @override
  VerificationContext validateIntegrity(Insertable<FoundationProbe> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  FoundationProbe map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FoundationProbe(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $FoundationProbesTable createAlias(String alias) {
    return $FoundationProbesTable(attachedDatabase, alias);
  }
}

class FoundationProbe extends DataClass implements Insertable<FoundationProbe> {
  final String key;
  final String value;
  const FoundationProbe({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  FoundationProbesCompanion toCompanion(bool nullToAbsent) {
    return FoundationProbesCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory FoundationProbe.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FoundationProbe(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  FoundationProbe copyWith({String? key, String? value}) => FoundationProbe(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  FoundationProbe copyWithCompanion(FoundationProbesCompanion data) {
    return FoundationProbe(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FoundationProbe(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FoundationProbe &&
          other.key == this.key &&
          other.value == this.value);
}

class FoundationProbesCompanion extends UpdateCompanion<FoundationProbe> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const FoundationProbesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FoundationProbesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<FoundationProbe> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FoundationProbesCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return FoundationProbesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoundationProbesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$FoundationDatabase extends GeneratedDatabase {
  _$FoundationDatabase(QueryExecutor e) : super(e);
  $FoundationDatabaseManager get managers => $FoundationDatabaseManager(this);
  late final $FoundationProbesTable foundationProbes =
      $FoundationProbesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [foundationProbes];
}

typedef $$FoundationProbesTableCreateCompanionBuilder
    = FoundationProbesCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$FoundationProbesTableUpdateCompanionBuilder
    = FoundationProbesCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$FoundationProbesTableFilterComposer
    extends Composer<_$FoundationDatabase, $FoundationProbesTable> {
  $$FoundationProbesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$FoundationProbesTableOrderingComposer
    extends Composer<_$FoundationDatabase, $FoundationProbesTable> {
  $$FoundationProbesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$FoundationProbesTableAnnotationComposer
    extends Composer<_$FoundationDatabase, $FoundationProbesTable> {
  $$FoundationProbesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$FoundationProbesTableTableManager extends RootTableManager<
    _$FoundationDatabase,
    $FoundationProbesTable,
    FoundationProbe,
    $$FoundationProbesTableFilterComposer,
    $$FoundationProbesTableOrderingComposer,
    $$FoundationProbesTableAnnotationComposer,
    $$FoundationProbesTableCreateCompanionBuilder,
    $$FoundationProbesTableUpdateCompanionBuilder,
    (
      FoundationProbe,
      BaseReferences<_$FoundationDatabase, $FoundationProbesTable,
          FoundationProbe>
    ),
    FoundationProbe,
    PrefetchHooks Function()> {
  $$FoundationProbesTableTableManager(
      _$FoundationDatabase db, $FoundationProbesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoundationProbesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoundationProbesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoundationProbesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FoundationProbesCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              FoundationProbesCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FoundationProbesTableProcessedTableManager = ProcessedTableManager<
    _$FoundationDatabase,
    $FoundationProbesTable,
    FoundationProbe,
    $$FoundationProbesTableFilterComposer,
    $$FoundationProbesTableOrderingComposer,
    $$FoundationProbesTableAnnotationComposer,
    $$FoundationProbesTableCreateCompanionBuilder,
    $$FoundationProbesTableUpdateCompanionBuilder,
    (
      FoundationProbe,
      BaseReferences<_$FoundationDatabase, $FoundationProbesTable,
          FoundationProbe>
    ),
    FoundationProbe,
    PrefetchHooks Function()>;

class $FoundationDatabaseManager {
  final _$FoundationDatabase _db;
  $FoundationDatabaseManager(this._db);
  $$FoundationProbesTableTableManager get foundationProbes =>
      $$FoundationProbesTableTableManager(_db, _db.foundationProbes);
}
