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
import 'package:grain_warehouse_erp_lite/core/trial/trial_service.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_state.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_document_scaffold.dart';

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

  group('Phase 108O printable scaffold logo query migration', () {
    testWidgets(
        'valid logo queries the exact filename once and preserves bytes and layout',
        (tester) async {
      final repository = _BusinessIdentityRepositorySpy(
        identity: _identityWithLogo,
        logoBytes: _pngBytes,
      );

      await _pumpScaffold(
        tester,
        repository: repository,
        application: _withBusinessLogoHandler(baseApplication, repository),
      );
      await tester.pumpAndSettle();

      final imageFinder = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is MemoryImage,
      );
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      expect((image.image as MemoryImage).bytes, same(_pngBytes));
      expect(image.fit, BoxFit.contain);
      expect(image.errorBuilder, isNotNull);

      final logoConstraints = tester
          .widgetList<ConstrainedBox>(
            find.ancestor(
              of: imageFinder,
              matching: find.byType(ConstrainedBox),
            ),
          )
          .singleWhere(
            (box) =>
                box.constraints.maxHeight == 60 &&
                box.constraints.maxWidth == 200,
          );
      expect(logoConstraints.constraints.maxHeight, 60);
      expect(logoConstraints.constraints.maxWidth, 200);
      expect(repository.managedFileNames, ['phase-108o-logo.png']);
      expect(repository.logoReads, 1);
      expect(find.text('Phase 108O warehouse'), findsOneWidget);
      expect(find.text('Phase 108O document'), findsOneWidget);
      expect(find.text('Phase 108O body'), findsOneWidget);
      _expectNoWrites(repository);
    });

    testWidgets('pending query is silent and completion renders without writes',
        (tester) async {
      final completion = Completer<Uint8List?>();
      final repository = _BusinessIdentityRepositorySpy(
        identity: _identityWithLogo,
        logoFuture: completion.future,
      );

      await _pumpScaffold(
        tester,
        repository: repository,
        application: _withBusinessLogoHandler(baseApplication, repository),
      );
      await tester.pump();

      expect(find.byType(Image), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(repository.logoReads, 1);
      _expectNoWrites(repository);

      completion.complete(_pngBytes);
      await tester.pumpAndSettle();

      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as MemoryImage).bytes, same(_pngBytes));
      expect(repository.logoReads, 1);
      _expectNoWrites(repository);
    });

    testWidgets('missing managed logo remains silent', (tester) async {
      final repository = _BusinessIdentityRepositorySpy(
        identity: _identityWithLogo,
      );

      await _pumpScaffold(
        tester,
        repository: repository,
        application: _withBusinessLogoHandler(baseApplication, repository),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
      expect(find.text('Phase 108O document'), findsOneWidget);
      expect(repository.managedFileNames, ['phase-108o-logo.png']);
      expect(repository.logoReads, 1);
      expect(tester.takeException(), isNull);
      _expectNoWrites(repository);
    });

    testWidgets('thrown query failure remains visually silent', (tester) async {
      final repository = _BusinessIdentityRepositorySpy(
        identity: _identityWithLogo,
        failure: StateError('hidden phase 108O logo failure'),
      );

      await _pumpScaffold(
        tester,
        repository: repository,
        application: _withBusinessLogoHandler(baseApplication, repository),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
      expect(find.textContaining('hidden phase 108O'), findsNothing);
      expect(repository.logoReads, 1);
      expect(tester.takeException(), isNull);
      _expectNoWrites(repository);
    });

    testWidgets(
        'empty and invalid bytes retain the silent Image.memory fallback',
        (tester) async {
      for (final bytes in <Uint8List>[
        Uint8List(0),
        Uint8List.fromList([1, 2, 3]),
      ]) {
        final repository = _BusinessIdentityRepositorySpy(
          identity: _identityWithLogo,
          logoBytes: bytes,
        );

        await _pumpScaffold(
          tester,
          repository: repository,
          application: _withBusinessLogoHandler(baseApplication, repository),
        );
        await tester.pumpAndSettle();

        final imageFinder = find.byType(Image);
        expect(imageFinder, findsOneWidget);
        final image = tester.widget<Image>(imageFinder);
        expect(image.image, isA<MemoryImage>());
        expect((image.image as MemoryImage).bytes, same(bytes));
        expect(image.fit, BoxFit.contain);
        expect(image.errorBuilder, isNotNull);
        expect(repository.logoReads, 1);
        expect(tester.takeException(), isNull);
        _expectNoWrites(repository);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });

    testWidgets(
        'absent metadata needs no ApplicationScope and preserves callbacks',
        (tester) async {
      final repository = _BusinessIdentityRepositorySpy(
        identity: const BusinessIdentity(
          establishmentName: 'Phase 108O no logo',
        ),
      );
      var exportCalls = 0;
      var shareCalls = 0;

      await _pumpScaffold(
        tester,
        repository: repository,
        onExportPdf: () async => exportCalls++,
        onOpenWhatsApp: () async => shareCalls++,
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
      expect(find.text('Phase 108O no logo'), findsOneWidget);
      expect(find.text('Phase 108O document'), findsOneWidget);
      expect(find.text('Phase 108O body'), findsOneWidget);
      expect(repository.logoReads, 0);
      expect(repository.managedFileNames, isEmpty);

      await tester.ensureVisible(find.text('تصدير PDF'));
      await tester.tap(find.text('تصدير PDF'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('فتح واتساب'));
      await tester.tap(find.text('فتح واتساب'));
      await tester.pumpAndSettle();

      expect(exportCalls, 1);
      expect(shareCalls, 1);
      expect(tester.takeException(), isNull);
      _expectNoWrites(repository);
    });

    testWidgets('invalid metadata needs no ApplicationScope and makes no read',
        (tester) async {
      final repository = _BusinessIdentityRepositorySpy(
        identity: _identityWithInvalidLogo,
      );

      await _pumpScaffold(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
      expect(find.text('Phase 108O invalid logo'), findsOneWidget);
      expect(find.text('Phase 108O document'), findsOneWidget);
      expect(repository.logoReads, 0);
      expect(repository.managedFileNames, isEmpty);
      expect(tester.takeException(), isNull);
      _expectNoWrites(repository);
    });
  });

  group('Phase 108O source, shared-consumer, and inventory guards', () {
    test('private logo renderer uses only the existing application query', () {
      final source = File(
        'lib/features/prints/printable_document_scaffold.dart',
      ).readAsStringSync();
      final targetStart = source.indexOf('class _PrintableLogo');
      final target = source.substring(targetStart);

      expect(source, contains('load_business_logo_query.dart'));
      expect(source, contains('application_scope.dart'));
      expect(target, contains('future: _loadBytes(context)'));
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
      expect(target, isNot(matches(RegExp(r'\bFile\s*\('))));
      expect(target, isNot(contains('BusinessContext')));
      expect(target, isNot(contains('SessionContext')));
      expect(target.toLowerCase(), isNot(contains('database')));
      expect(target.toLowerCase(), isNot(contains('drift')));
      expect(target.toLowerCase(), isNot(contains('sqlite')));
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
    });

    test('all five printable views remain on the one shared scaffold', () {
      expect(_printableScaffoldConsumerFiles(), {
        'lib/features/prints/printable_customer_statement_view.dart',
        'lib/features/prints/printable_daily_report_view.dart',
        'lib/features/prints/printable_purchase_invoice_view.dart',
        'lib/features/prints/printable_sales_invoice_view.dart',
        'lib/features/prints/printable_supplier_statement_view.dart',
      });
    });

    test('only the printable scaffold leaves the direct logo-read set', () {
      expect(_logoReadFiles(), {
        'lib/application/queries/load_business_logo_query.dart',
        'lib/core/backup/backup_export.dart',
        'lib/core/business_identity/business_identity_repository.dart',
        'lib/features/exports/pdf_export_service.dart',
        'lib/features/financial_reports/advances_and_refunds_report_screen.dart',
        'lib/features/financial_reports/expense_analysis_report_screen.dart',
        'lib/features/financial_reports/inflows_report_screen.dart',
        'lib/features/financial_reports/outflows_report_screen.dart',
      });
    });

    test('live locator and scope inventory has the exact Phase 108O delta', () {
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

      expect(featureSharedReferences, 138);
      expect(locatorFiles, hasLength(36));
      expect(allLibReferences, 154);
      expect(scopeConsumers, hasLength(12));
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

Future<void> _pumpScaffold(
  WidgetTester tester, {
  required _BusinessIdentityRepositorySpy repository,
  ApplicationBoundary? application,
  Future<void> Function()? onExportPdf,
  Future<void> Function()? onOpenWhatsApp,
}) async {
  await tester.binding.setSurfaceSize(const Size(1000, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final identityController = BusinessIdentityController(repository: repository);
  await identityController.initialize();
  addTearDown(identityController.dispose);

  Widget child = BusinessIdentityScope(
    controller: identityController,
    child: MaterialApp(
      home: Scaffold(
        body: PrintableDocumentScaffold(
          title: 'Phase 108O document',
          onExportPdf: onExportPdf,
          onOpenWhatsApp: onOpenWhatsApp,
          child: const Text('Phase 108O body'),
        ),
      ),
    ),
  );
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

Set<String> _printableScaffoldConsumerFiles() {
  return Directory('lib/features/prints')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) =>
          !file.path.endsWith('printable_document_scaffold.dart') &&
          file.readAsStringSync().contains('PrintableDocumentScaffold('))
      .map((file) => _normalizedPath(file.path))
      .toSet();
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

const _identityWithLogo = BusinessIdentity(
  establishmentName: 'Phase 108O warehouse',
  logo: LogoMetadata(
    managedFileName: 'phase-108o-logo.png',
    mimeType: 'image/png',
    sha256: 'phase-108o-logo',
    byteLength: 68,
    width: 1,
    height: 1,
  ),
);

const _identityWithInvalidLogo = BusinessIdentity(
  establishmentName: 'Phase 108O invalid logo',
  logo: LogoMetadata(
    managedFileName: '',
    mimeType: 'image/png',
    sha256: 'phase-108o-invalid-logo',
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
