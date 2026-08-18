import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/application/application_dependencies.dart';
import 'package:grain_warehouse_erp_lite/application/context/business_context.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_service.dart';

final class LegacyApplicationDependencyBridge {
  const LegacyApplicationDependencyBridge._();

  static ApplicationDependencies captureSharedInstances({
    required TrialEvaluator trialEvaluator,
  }) {
    return ApplicationDependencies(
      repositories: ApplicationRepositoryDependencies(
        auditLogReadRepository: AppRepositories.auditLogRepository,
        productCatalogReadRepository:
            AppRepositories.productCatalogReadRepository,
        inventoryRepository: AppRepositories.inventoryRepository,
        saleRepository: AppRepositories.saleRepository,
      ),
      services: ApplicationServiceDependencies(
        trialEvaluator: trialEvaluator,
      ),
      runtime: const ApplicationRuntimeDependencies(
        businessContextProvider: NoBusinessContextProvider(),
      ),
    );
  }
}
