import 'dart:convert';
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
import 'package:grain_warehouse_erp_lite/core/trial/trial_service.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_state.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/business_identity_header.dart';

void main() {
  group('Phase 96 - BusinessIdentityHeader widget', () {
    testWidgets('shows display name and logo when both available',
        (tester) async {
      final repository = _MemoryBusinessIdentityRepository(
        const BusinessIdentity(establishmentName: 'مخازن النور'),
        logoBytes: _historicalLogoBytes,
      );
      final database = openInMemoryTestDatabase();
      final baseApplication = await AppCompositionRoot.initializeProduction(
        databaseFactory: () async => database,
        trialEvaluator: _TrialEvaluatorStub(),
      );
      final application = _withBusinessLogoHandler(
        baseApplication,
        repository,
      );
      addTearDown(() async {
        final runtime = baseApplication.dependencies.runtime;
        runtime.authController.dispose();
        runtime.themeController.dispose();
        runtime.businessIdentityController.dispose();
        await AppCompositionRoot.close();
      });
      const identity = BusinessIdentity(
        establishmentName: 'مخازن النور',
        logo: LogoMetadata(
          managedFileName: 'logo.png',
          mimeType: 'image/png',
          sha256: 'abc',
          byteLength: 100,
          width: 64,
          height: 64,
        ),
      );

      await tester.pumpWidget(
        ApplicationScope(
          application: application,
          child: const MaterialApp(
            home: Scaffold(
              body: BusinessIdentityHeader(identity: identity),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('مخازن النور'), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<MemoryImage>());
      expect((image.image as MemoryImage).bytes, same(_historicalLogoBytes));
      expect(repository.logoReads, 1);
      expect(repository.managedFileNames, ['logo.png']);
    });

    testWidgets('shows display name without logo', (tester) async {
      const identity = BusinessIdentity(establishmentName: 'غلال');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BusinessIdentityHeader(identity: identity),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('غلال'), findsOneWidget);
    });

    testWidgets('falls back to default name when identity is null',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BusinessIdentityHeader(identity: null),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(BusinessIdentity.defaultDisplayName), findsOneWidget);
    });

    testWidgets('shows subtitle when provided', (tester) async {
      const identity = BusinessIdentity(establishmentName: 'غلال');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BusinessIdentityHeader(
              identity: identity,
              subtitle: 'إدارة مخازن الحبوب',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('غلال'), findsOneWidget);
      expect(find.text('إدارة مخازن الحبوب'), findsOneWidget);
    });

    testWidgets('compact mode shows truncated name', (tester) async {
      const identity = BusinessIdentity(establishmentName: 'غلال');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: BusinessIdentityHeader(
                identity: identity,
                compact: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('غلال'), findsOneWidget);
    });

    testWidgets('long Arabic name does not overflow', (tester) async {
      const identity = BusinessIdentity(
        establishmentName:
            'شركة مخازن الحبوب والقمح والذرة والبزرة والسمسم والعبادームصر',
      );

      tester.view.physicalSize = const Size(300, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BusinessIdentityHeader(
              identity: identity,
              compact: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final exception = tester.takeException();
      expect(exception, isNull);
    });

    testWidgets('no overflow on narrow width', (tester) async {
      const identity = BusinessIdentity(establishmentName: 'غلال');

      tester.view.physicalSize = const Size(200, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BusinessIdentityHeader(
              identity: identity,
              compact: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final exception = tester.takeException();
      expect(exception, isNull);
    });

    testWidgets('reads identity from BusinessIdentityScope', (tester) async {
      final repo = _MemoryBusinessIdentityRepository(
        const BusinessIdentity(establishmentName: 'الscope'),
      );
      final controller = BusinessIdentityController(repository: repo);
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: BusinessIdentityScope(
            controller: controller,
            child: const Scaffold(
              body: BusinessIdentityHeader(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الscope'), findsOneWidget);
    });
  });

  group('Phase 96 - Dashboard identity', () {
    testWidgets('dashboard screen shows dynamic brand name', (tester) async {
      final repo = _MemoryBusinessIdentityRepository(
        const BusinessIdentity(establishmentName: 'النور'),
      );
      final controller = BusinessIdentityController(repository: repo);
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: BusinessIdentityScope(
            controller: controller,
            child: Scaffold(
              body: ListView(
                children: [
                  Builder(
                    builder: (context) {
                      final displayName = BusinessIdentityScope.maybeOf(context)
                              ?.identity
                              .displayName ??
                          BusinessIdentity.defaultDisplayName;
                      return Text('لوحة متابعة $displayName');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('لوحة متابعة النور'), findsOneWidget);
    });

    testWidgets('dashboard uses default name when no custom name set',
        (tester) async {
      final repo = _MemoryBusinessIdentityRepository(BusinessIdentity.empty);
      final controller = BusinessIdentityController(repository: repo);
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: BusinessIdentityScope(
            controller: controller,
            child: Scaffold(
              body: ListView(
                children: [
                  Builder(
                    builder: (context) {
                      final displayName = BusinessIdentityScope.maybeOf(context)
                              ?.identity
                              .displayName ??
                          BusinessIdentity.defaultDisplayName;
                      return Text('لوحة متابعة $displayName');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('لوحة متابعة ${BusinessIdentity.defaultDisplayName}'),
        findsOneWidget,
      );
    });
  });
}

class _MemoryBusinessIdentityRepository implements BusinessIdentityRepository {
  _MemoryBusinessIdentityRepository(this._identity, {this.logoBytes});

  BusinessIdentity _identity;
  final Uint8List? logoBytes;
  int logoReads = 0;
  final List<String> managedFileNames = [];

  @override
  Future<BusinessIdentity> loadIdentity() async => _identity;

  @override
  Future<void> saveIdentity(BusinessIdentity identity) async {
    _identity = identity;
  }

  @override
  Future<LogoMetadata?> saveLogoBytes(Uint8List bytes, String mimeType) async {
    return null;
  }

  @override
  Future<Uint8List?> loadLogoBytes(String managedFileName) async {
    logoReads++;
    managedFileNames.add(managedFileName);
    return logoBytes;
  }

  @override
  Future<void> deleteLogoFile(String managedFileName) async {}

  @override
  String get managedLogosDirectory => '';
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

final _historicalLogoBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

final class _TrialEvaluatorStub implements TrialEvaluator {
  @override
  Future<TrialEvaluation> evaluate() async =>
      TrialEvaluation.blocked(TrialAccessStatus.invalidState);
}
