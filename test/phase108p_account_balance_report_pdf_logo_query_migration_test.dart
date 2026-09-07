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
import 'package:grain_warehouse_erp_lite/features/financial_reports/account_balance_report_screen.dart';

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

  group('Phase 108P account-balance PDF logo query migration', () {
    test('existing query preserves present byte identity', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final repository = _QueryBusinessIdentityRepositorySpy(logoBytes: bytes);
      final result =
          await LoadBusinessLogoQueryHandler(repository: repository).execute(
        const LoadBusinessLogoQuery(
          managedFileName: 'phase-108p-logo.png',
        ),
      );

      expect(result.value, same(bytes));
      expect(repository.logoReads, 1);
      expect(repository.managedFileNames, ['phase-108p-logo.png']);
    });

    testWidgets(
        'valid metadata loads identity through locator and exact logo through query once',
        (tester) async {
      final locatorRepository = _LocatorBusinessIdentityRepositorySpy(
        identity: _identityWithLogo,
      );
      final queryRepository = _QueryBusinessIdentityRepositorySpy(
        failure: StateError('intentional Phase 108P seam stop'),
      );

      await _pumpReport(
        tester,
        locatorRepository: locatorRepository,
        application: _withBusinessLogoHandler(
          baseApplication,
          queryRepository,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('PDF'));
      await tester.pump();

      expect(locatorRepository.identityReads, 1);
      expect(locatorRepository.directLogoReads, 0);
      expect(queryRepository.logoReads, 1);
      expect(queryRepository.managedFileNames, ['phase-108p-logo.png']);
      _expectNoWrites(locatorRepository, queryRepository);
    });

    testWidgets('absent metadata performs no scope lookup or logo read',
        (tester) async {
      final locatorRepository = _LocatorBusinessIdentityRepositorySpy(
        identity: BusinessIdentity.empty,
      );

      await _pumpReport(tester, locatorRepository: locatorRepository);
      await tester.pumpAndSettle();
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
      await tester.pumpAndSettle();
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
        failure: StateError('phase 108P query failure'),
      );

      await _pumpReport(
        tester,
        locatorRepository: locatorRepository,
        application: _withBusinessLogoHandler(
          baseApplication,
          queryRepository,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('PDF'));
      await tester.pump();

      expect(find.text('تعذر إنشاء ملف PDF.'), findsOneWidget);
      expect(find.textContaining('phase 108P query failure'), findsNothing);
      expect(locatorRepository.identityReads, 1);
      expect(locatorRepository.directLogoReads, 0);
      expect(queryRepository.logoReads, 1);
      expect(queryRepository.managedFileNames, ['phase-108p-logo.png']);
      _expectNoWrites(locatorRepository, queryRepository);
    });
  });

  group('Phase 108P source and architecture guards', () {
    test('only the selected export block moves to the existing query', () {
      final source = File(
        'lib/features/financial_reports/account_balance_report_screen.dart',
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
        'FinancialReportPdfBuilder.buildAccountBalanceReport',
      );
      expect(earlyReturn, greaterThanOrEqualTo(0));
      expect(earlyReturn, lessThan(identityRead));
      expect(identityRead, lessThan(validLogoGate));
      expect(validLogoGate, lessThan(queryLookup));
      expect(queryLookup, lessThan(builderCall));

      for (final writeToken in [
        'saveIdentity',
        'saveLogoBytes',
        'deleteLogoFile',
      ]) {
        expect(target, isNot(contains(writeToken)));
      }
    });

    test('live inventory contains exactly the Phase 108P delta', () {
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
          'lib/features/financial_reports/account_balance_report_screen.dart';

      expect(featureSharedReferences, 133);
      expect(locatorFiles, hasLength(36));
      expect(allLibReferences, 151);
      expect(scopeConsumers, hasLength(18));
      expect(normalizedLocatorFiles, contains(target));
      expect(normalizedScopeFiles, contains(target));
      expect(_logoReadFiles(), isNot(contains(target)));
      const phase108qTarget =
          'lib/features/financial_reports/account_statement_report_screen.dart';
      expect(normalizedLocatorFiles, contains(phase108qTarget));
      expect(normalizedScopeFiles, contains(phase108qTarget));
      expect(_logoReadFiles(), isNot(contains(phase108qTarget)));
    });
  });
}

Future<void> _pumpReport(
  WidgetTester tester, {
  required _LocatorBusinessIdentityRepositorySpy locatorRepository,
  ApplicationBoundary? application,
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
      home: const AccountBalanceReportScreen(),
    ),
  );
  if (application != null) {
    child = ApplicationScope(application: application, child: child);
  }
  await tester.pumpWidget(child);
}

void _failPdfAssetLoads() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(
    'flutter/assets',
    (_) async => null,
  );
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

String _normalizedPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.substring(normalized.indexOf('lib/'));
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

const _identityWithLogo = BusinessIdentity(
  establishmentName: 'Phase 108P warehouse',
  logo: LogoMetadata(
    managedFileName: 'phase-108p-logo.png',
    mimeType: 'image/png',
    sha256: 'phase-108p-logo',
    byteLength: 3,
    width: 1,
    height: 1,
  ),
);

const _identityWithInvalidLogo = BusinessIdentity(
  establishmentName: 'Phase 108P invalid logo',
  logo: LogoMetadata(
    managedFileName: '',
    mimeType: 'image/png',
    sha256: 'phase-108p-invalid-logo',
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
