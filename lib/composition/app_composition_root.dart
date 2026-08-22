import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/application/application_boundary.dart';
import 'package:grain_warehouse_erp_lite/application/commands/evaluate_trial_command.dart';
import 'package:grain_warehouse_erp_lite/application/context/business_context.dart';
import 'package:grain_warehouse_erp_lite/application/context/session_context.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_audit_logs_query.dart';
import 'package:grain_warehouse_erp_lite/composition/legacy_application_dependency_bridge.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_controller.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart';
import 'package:grain_warehouse_erp_lite/core/theme/theme_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/theme_settings_repository.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_service.dart';

final class AppCompositionRoot {
  const AppCompositionRoot._();

  static Future<ApplicationBoundary> initializeProduction({
    Future<FoundationDatabase> Function()? databaseFactory,
    TrialEvaluator? trialEvaluator,
  }) async {
    await AppRepositories.initializeProduction(
      databaseFactory: databaseFactory,
    );

    final sharedTrialEvaluator =
        trialEvaluator ?? await TrialService.production();
    final sessionContextProvider = LocalSessionContextProvider();
    final sessionSynchronizer = AuthSessionContextSynchronizer(
      provider: sessionContextProvider,
    );
    final authController = AuthController(
      repository: AppRepositories.authRepository,
      onAuthenticatedUserChanged: sessionSynchronizer.synchronize,
    );
    final themeController = ThemeController(
      repository: LocalThemeSettingsRepository(
        auditLogRepository: AppRepositories.auditLogRepository,
      ),
    );
    final sharedBusinessIdentityRepository =
        AppRepositories.businessIdentityRepository;
    final businessIdentityController = BusinessIdentityController(
      repository: sharedBusinessIdentityRepository,
    );
    final dependencies =
        LegacyApplicationDependencyBridge.captureSharedInstances(
      trialEvaluator: sharedTrialEvaluator,
      authController: authController,
      themeController: themeController,
      businessIdentityController: businessIdentityController,
      businessIdentityRepository: sharedBusinessIdentityRepository,
      sessionContextProvider: sessionContextProvider,
      businessContextProvider: const NoBusinessContextProvider(),
    );
    return ApplicationBoundary(
      dependencies: dependencies,
      commands: ApplicationCommands(
        trialEvaluation: EvaluateTrialCommandHandler(
          trialEvaluator: dependencies.services.trialEvaluator,
        ),
      ),
      queries: ApplicationQueries(
        auditLogs: LoadAuditLogsQueryHandler(
          repository: dependencies.repositories.auditLogReadRepository,
        ),
      ),
    );
  }

  static Future<void> close() => AppRepositories.close();
}
