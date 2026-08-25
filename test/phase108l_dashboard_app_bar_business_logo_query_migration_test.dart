import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/application/application_boundary.dart';
import 'package:grain_warehouse_erp_lite/application/queries/application_query.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_business_logo_query.dart';
import 'package:grain_warehouse_erp_lite/composition/app_composition_root.dart';
import 'package:grain_warehouse_erp_lite/composition/application_scope.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_controller.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_service.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_state.dart';
import 'package:grain_warehouse_erp_lite/features/dashboard/dashboard_shell.dart';

void main() {
  group('Phase 108L business-logo query handler', () {
    test('empty filename returns managed-file null without a repository call',
        () async {
      final repository = _BusinessIdentityRepositorySpy();
      final handler = LoadBusinessLogoQueryHandler(repository: repository);

      final result = await handler.execute(
        const LoadBusinessLogoQuery(managedFileName: ''),
      );
      final metadata = result.metadata as LocalQueryResultMetadata;

      expect(result.value, isNull);
      expect(repository.logoReads, 0);
      _expectManagedFileMetadata(metadata);
      _expectNoWrites(repository);
    });

    test('forwards a non-empty filename once and preserves exact byte identity',
        () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final repository = _BusinessIdentityRepositorySpy(logoBytes: bytes);
      final handler = LoadBusinessLogoQueryHandler(repository: repository);

      final result = await handler.execute(
        const LoadBusinessLogoQuery(managedFileName: '../verbatim/logo.png'),
      );
      final metadata = result.metadata as LocalQueryResultMetadata;

      expect(repository.managedFileNames, ['../verbatim/logo.png']);
      expect(repository.logoReads, 1);
      expect(result.value, same(bytes));
      _expectManagedFileMetadata(metadata);
      _expectNoWrites(repository);
    });

    test('preserves repository null as a successful managed-file result',
        () async {
      final repository = _BusinessIdentityRepositorySpy();
      final handler = LoadBusinessLogoQueryHandler(repository: repository);

      final result = await handler.execute(
        const LoadBusinessLogoQuery(managedFileName: 'missing.png'),
      );
      final metadata = result.metadata as LocalQueryResultMetadata;

      expect(result.value, isNull);
      expect(repository.managedFileNames, ['missing.png']);
      expect(repository.logoReads, 1);
      _expectManagedFileMetadata(metadata);
      _expectNoWrites(repository);
    });

    test('propagates the exact repository exception', () async {
      final failure = StateError('sentinel managed-file failure');
      final repository = _BusinessIdentityRepositorySpy(failure: failure);
      final handler = LoadBusinessLogoQueryHandler(repository: repository);

      await expectLater(
        handler.execute(
          const LoadBusinessLogoQuery(managedFileName: 'logo.png'),
        ),
        throwsA(same(failure)),
      );

      expect(repository.managedFileNames, ['logo.png']);
      expect(repository.logoReads, 1);
      _expectNoWrites(repository);
    });
  });

  group('Phase 108L production composition and Dashboard App Bar', () {
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

    test('root exposes the handler from the exact captured shared repository',
        () {
      expect(
        application.dependencies.repositories.businessIdentityRepository,
        same(AppRepositories.businessIdentityRepository),
      );
      expect(AppRepositories.database, same(database));
      expect(application.queries.businessLogo,
          isA<LoadBusinessLogoQueryHandler>());

      final rootSource = File(
        'lib/composition/app_composition_root.dart',
      ).readAsStringSync();
      expect(
        rootSource,
        contains(
          'repository: dependencies.repositories.businessIdentityRepository',
        ),
      );
    });

    testWidgets(
        'valid logo resolves the query once and preserves App Bar rendering',
        (tester) async {
      final repository = _BusinessIdentityRepositorySpy(
        identity: _identityWithLogo,
        logoBytes: _pngBytes,
      );
      final controllers = await _controllersFor(repository);
      addTearDown(controllers.dispose);

      await tester.pumpWidget(
        _dashboardHarness(
          application: _withBusinessLogoHandler(application, repository),
          auth: controllers.auth,
          identity: controllers.identity,
        ),
      );
      await _pumpDashboard(tester);

      final logoFinder = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is MemoryImage,
      );
      expect(logoFinder, findsOneWidget);
      final image = tester.widget<Image>(logoFinder);
      expect((image.image as MemoryImage).bytes, same(_pngBytes));
      expect(image.fit, BoxFit.contain);
      expect(
        tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox)).any(
              (box) =>
                  box.constraints.maxHeight == 32 &&
                  box.constraints.maxWidth == 80,
            ),
        isTrue,
      );
      expect(repository.managedFileNames, ['logo.png']);
      expect(repository.logoReads, 1);
      expect(find.text('مخازن 108L · الرئيسية'), findsOneWidget);
      expect(tester.takeException(), isNull);
      _expectNoWrites(repository);
    });

    testWidgets('loading and successful completion continue to render quietly',
        (tester) async {
      final completion = Completer<Uint8List?>();
      final repository = _BusinessIdentityRepositorySpy(
        identity: _identityWithLogo,
        logoFuture: completion.future,
      );
      final controllers = await _controllersFor(repository);
      addTearDown(controllers.dispose);

      await tester.pumpWidget(
        _dashboardHarness(
          application: _withBusinessLogoHandler(application, repository),
          auth: controllers.auth,
          identity: controllers.identity,
        ),
      );
      await tester.pump();

      expect(find.byType(RawImage), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      expect(repository.logoReads, 1);

      completion.complete(_pngBytes);
      await _pumpDashboard(tester);

      expect(find.byType(RawImage), findsOneWidget);
      expect(repository.logoReads, 1);
      expect(tester.takeException(), isNull);
      _expectNoWrites(repository);
    });

    testWidgets('missing logo bytes and read failure remain hidden',
        (tester) async {
      for (final failure in <Object?>[
        null,
        StateError('hidden logo read failure'),
      ]) {
        final repository = _BusinessIdentityRepositorySpy(
          identity: _identityWithLogo,
          failure: failure,
        );
        final controllers = await _controllersFor(repository);

        await tester.pumpWidget(
          _dashboardHarness(
            application: _withBusinessLogoHandler(application, repository),
            auth: controllers.auth,
            identity: controllers.identity,
          ),
        );
        await _pumpDashboard(tester);

        expect(find.byType(RawImage), findsNothing);
        expect(find.textContaining('hidden logo read failure'), findsNothing);
        expect(repository.logoReads, 1);
        expect(tester.takeException(), isNull);
        _expectNoWrites(repository);
        controllers.dispose();
      }
    });

    testWidgets('invalid image bytes retain the silent image-error fallback',
        (tester) async {
      final repository = _BusinessIdentityRepositorySpy(
        identity: _identityWithLogo,
        logoBytes: Uint8List.fromList([1, 2, 3]),
      );
      final controllers = await _controllersFor(repository);
      addTearDown(controllers.dispose);

      await tester.pumpWidget(
        _dashboardHarness(
          application: _withBusinessLogoHandler(application, repository),
          auth: controllers.auth,
          identity: controllers.identity,
        ),
      );
      await _pumpDashboard(tester);

      expect(find.byType(RawImage), findsNothing);
      expect(repository.logoReads, 1);
      expect(tester.takeException(), isNull);
      _expectNoWrites(repository);
    });

    testWidgets(
        'absent logo metadata stays scope-independent and makes no read',
        (tester) async {
      final repository = _BusinessIdentityRepositorySpy(
        identity: const BusinessIdentity(establishmentName: 'No logo'),
      );
      final controllers = await _controllersFor(repository);
      addTearDown(controllers.dispose);

      await tester.pumpWidget(
        BusinessIdentityScope(
          controller: controllers.identity,
          child: AuthScope(
            controller: controllers.auth,
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('ar'),
              home: const DashboardShell(),
            ),
          ),
        ),
      );
      await _pumpDashboard(tester);

      expect(repository.logoReads, 0);
      expect(find.byType(RawImage), findsNothing);
      expect(tester.takeException(), isNull);
      _expectNoWrites(repository);
    });
  });

  group('Phase 108L ownership and singular-scope guards', () {
    test('handler is read-only and free of locator or concrete infrastructure',
        () {
      final source = File(
        'lib/application/queries/load_business_logo_query.dart',
      ).readAsStringSync();

      expect(source, contains('BusinessIdentityRepository _repository'));
      expect(
        source,
        contains('_repository.loadLogoBytes(query.managedFileName)'),
      );
      expect(source, isNot(contains('app_repositories.dart')));
      expect(source, isNot(contains('AppRepositories')));
      expect(source, isNot(contains('dart:io')));
      expect(source, isNot(contains('File(')));
      expect(source, isNot(contains('FoundationDatabase')));
      expect(source, isNot(contains('Drift')));
      expect(source, isNot(contains('SQLite')));
      expect(source, isNot(contains('Supabase')));
      expect(source, isNot(contains('BusinessContext')));
      expect(source, isNot(contains('SessionContext')));
      for (final writeToken in [
        'saveIdentity',
        'saveLogoBytes',
        'deleteLogoFile',
        '.write',
        '.delete',
      ]) {
        expect(source, isNot(contains(writeToken)));
      }
    });

    test('only Dashboard App Bar moves and all other logo reads remain', () {
      final dashboard = File(
        'lib/features/dashboard/dashboard_shell.dart',
      ).readAsStringSync();
      expect(
        dashboard,
        matches(
          RegExp(
            r'ApplicationScope\.of\(context\)\s*\.queries\s*\.businessLogo',
          ),
        ),
      );
      expect(dashboard, contains('LoadBusinessLogoQuery('));
      expect(dashboard, isNot(contains('app_repositories.dart')));
      expect(dashboard, isNot(contains('AppRepositories')));
      expect(dashboard, isNot(contains('loadLogoBytes(')));
      expect(dashboard, isNot(contains('LoadBusinessLogoQueryHandler(')));
      expect(dashboard, isNot(contains('FoundationDatabase')));
      expect(dashboard, isNot(contains('Drift')));
      expect(dashboard, isNot(contains('Supabase')));

      expect(_logoReadFiles(), {
        'lib/application/queries/load_business_logo_query.dart',
        'lib/core/backup/backup_export.dart',
        'lib/core/business_identity/business_identity_repository.dart',
        'lib/features/exports/pdf_export_service.dart',
        'lib/features/financial_reports/account_balance_report_screen.dart',
        'lib/features/financial_reports/account_statement_report_screen.dart',
        'lib/features/financial_reports/advances_and_refunds_report_screen.dart',
        'lib/features/financial_reports/expense_analysis_report_screen.dart',
        'lib/features/financial_reports/inflows_report_screen.dart',
        'lib/features/financial_reports/outflows_report_screen.dart',
        'lib/features/financial_reports/payment_method_report_screen.dart',
        'lib/features/financial_reports/transfer_report_screen.dart',
        'lib/features/prints/printable_document_scaffold.dart',
      });
    });

    test('exactly four concrete typed query slices exist', () {
      final queryFiles = Directory('lib/application/queries')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('_query.dart'))
          .where((file) => !file.path.endsWith('application_query.dart'))
          .where((file) {
            final source = file.readAsStringSync();
            return source.contains('implements') &&
                source.contains('ApplicationQueryHandler<');
          })
          .map((file) => _normalizedLibPath(file.path))
          .toSet();

      expect(queryFiles, {
        'lib/application/queries/load_audit_logs_query.dart',
        'lib/application/queries/load_business_logo_query.dart',
        'lib/application/queries/load_document_history_query.dart',
        'lib/application/queries/load_product_catalog_query.dart',
      });
    });
  });
}

