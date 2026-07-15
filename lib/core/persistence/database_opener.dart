import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'foundation_database.dart';

const productionDatabaseFileName = 'grain_warehouse_erp.sqlite3';

Future<File> resolveProductionDatabaseFile(
    {Directory? supportDirectory}) async {
  final directory = supportDirectory ?? await getApplicationSupportDirectory();
  return File(path.join(directory.path, productionDatabaseFileName));
}

Future<FoundationDatabase> openProductionDatabase({
  Directory? supportDirectory,
}) async {
  final file = await resolveProductionDatabaseFile(
    supportDirectory: supportDirectory,
  );
  await file.parent.create(recursive: true);
  return openDatabaseFile(file);
}

FoundationDatabase openDatabaseFile(File file) {
  return FoundationDatabase(
    NativeDatabase.createInBackground(
      file,
      setup: (database) {
        database.execute('PRAGMA foreign_keys = ON');
        database.execute('PRAGMA journal_mode = WAL');
      },
    ),
  );
}

FoundationDatabase openInMemoryTestDatabase() {
  return FoundationDatabase(
    NativeDatabase.memory(
      setup: (database) => database.execute('PRAGMA foreign_keys = ON'),
    ),
  );
}
