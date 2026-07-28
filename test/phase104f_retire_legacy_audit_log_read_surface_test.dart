import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_controller.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';

void main() {
  test('write contract no longer requires a list read surface', () async {
    final AuditLogRepository repository = _WriteOnlyAuditLogRepository();

    expect(
      await repository.hasRecordedAction(
        actionType: 'write.only',
        referenceId: 'write-ref',
      ),
      isFalse,
    );
    final entry = await repository.record(
      const AuditLogDraft(
        actionType: 'write.only',
        descriptionAr: '\u0643\u062a\u0627\u0628\u0629 \u0641\u0642\u0637',
        referenceId: 'write-ref',
      ),
    );
    expect(entry.actionType, 'write.only');
  });

  test('empty local repository exposes empty read and storage views', () async {
    final repository = LocalAuditLogRepository();
    final AuditLogReadRepository readRepository = repository;
    final AuditLogStorageRepository storageRepository = repository;

    expect(await readRepository.listAuditLogs(), isEmpty);
    expect(await storageRepository.exportStoredAuditLogs(), isEmpty);
  });

  test('local writes remain visible with exact fields and existing order',
      () async {
    final repository = LocalAuditLogRepository();
    final older = await repository.record(
      AuditLogDraft(
        actionType: 'older.action',
        descriptionAr: '\u0627\u0644\u0623\u0642\u062f\u0645',
        timestamp: DateTime.utc(2026, 7, 27, 9),
      ),
    );
    final newer = await repository.record(
      AuditLogDraft(
        actionType: 'newer.action',
        descriptionAr: '\u0627\u0644\u0623\u062d\u062f\u062b',
        referenceId: 'exact-reference',
        timestamp: DateTime.utc(2026, 7, 28, 9),
      ),
    );

    final readModels = await repository.listAuditLogs();
    final storedEntries = await repository.exportStoredAuditLogs();

    expect(readModels.map((entry) => entry.id), [newer.id, older.id]);
    expect(storedEntries.map((entry) => entry.id), [newer.id, older.id]);
    expect(readModels[0].timestamp, newer.timestamp);
    expect(readModels[0].descriptionAr, newer.descriptionAr);
    expect(readModels[0].referenceId, 'exact-reference');
    expect(readModels[1].timestamp, older.timestamp);
    expect(readModels[1].descriptionAr, older.descriptionAr);
    expect(readModels[1].referenceId, isNull);

    await repository.clearForOwnerDataWipe();
    expect(await repository.listAuditLogs(), isEmpty);
    expect(await repository.exportStoredAuditLogs(), isEmpty);
  });

  test('write-side action lookup preserves exact matching semantics', () async {
    final repository = LocalAuditLogRepository();
    await repository.record(
      const AuditLogDraft(
        actionType: 'negative_balance.request.created',
        descriptionAr:
            '\u0637\u0644\u0628 \u0645\u0648\u0627\u0641\u0642\u0629',
        referenceId: 'request-104f',
      ),
    );

    expect(
      await repository.hasRecordedAction(
        actionType: 'negative_balance.request.created',
        referenceId: 'request-104f',
      ),
      isTrue,
    );
    expect(
      await repository.hasRecordedAction(
        actionType: 'negative_balance.request.created',
        referenceId: 'other-request',
      ),
      isFalse,
    );
    expect(
      await repository.hasRecordedAction(
        actionType: 'other.action',
        referenceId: 'request-104f',
      ),
      isFalse,
    );
    expect(await repository.exportStoredAuditLogs(), hasLength(1));
  });

  test('controller continues to consume only the frozen read contract',
      () async {
    final model = AuditLogReadModel(
      id: 'controller-104f',
      timestamp: DateTime.utc(2026, 7, 28, 12),
      descriptionAr:
          '\u0642\u0631\u0627\u0621\u0629 \u0627\u0644\u0643\u0646\u062a\u0631\u0648\u0644\u0631',
    );
    final repository = _ReadOnlyAuditRepository([model]);
    final controller = AuditLogController(repository: repository);

    expect(await controller.loadLogs(_owner), isTrue);
    expect(controller.entries.single, same(model));
    expect(repository.callCount, 1);
    expect(controller.isLoading, isFalse);
    expect(controller.errorMessage, isNull);
  });

  test('architecture has no legacy list surface or presentation entity leak',
      () async {
    const legacyListCall = 'list' 'Logs(';
    final controllerSource = await File(
      'lib/core/audit/audit_log_controller.dart',
    ).readAsString();
    final screenSource = await File(
      'lib/features/audit/audit_logs_screen.dart',
    ).readAsString();
    final repositorySource = await File(
      'lib/core/audit/audit_log_repository.dart',
    ).readAsString();

    expect(controllerSource, isNot(contains(legacyListCall)));
    expect(screenSource, isNot(contains(legacyListCall)));
    expect(repositorySource, isNot(contains(legacyListCall)));
    expect(controllerSource, isNot(contains('AuditLogEntry')));
    expect(screenSource, isNot(contains('AuditLogEntry')));
    expect(
      RegExp(r'final List<AuditLogEntry> _entries')
          .allMatches(repositorySource),
      hasLength(1),
    );
  });
}

final class _WriteOnlyAuditLogRepository implements AuditLogRepository {
  @override
  Future<bool> hasRecordedAction({
    required String actionType,
    required String referenceId,
  }) async =>
      false;

  @override
  Future<AuditLogEntry> record(AuditLogDraft draft) async => AuditLogEntry(
        id: 'write-only-entry',
        timestamp: DateTime.utc(2026, 7, 28),
        actionType: draft.actionType,
        descriptionAr: draft.descriptionAr,
        referenceId: draft.referenceId,
      );
}

final class _ReadOnlyAuditRepository implements AuditLogReadRepository {
  _ReadOnlyAuditRepository(this.entries);

  final List<AuditLogReadModel> entries;
  int callCount = 0;

  @override
  Future<List<AuditLogReadModel>> listAuditLogs() async {
    callCount++;
    return entries;
  }
}

final _now = DateTime.utc(2026);

final _owner = AppUser(
  id: 'owner-104f',
  name: '\u0645\u0627\u0644\u0643',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);