void _expectManagedFileMetadata(LocalQueryResultMetadata metadata) {
  expect(metadata.source, QueryResultSource.local);
  expect(metadata.readAuthority, LocalReadAuthority.managedFile);
  expect(metadata.consistency, LocalQueryConsistency.currentKnownState);
}

void _expectNoWrites(_BusinessIdentityRepositorySpy repository) {
  expect(repository.identityWrites, 0);
  expect(repository.logoWrites, 0);
  expect(repository.logoDeletes, 0);
}

ApplicationBoundary _withBusinessLogoHandler(
  ApplicationBoundary application,
  BusinessIdentityRepository repository,
) {
  return ApplicationBoundary(
    dependencies: application.dependencies,
    commands: application.commands,
    queries: ApplicationQueries(
      auditLogs: application.queries.auditLogs,
      businessLogo: LoadBusinessLogoQueryHandler(repository: repository),
      documentHistory: application.queries.documentHistory,
      productCatalog: application.queries.productCatalog,
    ),
  );
}

Widget _dashboardHarness({
  required ApplicationBoundary application,
  required AuthController auth,
  required BusinessIdentityController identity,
}) {
  return ApplicationScope(
    application: application,
    child: BusinessIdentityScope(
      controller: identity,
      child: AuthScope(
        controller: auth,
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('ar'),
          home: const DashboardShell(),
        ),
      ),
    ),
  );
}

