import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_controller.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/audit/drift_audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/features/audit/audit_logs_screen.dart';
import 'package:path/path.dart' as path;

void main() {
  group('AuditLogController controlled read state', () {
    test('starts empty and reports loading before an exact successful result',
        () async {
      final pending = Completer<List<AuditLogReadModel>>();
      final repository = _ScriptedAuditLogReadRepository()
        ..responses.add(() => pending.future);
      final controller = AuditLogController(repository: repository);
      addTearDown(controller.dispose);
      final states = <(bool, String?)>[];
      controller.addListener(
        () => states.add((controller.isLoading, controller.errorMessage)),
      );

      expect(controller.entries, isEmpty);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNull);

      final load = controller.loadLogs(_owner);
      expect(controller.isLoading, isTrue);
      expect(states, [(true, null)]);

      final entries = [
        AuditLogReadModel(
          id: 'newer',
          timestamp: DateTime.utc(2026, 7, 29, 12),
          descriptionAr: 'الأحدث',
          referenceId: 'ref-newer',
        ),
        AuditLogReadModel(
          id: 'older',
          timestamp: DateTime.utc(2026, 7, 28, 12),
          descriptionAr: 'الأقدم',
        ),
      ];
      pending.complete(entries);

      expect(await load, isTrue);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNull);
      expect(controller.entries.map((entry) => entry.id), ['newer', 'older']);
      expect(controller.entries.first.timestamp, entries.first.timestamp);
      expect(controller.entries.first.descriptionAr, 'الأحدث');
      expect(controller.entries.first.referenceId, 'ref-newer');
      expect(states, [(true, null), (false, null)]);
    });

    test('contains first failure and clears the error on a successful retry',
        () async {
      final retry = Completer<List<AuditLogReadModel>>();
      final repository = _ScriptedAuditLogReadRepository()
        ..responses.add(
          () => Future.error(StateError('sensitive database detail')),
        )
        ..responses.add(() => retry.future);
      final controller = AuditLogController(repository: repository);
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications++);

      expect(await controller.loadLogs(_owner), isFalse);
      expect(controller.entries, isEmpty);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, 'تعذر تحميل سجل التدقيق. حاول مرة أخرى.');
      expect(controller.errorMessage, isNot(contains('sensitive')));

      final load = controller.loadLogs(_owner);
      expect(controller.isLoading, isTrue);
      expect(controller.errorMessage, isNull);
      retry.complete([
        AuditLogReadModel(
          id: 'retry-success',
          timestamp: DateTime.utc(2026, 7, 29),
          descriptionAr: 'نجحت إعادة المحاولة',
        ),
      ]);

      expect(await load, isTrue);
      expect(controller.entries.single.id, 'retry-success');
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNull);
      expect(notifications, 4);
    });

    test('keeps the last successful models when refresh fails', () async {
      final cached = AuditLogReadModel(
        id: 'cached',
        timestamp: DateTime.utc(2026, 7, 29),
        descriptionAr: 'بيانات ناجحة سابقة',
      );
      final repository = _ScriptedAuditLogReadRepository()
        ..responses.add(() => Future.value([cached]))
        ..responses.add(() => Future.error(StateError('refresh failed')));
      final controller = AuditLogController(repository: repository);
      addTearDown(controller.dispose);

      expect(await controller.loadLogs(_owner), isTrue);
      expect(await controller.loadLogs(_owner), isFalse);

      expect(controller.entries.single, same(cached));
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNotNull);
    });

    test('does not notify after disposal while a read is completing', () async {
      final pending = Completer<List<AuditLogReadModel>>();
      final repository = _ScriptedAuditLogReadRepository()
        ..responses.add(() => pending.future);
      final controller = AuditLogController(repository: repository);
      final load = controller.loadLogs(_owner);
      controller.dispose();

      pending.complete(const []);

      expect(await load, isTrue);
      expect(controller.isLoading, isFalse);
    });
  });

  group('AuditLogsScreen failure and retry states', () {
    testWidgets('shows loading, data, and empty success states',
        (tester) async {
      final auth = await _signedInOwner();
      final pending = Completer<List<AuditLogReadModel>>();
      final repository = _ScriptedAuditLogReadRepository()
        ..responses.add(() => pending.future);
      final controller = AuditLogController(repository: repository);
      addTearDown(auth.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_harness(auth, controller));
      await tester.pump();
      expect(find.text('جاري التحميل...'), findsOneWidget);

      pending.complete([
        AuditLogReadModel(
          id: 'visible',
          timestamp: DateTime.utc(2026, 7, 29),
          descriptionAr: 'سجل ظاهر',
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('سجل ظاهر'), findsOneWidget);

      repository.responses.add(() => Future.value(const []));
      await controller.loadLogs(_owner);
      await tester.pump();
      expect(find.text('لا توجد أحداث تدقيق مسجلة بعد.'), findsOneWidget);
    });

    testWidgets('contains initial failure and retries to success',
        (tester) async {
      final auth = await _signedInOwner();
      final repository = _ScriptedAuditLogReadRepository()
        ..responses.add(() => Future.error(StateError('read failed')))
        ..responses.add(
          () => Future.value([
            AuditLogReadModel(
              id: 'after-retry',
              timestamp: DateTime.utc(2026, 7, 29),
              descriptionAr: 'ظهر بعد إعادة المحاولة',
            ),
          ]),
        );
      final controller = AuditLogController(repository: repository);
      addTearDown(auth.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_harness(auth, controller));
      await tester.pumpAndSettle();

      expect(
          find.text('تعذر تحميل سجل التدقيق. حاول مرة أخرى.'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
      expect(controller.isLoading, isFalse);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();

      expect(find.text('ظهر بعد إعادة المحاولة'), findsOneWidget);
      expect(find.text('تعذر تحميل سجل التدقيق. حاول مرة أخرى.'), findsNothing);
      expect(controller.isLoading, isFalse);
      expect(repository.callCount, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps cached data visible after a failed refresh',
        (tester) async {
      final auth = await _signedInOwner();
      final repository = _ScriptedAuditLogReadRepository()
        ..responses.add(
          () => Future.value([
            AuditLogReadModel(
              id: 'cached-widget',
              timestamp: DateTime.utc(2026, 7, 29),
              descriptionAr: 'سجل مخبأ',
            ),
          ]),
        )
        ..responses.add(() => Future.error(StateError('refresh failed')));
      final controller = AuditLogController(repository: repository);
      addTearDown(auth.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_harness(auth, controller));
      await tester.pumpAndSettle();
      expect(find.text('سجل مخبأ'), findsOneWidget);

      await controller.loadLogs(_owner);
      await tester.pump();

      expect(find.text('سجل مخبأ'), findsOneWidget);
      expect(
          find.text('تعذر تحميل سجل التدقيق. حاول مرة أخرى.'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
      expect(find.text('جاري التحميل...'), findsNothing);
      expect(controller.isLoading, isFalse);
    });
  });

  test(
      'SQLite close and reopen flows through production composition and controller',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('phase104h-audit-runtime-');
    final databaseFile =
        File(path.join(directory.path, 'isolated-audit.sqlite3'));
    var productionInitialized = false;
    addTearDown(() async {
      if (productionInitialized) await AppRepositories.close();
      if (directory.existsSync()) await directory.delete(recursive: true);
    });

    final testRoot = path.normalize(path.absolute(directory.path));
    final databasePath = path.normalize(path.absolute(databaseFile.path));
    final appData = Platform.environment['APPDATA'];
    expect(path.isWithin(testRoot, databasePath), isTrue,
        reason: 'The SQLite file must stay inside this test temporary folder.');
    if (appData != null && appData.isNotEmpty) {
      expect(
          path.isWithin(path.normalize(path.absolute(appData)), databasePath),
          isFalse,
          reason: 'The test must not use the real user APPDATA directory.');
    }
    expect(path.basename(databasePath), isNot(productionDatabaseFileName));

    var database = openDatabaseFile(databaseFile);
    final writer = DriftAuditLogRepository(database);
    final timestamp = DateTime.utc(2026, 7, 29, 15);
    final first = await writer.record(AuditLogDraft(
      actionType: 'phase104h.first',
      descriptionAr: 'السجل الأول',
      referenceId: 'ref-first',
      timestamp: timestamp,
    ));
    final second = await writer.record(AuditLogDraft(
      actionType: 'phase104h.second',
      descriptionAr: 'السجل الثاني',
      timestamp: timestamp,
    ));
    await database.close();

    database = openDatabaseFile(databaseFile);
    await AppRepositories.initializeProduction(
      databaseFactory: () async => database,
    );
    productionInitialized = true;
    final AuditLogReadRepository repository =
        AppRepositories.auditLogRepository;
    expect(repository, isA<DriftAuditLogRepository>());
    final controller = AuditLogController(repository: repository);
    addTearDown(controller.dispose);

    expect(await controller.loadLogs(_owner), isTrue);
    expect(controller.isLoading, isFalse);
    expect(controller.errorMessage, isNull);
    expect(controller.entries.map((entry) => entry.id), [second.id, first.id]);
    expect(
      controller.entries.first.timestamp.isAtSameMomentAs(second.timestamp),
      isTrue,
    );
    expect(controller.entries.first.descriptionAr, second.descriptionAr);
    expect(controller.entries.first.referenceId, second.referenceId);
    expect(
      controller.entries.last.timestamp.isAtSameMomentAs(first.timestamp),
      isTrue,
    );
    expect(controller.entries.last.descriptionAr, first.descriptionAr);
    expect(controller.entries.last.referenceId, first.referenceId);
  });
}

final class _ScriptedAuditLogReadRepository implements AuditLogReadRepository {
  final List<Future<List<AuditLogReadModel>> Function()> responses = [];
  int callCount = 0;

  @override
  Future<List<AuditLogReadModel>> listAuditLogs() {
    final response = responses[callCount];
    callCount++;
    return response();
  }
}

Future<AuthController> _signedInOwner() async {
  final auth = AuthController(repository: LocalAuthRepository.demo());
  await auth.initialize();
  await auth.signIn(phone: '01000000000', password: 'owner123');
  return auth;
}

Widget _harness(AuthController auth, AuditLogController controller) {
  return MaterialApp(
    locale: const Locale('ar'),
    home: AuthScope(
      controller: auth,
      child: Scaffold(body: AuditLogsScreen(controller: controller)),
    ),
  );
}

final _now = DateTime.utc(2026, 7, 29);

final _owner = AppUser(
  id: 'owner-104h',
  name: 'مالك',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);
