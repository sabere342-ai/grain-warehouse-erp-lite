import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/application/application_boundary.dart';
import 'package:grain_warehouse_erp_lite/application/queries/application_query.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_audit_logs_query.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_document_history_query.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_product_catalog_query.dart';
import 'package:grain_warehouse_erp_lite/composition/app_composition_root.dart';
import 'package:grain_warehouse_erp_lite/composition/application_scope.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history_controller.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_service.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_state.dart';
import 'package:grain_warehouse_erp_lite/features/documents/document_history_screen.dart';

void main() {
  group('Phase 108I document-history query handler parity', () {
    test('forwards the exact filter once and preserves list identity and order',
        () async {
      final filter = DocumentHistoryFilter(
        from: DateTime.utc(2026, 8, 1),
        to: DateTime.utc(2026, 8, 31),
        type: DocumentHistoryType.sale,
        status: DocumentHistoryStatus.cancelled,
        query: 'sale-108i',
        productName: 'wheat',
      );
      final older = _entry('older', DateTime.utc(2026, 8, 10));
      final newer = _entry('newer', DateTime.utc(2026, 8, 20));
      final repository = _DocumentHistoryRepositorySpy([older, newer]);
      final handler = LoadDocumentHistoryQueryHandler(repository: repository);

      final result = await handler.execute(
        LoadDocumentHistoryQuery(filter: filter),
      );

      expect(repository.calls, 1);
      expect(repository.filters.single, same(filter));
      expect(result.value, same(repository.entries));
      expect(result.value, same(repository.returnedLists.single));
      expect(result.value[0], same(older));
      expect(result.value[1], same(newer));
      expect(result.value.map((entry) => entry.id), ['older', 'newer']);
    });

    test('preserves an exact empty successful result and local metadata',
        () async {
      final entries = <DocumentHistoryEntry>[];
      final handler = LoadDocumentHistoryQueryHandler(
        repository: _DocumentHistoryRepositorySpy(entries),
      );

      final result = await handler.execute(
        const LoadDocumentHistoryQuery(filter: DocumentHistoryFilter()),
      );
      final metadata = result.metadata as LocalQueryResultMetadata;

      expect(result.value, same(entries));
      expect(result.value, isEmpty);
      expect(metadata.source, QueryResultSource.local);
      expect(metadata.readAuthority, LocalReadAuthority.sqlite);
      expect(metadata.consistency, LocalQueryConsistency.currentKnownState);
    });

    test('preserves the exact repository exception', () {
      final error = StateError('document history read failed');
      final repository = _DocumentHistoryRepositorySpy(const [], error: error);
      final handler = LoadDocumentHistoryQueryHandler(repository: repository);

      expect(
        handler.execute(
          const LoadDocumentHistoryQuery(filter: DocumentHistoryFilter()),
        ),
        throwsA(same(error)),
      );
    });
  });

  group('Phase 108I controller parity', () {
    test('accepts exactly one authorized constructor dependency', () async {
      final repositoryDependency = _DocumentHistoryRepositorySpy(const []);
      final handlerDependency = _DocumentHistoryRepositorySpy(const []);
      final repositoryController = DocumentHistoryController(
        repository: repositoryDependency,
      );
      final handlerController = DocumentHistoryController(
        queryHandler: LoadDocumentHistoryQueryHandler(
          repository: handlerDependency,
        ),
      );
      addTearDown(repositoryController.dispose);
      addTearDown(handlerController.dispose);

      await repositoryController.load(_owner);
      await handlerController.load(_owner);

      expect(repositoryDependency.calls, 1);
      expect(handlerDependency.calls, 1);
      expect(() => DocumentHistoryController(), throwsAssertionError);
      expect(
        () => DocumentHistoryController(
          repository: repositoryDependency,
          queryHandler: LoadDocumentHistoryQueryHandler(
            repository: handlerDependency,
          ),
        ),
        throwsAssertionError,
      );
    });

    test('applyFilter preserves state transitions, identities, and permissions',
        () async {
      final first = _entry('first', DateTime.utc(2026, 8, 20));
      final second = _entry('second', DateTime.utc(2026, 8, 10));
      final repository = _DocumentHistoryRepositorySpy([first, second]);
      final controller = DocumentHistoryController(
        queryHandler: LoadDocumentHistoryQueryHandler(repository: repository),
      );
      addTearDown(controller.dispose);
      final states = <({bool loading, bool audit, int entries})>[];
      controller.addListener(() {
        states.add((
          loading: controller.isLoading,
          audit: controller.canViewOwnerAudit,
          entries: controller.entries.length,
        ));
      });
      final filter = DocumentHistoryFilter(
        query: 'first',
        from: DateTime.utc(2026, 8, 1),
      );

      await controller.applyFilter(user: _owner, filter: filter);

      expect(controller.filter, same(filter));
      expect(repository.filters.single, same(filter));
      expect(controller.entries[0], same(first));
      expect(controller.entries[1], same(second));
      expect(controller.canViewOwnerAudit, isTrue);
      expect(controller.isLoading, isFalse);
      expect(states, [
        (loading: true, audit: true, entries: 0),
        (loading: false, audit: true, entries: 2),
      ]);
    });

    test('employee can read while owner audit details remain hidden', () async {
      final entry = _entry('employee-visible', DateTime.utc(2026, 8, 20));
      final repository = _DocumentHistoryRepositorySpy([entry]);
      final controller = DocumentHistoryController(repository: repository);
      addTearDown(controller.dispose);

      await controller.load(_employee);

      expect(controller.entries.single, same(entry));
      expect(controller.canViewOwnerAudit, isFalse);
      expect(controller.isLoading, isFalse);
    });

    test('failure identity and the existing failure state remain unchanged',
        () async {
      final retained = _entry('retained', DateTime.utc(2026, 8, 20));
      final repository = _DocumentHistoryRepositorySpy([retained]);
      final controller = DocumentHistoryController(repository: repository);
      addTearDown(controller.dispose);
      await controller.load(_owner);
      final failure = StateError('sentinel controller failure');
      repository.error = failure;
      const failureFilter = DocumentHistoryFilter(query: 'failure');
      final states = <({bool loading, int entries})>[];
      controller.addListener(() {
        states.add((
          loading: controller.isLoading,
          entries: controller.entries.length,
        ));
      });

      await expectLater(
        controller.applyFilter(user: _employee, filter: failureFilter),
        throwsA(same(failure)),
      );

      expect(controller.filter, same(failureFilter));
      expect(repository.filters.last, same(failureFilter));
      expect(controller.entries.single, same(retained));
      expect(controller.isLoading, isTrue);
      expect(controller.canViewOwnerAudit, isFalse);
      expect(states, [(loading: true, entries: 1)]);
    });
  });

  group('Phase 108I production wiring and scope', () {
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
      final runtime = application.dependencies.runtime;
      runtime.authController.dispose();
      runtime.themeController.dispose();
      runtime.businessIdentityController.dispose();
      await AppCompositionRoot.close();
    });

    test('reuses the shared repository and exposes all query slices', () {
      expect(
        application.dependencies.repositories.documentHistoryRepository,
        same(AppRepositories.documentHistoryRepository),
      );
      expect(AppRepositories.database, same(database));
      expect(application.queries.auditLogs, isA<LoadAuditLogsQueryHandler>());
      expect(
        application.queries.documentHistory,
        isA<LoadDocumentHistoryQueryHandler>(),
      );
      expect(
        application.queries.productCatalog,
        isA<LoadProductCatalogQueryHandler>(),
      );

      final rootSource = File(
        'lib/composition/app_composition_root.dart',
      ).readAsStringSync();
      expect(
        rootSource,
        contains(
          'repository: dependencies.repositories.documentHistoryRepository',
        ),
      );
    });

    test('production handler is local and leaves all read surfaces unchanged',
        () async {
      final before = await _productionReadSurfaceCounts();

      final result = await application.queries.documentHistory.execute(
        const LoadDocumentHistoryQuery(filter: DocumentHistoryFilter()),
      );
      final metadata = result.metadata as LocalQueryResultMetadata;
      final after = await _productionReadSurfaceCounts();

      expect(result.value, isEmpty);
      expect(metadata.source, QueryResultSource.local);
      expect(metadata.readAuthority, LocalReadAuthority.sqlite);
      expect(metadata.consistency, LocalQueryConsistency.currentKnownState);
      expect(after, before);
    });

    testWidgets('default screen resolves its handler from ApplicationScope',
        (tester) async {
      final auth = AuthController(repository: LocalAuthRepository.demo());
      addTearDown(auth.dispose);
      await auth.initialize();
      await auth.signIn(phone: '01100000000', password: 'employee123');

      await tester.pumpWidget(
        ApplicationScope(
          application: application,
          child: AuthScope(
            controller: auth,
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('ar'),
              home: const DocumentHistoryScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byKey(const Key('document-history-route-scaffold')),
        findsOneWidget,
      );
      expect(find.text('سجل المستندات'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('injected controller remains scope-independent',
        (tester) async {
      final auth = AuthController(repository: LocalAuthRepository.demo());
      final controller = DocumentHistoryController(
        repository: _DocumentHistoryRepositorySpy(const []),
      );
      addTearDown(auth.dispose);
      addTearDown(controller.dispose);
      await auth.initialize();
      await auth.signIn(phone: '01100000000', password: 'employee123');

      await tester.pumpWidget(
        AuthScope(
          controller: auth,
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('ar'),
            home: DocumentHistoryScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('لا توجد نتائج'), findsOneWidget);
    });
  });

  group('Phase 108I static ownership and no-write guards', () {
    test('screen and controller use only the typed application seam', () {
      final screenSource = File(
        'lib/features/documents/document_history_screen.dart',
      ).readAsStringSync();
      final controllerSource = File(
        'lib/core/documents/document_history_controller.dart',
      ).readAsStringSync();

      expect(
        screenSource,
        contains('ApplicationScope.of(context).queries.documentHistory'),
      );
      expect(screenSource, isNot(contains('app_repositories.dart')));
      expect(screenSource, isNot(contains('AppRepositories')));
      expect(controllerSource, contains('LoadDocumentHistoryQueryHandler'));
      expect(controllerSource, contains('LoadDocumentHistoryQuery('));
      expect(controllerSource, isNot(contains('app_repositories.dart')));
      expect(controllerSource, isNot(contains('AppRepositories')));
    });

    test('handler is read-only and has no locator or infrastructure access',
        () {
      final source = File(
        'lib/application/queries/load_document_history_query.dart',
      ).readAsStringSync();

      expect(source, contains('DocumentHistoryRepository _repository'));
      expect(source, contains('_repository.listHistory(filter: query.filter)'));
      expect(source, isNot(contains('app_repositories.dart')));
      expect(source, isNot(contains('AppRepositories')));
      expect(source, isNot(contains('FoundationDatabase')));
      expect(source, isNot(contains('Drift')));
      expect(source, isNot(contains('LocalDocumentHistoryRepository')));
      for (final writeToken in [
        '.create',
        '.update',
        '.delete',
        '.save',
        '.cancel',
        '.restore',
        '.wipe',
      ]) {
        expect(source, isNot(contains(writeToken)));
      }
    });

    test('audit, document history, and product catalog are query handlers', () {
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

      expect(
        queryFiles
            .map((file) => _normalizedPath(file.path))
            .map((path) => path.substring(path.indexOf('lib/application/')))
            .toSet(),
        {
          'lib/application/queries/load_audit_logs_query.dart',
          'lib/application/queries/load_document_history_query.dart',
          'lib/application/queries/load_product_catalog_query.dart',
        },
      );
    });

    test('locator and composition metrics move by exactly one UI reference',
        () {
      final featureSharedFiles = _dartFilesUnder([
        Directory('lib/features'),
        Directory('lib/shared'),
      ]);
      final allLibFiles = _dartFilesUnder([Directory('lib')]);
      final locatorPattern = RegExp(
        r'AppRepositories\.[A-Za-z_][A-Za-z0-9_]*',
      );
      final featureSharedWithLocator = featureSharedFiles.where((file) {
        return locatorPattern.hasMatch(file.readAsStringSync());
      }).toList();
      final featureSharedReferences = featureSharedFiles.fold<int>(
        0,
        (count, file) =>
            count + locatorPattern.allMatches(file.readAsStringSync()).length,
      );
      final allLibReferences = allLibFiles.fold<int>(
        0,
        (count, file) =>
            count + locatorPattern.allMatches(file.readAsStringSync()).length,
      );
      final scopeConsumers = featureSharedFiles.where((file) {
        return file.readAsStringSync().contains('ApplicationScope.of');
      }).toList();
      final featureSharedSource =
          featureSharedFiles.map((file) => file.readAsStringSync()).join('\n');
      final allLibSource =
          allLibFiles.map((file) => file.readAsStringSync()).join('\n');
      final bridgeSource = File(
        'lib/composition/legacy_application_dependency_bridge.dart',
      ).readAsStringSync();

      expect(featureSharedReferences, 146);
      expect(featureSharedWithLocator, hasLength(40));
      expect(scopeConsumers, hasLength(4));
      expect(allLibReferences, 162);
      expect(
        'AppRepositories.documentHistoryRepository'
            .allMatches(bridgeSource)
            .length,
        1,
      );
      expect(
        'LegacyApplicationDependencyBridge.captureSharedInstances('
            .allMatches(allLibSource)
            .length,
        1,
      );
      expect(
        'AppRepositories.initializeProduction('.allMatches(allLibSource).length,
        1,
      );
      expect(
        RegExp(r'FoundationDatabase\s*\(').allMatches(featureSharedSource),
        isEmpty,
      );
      expect(
        RegExp(r'Drift[A-Za-z0-9_]*Repository\s*\(')
            .allMatches(featureSharedSource),
        isEmpty,
      );
    });
  });
}

Future<Map<String, int>> _productionReadSurfaceCounts() async {
  return {
    'catalog': (await AppRepositories.productCatalogReadRepository
            .listProductCatalog(includeInactive: true))
        .length,
    'inventory':
        (await AppRepositories.inventoryRepository.listAllMovements()).length,
    'purchases':
        (await AppRepositories.purchaseRepository.listPurchaseIntakes()).length,
    'sales': (await AppRepositories.saleRepository.listSales()).length,
    'audit': (await AppRepositories.auditLogRepository.listAuditLogs()).length,
  };
}

List<File> _dartFilesUnder(List<Directory> roots) {
  return roots
      .expand((root) => root.listSync(recursive: true).whereType<File>())
      .where((file) => file.path.endsWith('.dart'))
      .toList();
}

String _normalizedPath(String path) => path.replaceAll('\\', '/');

DocumentHistoryEntry _entry(String id, DateTime createdAt) {
  return DocumentHistoryEntry(
    id: id,
    type: DocumentHistoryType.sale,
    productId: 'product-$id',
    productName: 'Product $id',
    quantityKg: 100,
    createdByUserId: 'user-108i',
    createdAt: createdAt,
    originalMovement: null,
    reversalMovements: const [],
  );
}

final class _DocumentHistoryRepositorySpy implements DocumentHistoryRepository {
  _DocumentHistoryRepositorySpy(this.entries, {this.error});

  List<DocumentHistoryEntry> entries;
  Object? error;
  int calls = 0;
  final List<DocumentHistoryFilter> filters = [];
  final List<List<DocumentHistoryEntry>> returnedLists = [];

  @override
  Future<List<DocumentHistoryEntry>> listHistory({
    DocumentHistoryFilter filter = const DocumentHistoryFilter(),
  }) async {
    calls++;
    filters.add(filter);
    final failure = error;
    if (failure != null) throw failure;
    returnedLists.add(entries);
    return entries;
  }
}

final class _TrialEvaluatorStub implements TrialEvaluator {
  @override
  Future<TrialEvaluation> evaluate() async =>
      TrialEvaluation.blocked(TrialAccessStatus.invalidState);
}

final _timestamp = DateTime.utc(2026, 8, 23);

final _owner = AppUser(
  id: 'owner-108i',
  name: 'Owner',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

final _employee = AppUser(
  id: 'employee-108i',
  name: 'Employee',
  phone: '01100000000',
  role: UserRole.employee,
  isActive: true,
  createdAt: _timestamp,
  updatedAt: _timestamp,
);