Future<void> _pumpDashboard(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<_DashboardControllers> _controllersFor(
  _BusinessIdentityRepositorySpy repository,
) async {
  final auth = AuthController(repository: LocalAuthRepository.demo());
  final identity = BusinessIdentityController(repository: repository);
  await auth.initialize();
  await auth.signIn(phone: '01100000000', password: 'employee123');
  await identity.initialize();
  return _DashboardControllers(auth: auth, identity: identity);
}

Set<String> _logoReadFiles() {
  return Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) => RegExp(
            r'(^|[^_])loadLogoBytes\(',
          ).hasMatch(file.readAsStringSync()))
      .map((file) => _normalizedLibPath(file.path))
      .toSet();
}

String _normalizedLibPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.substring(normalized.indexOf('lib/'));
}

final class _DashboardControllers {
  const _DashboardControllers({required this.auth, required this.identity});

  final AuthController auth;
  final BusinessIdentityController identity;

  void dispose() {
    auth.dispose();
    identity.dispose();
  }
}

final class _BusinessIdentityRepositorySpy
    implements BusinessIdentityRepository {
  _BusinessIdentityRepositorySpy({
    this.identity = BusinessIdentity.empty,
    this.logoBytes,
    this.logoFuture,
    this.failure,
  });

  final BusinessIdentity identity;
  final Uint8List? logoBytes;
  final Future<Uint8List?>? logoFuture;
  final Object? failure;
  int logoReads = 0;
  int identityWrites = 0;
  int logoWrites = 0;
  int logoDeletes = 0;
  final List<String> managedFileNames = [];

  @override
  Future<BusinessIdentity> loadIdentity() async => identity;

  @override
  Future<Uint8List?> loadLogoBytes(String managedFileName) async {
    logoReads++;
    managedFileNames.add(managedFileName);
    final error = failure;
    if (error != null) throw error;
    final pending = logoFuture;
    if (pending != null) return pending;
    return logoBytes;
  }

  @override
  Future<void> saveIdentity(BusinessIdentity identity) async {
    identityWrites++;
  }

  @override
  Future<LogoMetadata?> saveLogoBytes(Uint8List bytes, String mimeType) async {
    logoWrites++;
    return null;
  }

  @override
  Future<void> deleteLogoFile(String managedFileName) async {
    logoDeletes++;
  }

  @override
  String get managedLogosDirectory => '';
}

const _identityWithLogo = BusinessIdentity(
  establishmentName: 'مخازن 108L',
  logo: LogoMetadata(
    managedFileName: 'logo.png',
    mimeType: 'image/png',
    sha256: 'phase-108l-logo',
    byteLength: 68,
    width: 1,
    height: 1,
  ),
);

final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

final class _TrialEvaluatorStub implements TrialEvaluator {
  @override
  Future<TrialEvaluation> evaluate() async =>
      TrialEvaluation.blocked(TrialAccessStatus.invalidState);
}
