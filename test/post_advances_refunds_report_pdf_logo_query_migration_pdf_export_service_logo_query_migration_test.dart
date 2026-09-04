import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/application/application_boundary.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_business_logo_query.dart';
import 'package:grain_warehouse_erp_lite/composition/app_composition_root.dart';
import 'package:grain_warehouse_erp_lite/composition/application_scope.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_models.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_service.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_state.dart';
import 'package:grain_warehouse_erp_lite/features/exports/pdf_export_service.dart';

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

  group('PDF Export Service logo query migration', () {
    testWidgets('valid PNG uses the exact canonical query and exports a PDF',
        (tester) async {
      final locatorRepository = _LocatorBusinessIdentityRepositorySpy(
        identity: _identityWithLogo,
      );
      final queryRepository = _QueryBusinessIdentityRepositorySpy(
        logoBytes: _pngBytes,
      );
      final tempDirectory = (await tester.runAsync(
        () => _prepareExport(locatorRepository: locatorRepository),
      ))!;

      final result = await _exportAccountBalance(
        tester,
        application: _withBusinessLogoHandler(
          baseApplication,
          queryRepository,
        ),
      );

      expect(result, isTrue);
      expect(_pdfFiles(tempDirectory), hasLength(1));
      expect(_pdfFiles(tempDirectory).single.lengthSync(), greaterThan(100));
      expect(locatorRepository.identityReads, 1);
      expect(locatorRepository.directLogoReads, 0);
      expect(queryRepository.logoReads, 1);
      expect(queryRepository.managedFileNames, [_managedFileName]);
      _expectNoWrites(locatorRepository, queryRepository);
    });

    testWidgets('absent and invalid metadata skip the query and still export',
        (tester) async {
      for (final identity in [
        BusinessIdentity.empty,
        _identityWithInvalidLogo
      ]) {
        final locatorRepository = _LocatorBusinessIdentityRepositorySpy(
          identity: identity,
        );
        final queryRepository = _QueryBusinessIdentityRepositorySpy(
          failure: StateError('query must not run'),
        );
        final tempDirectory = (await tester.runAsync(
          () => _prepareExport(locatorRepository: locatorRepository),
        ))!;

        final result = await _exportAccountBalance(
          tester,
          application: _withBusinessLogoHandler(
            baseApplication,
            queryRepository,
          ),
        );

        expect(result, isTrue);
        expect(_pdfFiles(tempDirectory), hasLength(1));
        expect(locatorRepository.identityReads, 1);
        expect(locatorRepository.directLogoReads, 0);
        expect(queryRepository.logoReads, 0);
        _expectNoWrites(locatorRepository, queryRepository);
      }
    });

    testWidgets('query null preserves the null-logo PDF fallback',
        (tester) async {
      final locatorRepository = _LocatorBusinessIdentityRepositorySpy(
        identity: _identityWithLogo,
      );
      final queryRepository = _QueryBusinessIdentityRepositorySpy();
      final tempDirectory = (await tester.runAsync(
        () => _prepareExport(locatorRepository: locatorRepository),
      ))!;

      final result = await _exportAccountBalance(
        tester,
        application: _withBusinessLogoHandler(
          baseApplication,
          queryRepository,
        ),
      );

      expect(result, isTrue);
      expect(_pdfFiles(tempDirectory), hasLength(1));
      expect(locatorRepository.directLogoReads, 0);
      expect(queryRepository.logoReads, 1);
      expect(queryRepository.managedFileNames, [_managedFileName]);
      _expectNoWrites(locatorRepository, queryRepository);
    });

    testWidgets('query empty bytes preserve the no-image PDF behavior',
        (tester) async {
      final locatorRepository = _LocatorBusinessIdentityRepositorySpy(
        identity: _identityWithLogo,
      );
      final queryRepository = _QueryBusinessIdentityRepositorySpy(
        logoBytes: Uint8List(0),
      );
      final tempDirectory = (await tester.runAsync(
        () => _prepareExport(locatorRepository: locatorRepository),
      ))!;

      final result = await _exportAccountBalance(
        tester,
        application: _withBusinessLogoHandler(
          baseApplication,
          queryRepository,
        ),
      );

      expect(result, isTrue);
      expect(_pdfFiles(tempDirectory), hasLength(1));
      expect(locatorRepository.directLogoReads, 0);
      expect(queryRepository.logoReads, 1);
      expect(queryRepository.managedFileNames, [_managedFileName]);
      _expectNoWrites(locatorRepository, queryRepository);
    });

    testWidgets('query failure preserves the helper PDF fallback',
        (tester) async {
      final locatorRepository = _LocatorBusinessIdentityRepositorySpy(
        identity: _identityWithLogo,
      );
      final queryRepository = _QueryBusinessIdentityRepositorySpy(
        failure: StateError('intentional PDF export logo query failure'),
      );
      final tempDirectory = (await tester.runAsync(
        () => _prepareExport(locatorRepository: locatorRepository),
      ))!;

      final result = await _exportAccountBalance(
        tester,
        application: _withBusinessLogoHandler(
          baseApplication,
          queryRepository,
        ),
      );

      expect(result, isTrue);
      expect(_pdfFiles(tempDirectory), hasLength(1));
      expect(locatorRepository.directLogoReads, 0);
      expect(queryRepository.logoReads, 1);
      expect(queryRepository.managedFileNames, [_managedFileName]);
      _expectNoWrites(locatorRepository, queryRepository);
    });

    test('source keeps all nine lookups safe and the deferred seam intact', () {
      final source = File('lib/features/exports/pdf_export_service.dart')
          .readAsStringSync();
      final backup =
          File('lib/core/backup/backup_export.dart').readAsStringSync();

      expect(source, contains('load_business_logo_query.dart'));
      expect(source, contains('application_scope.dart'));
      expect(
        RegExp(r'ApplicationScope\.of\(context\)\.queries\.businessLogo')
            .allMatches(source),
        hasLength(9),
      );
      expect(
        RegExp(r'_loadBranding\(businessLogoQuery\)').allMatches(source),
        hasLength(9),
      );
      expect(
          source, contains('LoadBusinessLogoQueryHandler businessLogoQuery'));
      expect(source, contains('businessLogoQuery.execute('));
      expect(source, contains('LoadBusinessLogoQuery('));
      expect(source, contains('logoBytes: result.value'));
      expect(
        source,
        contains(
          'await AppRepositories.businessIdentityRepository.loadIdentity()',
        ),
      );
      expect(source, contains('identity.hasLogo || identity.logo == null'));
      expect(source, isNot(contains('.loadLogoBytes(')));
      expect(backup, contains('.loadLogoBytes('));

      for (final symbol in _pdfEntryPoints) {
        final start = source.indexOf('static Future<bool> $symbol(');
        expect(start, greaterThanOrEqualTo(0), reason: symbol);
        final next = source.indexOf('static Future<', start + 1);
        final body = source.substring(start, next < 0 ? source.length : next);
        final queryLookup = body.indexOf('ApplicationScope.of(context)');
        final firstAwait = body.indexOf('await ');
        expect(queryLookup, greaterThanOrEqualTo(0), reason: symbol);
        expect(firstAwait, greaterThan(queryLookup), reason: symbol);
        expect(body, contains('_loadBranding(businessLogoQuery)'));
      }

      expect(_logoInvocationFiles(), {
        'lib/application/queries/load_business_logo_query.dart',
        'lib/core/backup/backup_export.dart',
      });
    });
  });
}

