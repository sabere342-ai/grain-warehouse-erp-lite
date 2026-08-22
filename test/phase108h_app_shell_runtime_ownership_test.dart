import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/app/grain_warehouse_app.dart';
import 'package:grain_warehouse_erp_lite/application/application_boundary.dart';
import 'package:grain_warehouse_erp_lite/composition/app_composition_root.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
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

void main() {
  group('Phase 108H central app-shell ownership', () {
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

    test('runtime exposes the exact controllers supplied to the app', () {
      final runtime = application.dependencies.runtime;
      final app = GrainWarehouseApp(
        authController: runtime.authController,
        themeController: runtime.themeController,
        businessIdentityController: runtime.businessIdentityController,
      );

      expect(app.authController, same(runtime.authController));
      expect(app.themeController, same(runtime.themeController));
      expect(
        app.businessIdentityController,
        same(runtime.businessIdentityController),
      );
    });

    test('business identity controller shares the production repository', () {
      expect(
        application.dependencies.repositories.businessIdentityRepository,
        same(AppRepositories.businessIdentityRepository),
      );

      final rootSource = File(
        'lib/composition/app_composition_root.dart',
      ).readAsStringSync();
      expect(
        rootSource,
        contains(
          'final sharedBusinessIdentityRepository =\n'
          '        AppRepositories.businessIdentityRepository;',
        ),
      );
      expect(
        rootSource,
        contains('repository: sharedBusinessIdentityRepository'),
      );
    });

    test('business context remains unavailable', () {
      expect(
        application.dependencies.runtime.businessContextProvider.current,
        isNull,
      );
    });
  });

  test('production app shell has no locator or concrete repositories', () {
    final source = File('lib/app/grain_warehouse_app.dart').readAsStringSync();

    expect(source, isNot(contains('AppRepositories')));
    expect(source, isNot(contains('LocalThemeSettingsRepository')));
    expect(source, isNot(contains('LocalBusinessIdentityRepository')));
  });

  test('main injects all exact root-owned app-shell controllers', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(
      source,
      contains('application.dependencies.runtime.authController'),
    );
    expect(
      source,
      contains('application.dependencies.runtime.themeController'),
    );
    expect(
      source,
      contains(
        'application.dependencies.runtime.businessIdentityController',
      ),
    );
  });

  test('theme initialization preserves persisted state and notifications',
      () async {
    final repository = _ThemeSettingsRepositoryStub(
      const AppThemeSettings(
        mode: AppThemeMode.dark,
        preset: AppThemePreset.blue,
      ),
    );
    final controller = ThemeController(repository: repository);
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.initialize();

    expect(repository.loadCalls, 1);
    expect(controller.mode, AppThemeMode.dark);
    expect(controller.preset, AppThemePreset.blue);
    expect(controller.isLoading, isFalse);
    expect(notifications, 2);
  });

  test('branding initialization preserves values and notifications', () async {
    const identity = BusinessIdentity(
      establishmentName: 'مخازن النور',
      taxNumber: '00123',
      address: 'القاهرة',
      phone: '01000000000',
    );
    final repository = _BusinessIdentityRepositoryStub(identity);
    final controller = BusinessIdentityController(repository: repository);
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.initialize();

    expect(repository.loadCalls, 1);
    expect(controller.identity, same(identity));
    expect(controller.isLoading, isFalse);
    expect(notifications, 2);
  });

  testWidgets('app does not dispose injected root-owned controllers',
      (tester) async {
    final authController = AuthController(
      repository: LocalAuthRepository.empty(),
    );
    final themeController = _TrackingThemeController(
      repository: _ThemeSettingsRepositoryStub(
        const AppThemeSettings(
          mode: AppThemeMode.system,
          preset: AppThemePreset.olive,
        ),
      ),
    );
    final businessIdentityController = _TrackingBusinessIdentityController(
      repository: _BusinessIdentityRepositoryStub(BusinessIdentity.empty),
    );
    addTearDown(authController.dispose);
    addTearDown(themeController.dispose);
    addTearDown(businessIdentityController.dispose);

    await tester.pumpWidget(
      GrainWarehouseApp(
        authController: authController,
        themeController: themeController,
        businessIdentityController: businessIdentityController,
        initializeAuth: false,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());

    expect(themeController.wasDisposed, isFalse);
    expect(businessIdentityController.wasDisposed, isFalse);
  });

  test('no user-to-business mapping is introduced in ownership sources', () {
    final sources = [
      'lib/application/application_dependencies.dart',
      'lib/composition/app_composition_root.dart',
      'lib/composition/legacy_application_dependency_bridge.dart',
      'lib/app/grain_warehouse_app.dart',
      'lib/main.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');

    expect(sources, isNot(contains('businessId:')));
    expect(sources, isNot(contains('businessId =')));
  });
}

final class _ThemeSettingsRepositoryStub implements ThemeSettingsRepository {
  _ThemeSettingsRepositoryStub(this.settings);

  final AppThemeSettings settings;
  int loadCalls = 0;

  @override
  Future<AppThemeSettings> loadSettings() async {
    loadCalls++;
    return settings;
  }

  @override
  Future<void> saveSettings(AppThemeSettings settings) async {}
}

final class _BusinessIdentityRepositoryStub
    implements BusinessIdentityRepository {
  _BusinessIdentityRepositoryStub(this.identity);

  BusinessIdentity identity;
  int loadCalls = 0;

  @override
  Future<BusinessIdentity> loadIdentity() async {
    loadCalls++;
    return identity;
  }

  @override
  Future<void> saveIdentity(BusinessIdentity identity) async {
    this.identity = identity;
  }

  @override
  Future<LogoMetadata?> saveLogoBytes(Uint8List bytes, String mimeType) async =>
      null;

  @override
  Future<Uint8List?> loadLogoBytes(String managedFileName) async => null;

  @override
  Future<void> deleteLogoFile(String managedFileName) async {}

  @override
  String get managedLogosDirectory => '';
}

final class _TrackingThemeController extends ThemeController {
  _TrackingThemeController({required super.repository});

  bool wasDisposed = false;

  @override
  void dispose() {
    wasDisposed = true;
    super.dispose();
  }
}

final class _TrackingBusinessIdentityController
    extends BusinessIdentityController {
  _TrackingBusinessIdentityController({required super.repository});

  bool wasDisposed = false;

  @override
  void dispose() {
    wasDisposed = true;
    super.dispose();
  }
}

final class _TrialEvaluatorStub implements TrialEvaluator {
  @override
  Future<TrialEvaluation> evaluate() async =>
      TrialEvaluation.blocked(TrialAccessStatus.invalidState);
}
