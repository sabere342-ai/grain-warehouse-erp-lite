import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/application/application_boundary.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_business_logo_query.dart';
import 'package:grain_warehouse_erp_lite/composition/app_composition_root.dart';
import 'package:grain_warehouse_erp_lite/composition/application_scope.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_service.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_state.dart';
import 'package:grain_warehouse_erp_lite/features/financial_reports/payment_method_report_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FoundationDatabase database;
  late ApplicationBoundary baseApplication;

  setUpAll(() async {
    database = openInMemoryTestDatabase();
    baseApplication = await AppCompositionRoot.initializeProduction(
      databaseFactory: () async => database,
      trialEvaluator: _TrialEvaluatorStub(),
    );
  });

  tearDownAll(() async {
    final runtime = baseApplication.dependencies.runtime;
    runtime.authController.dispose();
    runtime.themeController.dispose();
    runtime.businessIdentityController.dispose();
    await AppCompositionRoot.close();
  });

  group('Phase 108R payment-method PDF logo query migration', () {
    testWidgets('without a loaded report the PDF action remains disabled',
        (tester) async {
      final locatorRepository = _LocatorBusinessIdentityRepositorySpy(
        identity: _identityWithLogo,
      );
      final queryRepository = _QueryBusinessIdentityRepositorySpy();

      await _pumpReport(
        tester,
        locatorRepository: locatorRepository,
        application: _withBusinessLogoHandler(
          baseApplication,
          queryRepository,
        ),
        loadReport: false,
      );

      final button = tester.widget<OutlinedButton>(_pdfButtonFinder());
      expect(button.onPressed, isNull);
      expect(locatorRepository.identityReads, 0);
      expect(locatorRepository.directLogoReads, 0);
      expect(queryRepository.logoReads, 0);
      _expectNoWrites(locatorRepository, queryRepository);

      await tester.pumpAndSettle();
    });

    test('existing query preserves present byte identity', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final repository = _QueryBusinessIdentityRepositorySpy(logoBytes: bytes);
      final result =
          await LoadBusinessLogoQueryHandler(repository: repository).execute(
        const LoadBusinessLogoQuery(managedFileName: _managedFileName),
      );

      expect(result.value, same(bytes));
      expect(repository.logoReads, 1);
      expect(repository.managedFileNames, [_managedFileName]);
    });

    test('existing query preserves empty byte identity', () async {
      final bytes = Uint8List(0);
      final repository = _QueryBusinessIdentityRepositorySpy(logoBytes: bytes);
      final result =
          await LoadBusinessLogoQueryHandler(repository: repository).execute(
        const LoadBusinessLogoQuery(managedFileName: _managedFileName),
      );

      expect(result.value, same(bytes));
      expect(result.value, isEmpty);
      expect(repository.logoReads, 1);
      expect(repository.managedFileNames, [_managedFileName]);
    });

    test('existing query preserves repository null', () async {
      final repository = _QueryBusinessIdentityRepositorySpy();
      final result =
          await LoadBusinessLogoQueryHandler(repository: repository).execute(
        const LoadBusinessLogoQuery(managedFileName: _managedFileName),
      );

      expect(result.value, isNull);
      expect(repository.logoReads, 1);
      expect(repository.managedFileNames, [_managedFileName]);
    });

    testWidgets('valid metadata loads locator identity before exact query once',
        (tester) async {
      final events = <String>[];
      final locatorRepository = _LocatorBusinessIdentityRepositorySpy(
        identity: _identityWithLogo,
        events: events,
      );
      final queryRepository = _QueryBusinessIdentityRepositorySpy(
        failure: StateError('intentional Phase 108R seam stop'),
        events: events,
      );

      await _pumpReport(
        tester,
        locatorRepository: locatorRepository,
        application: _withBusinessLogoHandler(
          baseApplication,
          queryRepository,
        ),
      );
      await tester.tap(find.text('PDF'));
      await tester.pump();

      expect(locatorRepository.identityReads, 1);
      expect(locatorRepository.directLogoReads, 0);
      expect(queryRepository.logoReads, 1);
      expect(queryRepository.managedFileNames, [_managedFileName]);
      expect(events, ['identity', 'query:$_managedFileName']);
      _expectNoWrites(locatorRepository, queryRepository);
    });

    testWidgets('absent metadata performs no scope lookup or logo read',
        (tester) async {
      final locatorRepository = _LocatorBusinessIdentityRepositorySpy(
        identity: BusinessIdentity.empty,
      );

      await _pumpReport(tester, locatorRepository: locatorRepository);
      _failPdfAssetLoads();
      await tester.tap(find.text('PDF'));
      await tester.pump();

      expect(locatorRepository.identityReads, 1);
      expect(locatorRepository.directLogoReads, 0);
      expect(tester.takeException(), isNull);
      expect(locatorRepository.identityWrites, 0);
      expect(locatorRepository.logoWrites, 0);
      expect(locatorRepository.logoDeletes, 0);
    });

    testWidgets('invalid metadata performs no scope lookup or logo read',
        (tester) async {
      final locatorRepository = _LocatorBusinessIdentityRepositorySpy(
        identity: _identityWithInvalidLogo,
      );

      await _pumpReport(tester, locatorRepository: locatorRepository);
      _failPdfAssetLoads();
      await tester.tap(find.text('PDF'));
      await tester.pump();

      expect(locatorRepository.identityReads, 1);
      expect(locatorRepository.directLogoReads, 0);
      expect(tester.takeException(), isNull);
      expect(locatorRepository.identityWrites, 0);
      expect(locatorRepository.logoWrites, 0);
      expect(locatorRepository.logoDeletes, 0);
    });

    testWidgets('query failure retains the existing PDF failure snackbar',
        (tester) async {
      final locatorRepository = _LocatorBusinessIdentityRepositorySpy(
        identity: _identityWithLogo,
      );
      final queryRepository = _QueryBusinessIdentityRepositorySpy(
        failure: StateError('phase 108R query failure'),
      );

      await _pumpReport(
        tester,
        locatorRepository: locatorRepository,
        application: _withBusinessLogoHandler(
          baseApplication,
          queryRepository,
        ),
      );
      await tester.tap(find.text('PDF'));
      await tester.pump();

      expect(find.text('تعذر إنشاء ملف PDF.'), findsOneWidget);
      expect(find.textContaining('phase 108R query failure'), findsNothing);
      expect(locatorRepository.identityReads, 1);
      expect(locatorRepository.directLogoReads, 0);
      expect(queryRepository.logoReads, 1);
      expect(queryRepository.managedFileNames, [_managedFileName]);
      _expectNoWrites(locatorRepository, queryRepository);
    });
  });

  group('Phase 108R source and architecture guards', () {
    test('only the selected export block moves to the existing query', () {
      final source = File(
        'lib/features/financial_reports/payment_method_report_screen.dart',
      ).readAsStringSync();
      final targetStart = source.indexOf('Future<void> _exportPdf()');
      final targetEnd =
          source.indexOf('Future<void> _exportCsv()', targetStart);
      final target = source.substring(targetStart, targetEnd);

      expect(source, contains('load_business_logo_query.dart'));
      expect(source, contains('application_scope.dart'));
      expect(
        target,
        contains(
          'await AppRepositories.businessIdentityRepository.loadIdentity()',
        ),
      );
      expect(target, contains('identity.hasLogo && identity.logo != null'));
      expect(
        target,
        matches(
          RegExp(
            r'ApplicationScope\.of\(context\)\s*\.queries\s*\.businessLogo\s*\.execute\s*\(\s*LoadBusinessLogoQuery\s*\(',
          ),
        ),
      );
      expect(
        target,
        contains('managedFileName: identity.logo!.managedFileName'),
      );
      expect(target, contains('logoBytes = result.value;'));
      expect(target, isNot(contains('.loadLogoBytes(')));
      expect(target, isNot(contains('LoadBusinessLogoQueryHandler(')));
      expect(target, contains('report: _report!'));
      expect(target, contains('businessIdentity: identity'));
      expect(target, contains('logoBytes: logoBytes'));
      expect(target, contains('await _showExportResult(file);'));
      expect(target, contains("content: Text('تعذر إنشاء ملف PDF.')"));

      final earlyReturn = target.indexOf('if (_report == null) return;');
      final identityRead = target.indexOf(
        'await AppRepositories.businessIdentityRepository.loadIdentity()',
      );
      final validLogoGate = target.indexOf(
        'if (identity.hasLogo && identity.logo != null)',
      );
      final queryLookup = target.indexOf('ApplicationScope.of(context)');
      final builderCall = target.indexOf(
        'FinancialReportPdfBuilder.buildPaymentMethodReport',
      );
      final resultHandler = target.indexOf('await _showExportResult(file);');
      expect(earlyReturn, greaterThanOrEqualTo(0));
      expect(earlyReturn, lessThan(identityRead));
      expect(identityRead, lessThan(validLogoGate));
      expect(validLogoGate, lessThan(queryLookup));
      expect(queryLookup, lessThan(builderCall));
      expect(builderCall, lessThan(resultHandler));

      for (final writeToken in [
        'saveIdentity',
        'saveLogoBytes',
        'deleteLogoFile',
      ]) {
        expect(target, isNot(contains(writeToken)));
      }

      expect(source, contains('canExportFinancialReports'));
      expect(
        source,
        contains('onPressed: _report != null ? _exportPdf : null'),
      );
      expect(source, contains('_service.paymentMethodReport'));
      expect(
        source,
        contains('FinancialReportCsvExporter.exportPaymentMethodReport'),
      );
      expect(source, contains('_paymentMethodFilter'));
      expect(source, contains('_sourceTypeFilter'));
      expect(source, contains('_accountIdFilter'));
      expect(source, contains('_directionFilter'));
      expect(source, contains('_expandedRows'));
    });

    test('live inventories and direct-read sets have only the Phase 108R delta',
        () {
      final featureSharedFiles = _dartFilesUnder([
        Directory('lib/features'),
        Directory('lib/shared'),
      ]);
      final allLibFiles = _dartFilesUnder([Directory('lib')]);
      final locatorPattern = RegExp(r'AppRepositories\.');
      final locatorFiles = featureSharedFiles.where((file) {
        return locatorPattern.hasMatch(file.readAsStringSync());
      }).toList();
      final scopeConsumers = featureSharedFiles.where((file) {
        return file.readAsStringSync().contains('ApplicationScope.of');
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
      final normalizedLocatorFiles =
          locatorFiles.map((file) => _normalizedPath(file.path)).toSet();
      final normalizedScopeFiles =
          scopeConsumers.map((file) => _normalizedPath(file.path)).toSet();
      const target =
          'lib/features/financial_reports/payment_method_report_screen.dart';

      expect(featureSharedReferences, 139);
      expect(locatorFiles, hasLength(36));
      expect(allLibReferences, 155);
      expect(scopeConsumers, hasLength(11));
      expect(normalizedLocatorFiles, contains(target));
      expect(normalizedScopeFiles, contains(target));
      expect(_logoReadFiles(), isNot(contains(target)));
      expect(_logoReadFiles(), {
        'lib/application/queries/load_business_logo_query.dart',
        'lib/core/backup/backup_export.dart',
        'lib/core/business_identity/business_identity_repository.dart',
        'lib/features/exports/pdf_export_service.dart',
        'lib/features/financial_reports/advances_and_refunds_report_screen.dart',
        'lib/features/financial_reports/expense_analysis_report_screen.dart',
        'lib/features/financial_reports/inflows_report_screen.dart',
        'lib/features/financial_reports/outflows_report_screen.dart',
        'lib/features/financial_reports/transfer_report_screen.dart',
      });
      expect(_logoInvocationFiles(), {
        'lib/application/queries/load_business_logo_query.dart',
        'lib/core/backup/backup_export.dart',
        'lib/features/exports/pdf_export_service.dart',
        'lib/features/financial_reports/advances_and_refunds_report_screen.dart',
        'lib/features/financial_reports/expense_analysis_report_screen.dart',
        'lib/features/financial_reports/inflows_report_screen.dart',
        'lib/features/financial_reports/outflows_report_screen.dart',
        'lib/features/financial_reports/transfer_report_screen.dart',
      });
    });
  });
}

Future<void> _pumpReport(
  WidgetTester tester, {
  required _LocatorBusinessIdentityRepositorySpy locatorRepository,
  ApplicationBoundary? application,
  bool loadReport = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final previousIdentityRepository = AppRepositories.businessIdentityRepository;
  AppRepositories.businessIdentityRepository = locatorRepository;
  addTearDown(() {
    AppRepositories.businessIdentityRepository = previousIdentityRepository;
  });

  final auth = AuthController(repository: LocalAuthRepository.demo());
  addTearDown(auth.dispose);
  await auth.initialize();
  await auth.signIn(phone: '01000000000', password: 'owner123');

  Widget child = AuthScope(
    controller: auth,
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ar'),
      builder: (context, routeChild) => Directionality(
        textDirection: TextDirection.rtl,
        child: routeChild ?? const SizedBox.shrink(),
      ),
      home: const PaymentMethodReportScreen(),
    ),
  );
  if (application != null) {
    child = ApplicationScope(application: application, child: child);
  }
  await tester.pumpWidget(child);

  if (loadReport) {
    await tester.pumpAndSettle();
    final button = tester.widget<OutlinedButton>(_pdfButtonFinder());
    expect(button.onPressed, isNotNull);
  }
}

Finder _pdfButtonFinder() {
  return find.ancestor(
    of: find.text('PDF'),
    matching: find.byWidgetPredicate((widget) => widget is OutlinedButton),
  );
}

void _failPdfAssetLoads() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (_) async => null);
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });
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

