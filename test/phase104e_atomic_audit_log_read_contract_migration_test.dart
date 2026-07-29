import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_controller.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/features/audit/audit_logs_screen.dart';

void main() {
  test('controller consumes the frozen contract and preserves models and order',
      () async {
    final older = AuditLogReadModel(
      id: 'audit-older',
      timestamp: DateTime.utc(2026, 7, 27, 10),
      descriptionAr: '\u0627\u0644\u0623\u0642\u062f\u0645',
    );
    final newer = AuditLogReadModel(
      id: 'audit-newer',
      timestamp: DateTime.utc(2026, 7, 28, 10),
      descriptionAr: '\u0627\u0644\u0623\u062d\u062f\u062b',
      referenceId: 'ref-newer',
    );
    final fakeRepository = _FakeAuditLogReadRepository([newer, older]);
    final AuditLogReadRepository repository = fakeRepository;
    final controller = AuditLogController(repository: repository);

    expect(await controller.loadLogs(_owner), isTrue);

    final List<AuditLogReadModel> entries = controller.entries;
    expect(entries.map((entry) => entry.id), ['audit-newer', 'audit-older']);
    expect(entries[0].timestamp, newer.timestamp);
    expect(entries[0].descriptionAr, newer.descriptionAr);
    expect(entries[0].referenceId, 'ref-newer');
    expect(entries[1].referenceId, isNull);
    expect(fakeRepository.callCount, 1);
    expect(controller.isLoading, isFalse);
    expect(controller.errorMessage, isNull);
  });

  test(
      'controller preserves empty, denied, reload, and repository error behavior',
      () async {
    final repository = _FakeAuditLogReadRepository(const []);
    final controller = AuditLogController(repository: repository);

    expect(await controller.loadLogs(_owner), isTrue);
    expect(controller.entries, isEmpty);
    expect(controller.isLoading, isFalse);

    repository.logs = [
      AuditLogReadModel(
        id: 'audit-reload',
        timestamp: DateTime.utc(2026, 7, 28),
        descriptionAr:
            '\u0625\u0639\u0627\u062f\u0629 \u062a\u062d\u0645\u064a\u0644',
      ),
    ];
    expect(await controller.loadLogs(_owner), isTrue);
    expect(controller.entries.single.id, 'audit-reload');
    expect(repository.callCount, 2);

    expect(await controller.loadLogs(_employee), isFalse);
    expect(repository.callCount, 2);
    expect(controller.errorMessage, isNotNull);

    repository.error = StateError('read failed');
    var notificationCount = 0;
    controller.addListener(() => notificationCount++);
    expect(await controller.loadLogs(_owner), isFalse);
    expect(repository.callCount, 3);
    expect(controller.entries.single.id, 'audit-reload');
    expect(controller.isLoading, isFalse);
    expect(controller.errorMessage, 'تعذر تحميل سجل التدقيق. حاول مرة أخرى.');
    expect(notificationCount, 2);
  });

  test('local repository maps exact frozen fields and preserves read ordering',
      () async {
    final repository = LocalAuditLogRepository();
    final older = await repository.record(
      AuditLogDraft(
        actionType: 'older',
        descriptionAr: '\u0627\u0644\u0623\u0642\u062f\u0645',
        timestamp: DateTime.utc(2026, 7, 27),
      ),
    );
    final newer = await repository.record(
      AuditLogDraft(
        actionType: 'newer',
        descriptionAr: '\u0627\u0644\u0623\u062d\u062f\u062b',
        referenceId: 'ref-local',
        timestamp: DateTime.utc(2026, 7, 28),
      ),
    );
    final AuditLogReadRepository readRepository = repository;

    final logs = await readRepository.listAuditLogs();

    expect(logs.map((log) => log.id), [newer.id, older.id]);
    expect(logs[0].timestamp, newer.timestamp);
    expect(logs[0].descriptionAr, newer.descriptionAr);
    expect(logs[0].referenceId, newer.referenceId);
    expect(logs[1].timestamp, older.timestamp);
    expect(logs[1].descriptionAr, older.descriptionAr);
    expect(logs[1].referenceId, isNull);
  });

  testWidgets('screen renders models supplied only by the frozen read contract',
      (tester) async {
    final auth = AuthController(repository: LocalAuthRepository.demo());
    addTearDown(auth.dispose);
    await auth.initialize();
    await auth.signIn(phone: '01000000000', password: 'owner123');
    final repository = _FakeAuditLogReadRepository([
      AuditLogReadModel(
        id: 'audit-screen',
        timestamp: DateTime.utc(2026, 7, 28, 10, 30),
        descriptionAr:
            '\u0633\u062c\u0644 \u0645\u0646 \u0639\u0642\u062f \u0627\u0644\u0642\u0631\u0627\u0621\u0629',
        referenceId: 'ref-screen',
      ),
    ]);
    final controller = AuditLogController(repository: repository);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        home: AuthScope(
          controller: auth,
          child: Scaffold(body: AuditLogsScreen(controller: controller)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.text(
            '\u0633\u062c\u0644 \u0645\u0646 \u0639\u0642\u062f \u0627\u0644\u0642\u0631\u0627\u0621\u0629'),
        findsOneWidget);
    expect(find.textContaining('ref-screen'), findsOneWidget);
    expect(repository.callCount, 1);
  });
}

final class _FakeAuditLogReadRepository implements AuditLogReadRepository {
  _FakeAuditLogReadRepository(this.logs);

  List<AuditLogReadModel> logs;
  StateError? error;
  int callCount = 0;

  @override
  Future<List<AuditLogReadModel>> listAuditLogs() async {
    callCount++;
    final currentError = error;
    if (currentError != null) throw currentError;
    return logs;
  }
}

final _now = DateTime.utc(2026);

final _owner = AppUser(
  id: 'owner-104e',
  name: '\u0645\u0627\u0644\u0643',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);

final _employee = AppUser(
  id: 'employee-104e',
  name: '\u0645\u0648\u0638\u0641',
  phone: '01100000000',
  role: UserRole.employee,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);
