import 'package:grain_warehouse_erp_lite/application/context/business_context.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_service.dart';

final class ApplicationDependencies {
  const ApplicationDependencies({
    required this.repositories,
    required this.services,
    required this.runtime,
  });

  final ApplicationRepositoryDependencies repositories;
  final ApplicationServiceDependencies services;
  final ApplicationRuntimeDependencies runtime;
}

final class ApplicationServiceDependencies {
  const ApplicationServiceDependencies({
    required this.trialEvaluator,
  });

  final TrialEvaluator trialEvaluator;
}

final class ApplicationRepositoryDependencies {
  const ApplicationRepositoryDependencies({
    required this.productCatalogReadRepository,
    required this.inventoryRepository,
    required this.saleRepository,
  });

  final ProductCatalogReadRepository productCatalogReadRepository;
  final InventoryRepository inventoryRepository;
  final SaleRepository saleRepository;
}

final class ApplicationRuntimeDependencies {
  const ApplicationRuntimeDependencies({
    required this.businessContextProvider,
  });

  final BusinessContextProvider businessContextProvider;
}
