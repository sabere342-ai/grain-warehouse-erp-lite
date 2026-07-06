import 'package:grain_warehouse_erp_lite/core/backup/backup_export.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_file_writer.dart';
import 'package:grain_warehouse_erp_lite/core/backup/business_data_wipe_service.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_restore_service.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/reports/report_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

class AppRepositories {
  AppRepositories._();

  static final LocalProductRepository productRepository =
      LocalProductRepository();

  static final LocalInventoryRepository inventoryRepository =
      LocalInventoryRepository(productRepository: productRepository);

  static final LocalSupplierRepository supplierRepository =
      LocalSupplierRepository();

  static final LocalPurchaseRepository purchaseRepository =
      LocalPurchaseRepository(
    supplierRepository: supplierRepository,
    productRepository: productRepository,
    inventoryRepository: inventoryRepository,
  );

  static final LocalSaleRepository saleRepository = LocalSaleRepository(
    productRepository: productRepository,
    inventoryRepository: inventoryRepository,
  );

  static final LocalReportRepository reportRepository = LocalReportRepository(
    purchaseRepository: purchaseRepository,
    saleRepository: saleRepository,
    inventoryRepository: inventoryRepository,
    productRepository: productRepository,
  );

  static final LocalDocumentHistoryRepository documentHistoryRepository =
      LocalDocumentHistoryRepository(
    purchaseRepository: purchaseRepository,
    saleRepository: saleRepository,
    productRepository: productRepository,
    inventoryRepository: inventoryRepository,
  );

  static BackupExportService get backupExportService => BackupExportService(
        productRepository: productRepository,
        inventoryRepository: inventoryRepository,
        supplierRepository: supplierRepository,
        purchaseRepository: purchaseRepository,
        saleRepository: saleRepository,
        documentHistoryRepository: documentHistoryRepository,
      );

  static BackupRestoreService get backupRestoreService => BackupRestoreService(
        productRepository: productRepository,
        inventoryRepository: inventoryRepository,
        supplierRepository: supplierRepository,
        purchaseRepository: purchaseRepository,
        saleRepository: saleRepository,
        documentHistoryRepository: documentHistoryRepository,
      );

  static BusinessDataWipeService get businessDataWipeService =>
      BusinessDataWipeService(
        backupExportService: backupExportService,
        backupFileWriter: const LocalBackupFileWriter(),
        productRepository: productRepository,
        inventoryRepository: inventoryRepository,
        supplierRepository: supplierRepository,
        purchaseRepository: purchaseRepository,
        saleRepository: saleRepository,
        documentHistoryRepository: documentHistoryRepository,
      );
}
