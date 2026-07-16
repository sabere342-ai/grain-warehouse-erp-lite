import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';

void main() {
  test('fresh database opens with current schema version', () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    expect(database.schemaVersion, 5);
    expect(await database.probeCount(), 0);
  });

  test('successful transaction commits all writes', () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    await database.inTransaction(() async {
      await database.writeProbe('first', 'one');
      await database.writeProbe('second', 'two');
    });
    expect(await database.readProbe('first'), 'one');
    expect(await database.readProbe('second'), 'two');
  });

  test('failed transaction rolls back fully and exposes the error', () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    await expectLater(
      database.inTransaction<void>(() async {
        await database.writeProbe('kept-out', 'value');
        throw const FormatException('injected failure');
      }),
      throwsA(isA<FormatException>()),
    );
    expect(await database.readProbe('kept-out'), isNull);
  });

  test('file database retains data after close and reopen', () async {
    final directory = await Directory.systemTemp.createTemp('phase8a-reopen-');
    final file =
        File('${directory.path}${Platform.pathSeparator}probe.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    final first = openDatabaseFile(file);
    await first.writeProbe('durable', 'yes');
    await first.close();
    final reopened = openDatabaseFile(file);
    expect(await reopened.readProbe('durable'), 'yes');
    await reopened.close();
  });

  test('independent test databases do not share state', () async {
    final first = openInMemoryTestDatabase();
    await first.writeProbe('isolated', 'first');
    await first.close();

    final second = openInMemoryTestDatabase();
    addTearDown(second.close);
    expect(await second.readProbe('isolated'), isNull);
  });

  test('concurrent transactions serialize without silent loss', () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    await Future.wait([
      database.inTransaction(() => database.writeProbe('a', '1')),
      database.inTransaction(() => database.writeProbe('b', '2')),
    ]);
    expect(await database.probeCount(), 2);
    expect(await database.readProbe('a'), '1');
    expect(await database.readProbe('b'), '2');
  });

  test('production path uses support directory and fixed filename', () async {
    final support = await Directory.systemTemp.createTemp('phase8a-path-');
    addTearDown(() => support.delete(recursive: true));
    final file = await resolveProductionDatabaseFile(supportDirectory: support);
    expect(file.parent.path, support.path);
    expect(file.path, endsWith(productionDatabaseFileName));
    expect(file.existsSync(), isFalse);
    expect(file.absolute.path, isNot(contains(Directory.current.path)));
  });

  test('foundation schema remains alongside Phase 8B through 8E tables',
      () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final rows = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table'",
        )
        .get();
    final tables = rows.map((row) => row.read<String>('name')).toSet();
    expect(tables, contains('foundation_probes'));
    expect(
        tables,
        containsAll([
          'products',
          'customers',
          'suppliers',
          'repository_sequences',
          'inventory_movements'
        ]));
    expect(tables.intersection({'sales'}), isEmpty);
  });
}