void _expectNoWrites(
  _LocatorBusinessIdentityRepositorySpy locatorRepository,
  _QueryBusinessIdentityRepositorySpy queryRepository,
) {
  expect(locatorRepository.identityWrites, 0);
  expect(locatorRepository.logoWrites, 0);
  expect(locatorRepository.logoDeletes, 0);
  expect(queryRepository.identityWrites, 0);
  expect(queryRepository.logoWrites, 0);
  expect(queryRepository.logoDeletes, 0);
}

List<File> _dartFilesUnder(List<Directory> roots) {
  return roots
      .expand((root) => root.listSync(recursive: true).whereType<File>())
      .where((file) => file.path.endsWith('.dart'))
      .toList();
}

Set<String> _logoReadFiles() {
  return Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) => RegExp(
            r'(^|[^_])loadLogoBytes\(',
          ).hasMatch(file.readAsStringSync()))
      .map((file) => _normalizedPath(file.path))
      .toSet();
}

Set<String> _logoInvocationFiles() {
  return Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) => file.readAsStringSync().contains('.loadLogoBytes('))
      .map((file) => _normalizedPath(file.path))
      .toSet();
}

String _normalizedPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.substring(normalized.indexOf('lib/'));
}

final class _LocatorBusinessIdentityRepositorySpy
    extends LocalBusinessIdentityRepository {
  _LocatorBusinessIdentityRepositorySpy({
    required this.identity,
    this.events,
  });

  final BusinessIdentity identity;
  final List<String>? events;
  int identityReads = 0;
  int directLogoReads = 0;
  int identityWrites = 0;
  int logoWrites = 0;
  int logoDeletes = 0;

  @override
  Future<BusinessIdentity> loadIdentity() async {
    identityReads++;
    events?.add('identity');
    return identity;
  }

  @override
  Future<Uint8List?> loadLogoBytes(String managedFileName) async {
    directLogoReads++;
    return null;
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
}

final class _QueryBusinessIdentityRepositorySpy
    implements BusinessIdentityRepository {
  _QueryBusinessIdentityRepositorySpy({
    this.logoBytes,
    this.failure,
    this.events,
  });

  final Uint8List? logoBytes;
  final Object? failure;
  final List<String>? events;
  int logoReads = 0;
  int identityWrites = 0;
  int logoWrites = 0;
  int logoDeletes = 0;
  final List<String> managedFileNames = [];

  @override
  Future<BusinessIdentity> loadIdentity() async => BusinessIdentity.empty;

  @override
  Future<Uint8List?> loadLogoBytes(String managedFileName) async {
    logoReads++;
    managedFileNames.add(managedFileName);
    events?.add('query:$managedFileName');
    final error = failure;
    if (error != null) throw error;
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

const _managedFileName = 'phase-108r-logo.png';

const _identityWithLogo = BusinessIdentity(
  establishmentName: 'Phase 108R warehouse',
  logo: LogoMetadata(
    managedFileName: _managedFileName,
    mimeType: 'image/png',
    sha256: 'phase-108r-logo',
    byteLength: 3,
    width: 1,
    height: 1,
  ),
);

const _identityWithInvalidLogo = BusinessIdentity(
  establishmentName: 'Phase 108R invalid logo',
  logo: LogoMetadata(
    managedFileName: '',
    mimeType: 'image/png',
    sha256: 'phase-108r-invalid-logo',
    byteLength: 1,
    width: 1,
    height: 1,
  ),
);

final class _TrialEvaluatorStub implements TrialEvaluator {
  @override
  Future<TrialEvaluation> evaluate() async =>
      TrialEvaluation.blocked(TrialAccessStatus.invalidState);
}
