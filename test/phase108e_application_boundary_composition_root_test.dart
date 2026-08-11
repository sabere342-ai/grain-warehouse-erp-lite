import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/application/application_boundary.dart';
import 'package:grain_warehouse_erp_lite/application/commands/application_command.dart';
import 'package:grain_warehouse_erp_lite/application/commands/evaluate_trial_command.dart';
import 'package:grain_warehouse_erp_lite/application/context/business_context.dart';
import 'package:grain_warehouse_erp_lite/application/queries/application_query.dart';
import 'package:grain_warehouse_erp_lite/composition/app_composition_root.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_service.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_state.dart';

void main() {
  group('Phase 108E application boundary and composition root', () {
    late FoundationDatabase database;
    late ApplicationBoundary application;
    late _TrialEvaluatorSpy trialEvaluator;

    setUpAll(() async {
      database = openInMemoryTestDatabase();
      trialEvaluator = _TrialEvaluatorSpy();
      application = await AppCompositionRoot.initializeProduction(
        databaseFactory: () async => database,
        trialEvaluator: trialEvaluator,
      );
    });

    tearDownAll(AppCompositionRoot.close);

    test('T1 central root builds a usable application graph', () async {
      final result = await application.commands.trialEvaluation.execute(
        const ApplicationCommandRequest(command: EvaluateTrialCommand()),
      );

      expect(result, same(trialEvaluator.evaluation));
      expect(application.dependencies.runtime.businessContextProvider.current,
          isNull);
    });

    test('T2 application and legacy bridge share stateful instances', () {
      final repositories = application.dependencies.repositories;

      expect(
        repositories.productCatalogReadRepository,
        same(AppRepositories.productCatalogReadRepository),
      );
      expect(
        repositories.inventoryRepository,
        same(AppRepositories.inventoryRepository),
      );
      expect(
        repositories.saleRepository,
        same(AppRepositories.saleRepository),
      );
      expect(
        application.dependencies.services.trialEvaluator,
        same(trialEvaluator),
      );
      expect(AppRepositories.database, same(database));
    });

    test('T3 command handler uses only its explicitly injected evaluator',
        () async {
      final evaluator = _TrialEvaluatorSpy();
      final handler = EvaluateTrialCommandHandler(trialEvaluator: evaluator);

      final result = await handler.execute(
        const ApplicationCommandRequest(command: EvaluateTrialCommand()),
      );

      expect(result, same(evaluator.evaluation));
      expect(evaluator.calls, 1);
    });

    test('T5 command and legacy evaluator preserve the same result', () async {
      final directEvaluator = _TrialEvaluatorSpy();
      final handler = EvaluateTrialCommandHandler(
        trialEvaluator: directEvaluator,
      );

      final migrated = await handler.evaluate();

      expect(migrated, same(directEvaluator.evaluation));
      expect(migrated.status, TrialAccessStatus.invalidState);
    });

    test('T6 legacy repository consumers remain usable through the bridge',
        () async {
      expect(
        await AppRepositories.productCatalogReadRepository
            .listProductCatalog(includeInactive: true),
        isEmpty,
      );
    });
  });

  test('command request has real context and idempotency extension seams', () {
    const context = BusinessContext(
      businessId: 'business-108e',
      userId: 'user-108e',
    );
    const request = ApplicationCommandRequest<String>(
      command: 'sample-command',
      businessContext: context,
      idempotencyKey: 'request-108e',
    );

    expect(request.businessContext, same(context));
    expect(request.idempotencyKey, 'request-108e');
  });

  test('query results retain a typed provenance extension seam', () {
    const result = ApplicationQueryResult<int>(
      value: 1,
      metadata: LocalQueryResultMetadata(),
    );

    expect(result.value, 1);
    expect(result.metadata, isA<QueryResultMetadata>());
  });

  test('T4 production trial UI path adopts the application command', () {
    final mainSource = File('lib/main.dart').readAsStringSync();

    expect(mainSource, contains('AppCompositionRoot.initializeProduction()'));
    expect(
      mainSource,
      contains('application.commands.trialEvaluation'),
    );
    expect(
      mainSource,
      contains('evaluator: application.commands.trialEvaluation'),
    );
  });

  test('T7 application handler cannot import or call the legacy locator', () {
    final handlerSource = File(
      'lib/application/commands/evaluate_trial_command.dart',
    ).readAsStringSync();

    expect(handlerSource, isNot(contains('app_repositories.dart')));
    expect(handlerSource, isNot(contains('AppRepositories')));
  });
}

final class _TrialEvaluatorSpy implements TrialEvaluator {
  final TrialEvaluation evaluation = TrialEvaluation.blocked(
    TrialAccessStatus.invalidState,
  );
  int calls = 0;

  @override
  Future<TrialEvaluation> evaluate() async {
    calls++;
    return evaluation;
  }
}
