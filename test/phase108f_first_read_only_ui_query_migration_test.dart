import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/application/application_boundary.dart';
import 'package:grain_warehouse_erp_lite/application/queries/application_query.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_audit_logs_query.dart';
import 'package:grain_warehouse_erp_lite/composition/app_composition_root.dart';
import 'package:grain_warehouse_erp_lite/composition/application_scope.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_service.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_state.dart';

void main() {
  group('Phase 108F audit-log query handler', () {
    test('Q1-Q3 preserves exact result objects, order, and membership',
        () async {
      final newer = _entry('newer', DateTime.utc(2026, 8, 11, 12));
      final older = _entry('older', DateTime.utc(2026, 8, 10, 12));
      final repository = _AuditLogReadRepositorySpy([newer, older]);
      final handler = LoadAuditLogsQueryHandler(repository: repository);

      final result = await handler.execute(const LoadAuditLogsQuery());

      expect(result.value, hasLength(2));
      expect(result.value[0], same(newer));
      expect(result.value[1], same(older));
      expect(result.value.map((entry) => entry.id), ['newer', 'older']);
      expect(repository.calls, 1);
    });

    test('Q4 preserves an empty successful result', () async {
      final handler = LoadAuditLogsQueryHandler(
        repository: _AuditLogReadRepositorySpy(const []),
      );

      final result = await handler.execute(const LoadAuditLogsQuery());

      expect(result.value, isEmpty);
    });

    test('Q5 preserves repository exception identity and propagation', () {
      final error = StateError('local read failed');
      final handler = LoadAuditLogsQueryHandler(
        repository: _AuditLogReadRepositorySpy(const [], error: error),
      );

      expect(
        handler.execute(const LoadAuditLogsQuery()),
        throwsA(same(error)),
      );
    });

    test('Q6 reports explicit local SQLite current-known-state provenance',
        () async {
      final handler = LoadAuditLogsQueryHandler(
        repository: _AuditLogReadRepositorySpy(const []),
      );

      final result = await handler.execute(const LoadAuditLogsQuery());
      final metadata = result.metadata as LocalQueryResultMetadata;

      expect(metadata.source, QueryResultSource.local);
      expect(metadata.readAuthority, LocalReadAuthority.sqlite);
      expect(metadata.consistency, LocalQueryConsistency.currentKnownState);
    });
  });

  group('Phase 108F production wiring', () {
    late FoundationDatabase database;
    late ApplicationBoundary application;

    setUpAll(() async {
      database = openInMemoryTestDatabase();
      application = await AppCompositionRoot.initializeProduction(
        databaseFactory: () async => database,
        trialEvaluator: _TrialEvaluatorStub(),
      );
    });

    tearDownAll(AppCompositionRoot.close);

    test('Q7 reuses the legacy graph audit repository instance', () {
      expect(
        application.dependencies.repositories.auditLogReadRepository,
        same(AppRepositories.auditLogRepository),
      );
      expect(AppRepositories.database, same(database));
    });

    test('Q8 composition root exposes a working production handler', () async {
      final result = await application.queries.auditLogs
          .execute(const LoadAuditLogsQuery());

      expect(result.value, isEmpty);
      expect(result.metadata, isA<LocalQueryResultMetadata>());
    });

    testWidgets('Q9 ApplicationScope exposes the owned boundary',
        (tester) async {
      ApplicationBoundary? resolved;

      await tester.pumpWidget(
        ApplicationScope(
          application: application,
          child: Builder(
            builder: (context) {
              resolved = ApplicationScope.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved, same(application));
    });
  });

  test('Q10 migrated UI consumer has no direct legacy access', () {
    final source =
        File('lib/features/audit/audit_logs_screen.dart').readAsStringSync();

    expect(source, contains('ApplicationScope.of(context).queries.auditLogs'));
    expect(source, isNot(contains('app_repositories.dart')));
    expect(source, isNot(contains('AppRepositories')));
  });

  test('Q11 application boundary contains two concrete production query slices',
      () {
    final queryFiles = Directory('lib/application/queries')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('_query.dart'))
        .where((file) => !file.path.endsWith('application_query.dart'))
        .where((file) {
      final source = file.readAsStringSync();
      return source.contains('implements') &&
          source.contains('ApplicationQueryHandler<');
    }).toList();

    expect(queryFiles, hasLength(2));
    expect(
      queryFiles
          .map((file) => file.path.replaceAll('\\', '/'))
          .map((path) => path.substring(path.indexOf('lib/application/')))
          .toSet(),
      {
        'lib/application/queries/load_audit_logs_query.dart',
        'lib/application/queries/load_document_history_query.dart',
      },
    );
  });
}

AuditLogReadModel _entry(String id, DateTime timestamp) => AuditLogReadModel(
      id: id,
      timestamp: timestamp,
      descriptionAr: id,
    );

final class _AuditLogReadRepositorySpy implements AuditLogReadRepository {
  _AuditLogReadRepositorySpy(this.entries, {this.error});

  final List<AuditLogReadModel> entries;
  final Object? error;
  int calls = 0;

  @override
  Future<List<AuditLogReadModel>> listAuditLogs() async {
    calls++;
    final failure = error;
    if (failure != null) throw failure;
    return entries;
  }
}

final class _TrialEvaluatorStub implements TrialEvaluator {
  @override
  Future<TrialEvaluation> evaluate() async =>
      TrialEvaluation.blocked(TrialAccessStatus.invalidState);
}
