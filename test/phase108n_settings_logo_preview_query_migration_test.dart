import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/application/application_boundary.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_business_logo_query.dart';
import 'package:grain_warehouse_erp_lite/composition/app_composition_root.dart';
import 'package:grain_warehouse_erp_lite/composition/application_scope.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_controller.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme_mode.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme_preset.dart';
import 'package:grain_warehouse_erp_lite/core/theme/theme_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/theme_settings_repository.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_service.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_state.dart';
import 'package:grain_warehouse_erp_lite/features/settings/settings_screen.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

void main() {
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

  group('Phase 108N Settings logo preview query migration', () {
    testWidgets(
        'target preview and shared header each query the exact filename once',
        (tester) async {
      final repository = _BusinessIdentityRepositorySpy(
        identity: _identityWithLogo,
        logoBytes: _pngBytes,
      );

      await _pumpSettings(
        tester,
        repository: repository,
        application: _withBusinessLogoHandler(baseApplication, repository),
      );
      await tester.pumpAndSettle();

      final logoCard = find.ancestor(
        of: find.text('شعار المنشأة'),
        matching: find.byType(PremiumCard),
      );
      final targetImage = find.descendant(
        of: logoCard,
        matching: find.byWidgetPredicate(
          (widget) => widget is Image && widget.image is MemoryImage,
        ),
      );
      expect(targetImage, findsOneWidget);
      final image = tester.widget<Image>(targetImage);
      expect((image.image as MemoryImage).bytes, same(_pngBytes));
      expect(image.fit, BoxFit.contain);
      final constrainedContainer = find.descendant(
        of: logoCard,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.constraints?.maxHeight == 80 &&
              widget.constraints?.maxWidth == 200,
        ),
      );
      expect(constrainedContainer, findsOneWidget);
      final constraints =
          tester.widget<Container>(constrainedContainer).constraints!;
      expect(constraints.maxHeight, 80);
      expect(constraints.maxWidth, 200);

      expect(find.byType(Image), findsNWidgets(2));
      expect(repository.managedFileNames, [
        'phase-108n-logo.png',
        'phase-108n-logo.png',
      ]);
      expect(repository.logoReads, 2);
      _expectNoWrites(repository);
    });

    testWidgets('loading remains silent for both independent renderers',
        (tester) async {
      final completion = Completer<Uint8List?>();
      final repository = _BusinessIdentityRepositorySpy(
        identity: _identityWithLogo,
        logoFuture: completion.future,
      );

      await _pumpSettings(
        tester,
        repository: repository,
        application: _withBusinessLogoHandler(baseApplication, repository),
      );
      await tester.pump();

      expect(find.byType(Image), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(repository.logoReads, 2);
      _expectNoWrites(repository);

      completion.complete(null);
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('missing managed logo remains silent', (tester) async {
      final repository = _BusinessIdentityRepositorySpy(
        identity: _identityWithLogo,
      );

      await _pumpSettings(
        tester,
        repository: repository,
        application: _withBusinessLogoHandler(baseApplication, repository),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
      expect(repository.logoReads, 2);
      expect(tester.takeException(), isNull);
      _expectNoWrites(repository);
    });

    testWidgets('thrown query failure remains silent', (tester) async {
      final repository = _BusinessIdentityRepositorySpy(
        identity: _identityWithLogo,
        failure: StateError('hidden phase 108N logo failure'),
      );

      await _pumpSettings(
        tester,
        repository: repository,
        application: _withBusinessLogoHandler(baseApplication, repository),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
      expect(find.textContaining('hidden phase 108N'), findsNothing);
      expect(repository.logoReads, 2);
      expect(tester.takeException(), isNull);
      _expectNoWrites(repository);
    });

    testWidgets('invalid image bytes retain the silent Image.memory fallback',
        (tester) async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final repository = _BusinessIdentityRepositorySpy(
        identity: _identityWithLogo,
        logoBytes: bytes,
      );

      await _pumpSettings(
        tester,
        repository: repository,
        application: _withBusinessLogoHandler(baseApplication, repository),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNWidgets(2));
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        expect(image.image, isA<MemoryImage>());
        expect((image.image as MemoryImage).bytes, same(bytes));
        expect(image.errorBuilder, isNotNull);
      }
      expect(repository.logoReads, 2);
      expect(tester.takeException(), isNull);
      _expectNoWrites(repository);
    });

    testWidgets('absent metadata needs no ApplicationScope and makes no read',
        (tester) async {
      final repository = _BusinessIdentityRepositorySpy(
        identity: BusinessIdentity.empty,
      );

      await _pumpSettings(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
      expect(repository.logoReads, 0);
      expect(repository.managedFileNames, isEmpty);
      expect(tester.takeException(), isNull);
      _expectNoWrites(repository);
    });

    testWidgets('invalid metadata needs no ApplicationScope and makes no read',
        (tester) async {
      final repository = _BusinessIdentityRepositorySpy(
        identity: _identityWithInvalidLogo,
      );

      await _pumpSettings(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
      expect(repository.logoReads, 0);
      expect(repository.managedFileNames, isEmpty);
      expect(tester.takeException(), isNull);
      _expectNoWrites(repository);
    });
  });

  group('Phase 108N source and live inventory guards', () {
    test('target preview uses only the existing application query boundary',
        () {
      final settingsSource = File(
        'lib/features/settings/settings_screen.dart',
      ).readAsStringSync();
      final targetStart = settingsSource.indexOf('class _LogoPreview');
      final targetEnd = settingsSource.indexOf(
        'class _ProfileDetailsSection',
        targetStart,
      );
      final target = settingsSource.substring(targetStart, targetEnd);

      expect(settingsSource, contains('load_business_logo_query.dart'));
      expect(settingsSource, contains('application_scope.dart'));
      expect(target, contains('future: _loadLogoBytes(context)'));
      expect(
        target,
        matches(
          RegExp(
            r'ApplicationScope\.of\(context\)\s*\.queries\s*\.businessLogo\s*\.execute\s*\(\s*LoadBusinessLogoQuery\s*\(',
          ),
        ),
      );
      expect(target, contains('managedFileName: managedFileName'));
      expect(target, contains('return result.value;'));
      expect(target, isNot(contains('AppRepositories')));
      expect(target, isNot(contains('.loadLogoBytes(')));
      expect(target, isNot(contains('LoadBusinessLogoQueryHandler(')));
      expect(target, isNot(contains('LocalBusinessIdentityRepository')));
      expect(target, isNot(contains('dart:io')));
      expect(target.toLowerCase(), isNot(contains('database')));
      expect(target.toLowerCase(), isNot(contains('drift')));
      expect(target.toLowerCase(), isNot(contains('supabase')));
      expect(target.toLowerCase(), isNot(contains('cloud')));
      for (final writeToken in [
        'saveIdentity',
        'saveLogoBytes',
        'deleteLogoFile',
      ]) {
        expect(target, isNot(contains(writeToken)));
      }

      final shortCircuit = target.indexOf(
        'if (managedFileName.isEmpty) return null;',
      );
      final queryLookup = target.indexOf('ApplicationScope.of(context)');
      expect(shortCircuit, greaterThanOrEqualTo(0));
      expect(shortCircuit, lessThan(queryLookup));

      expect(settingsSource, contains('controller.saveLogo'));
      expect(settingsSource, contains('identityController.removeLogo'));
      expect(settingsSource, contains('identityController.saveProfileDetails'));
    });

    test('live locator and scope inventories reflect exactly one migration',
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
      final normalizedLocatorFiles =
          locatorFiles.map((file) => _normalizedPath(file.path)).toSet();
      final normalizedScopeFiles =
          scopeConsumers.map((file) => _normalizedPath(file.path)).toSet();

      expect(featureSharedReferences, 133);
      expect(locatorFiles, hasLength(36));
      expect(allLibReferences, 149);
      expect(scopeConsumers, hasLength(17));
      expect(
        normalizedLocatorFiles,
        contains(
          'lib/features/financial_reports/account_balance_report_screen.dart',
        ),
      );
      expect(
        normalizedScopeFiles,
        contains(
          'lib/features/financial_reports/account_balance_report_screen.dart',
        ),
      );
      expect(
        normalizedLocatorFiles,
        contains(
          'lib/features/financial_reports/account_statement_report_screen.dart',
        ),
      );
      expect(
        normalizedScopeFiles,
        contains(
          'lib/features/financial_reports/account_statement_report_screen.dart',
        ),
      );
      expect(
        normalizedLocatorFiles,
        isNot(contains('lib/features/settings/settings_screen.dart')),
      );
      expect(
        normalizedScopeFiles,
        contains('lib/features/settings/settings_screen.dart'),
      );
      expect(
        normalizedLocatorFiles,
        isNot(contains(
          'lib/features/prints/printable_document_scaffold.dart',
        )),
      );
      expect(
        normalizedScopeFiles,
        contains('lib/features/prints/printable_document_scaffold.dart'),
      );
    });
  });
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  required _BusinessIdentityRepositorySpy repository,
  ApplicationBoundary? application,
}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 2600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final identityController = BusinessIdentityController(repository: repository);
  final themeController = ThemeController(repository: _ThemeRepositoryStub());
  await identityController.initialize();
  await themeController.initialize();
  addTearDown(identityController.dispose);
  addTearDown(themeController.dispose);

  Widget child = MaterialApp(
    home: Scaffold(
      body: BusinessIdentityScope(
        controller: identityController,
        child: const SettingsScreen(),
      ),
    ),
  );
  child = ThemeScope(controller: themeController, child: child);
  if (application != null) {
    child = ApplicationScope(application: application, child: child);
  }
  await tester.pumpWidget(child);
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

List<File> _dartFilesUnder(List<Directory> roots) {
  return roots
      .expand((root) => root.listSync(recursive: true).whereType<File>())
      .where((file) => file.path.endsWith('.dart'))
      .toList();
}

String _normalizedPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.substring(normalized.indexOf('lib/'));
}

final class _BusinessIdentityRepositorySpy
    implements BusinessIdentityRepository {
  _BusinessIdentityRepositorySpy({
    required this.identity,
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

final class _ThemeRepositoryStub implements ThemeSettingsRepository {
  @override
  Future<AppThemeSettings> loadSettings() async => const AppThemeSettings(
        mode: AppThemeMode.system,
        preset: AppThemePreset.olive,
      );

  @override
  Future<void> saveSettings(AppThemeSettings settings) async {}
}

const _identityWithLogo = BusinessIdentity(
  establishmentName: 'Phase 108N',
  logo: LogoMetadata(
    managedFileName: 'phase-108n-logo.png',
    mimeType: 'image/png',
    sha256: 'phase-108n-logo',
    byteLength: 68,
    width: 1,
    height: 1,
  ),
);

const _identityWithInvalidLogo = BusinessIdentity(
  establishmentName: 'Phase 108N invalid',
  logo: LogoMetadata(
    managedFileName: '',
    mimeType: 'image/png',
    sha256: 'phase-108n-invalid-logo',
    byteLength: 1,
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
