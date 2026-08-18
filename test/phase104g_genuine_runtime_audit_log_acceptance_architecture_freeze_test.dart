import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/audit/drift_audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;

void main() {
  test('public read contract remains singular and legacy surface stays retired',
      () {
    final dartSources = _dartSourcesUnder(const ['lib', 'test', 'tool']);
    const legacyCall = 'list' 'Logs(';

    expect(
      dartSources.where((source) => source.contents.contains(legacyCall)),
      isEmpty,
      reason: 'Executable code must not restore the retired bulk-list API.',
    );

    final librarySources = dartSources.where(
        (source) => source.path == 'lib' || source.path.startsWith('lib/'));
    expect(
      librarySources
          .where((source) => source.contents.contains(
                'abstract interface class AuditLogReadRepository',
              ))
          .map((source) => source.path),
      ['lib/core/audit/audit_log_read_repository.dart'],
    );
    expect(
      _read('lib/core/audit/audit_log_read_repository.dart'),
      contains('Future<List<AuditLogReadModel>> listAuditLogs();'),
    );
    final writeContracts = _read('lib/core/audit/audit_log_repository.dart');
    final writeContract = writeContracts.substring(
      writeContracts.indexOf('abstract class AuditLogRepository'),
      writeContracts
          .indexOf('abstract interface class AuditLogStorageRepository'),
    );
    expect(writeContract, isNot(contains('Future<List<AuditLogEntry>>')));
  });

  test('presentation and controller remain read-model-only', () {
    final controller = _read('lib/core/audit/audit_log_controller.dart');
    final screen = _read('lib/features/audit/audit_logs_screen.dart');

    expect(controller, contains('AuditLogReadRepository'));
    expect(controller, contains('List<AuditLogReadModel>'));
    expect(controller, isNot(contains('AuditLogEntry')));
    expect(controller, isNot(contains('AuditLogStorageRepository')));
    expect(screen, contains('AuditLogReadModel'));
    expect(screen, isNot(contains('AuditLogEntry')));
    expect(screen, isNot(contains('AuditLogStorageRepository')));
    expect(screen, isNot(contains('drift_audit_log_repository.dart')));
    expect(screen, isNot(contains('audit_log_repository.dart')));
  });

  test(
      'local write-to-read visibility preserves fields, nullability, and order',
      () async {
    final repository = LocalAuditLogRepository();
    final AuditLogReadRepository readRepository = repository;
    expect(await readRepository.listAuditLogs(), isEmpty);

    final older = await repository.record(
      AuditLogDraft(
        actionType: ' local.older ',
        descriptionAr: ' older description ',
        timestamp: DateTime.utc(2026, 7, 28, 8),
      ),
    );
    final firstRead = await readRepository.listAuditLogs();
    expect(firstRead.single.id, older.id);
    expect(firstRead.single.referenceId, isNull);

    final newer = await repository.record(
      AuditLogDraft(
        actionType: 'local.newer',
        descriptionAr: ' newer description ',
        referenceId: ' reference-104g ',
        timestamp: DateTime.utc(2026, 7, 29, 8),
      ),
    );
    final secondRead = await readRepository.listAuditLogs();

    expect(secondRead.map((entry) => entry.id), [newer.id, older.id]);
    expect(secondRead.map((entry) => entry.id).toSet(), hasLength(2));
    expect(secondRead.first.timestamp, newer.timestamp);
    expect(secondRead.first.descriptionAr, 'newer description');
    expect(secondRead.first.referenceId, 'reference-104g');
    expect(secondRead.last.timestamp, older.timestamp);
    expect(secondRead.last.descriptionAr, 'older description');
    expect(secondRead.last.referenceId, isNull);
  });

  test('Drift write-to-read visibility preserves frozen mapping and order',
      () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final repository = DriftAuditLogRepository(database);
    final AuditLogReadRepository readRepository = repository;
    expect(await readRepository.listAuditLogs(), isEmpty);

    final timestamp = DateTime.utc(2026, 7, 29, 9);
    final first = await repository.record(
      AuditLogDraft(
        actionType: 'drift.first',
        descriptionAr: 'first description',
        timestamp: timestamp,
      ),
    );
    expect((await readRepository.listAuditLogs()).single.id, first.id);

    final second = await repository.record(
      AuditLogDraft(
        actionType: 'drift.second',
        descriptionAr: 'second description',
        referenceId: 'drift-reference',
        timestamp: timestamp,
      ),
    );
    final readModels = await readRepository.listAuditLogs();
    final stored = await repository.exportStoredAuditLogs();

    expect(
        readModels.map((entry) => entry.id), stored.map((entry) => entry.id));
    expect(readModels.map((entry) => entry.id), [second.id, first.id]);
    expect(readModels.map((entry) => entry.id).toSet(), hasLength(2));
    for (var index = 0; index < stored.length; index++) {
      expect(readModels[index].id, stored[index].id);
      expect(readModels[index].timestamp, stored[index].timestamp);
      expect(readModels[index].descriptionAr, stored[index].descriptionAr);
      expect(readModels[index].referenceId, stored[index].referenceId);
    }
    expect(readModels.first.referenceId, 'drift-reference');
    expect(readModels.last.referenceId, isNull);
  });

  test('Drift write coordination uses an exact query, not a bulk read scan',
      () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final repository = DriftAuditLogRepository(database);

    await database.into(database.auditLogs).insert(
          db.AuditLogsCompanion.insert(
            id: 'unrelated-corrupt-row',
            timestamp: DateTime.utc(2026, 7, 29),
            actionType: 'unrelated.action',
            descriptionAr: 'unrelated',
            referenceId: const Value('unrelated-reference'),
            metadataJson: 'not-json',
          ),
        );
    await repository.record(
      const AuditLogDraft(
        actionType: 'negative_balance.request.created',
        descriptionAr: 'write coordination',
        referenceId: 'request-104g',
      ),
    );

    expect(
      await repository.hasRecordedAction(
        actionType: 'negative_balance.request.created',
        referenceId: 'request-104g',
      ),
      isTrue,
    );
    expect(
      await repository.hasRecordedAction(
        actionType: 'negative_balance.request.created',
        referenceId: 'missing-request',
      ),
      isFalse,
    );

    final source = _read('lib/core/audit/drift_audit_log_repository.dart');
    final method = _methodBody(source, 'Future<bool> hasRecordedAction');
    expect(method, contains('row.actionType.equals(actionType)'));
    expect(method, contains('row.referenceId.equals(referenceId)'));
    expect(method, contains('..limit(1)'));
    expect(method, isNot(contains('exportStoredAuditLogs')));
  });

  test('storage export remains isolated and backup restore contract is frozen',
      () {
    final repository = _read('lib/core/audit/audit_log_repository.dart');
    expect(
      repository,
      contains('abstract interface class AuditLogStorageRepository'),
    );
    expect(repository, contains('exportStoredAuditLogs();'));
    expect(repository, contains('restoreAuditLogsIntoEmpty('));
    expect(repository, contains('clearForOwnerDataWipe();'));

    final backupExport = _read('lib/core/backup/backup_export.dart');
    final backupRestore = _read('lib/core/backup/backup_restore_service.dart');
    final wipe = _read('lib/core/backup/business_data_wipe_service.dart');
    expect(backupExport, contains('AuditLogStorageRepository'));
    expect(backupExport, contains('exportStoredAuditLogs()'));
    expect(backupRestore, contains('restoreAuditLogsIntoEmpty('));
    expect(wipe, contains('clearForOwnerDataWipe()'));
    expect(backupRestore, isNot(contains('AuditLogReadRepository')));
    expect(backupRestore, isNot(contains('listAuditLogs()')));
    expect(wipe, isNot(contains('AuditLogReadRepository')));
    expect(wipe, isNot(contains('listAuditLogs()')));
  });

  test('composition has no audit adapters, casts, or concrete-type branching',
      () {
    final composition = _read('lib/app/app_repositories.dart');
    final screen = _read('lib/features/audit/audit_logs_screen.dart');

    expect(composition, isNot(matches(RegExp(r'AuditLog\w*Adapter'))));
    expect(
      composition,
      isNot(matches(
          RegExp(r'\b(?:is|as)\s+(?:Drift|Local)AuditLogRepository\b'))),
    );
    expect(screen, isNot(matches(RegExp(r'AuditLog\w*Adapter'))));
    expect(
      screen,
      contains('ApplicationScope.of(context).queries.auditLogs'),
    );
    expect(screen, isNot(contains('AppRepositories')));
  });

  test('every remaining AuditLogEntry usage is in an allowed scope', () {
    const allowedProductionFiles = {
      'lib/core/audit/audit_log_entry.dart',
      'lib/core/audit/audit_log_repository.dart',
      'lib/core/audit/drift_audit_log_repository.dart',
      'lib/core/backup/backup_export.dart',
      'lib/core/backup/backup_restore_service.dart',
    };
    final offenders = <String>[];
    for (final source in _dartSourcesUnder(const ['lib', 'test', 'tool'])) {
      if (!source.contents.contains('AuditLogEntry')) continue;
      final allowed = source.path.startsWith('test/') ||
          allowedProductionFiles.contains(source.path);
      if (!allowed) offenders.add(source.path);
    }
    expect(
      offenders,
      isEmpty,
      reason: 'AuditLogEntry is limited to storage/write, backup/restore, '
          'mapping, snapshots, and test fakes/fixtures.',
    );
  });

  test('fresh profitability state remains not activated', () async {
    final repository = LocalInventoryValuationRepository();
    final activation = await repository.getActivation();

    expect(activation.isNotActivated, isTrue);
    expect(activation.isActivated, isFalse);
    expect(await repository.listStates(), isEmpty);
    expect(await repository.listEvents(), isEmpty);
  });

  test('runtime evidence artifact exists and declares every required field',
      () {
    final evidence = _read(
      'docs/evidence/phase104g-audit-log-runtime-smoke-evidence.md',
    );
    for (final field in const [
      'Execution timestamp:',
      'Time zone:',
      'Commit:',
      'Executable path:',
      'Executable SHA-256:',
      'Executable size:',
      'Runtime environment:',
      'User/role:',
      'Database:',
      'Audit screen load:',
      'Write-to-read visibility:',
      'Restart persistence:',
      'Navigation:',
      'Runtime errors:',
      'Audit entry creation:',
      'Limitations:',
    ]) {
      expect(evidence, contains(field),
          reason: 'Missing evidence field: $field');
    }
  });
}

String _read(String path) => File(path).readAsStringSync();

String _methodBody(String source, String signature) {
  final start = source.indexOf(signature);
  if (start < 0) return '';
  final nextOverride =
      source.indexOf('\n  @override', start + signature.length);
  return source.substring(
      start, nextOverride < 0 ? source.length : nextOverride);
}

List<_SourceFile> _dartSourcesUnder(List<String> roots) {
  final sources = <_SourceFile>[];
  for (final root in roots) {
    final directory = Directory(root);
    if (!directory.existsSync()) continue;
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      sources.add(
        _SourceFile(
          entity.path.replaceAll('\\', '/'),
          entity.readAsStringSync(),
        ),
      );
    }
  }
  sources.sort((left, right) => left.path.compareTo(right.path));
  return sources;
}

final class _SourceFile {
  const _SourceFile(this.path, this.contents);

  final String path;
  final String contents;
}
