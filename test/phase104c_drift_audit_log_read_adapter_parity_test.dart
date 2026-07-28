import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/audit/drift_audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';

void main() {
  test('empty Drift repository conforms to the frozen read contract', () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final driftRepository = DriftAuditLogRepository(database);
    final AuditLogReadRepository repository = driftRepository;

    expect(await driftRepository.exportStoredAuditLogs(), isEmpty);
    expect(await repository.listAuditLogs(), isEmpty);
  });

  test('read adapter maps every frozen field and preserves null reference',
      () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final driftRepository = DriftAuditLogRepository(database);
    final timestamp = DateTime.utc(2026, 7, 28, 10, 30, 45, 123, 456);
    await driftRepository.record(AuditLogDraft(
      actionType: 'audit.read.parity',
      descriptionAr:
          '\u0627\u062e\u062a\u0628\u0627\u0631 \u062a\u0643\u0627\u0641\u0624 \u0627\u0644\u0642\u0631\u0627\u0621\u0629',
      timestamp: timestamp,
    ));

    final legacy = (await driftRepository.exportStoredAuditLogs()).single;
    final mapped = (await driftRepository.listAuditLogs()).single;

    expect(mapped.id, legacy.id);
    expect(mapped.timestamp, legacy.timestamp);
    expect(mapped.descriptionAr, legacy.descriptionAr);
    expect(mapped.referenceId, legacy.referenceId);
    expect(mapped.referenceId, isNull);
  });

  test('read adapter preserves legacy timestamp and id descending order',
      () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final driftRepository = DriftAuditLogRepository(database);
    final olderTimestamp = DateTime.utc(2026, 7, 27);
    final newerTimestamp = DateTime.utc(2026, 7, 28);
    await driftRepository.record(AuditLogDraft(
      actionType: 'older',
      descriptionAr: '\u0627\u0644\u0623\u0642\u062f\u0645',
      referenceId: 'ref-older',
      timestamp: olderTimestamp,
    ));
    await driftRepository.record(AuditLogDraft(
      actionType: 'newer.first',
      descriptionAr:
          '\u0627\u0644\u0623\u062d\u062f\u062b \u0627\u0644\u0623\u0648\u0644',
      referenceId: 'ref-newer-1',
      timestamp: newerTimestamp,
    ));
    await driftRepository.record(AuditLogDraft(
      actionType: 'newer.second',
      descriptionAr:
          '\u0627\u0644\u0623\u062d\u062f\u062b \u0627\u0644\u062b\u0627\u0646\u064a',
      referenceId: 'ref-newer-2',
      timestamp: newerTimestamp,
    ));

    final legacy = await driftRepository.exportStoredAuditLogs();
    final mapped = await driftRepository.listAuditLogs();

    expect(mapped, hasLength(legacy.length));
    expect(mapped.map((log) => log.id), legacy.map((log) => log.id));
    for (var index = 0; index < legacy.length; index++) {
      expect(mapped[index].id, legacy[index].id);
      expect(mapped[index].timestamp, legacy[index].timestamp);
      expect(mapped[index].descriptionAr, legacy[index].descriptionAr);
      expect(mapped[index].referenceId, legacy[index].referenceId);
    }
    expect(legacy[0].timestamp.microsecondsSinceEpoch,
        newerTimestamp.microsecondsSinceEpoch);
    expect(legacy[1].timestamp.microsecondsSinceEpoch,
        newerTimestamp.microsecondsSinceEpoch);
    expect(legacy[0].id.compareTo(legacy[1].id), greaterThan(0));
    expect(legacy[2].timestamp.microsecondsSinceEpoch,
        olderTimestamp.microsecondsSinceEpoch);
  });
}
