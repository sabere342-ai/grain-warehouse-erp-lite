import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/audit/drift_audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('fresh v10 stores and reopens every audit field in newest-first order',
      () async {
    final directory = await Directory.systemTemp.createTemp('phase8i-reopen-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    var database = openDatabaseFile(file);
    var repository = DriftAuditLogRepository(database);
    expect(database.schemaVersion, 15);
    expect(await repository.exportStoredAuditLogs(), isEmpty);
    final older = await repository.record(AuditLogDraft(
      actionType: ' sale.created ',
      descriptionAr: ' تم إنشاء البيع ',
      referenceId: ' sale-1 ',
      timestamp: DateTime.utc(2026, 7, 15),
      metadata: const {'amount': 1250, 'paid': true},
    ));
    final newer = await repository.record(AuditLogDraft(
      actionType: 'owner.login',
      descriptionAr: 'دخول المالك',
      referenceId: '   ',
      timestamp: DateTime.utc(2026, 7, 16),
    ));
    await database.close();

    database = openDatabaseFile(file);
    repository = DriftAuditLogRepository(database);
    final restored = await repository.exportStoredAuditLogs();
    expect(restored.map((entry) => entry.id), [newer.id, older.id]);
    expect(restored.last.actionType, 'sale.created');
    expect(restored.last.descriptionAr, 'تم إنشاء البيع');
    expect(restored.last.referenceId, 'sale-1');
    expect(restored.last.metadata, {'amount': 1250, 'paid': true});
    expect(restored.first.referenceId, equals(null));
    await database.close();
  });

  test('nested JSON metadata round-trips with Arabic and scalar types',
      () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final repository = DriftAuditLogRepository(database);
    const metadata = <String, Object?>{
      'null': null,
      'bool': false,
      'int': 7,
      'double': 2.5,
      'arabic': 'قمح',
      'empty': <Object?>[],
      'nested': <String, Object?>{
        'items': <Object?>[1, 'طن', null, true]
      },
    };
    await repository.record(const AuditLogDraft(
      actionType: 'metadata.test',
      descriptionAr: 'اختبار البيانات',
      metadata: metadata,
    ));
    expect(
        (await repository.exportStoredAuditLogs()).single.metadata, metadata);
  });

  test('malformed persisted metadata fails closed', () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    await database.into(database.auditLogs).insert(db.AuditLogsCompanion.insert(
          id: 'aud-bad-1',
          timestamp: DateTime.utc(2026),
          actionType: 'bad',
          descriptionAr: 'تالف',
          referenceId: const Value(null),
          metadataJson: '[1,2,3]',
        ));
    expect(DriftAuditLogRepository(database).exportStoredAuditLogs(),
        throwsA(isA<FormatException>()));
  });

  test('sequence survives restart and concurrent records remain unique',
      () async {
    final directory = await Directory.systemTemp.createTemp('phase8i-seq-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    var database = openDatabaseFile(file);
    var repository = DriftAuditLogRepository(database);
    final timestamp = DateTime.utc(2026, 7, 16);
    final first = await repository.record(AuditLogDraft(
      actionType: 'first',
      descriptionAr: 'الأول',
      timestamp: timestamp,
    ));
    await database.close();
    database = openDatabaseFile(file);
    repository = DriftAuditLogRepository(database);
    final created = await Future.wait(List.generate(
      12,
      (index) => repository.record(AuditLogDraft(
        actionType: 'parallel.$index',
        descriptionAr: 'متوازٍ $index',
        timestamp: timestamp,
      )),
    ));
    expect({first.id, ...created.map((entry) => entry.id)}, hasLength(13));
    expect(await repository.exportStoredAuditLogs(), hasLength(13));
    await database.close();
  });

  test('transaction snapshot rolls rows and sequence back atomically',
      () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final repository = DriftAuditLogRepository(database);
    final timestamp = DateTime.utc(2026);
    final before = await repository.record(AuditLogDraft(
      actionType: 'before',
      descriptionAr: 'قبل',
      timestamp: timestamp,
    ));
    await expectLater(
      RepositoryTransaction.execute([repository.createTransactionSnapshot()],
          () async {
        await repository.record(AuditLogDraft(
          actionType: 'rolled',
          descriptionAr: 'يُلغى',
          timestamp: timestamp,
        ));
        throw const FormatException('injected');
      }),
      throwsFormatException,
    );
    expect((await repository.exportStoredAuditLogs()).single.id, before.id);
    final after = await repository.record(AuditLogDraft(
      actionType: 'after',
      descriptionAr: 'بعد',
      timestamp: timestamp,
    ));
    expect(after.id.endsWith('-2'), isTrue);
  });

  test('restore rejects duplicates without partial rows and wipe resets safely',
      () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final repository = DriftAuditLogRepository(database);
    final entry = AuditLogEntry(
      id: 'aud-${DateTime.utc(2026).microsecondsSinceEpoch}-4',
      timestamp: DateTime.utc(2026),
      actionType: 'restore',
      descriptionAr: 'استعادة',
    );
    await expectLater(
        repository.restoreAuditLogsIntoEmpty([entry, entry]), throwsStateError);
    expect(await repository.exportStoredAuditLogs(), isEmpty);
    await repository.restoreAuditLogsIntoEmpty([entry]);
    await repository.clearForOwnerDataWipe();
    expect(await repository.exportStoredAuditLogs(), isEmpty);
    expect(
      (await repository.record(AuditLogDraft(
        actionType: 'fresh',
        descriptionAr: 'جديد',
        timestamp: DateTime.utc(2026),
      )))
          .id
          .endsWith('-1'),
      isTrue,
    );
  });

  test('populated v8 database migrates additively to v9', () async {
    final directory = await Directory.systemTemp.createTemp('phase8i-migrate-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    final seeded = openDatabaseFile(file);
    await seeded.writeProbe('legacy', 'kept');
    await seeded.close();
    final legacy = sqlite3.open(file.path);
    legacy.execute('DROP TABLE audit_logs');
    legacy.execute('PRAGMA user_version = 8');
    legacy.dispose();

    final upgraded = openDatabaseFile(file);
    expect(await upgraded.readProbe('legacy'), 'kept');
    final repository = DriftAuditLogRepository(upgraded);
    await repository.record(const AuditLogDraft(
      actionType: 'after.migration',
      descriptionAr: 'بعد الترحيل',
    ));
    expect(await repository.exportStoredAuditLogs(), hasLength(1));
    await upgraded.close();
  });

  test('production initialization wires the durable Drift repository',
      () async {
    final database = openInMemoryTestDatabase();
    await AppRepositories.initializeProduction(
        databaseFactory: () async => database);
    expect(AppRepositories.auditLogRepository, isA<DriftAuditLogRepository>());
    await AppRepositories.auditLogRepository.record(const AuditLogDraft(
      actionType: 'production',
      descriptionAr: 'إنتاج',
    ));
    expect(await database.auditLogs.count().getSingle(), 1);
    await AppRepositories.close();
  });
}
