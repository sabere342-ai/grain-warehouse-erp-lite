import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/application/application_boundary.dart';
import 'package:grain_warehouse_erp_lite/application/queries/application_query.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_product_catalog_query.dart';
import 'package:grain_warehouse_erp_lite/composition/app_composition_root.dart';
import 'package:grain_warehouse_erp_lite/composition/application_scope.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_controller.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    show FoundationDatabase;
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_service.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_state.dart';
import 'package:grain_warehouse_erp_lite/features/products/products_screen.dart';

void main() {
  group('Phase 108K product-catalog query handler parity', () {
    test('forwards false and true exactly once without changing results',
        () async {
      final repository = _CatalogRepositorySpy(_snapshot);
      final handler = LoadProductCatalogQueryHandler(repository: repository);

      final activeResult = await handler.execute(
        const LoadProductCatalogQuery(includeInactive: false),
      );
      final completeResult = await handler.execute(
        const LoadProductCatalogQuery(includeInactive: true),
      );

      expect(repository.includeInactiveValues, [false, true]);
      expect(repository.calls, 2);
      expect(activeResult.value, same(_snapshot));
      expect(completeResult.value, same(_snapshot));
      expect(completeResult.value[0], same(_snapshot[0]));
      expect(completeResult.value[1], same(_snapshot[1]));
      expect(completeResult.value.map((product) => product.id), [
        'product-inactive',
        'product-active',
      ]);
      expect(completeResult.value.first.notes, '  verbatim note  ');
      expect(completeResult.value.last.code, isNull);
      expect(
        completeResult.value.last.referenceCostPricePiastersPerKg,
        isNull,
      );
    });

    test('preserves empty success and local SQLite metadata', () async {
      final products = <ProductCatalogReadModel>[];
      final handler = LoadProductCatalogQueryHandler(
        repository: _CatalogRepositorySpy(products),
      );

      final result = await handler.execute(
        const LoadProductCatalogQuery(includeInactive: false),
      );
      final metadata = result.metadata as LocalQueryResultMetadata;

      expect(result.value, same(products));
      expect(result.value, isEmpty);
      expect(metadata.source, QueryResultSource.local);
      expect(metadata.readAuthority, LocalReadAuthority.sqlite);
      expect(metadata.consistency, LocalQueryConsistency.currentKnownState);
    });

    test('propagates the exact repository exception', () async {
      final failure = StateError('sentinel catalog failure');
      final repository = _CatalogRepositorySpy(const [], failure: failure);
      final handler = LoadProductCatalogQueryHandler(repository: repository);

      await expectLater(
        handler.execute(
          const LoadProductCatalogQuery(includeInactive: true),
        ),
        throwsA(same(failure)),
      );
      expect(repository.calls, 1);
    });
  });

  group('Phase 108K controller compatibility and behavior', () {
    test('requires exactly one read dependency and a separate write repository',
        () async {
      final repositoryRead = _CatalogRepositorySpy(const []);
      final handlerRead = _CatalogRepositorySpy(const []);
      final writes = _WriteRepositorySpy();
      final repositoryController = ProductController(
        productCatalogReadRepository: repositoryRead,
        repository: writes,
      );
      final handlerController = ProductController(
        queryHandler: LoadProductCatalogQueryHandler(repository: handlerRead),
        repository: writes,
      );
      addTearDown(repositoryController.dispose);
      addTearDown(handlerController.dispose);

      await repositoryController.loadProducts(_owner);
      await handlerController.loadProducts(_employee);

      expect(repositoryRead.includeInactiveValues, [true]);
      expect(handlerRead.includeInactiveValues, [false]);
      expect(
        () => ProductController(repository: writes),
        throwsAssertionError,
      );
      expect(
        () => ProductController(
          productCatalogReadRepository: repositoryRead,
          queryHandler: LoadProductCatalogQueryHandler(repository: handlerRead),
          repository: writes,
        ),
        throwsAssertionError,
      );
    });

    test('preserves owner/employee permissions and loading notifications',
        () async {
      final repository = _CatalogRepositorySpy(_snapshot);
      final controller = ProductController(
        queryHandler: LoadProductCatalogQueryHandler(repository: repository),
        repository: _WriteRepositorySpy(),
      );
      addTearDown(controller.dispose);
      final loadingStates = <bool>[];
      controller.addListener(() => loadingStates.add(controller.isLoading));

      await controller.loadProducts(_owner);

      expect(repository.includeInactiveValues, [true]);
      expect(controller.products[0], same(_snapshot[0]));
      expect(controller.products[1], same(_snapshot[1]));
      expect(loadingStates, [true, false]);

      loadingStates.clear();
      await controller.loadProducts(_employee);

      expect(repository.includeInactiveValues, [true, false]);
      expect(loadingStates, [true, false]);
    });

    test('preserves failure identity, loading, error, and retained products',
        () async {
      final repository = _CatalogRepositorySpy(_snapshot);
      final controller = ProductController(
        queryHandler: LoadProductCatalogQueryHandler(repository: repository),
        repository: _WriteRepositorySpy(),
      );
      addTearDown(controller.dispose);
      await controller.loadProducts(_owner);
      final retained = controller.products.first;
      final failure = StateError('later catalog failure');
      repository.failure = failure;
      final loadingStates = <bool>[];
      controller.addListener(() => loadingStates.add(controller.isLoading));

      await expectLater(
        controller.loadProducts(_employee),
        throwsA(same(failure)),
      );

      expect(controller.isLoading, isTrue);
      expect(controller.errorMessage, isNull);
      expect(controller.products.first, same(retained));
      expect(loadingStates, [true]);
    });

    test('writes stay on ProductRepository and refresh once through handler',
        () async {
      final reads = _CatalogRepositorySpy(_snapshot);
      final writes = _WriteRepositorySpy();
      final controller = ProductController(
        queryHandler: LoadProductCatalogQueryHandler(repository: reads),
        repository: writes,
      );
      addTearDown(controller.dispose);
      const draft = ProductDraft(
        name: 'Updated product',
        unit: GrainUnit.kilogram,
        notes: 'write remains local',
      );

      expect(
        await controller.createProduct(user: _owner, draft: draft),
        isTrue,
      );
      expect(
        await controller.updateProduct(
          user: _owner,
          productId: 'product-active',
          draft: draft,
        ),
        isTrue,
      );
      expect(
        await controller.setProductActive(
          user: _owner,
          productId: 'product-active',
          isActive: false,
        ),
        isTrue,
      );

      expect(writes.createCalls, 1);
      expect(writes.updateCalls, 1);
      expect(writes.setActiveCalls, 1);
      expect(writes.listCalls, 0);
      expect(reads.includeInactiveValues, [true, true, true]);
    });
  });

  group('Phase 108K production composition and ProductsScreen scope', () {
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

    test('exposes the handler with the same shared repository instance', () {
      expect(
        application.dependencies.repositories.productCatalogReadRepository,
        same(AppRepositories.productCatalogReadRepository),
      );
      expect(AppRepositories.database, same(database));
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
          'repository: dependencies.repositories.productCatalogReadRepository',
        ),
      );
    });

    testWidgets('default owner screen resolves scope and loads through handler',
        (tester) async {
      final reads = _CatalogRepositorySpy(_snapshot);
      final auth = await _signedInAuth('01000000000', 'owner123');
      addTearDown(auth.dispose);

      await tester.pumpWidget(
        _defaultScreenHarness(
          application: _withCatalogHandler(application, reads),
          auth: auth,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(reads.includeInactiveValues, [true]);
      expect(find.text('Inactive product'), findsOneWidget);
      expect(find.text('إضافة صنف حبوب'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('default employee and unauthenticated behavior stay unchanged',
        (tester) async {
      final reads = _CatalogRepositorySpy([_snapshot.last]);
      final employee = await _signedInAuth('01100000000', 'employee123');
      addTearDown(employee.dispose);

      await tester.pumpWidget(
        _defaultScreenHarness(
          application: _withCatalogHandler(application, reads),
          auth: employee,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(reads.includeInactiveValues, [false]);
      expect(find.text('Active product'), findsOneWidget);
      expect(find.text('إضافة صنف حبوب'), findsNothing);

      final signedOut = AuthController(repository: LocalAuthRepository.demo());
      addTearDown(signedOut.dispose);
      await signedOut.initialize();
      reads.includeInactiveValues.clear();

      await tester.pumpWidget(
        _defaultScreenHarness(
          application: _withCatalogHandler(application, reads),
          auth: signedOut,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(reads.includeInactiveValues, isEmpty);
      expect(find.text('يجب تسجيل الدخول لعرض الأصناف.'), findsOneWidget);
    });

    testWidgets(
        'injected controller remains scope-independent with empty state',
        (tester) async {
      final auth = await _signedInAuth('01100000000', 'employee123');
      final controller = ProductController(
        productCatalogReadRepository: _CatalogRepositorySpy(const []),
        repository: _WriteRepositorySpy(),
      );
      addTearDown(auth.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        AuthScope(
          controller: auth,
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('ar'),
            home: ProductsScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('لا توجد أصناف حبوب مسجلة بعد'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Phase 108K static ownership and singular-scope guards', () {
    test('handler is local, read-only, and free of concrete infrastructure',
        () {
      final source = File(
        'lib/application/queries/load_product_catalog_query.dart',
      ).readAsStringSync();

      expect(source, contains('ProductCatalogReadRepository _repository'));
      expect(source, contains('_repository.listProductCatalog('));
      expect(source, isNot(contains('app_repositories.dart')));
      expect(source, isNot(contains('AppRepositories')));
      expect(source, isNot(contains('FoundationDatabase')));
      expect(source, isNot(contains('Drift')));
      expect(source, isNot(contains('Supabase')));
      for (final writeToken in [
        '.create',
        '.update',
        '.delete',
        '.save',
        '.setProductActive',
      ]) {
        expect(source, isNot(contains(writeToken)));
      }
    });

    test('ProductsScreen owns only the unchanged write locator', () {
      final screen = File(
        'lib/features/products/products_screen.dart',
      ).readAsStringSync();

      expect(
        screen,
        contains('ApplicationScope.of(context).queries.productCatalog'),
      );
      expect(
        screen,
        isNot(contains('AppRepositories.productCatalogReadRepository')),
      );
      expect(
        'AppRepositories.productRepository'.allMatches(screen),
        hasLength(1),
      );
      expect(screen, isNot(contains('DriftProductCatalogReadRepository')));
      expect(screen, isNot(contains('FoundationDatabase')));
    });

    test('exactly four typed query slices exist and no second UI read moved',
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
      }).map((file) {
        final path = file.path.replaceAll('\\', '/');
        return path.substring(path.indexOf('lib/application/'));
      }).toSet();

      expect(queryFiles, {
        'lib/application/queries/load_audit_logs_query.dart',
        'lib/application/queries/load_business_logo_query.dart',
        'lib/application/queries/load_document_history_query.dart',
        'lib/application/queries/load_product_catalog_query.dart',
      });
      final controller = File(
        'lib/core/catalog/product_controller.dart',
      ).readAsStringSync();
      expect(
        '.listProductCatalog('.allMatches(controller),
        isEmpty,
      );
      expect(controller, contains('LoadProductCatalogQuery('));
      expect(controller, contains('final ProductRepository _repository;'));
    });
  });
}

ApplicationBoundary _withCatalogHandler(
  ApplicationBoundary application,
  ProductCatalogReadRepository repository,
) {
  return ApplicationBoundary(
    dependencies: application.dependencies,
    commands: application.commands,
    queries: ApplicationQueries(
      auditLogs: application.queries.auditLogs,
      businessLogo: application.queries.businessLogo,
      documentHistory: application.queries.documentHistory,
      productCatalog: LoadProductCatalogQueryHandler(repository: repository),
    ),
  );
}

Widget _defaultScreenHarness({
  required ApplicationBoundary application,
  required AuthController auth,
}) {
  return ApplicationScope(
    application: application,
    child: AuthScope(
      controller: auth,
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ar'),
        home: const ProductsScreen(),
      ),
    ),
  );
}

Future<AuthController> _signedInAuth(String phone, String password) async {
  final controller = AuthController(repository: LocalAuthRepository.demo());
  await controller.initialize();
  await controller.signIn(phone: phone, password: password);
  return controller;
}

final class _CatalogRepositorySpy implements ProductCatalogReadRepository {
  _CatalogRepositorySpy(this.products, {this.failure});

  List<ProductCatalogReadModel> products;
  Object? failure;
  int calls = 0;
  final List<bool> includeInactiveValues = [];

  @override
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  }) async {
    calls++;
    includeInactiveValues.add(includeInactive);
    final error = failure;
    if (error != null) throw error;
    return products;
  }
}

final class _WriteRepositorySpy implements ProductRepository {
  int listCalls = 0;
  int createCalls = 0;
  int updateCalls = 0;
  int setActiveCalls = 0;

  @override
  Future<List<Product>> listProducts({bool includeInactive = true}) async {
    listCalls++;
    throw StateError('Legacy product list must not be called.');
  }

  @override
  Future<Product> createProduct(ProductDraft draft) async {
    createCalls++;
    return _writtenProduct;
  }

  @override
  Future<Product> updateProduct({
    required String productId,
    required ProductDraft draft,
  }) async {
    updateCalls++;
    return _writtenProduct;
  }

  @override
  Future<Product> setProductActive({
    required String productId,
    required bool isActive,
  }) async {
    setActiveCalls++;
    return _writtenProduct;
  }
}

final _timestamp = DateTime.utc(2026, 8, 24);

final _snapshot = <ProductCatalogReadModel>[
  ProductCatalogReadModel(
    id: 'product-inactive',
    name: 'Inactive product',
    code: 'INACTIVE-1',
    unit: GrainUnit.ton,
    isActive: false,
    referenceCostPricePiastersPerKg: 2100,
    defaultSalePricePiastersPerKg: 3000,
    minimumSalePricePiastersPerKg: 2500,
    notes: '  verbatim note  ',
    createdAt: _timestamp,
    updatedAt: _timestamp,
  ),
  ProductCatalogReadModel(
    id: 'product-active',
    name: 'Active product',
    code: null,
    unit: GrainUnit.kilogram,
    isActive: true,
    referenceCostPricePiastersPerKg: null,
    defaultSalePricePiastersPerKg: null,
    minimumSalePricePiastersPerKg: null,
    notes: null,
    createdAt: _timestamp.add(const Duration(seconds: 1)),
    updatedAt: _timestamp.add(const Duration(seconds: 1)),
  ),
];

final _writtenProduct = Product(
  id: 'written-product',
  name: 'Written product',
  unit: GrainUnit.kilogram,
  isActive: true,
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

final _owner = AppUser(
  id: 'owner-108k',
  name: 'Owner',
  phone: '01000000108',
  role: UserRole.owner,
  isActive: true,
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

final _employee = AppUser(
  id: 'employee-108k',
  name: 'Employee',
  phone: '01100000108',
  role: UserRole.employee,
  isActive: true,
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

final class _TrialEvaluatorStub implements TrialEvaluator {
  @override
  Future<TrialEvaluation> evaluate() async =>
      TrialEvaluation.blocked(TrialAccessStatus.invalidState);
}
