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
  test('real composition drives empty and mapped data without duplicates',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('phase104j-audit-acceptance-');
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
    expect(path.isWithin(testRoot, databasePath), isTrue);
    if (appData != null && appData.isNotEmpty) {
      expect(
        path.isWithin(path.normalize(path.absolute(appData)), databasePath),
        isFalse,
      );
    }
    expect(path.basename(databasePath), isNot(productionDatabaseFileName));

    final database = openDatabaseFile(databaseFile);
    await AppRepositories.initializeProduction(
      databaseFactory: () async => database,
    );
    productionInitialized = true;

    final AuditLogReadRepository readRepository =
        AppRepositories.auditLogRepository;
    expect(readRepository, isA<DriftAuditLogRepository>());
    expect(AppRepositories.database, same(database));

    final controller = AuditLogController(repository: readRepository);
    addTearDown(controller.dispose);
    expect(await controller.loadLogs(_owner), isTrue);
    expect(controller.entries, isEmpty);
    expect(controller.isLoading, isFalse);
    expect(controller.errorMessage, isNull);

    final writer = AppRepositories.auditLogRepository;
    final older = await writer.record(
      AuditLogDraft(
        actionType: 'phase104j.older',
        descriptionAr: 'السجل الأقدم',
        referenceId: 'reference-older',
        timestamp: DateTime.utc(2026, 7, 29, 8),
      ),
    );
    final newer = await writer.record(
      AuditLogDraft(
        actionType: 'phase104j.newer',
        descriptionAr: 'السجل الأحدث',
        referenceId: 'reference-newer',
        timestamp: DateTime.utc(2026, 7, 29, 9),
      ),
    );

    for (var attempt = 0; attempt < 2; attempt++) {
      expect(await controller.loadLogs(_owner), isTrue);
      expect(controller.entries.map((entry) => entry.id), [newer.id, older.id]);
      expect(controller.entries.map((entry) => entry.id).toSet(), hasLength(2));
      expect(
        controller.entries.first.timestamp.isAtSameMomentAs(newer.timestamp),
        isTrue,
      );
      expect(controller.entries.first.descriptionAr, newer.descriptionAr);
      expect(controller.entries.first.referenceId, newer.referenceId);
      expect(
        controller.entries.last.timestamp.isAtSameMomentAs(older.timestamp),
        isTrue,
      );
      expect(controller.entries.last.descriptionAr, older.descriptionAr);
      expect(controller.entries.last.referenceId, older.referenceId);
    }

    final repositoryAfterReads = AppRepositories.auditLogRepository;
    expect(repositoryAfterReads, same(readRepository));
    expect(AppRepositories.database, same(database));
  });

  testWidgets('screen renders empty and ordered data states without duplicates',
      (tester) async {
    final newer = AuditLogReadModel(
      id: 'screen-newer-104j',
      timestamp: DateTime.utc(2026, 7, 29, 9),
      descriptionAr: 'السجل الأحدث',
      referenceId: 'reference-newer',
    );
    final older = AuditLogReadModel(
      id: 'screen-older-104j',
      timestamp: DateTime.utc(2026, 7, 29, 8),
      descriptionAr: 'السجل الأقدم',
      referenceId: 'reference-older',
    );
    final repository = _ScriptedAuditLogReadRepository()
      ..responses.add(() => Future.value(const []))
      ..responses.add(() => Future.value([newer, older]));
    final controller = AuditLogController(repository: repository);
    final auth = await _signedInOwner();
    addTearDown(controller.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      _harness(auth, AuditLogsScreen(controller: controller)),
    );
    await tester.pumpAndSettle();
    expect(find.text('لا توجد أحداث تدقيق مسجلة بعد.'), findsOneWidget);
    expect(controller.isLoading, isFalse);
    expect(controller.errorMessage, isNull);

    expect(await controller.loadLogs(_owner), isTrue);
    await tester.pump();
    expect(controller.entries.map((entry) => entry.id), [newer.id, older.id]);
    expect(controller.entries.map((entry) => entry.id).toSet(), hasLength(2));
    expect(find.text('السجل الأحدث'), findsOneWidget);
    expect(find.text('رقم المستند: reference-newer'), findsOneWidget);
    expect(find.text('السجل الأقدم'), findsOneWidget);
    expect(find.text('رقم المستند: reference-older'), findsOneWidget);
    final visibleText = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .whereType<String>()
        .toList(growable: false);
    expect(
      visibleText.indexOf('السجل الأحدث'),
      lessThan(visibleText.indexOf('السجل الأقدم')),
    );
    expect(repository.callCount, 2);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    repository.responses.add(() => Future.value(const []));
    expect(await controller.loadLogs(_owner), isTrue,
        reason: 'The screen must not dispose an injected controller.');
  });

  testWidgets(
      'controlled failure retries without leaks or duplicates and preserves cached data',
      (tester) async {
    final repository = _ScriptedAuditLogReadRepository()
      ..responses.add(
        () => Future.error(StateError('sensitive database failure')),
      )
      ..responses.add(
        () => Future.value([
          AuditLogReadModel(
            id: 'cached-104j',
            timestamp: DateTime.utc(2026, 7, 29, 10),
            descriptionAr: 'بيانات ناجحة مخزنة',
            referenceId: 'cached-reference',
          ),
        ]),
      )
      ..responses.add(
        () => Future.error(StateError('refresh failure')),
      )
      ..responses.add(
        () => Future.value([
          AuditLogReadModel(
            id: 'retry-104j',
            timestamp: DateTime.utc(2026, 7, 29, 11),
            descriptionAr: 'بيانات إعادة المحاولة',
            referenceId: 'retry-reference',
          ),
        ]),
      );
    final controller = AuditLogController(repository: repository);
    final auth = await _signedInOwner();
    addTearDown(controller.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      _harness(auth, AuditLogsScreen(controller: controller)),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('تعذر تحميل سجل التدقيق. حاول مرة أخرى.'),
      findsOneWidget,
    );
    expect(controller.entries, isEmpty);
    expect(controller.isLoading, isFalse);
    expect(controller.errorMessage, isNot(contains('sensitive')));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.text('بيانات ناجحة مخزنة'), findsOneWidget);
    expect(controller.entries.map((entry) => entry.id), ['cached-104j']);
    expect(controller.errorMessage, isNull);
    expect(controller.isLoading, isFalse);

    expect(await controller.loadLogs(_owner), isFalse);
    await tester.pump();
    expect(find.text('بيانات ناجحة مخزنة'), findsOneWidget);
    expect(
      find.text('تعذر تحميل سجل التدقيق. حاول مرة أخرى.'),
      findsOneWidget,
    );
    expect(controller.entries.map((entry) => entry.id), ['cached-104j']);
    expect(controller.isLoading, isFalse);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.text('بيانات إعادة المحاولة'), findsOneWidget);
    expect(find.text('بيانات ناجحة مخزنة'), findsNothing);
    expect(
      find.text('تعذر تحميل سجل التدقيق. حاول مرة أخرى.'),
      findsNothing,
    );
    expect(controller.entries.map((entry) => entry.id), ['retry-104j']);
    expect(controller.entries.map((entry) => entry.id).toSet(), hasLength(1));
    expect(controller.errorMessage, isNull);
    expect(controller.isLoading, isFalse);
    expect(repository.callCount, 4);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    repository.responses.add(() => Future.value(const []));
    expect(await controller.loadLogs(_owner), isTrue,
        reason: 'The screen must not dispose an injected controller.');
    expect(controller.entries, isEmpty);
  });

  test('architecture freezes the production boundary and resource ownership',
      () {
    final mainSource = _read('lib/main.dart');
    final composition = _read('lib/app/app_repositories.dart');
    final dashboard = _read('lib/features/dashboard/dashboard_shell.dart');
    final screen = _read('lib/features/audit/audit_logs_screen.dart');
    final controller = _read('lib/core/audit/audit_log_controller.dart');
    final contracts = _read('lib/core/audit/audit_log_repository.dart');
    final drift = _read('lib/core/audit/drift_audit_log_repository.dart');

    expect(
      mainSource.indexOf('await AppRepositories.initializeProduction();'),
      lessThan(mainSource.indexOf('runApp(const GrainWarehouseApp());')),
    );
    expect(
      composition,
      contains('_auditLogRepository = DriftAuditLogRepository(database);'),
    );
    expect(contracts, contains('AuditLogReadRepository'));
    expect(drift, contains('implements DurableAuditLogRepository'));
    expect(dashboard, contains('AuditLogsScreen()'));
    expect(
      screen,
      contains(
        'AuditLogController(repository: AppRepositories.auditLogRepository)',
      ),
    );

    expect(controller, contains('required AuditLogReadRepository repository'));
    expect(controller, contains('final AuditLogReadRepository _repository;'));
    expect(controller, contains('_repository.listAuditLogs()'));
    for (final forbidden in const [
      'AuditLogEntry',
      'DriftAuditLogRepository',
      'FoundationDatabase',
      'database_opener.dart',
      'drift_audit_log_repository.dart',
    ]) {
      expect(controller, isNot(contains(forbidden)));
      expect(screen, isNot(contains(forbidden)));
    }

    expect(screen, contains('_ownsController = widget.controller == null;'));
    expect(screen, contains('if (_ownsController)'));
    expect(screen, contains('_controller.dispose();'));
    expect(
      _methodBody(screen, 'Widget build(BuildContext context)'),
      isNot(contains('AuditLogController(')),
    );
    expect(
        screen,
        isNot(
            matches(RegExp(r'\b(?:select|customSelect|rawQuery|query)\s*\('))));

    const legacyReadCall = 'list' 'Logs(';
    final sources = _dartSourcesUnder(const ['lib', 'test', 'tool']);
    expect(
      sources.where((source) => source.contents.contains(legacyReadCall)),
      isEmpty,
      reason: 'The retired executable bulk-read surface must stay absent.',
    );

    const allowedProductionEntryFiles = {
      'lib/core/audit/audit_log_entry.dart',
      'lib/core/audit/audit_log_repository.dart',
      'lib/core/audit/drift_audit_log_repository.dart',
      'lib/core/backup/backup_export.dart',
      'lib/core/backup/backup_restore_service.dart',
    };
    final entryOffenders = sources
        .where((source) => source.path.startsWith('lib/'))
        .where((source) => source.contents.contains('AuditLogEntry'))
        .where((source) => !allowedProductionEntryFiles.contains(source.path))
        .map((source) => source.path)
        .toList(growable: false);
    expect(entryOffenders, isEmpty);

    final auditRuntimeSources = _dartSourcesUnder(
      const ['lib/core/audit', 'lib/features/audit'],
    );
    final directDatabaseReaders = auditRuntimeSources
        .where((source) =>
            source.path != 'lib/core/audit/drift_audit_log_repository.dart')
        .where((source) => RegExp(
              r'\b(?:select|customSelect|rawQuery|query)\s*\(',
            ).hasMatch(source.contents))
        .map((source) => source.path)
        .toList(growable: false);
    expect(
      directDatabaseReaders,
      isEmpty,
      reason: 'Only the Drift adapter may query Audit Log persistence.',
    );
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

Widget _harness(AuthController auth, Widget child) {
  return MaterialApp(
    locale: const Locale('ar'),
    home: AuthScope(
      controller: auth,
      child: Scaffold(body: child),
    ),
  );
}

String _read(String filePath) => File(filePath).readAsStringSync();

String _methodBody(String source, String signature) {
  final start = source.indexOf(signature);
  if (start < 0) return '';
  final openBrace = source.indexOf('{', start);
  var depth = 0;
  for (var index = openBrace; index < source.length; index++) {
    if (source[index] == '{') depth++;
    if (source[index] == '}') depth--;
    if (depth == 0) return source.substring(start, index + 1);
  }
  return '';
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

final _now = DateTime.utc(2026, 7, 29);

final _owner = AppUser(
  id: 'owner-104j',
  name: 'مالك',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);
