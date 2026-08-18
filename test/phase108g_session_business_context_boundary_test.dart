import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/application/application_boundary.dart';
import 'package:grain_warehouse_erp_lite/application/context/business_context.dart';
import 'package:grain_warehouse_erp_lite/application/context/session_context.dart';
import 'package:grain_warehouse_erp_lite/composition/app_composition_root.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_service.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_state.dart';

void main() {
  group('Phase 108G local session boundary', () {
    test('provider has explicit unavailable, replacement, and clear states',
        () {
      final provider = LocalSessionContextProvider();

      expect(provider.current, isNull);

      provider.replace(const SessionContext(userId: 'user-a'));
      expect(provider.current?.userId, 'user-a');

      provider.replace(const SessionContext(userId: 'user-b'));
      expect(provider.current?.userId, 'user-b');

      provider.clear();
      expect(provider.current, isNull);
    });

    test('existing authenticated user recovery populates session context',
        () async {
      final repository = LocalAuthRepository.demo();
      final recovered = await repository.signIn(
        phone: '01000000000',
        password: 'owner123',
      );
      final provider = LocalSessionContextProvider();
      final synchronizer = AuthSessionContextSynchronizer(provider: provider);
      final controller = AuthController(
        repository: repository,
        onAuthenticatedUserChanged: synchronizer.synchronize,
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(provider.current?.userId, recovered?.id);
    });

    test('sign-in replaces and sign-out clears session context', () async {
      final provider = LocalSessionContextProvider();
      final synchronizer = AuthSessionContextSynchronizer(provider: provider);
      final controller = AuthController(
        repository: LocalAuthRepository.demo(),
        onAuthenticatedUserChanged: synchronizer.synchronize,
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      await controller.signIn(
        phone: '01000000000',
        password: 'owner123',
      );
      expect(provider.current?.userId, 'owner-demo');

      await controller.signOut();
      expect(provider.current, isNull);

      await controller.signIn(
        phone: '01100000000',
        password: 'employee123',
      );
      expect(provider.current?.userId, 'employee-demo');
    });

    test('first-owner authentication populates only verified user identity',
        () async {
      final provider = LocalSessionContextProvider();
      final synchronizer = AuthSessionContextSynchronizer(provider: provider);
      final controller = AuthController(
        repository: LocalAuthRepository.empty(),
        onAuthenticatedUserChanged: synchronizer.synchronize,
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      await controller.createFirstOwner(
        name: 'Owner',
        phone: '01000000000',
        password: 'owner123',
      );

      expect(provider.current?.userId, controller.state.user?.id);
      expect(provider.current?.userId, isNotEmpty);
    });
  });

  group('Phase 108G central composition ownership', () {
    late FoundationDatabase database;
    late ApplicationBoundary application;

    setUpAll(() async {
      database = openInMemoryTestDatabase();
      application = await AppCompositionRoot.initializeProduction(
        databaseFactory: () async => database,
        trialEvaluator: _TrialEvaluatorStub(),
      );
    });

    tearDownAll(() async {
      application.dependencies.runtime.authController.dispose();
      await AppCompositionRoot.close();
    });

    test('root exposes one auth controller and local session provider', () {
      expect(
        application.dependencies.runtime.authController,
        isA<AuthController>(),
      );
      expect(
        application.dependencies.runtime.sessionContextProvider,
        isA<LocalSessionContextProvider>(),
      );
      expect(
        application.dependencies.runtime.sessionContextProvider.current,
        isNull,
      );
    });

    test('business context stays explicitly unavailable without authority', () {
      final businessProvider =
          application.dependencies.runtime.businessContextProvider;

      expect(businessProvider, isA<NoBusinessContextProvider>());
      expect(businessProvider.current, isNull);
    });

    test('root-wired auth lifecycle updates its session dependency', () async {
      final runtime = application.dependencies.runtime;
      final auth = runtime.authController;
      await auth.initialize();

      await auth.createFirstOwner(
        name: 'Owner',
        phone: '01000000000',
        password: 'owner123',
      );
      expect(
        runtime.sessionContextProvider.current?.userId,
        auth.state.user?.id,
      );
      expect(runtime.businessContextProvider.current, isNull);

      await auth.signOut();
      expect(runtime.sessionContextProvider.current, isNull);
      expect(runtime.businessContextProvider.current, isNull);
    });
  });

  test('UI consumes root-owned auth while Phase 108E and 108F stay wired', () {
    final appSource =
        File('lib/app/grain_warehouse_app.dart').readAsStringSync();
    final rootSource =
        File('lib/composition/app_composition_root.dart').readAsStringSync();
    final mainSource = File('lib/main.dart').readAsStringSync();
    final boundarySource =
        File('lib/application/application_boundary.dart').readAsStringSync();

    expect(appSource, isNot(contains('AppRepositories.authRepository')));
    expect(appSource, isNot(contains('AuthController(repository:')));
    expect(rootSource, contains('LocalSessionContextProvider()'));
    expect(rootSource, contains('AuthController('));
    expect(mainSource,
        contains('application.dependencies.runtime.authController'));
    expect(boundarySource, contains('LoadAuditLogsQueryHandler auditLogs'));
  });

  test('no production mapping fabricates business identity from user identity',
      () {
    final productionSources = [
      'lib/application/context/session_context.dart',
      'lib/composition/app_composition_root.dart',
      'lib/composition/legacy_application_dependency_bridge.dart',
      'lib/core/auth/auth_controller.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');

    expect(productionSources, isNot(contains('businessId:')));
    expect(productionSources, isNot(contains('businessId =')));
  });
}

final class _TrialEvaluatorStub implements TrialEvaluator {
  @override
  Future<TrialEvaluation> evaluate() async =>
      TrialEvaluation.blocked(TrialAccessStatus.invalidState);
}
