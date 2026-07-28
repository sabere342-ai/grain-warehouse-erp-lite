import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_read_repository.dart';

void main() {
  test('read model preserves the frozen fields and nullability', () {
    final timestamp = DateTime.utc(2026, 7, 28, 12, 30);
    final withReference = AuditLogReadModel(
      id: 'aud-2',
      timestamp: timestamp,
      descriptionAr: 'تم إنشاء مستند',
      referenceId: 'document-1',
    );
    final withoutReference = AuditLogReadModel(
      id: 'aud-1',
      timestamp: timestamp.subtract(const Duration(minutes: 1)),
      descriptionAr: 'تم تسجيل الدخول',
    );

    expect(withReference.id, 'aud-2');
    expect(withReference.timestamp, timestamp);
    expect(withReference.descriptionAr, 'تم إنشاء مستند');
    expect(withReference.referenceId, 'document-1');
    expect(withoutReference.referenceId, isNull);
  });

  test('repository can be implemented without platform or database setup',
      () async {
    final newer = AuditLogReadModel(
      id: 'aud-2',
      timestamp: DateTime.utc(2026, 7, 28, 12),
      descriptionAr: 'الأحدث',
    );
    final older = AuditLogReadModel(
      id: 'aud-1',
      timestamp: DateTime.utc(2026, 7, 28, 11),
      descriptionAr: 'الأقدم',
      referenceId: 'ref-1',
    );
    final AuditLogReadRepository repository =
        _FakeAuditLogReadRepository([newer, older]);

    final Future<List<AuditLogReadModel>> future = repository.listAuditLogs();
    final logs = await future;

    expect(logs, hasLength(2));
    expect(logs, orderedEquals([newer, older]));
    expect(logs.last.referenceId, 'ref-1');
  });

  test('repository represents no results with an empty non-null list',
      () async {
    const AuditLogReadRepository repository = _FakeAuditLogReadRepository([]);

    final logs = await repository.listAuditLogs();

    expect(logs, isEmpty);
  });
}

final class _FakeAuditLogReadRepository implements AuditLogReadRepository {
  const _FakeAuditLogReadRepository(this.logs);

  final List<AuditLogReadModel> logs;

  @override
  Future<List<AuditLogReadModel>> listAuditLogs() async => logs;
}