Future<Directory> _prepareExport({
  required _LocatorBusinessIdentityRepositorySpy locatorRepository,
}) async {
  final tempDirectory = await Directory.systemTemp.createTemp(
    'pdf-export-logo-query-',
  );
  addTearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(pathProviderChannel, (call) async {
    if (call.method == 'getApplicationDocumentsDirectory') {
      return tempDirectory.path;
    }
    return null;
  });
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  final previousRepository = AppRepositories.businessIdentityRepository;
  AppRepositories.businessIdentityRepository = locatorRepository;
  addTearDown(() {
    AppRepositories.businessIdentityRepository = previousRepository;
  });
  return tempDirectory;
}

Future<bool> _exportAccountBalance(
  WidgetTester tester, {
  required ApplicationBoundary application,
}) async {
  late BuildContext exportContext;
  await tester.pumpWidget(
    ApplicationScope(
      application: application,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              exportContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    ),
  );

  final result = await tester.runAsync(
    () => PdfExportService.exportAccountBalanceReport(
      exportContext,
      report: _accountBalanceReport,
    ),
  );
  await tester.pump();
  return result!;
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

List<File> _pdfFiles(Directory directory) {
  return directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.pdf'))
      .toList();
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

final class _LocatorBusinessIdentityRepositorySpy
    extends LocalBusinessIdentityRepository {
  _LocatorBusinessIdentityRepositorySpy({required this.identity});

  final BusinessIdentity identity;
  int identityReads = 0;
  int directLogoReads = 0;
  int identityWrites = 0;
  int logoWrites = 0;
  int logoDeletes = 0;

  @override
  Future<BusinessIdentity> loadIdentity() async {
    identityReads++;
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
  _QueryBusinessIdentityRepositorySpy({this.logoBytes, this.failure});

  final Uint8List? logoBytes;
  final Object? failure;
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

final _accountBalanceReport = AccountBalanceReport(
  fromDate: DateTime(2026, 9, 1),
  toDate: DateTime(2026, 9, 4),
  rows: const [],
  totalOpeningQirsh: 0,
  totalInflowsQirsh: 0,
  totalOutflowsQirsh: 0,
  totalClosingQirsh: 0,
);

const _managedFileName = 'pdf-export-service-logo.png';

const _identityWithLogo = BusinessIdentity(
  establishmentName: 'PDF Export Service warehouse',
  logo: LogoMetadata(
    managedFileName: _managedFileName,
    mimeType: 'image/png',
    sha256: 'pdf-export-service-logo-sha256',
    byteLength: 68,
    width: 1,
    height: 1,
  ),
);

const _identityWithInvalidLogo = BusinessIdentity(
  establishmentName: 'PDF Export Service invalid logo warehouse',
  logo: LogoMetadata(
    managedFileName: '',
    mimeType: 'image/png',
    sha256: 'pdf-export-service-invalid-logo',
    byteLength: 1,
    width: 1,
    height: 1,
  ),
);

final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

const _pdfEntryPoints = [
  'exportSalesInvoice',
  'exportCustomerStatement',
  'exportDailyReport',
  'exportPurchaseInvoice',
  'exportSupplierStatement',
  'exportAccountBalanceReport',
  'exportAccountStatementReport',
  'exportPaymentMethodReport',
  'exportTransferReport',
];

final class _TrialEvaluatorStub implements TrialEvaluator {
  @override
  Future<TrialEvaluation> evaluate() async =>
      TrialEvaluation.blocked(TrialAccessStatus.invalidState);
}
