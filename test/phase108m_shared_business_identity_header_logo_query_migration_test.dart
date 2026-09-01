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
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_service.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_state.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/business_identity_header.dart';

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

  group('Phase 108M shared business identity header logo query', () {
    testWidgets(
        'standard logo uses the query once and preserves bytes and layout',
        (tester) async {
      final repository = _BusinessIdentityRepositorySpy(logoBytes: _pngBytes);

      await tester.pumpWidget(
        _headerHarness(
          application: _withBusinessLogoHandler(baseApplication, repository),
          identity: _identityWithLogo,
        ),
      );
      await tester.pumpAndSettle();

      final imageFinder = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is MemoryImage,
      );
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      expect((image.image as MemoryImage).bytes, same(_pngBytes));
      expect(image.fit, BoxFit.contain);
      final constrainedBox = tester.widget<ConstrainedBox>(
        find.ancestor(
          of: imageFinder,
          matching: find.byType(ConstrainedBox),
        ),
      );
      expect(constrainedBox.constraints.maxHeight, AppIconSizes.hero);
      expect(constrainedBox.constraints.maxWidth, 120);
      expect(repository.managedFileNames, ['phase-108m-logo.png']);
      expect(repository.logoReads, 1);
      _expectNoWrites(repository);
    });

    testWidgets(
        'compact logo uses the query once and preserves bytes and layout',
        (tester) async {
      final repository = _BusinessIdentityRepositorySpy(logoBytes: _pngBytes);

      await tester.pumpWidget(
        _headerHarness(
          application: _withBusinessLogoHandler(baseApplication, repository),
          identity: _identityWithLogo,
          compact: true,
        ),
      );
      await tester.pumpAndSettle();

      final imageFinder = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is MemoryImage,
      );
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      expect((image.image as MemoryImage).bytes, same(_pngBytes));
      expect(image.fit, BoxFit.contain);
      final constrainedBox = tester.widget<ConstrainedBox>(
        find.ancestor(
          of: imageFinder,
          matching: find.byType(ConstrainedBox),
        ),
      );
      expect(constrainedBox.constraints.maxHeight, AppIconSizes.md);
      expect(constrainedBox.constraints.maxWidth, AppIconSizes.lg);
      expect(repository.managedFileNames, ['phase-108m-logo.png']);
      expect(repository.logoReads, 1);
      _expectNoWrites(repository);
    });

    testWidgets('loading remains silent', (tester) async {
      final completion = Completer<Uint8List?>();
      final repository = _BusinessIdentityRepositorySpy(
        logoFuture: completion.future,
      );

      await tester.pumpWidget(
        _headerHarness(
          application: _withBusinessLogoHandler(baseApplication, repository),
          identity: _identityWithLogo,
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(repository.logoReads, 1);
      _expectNoWrites(repository);

      completion.complete(null);
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('missing managed logo remains silent', (tester) async {
      final repository = _BusinessIdentityRepositorySpy();

      await tester.pumpWidget(
        _headerHarness(
          application: _withBusinessLogoHandler(baseApplication, repository),
          identity: _identityWithLogo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
      expect(repository.managedFileNames, ['phase-108m-logo.png']);
      expect(repository.logoReads, 1);
      expect(tester.takeException(), isNull);
      _expectNoWrites(repository);
    });

    testWidgets('thrown query failure remains silent', (tester) async {
      final repository = _BusinessIdentityRepositorySpy(
        failure: StateError('hidden phase 108M logo failure'),
      );

      await tester.pumpWidget(
        _headerHarness(
          application: _withBusinessLogoHandler(baseApplication, repository),
          identity: _identityWithLogo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
      expect(find.textContaining('hidden phase 108M'), findsNothing);
      expect(repository.logoReads, 1);
      expect(tester.takeException(), isNull);
      _expectNoWrites(repository);
    });

    testWidgets('empty managed filename makes no query and stays silent',
        (tester) async {
      final repository = _BusinessIdentityRepositorySpy();

      await tester.pumpWidget(
        _headerHarness(
          application: _withBusinessLogoHandler(baseApplication, repository),
          identity: _identityWithEmptyManagedFileName,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
      expect(repository.logoReads, 0);
      expect(repository.managedFileNames, isEmpty);
      expect(tester.takeException(), isNull);
      _expectNoWrites(repository);
    });

    testWidgets('empty and invalid returned bytes retain Image.memory fallback',
        (tester) async {
      for (final bytes in <Uint8List>[
        Uint8List(0),
        Uint8List.fromList([1, 2, 3]),
      ]) {
        final repository = _BusinessIdentityRepositorySpy(logoBytes: bytes);

        await tester.pumpWidget(
          _headerHarness(
            application: _withBusinessLogoHandler(baseApplication, repository),
            identity: _identityWithLogo,
          ),
        );
        await tester.pumpAndSettle();

        final imageFinder = find.byType(Image);
        expect(imageFinder, findsOneWidget);
        final image = tester.widget<Image>(imageFinder);
        expect(image.image, isA<MemoryImage>());
        expect((image.image as MemoryImage).bytes, same(bytes));
        expect(image.fit, BoxFit.contain);
        expect(repository.logoReads, 1);
        expect(tester.takeException(), isNull);
        _expectNoWrites(repository);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });

    testWidgets('absent logo metadata performs no query', (tester) async {
      final repository = _BusinessIdentityRepositorySpy();

      await tester.pumpWidget(
        _headerHarness(
          application: _withBusinessLogoHandler(baseApplication, repository),
          identity: const BusinessIdentity(establishmentName: 'No logo'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
      expect(repository.logoReads, 0);
      expect(repository.managedFileNames, isEmpty);
      _expectNoWrites(repository);
    });
  });

  group('Phase 108M source and one-seam guards', () {
    test('header uses only the existing application query boundary', () {
      final source = File(
        'lib/shared/widgets/business_identity_header.dart',
      ).readAsStringSync();

      expect(source, contains('load_business_logo_query.dart'));
      expect(source, contains('application_scope.dart'));
      expect(
        source,
        matches(
          RegExp(
            r'ApplicationScope\.of\(context\)\s*\.queries\s*\.businessLogo\s*\.execute\s*\(\s*LoadBusinessLogoQuery\s*\(',
          ),
        ),
      );
      expect(source, contains('return result.value;'));
      expect(source, isNot(contains('app_repositories.dart')));
      expect(source, isNot(contains('AppRepositories')));
      expect(source, isNot(contains('loadLogoBytes(')));
      expect(source, isNot(contains('LocalBusinessIdentityRepository')));
      expect(source, isNot(contains('dart:io')));
      expect(source, isNot(matches(RegExp(r'\bFile\s*\('))));
      expect(source, isNot(contains('FoundationDatabase')));
      expect(source, isNot(contains('Drift')));
      expect(source.toLowerCase(), isNot(contains('database')));
      expect(source.toLowerCase(), isNot(contains('supabase')));
      expect(source.toLowerCase(), isNot(contains('cloud')));
      expect(source, isNot(contains('LoadBusinessLogoQueryHandler(')));
      for (final writeToken in [
        'saveIdentity',
        'saveLogoBytes',
        'deleteLogoFile',
      ]) {
        expect(source, isNot(contains(writeToken)));
      }

      final shortCircuit = source.indexOf(
        'if (managedFileName.isEmpty) return null;',
      );
      final queryLookup = source.indexOf('ApplicationScope.of(context)');
      expect(shortCircuit, greaterThanOrEqualTo(0));
      expect(shortCircuit, lessThan(queryLookup));
    });

    test('only the selected locator seam disappears from live inventory', () {
      final featureSharedFiles = _dartFilesUnder([
        Directory('lib/features'),
        Directory('lib/shared'),
      ]);
      final allLibFiles = _dartFilesUnder([Directory('lib')]);
      final locatorPattern = RegExp(r'AppRepositories\.');
      final featureSharedLocatorFiles = featureSharedFiles.where((file) {
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
      final normalizedLocatorFiles = featureSharedLocatorFiles
          .map((file) => _normalizedPath(file.path))
          .toSet();
      final normalizedScopeFiles =
          scopeConsumers.map((file) => _normalizedPath(file.path)).toSet();

      expect(featureSharedReferences, 136);
      expect(featureSharedLocatorFiles, hasLength(36));
      expect(allLibReferences, 152);
      expect(scopeConsumers, hasLength(14));
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
        isNot(contains('lib/shared/widgets/business_identity_header.dart')),
      );
      expect(
        normalizedScopeFiles,
        contains('lib/shared/widgets/business_identity_header.dart'),
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

Widget _headerHarness({
  required ApplicationBoundary application,
  required BusinessIdentity identity,
  bool compact = false,
}) {
  return ApplicationScope(
    application: application,
    child: MaterialApp(
      home: Scaffold(
        body: BusinessIdentityHeader(
          identity: identity,
          compact: compact,
        ),
      ),
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
    this.logoBytes,
    this.logoFuture,
    this.failure,
  });

  final Uint8List? logoBytes;
  final Future<Uint8List?>? logoFuture;
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
  establishmentName: 'Phase 108M',
  logo: LogoMetadata(
    managedFileName: 'phase-108m-logo.png',
    mimeType: 'image/png',
    sha256: 'phase-108m-logo',
    byteLength: 68,
    width: 1,
    height: 1,
  ),
);

const _identityWithEmptyManagedFileName = BusinessIdentity(
  establishmentName: 'Phase 108M empty logo',
  logo: LogoMetadata(
    managedFileName: '',
    mimeType: 'image/png',
    sha256: 'phase-108m-empty-logo',
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
