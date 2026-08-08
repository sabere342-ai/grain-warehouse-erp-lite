import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:grain_warehouse_erp_lite/core/audit/drift_audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_export.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_file_writer.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_restore_service.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/drift_inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/drift_inventory_valuation_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/synthetic_profitability_activation_service.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart';
import 'package:grain_warehouse_erp_lite/core/profitability/profitability_report_service.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/drift_sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

import 'phase102j_synthetic_inventory_package.dart';

Future<void> main(List<String> arguments) async {
  final packagePath = arguments.isNotEmpty
      ? arguments[0]
      : 'owner-input/${Phase102JPackageReader.approvedFileName}';
  final artifactDirectory = arguments.length > 1
      ? Directory(arguments[1]).absolute
      : Directory('${Directory.systemTemp.path}'
          '${Platform.pathSeparator}phase102j-trial-'
          '${DateTime.now().toUtc().microsecondsSinceEpoch}');
  final workspace = Directory.current.absolute.path.toLowerCase();
  if (artifactDirectory.path.toLowerCase().startsWith(workspace)) {
    throw StateError(
        'Trial databases and backups must remain outside the workspace.');
  }
  await artifactDirectory.create(recursive: true);

  final package = await Phase102JPackageReader().read(File(packagePath));
  final owner = AppUser(
    id: 'phase-102j-owner',
    name: 'Phase 102J Owner',
    phone: '01000000000',
    role: UserRole.owner,
    isActive: true,
    createdAt: DateTime(2026, 7, 28),
    updatedAt: DateTime(2026, 7, 28),
  );
  final sourceFile = File('${artifactDirectory.path}'
      '${Platform.pathSeparator}phase102j_sandbox.sqlite3');
  var source = _TrialRepositories.open(sourceFile);
  final writer = LocalBackupFileWriter(baseFolderPath: artifactDirectory.path);
  final preBackup = await source.exportService().createBackup();
  final preSave = await writer.save(
    fileName: 'phase102j_pre_import_backup.json',
    jsonText: preBackup.jsonText,
  );

  final service = source.syntheticService();
  final firstImport = await service.activate(
    user: owner,
    activationDate: DateTime(2026, 7, 28),
    packageId: Phase102JPackageReader.approvedFileName,
    packageSha256: package.sha256,
    rows: package.rows,
  );
  final duplicateReplay = await service.activate(
    user: owner,
    activationDate: DateTime(2026, 7, 28),
    packageId: Phase102JPackageReader.approvedFileName,
    packageSha256: package.sha256,
    rows: package.rows,
  );
  await source.database.close();

  source = _TrialRepositories.open(sourceFile);
  final persistedActivation = await source.valuation.getActivation();
  final persistedProducts = await source.products.listProducts();
  final persistedMovements = await source.inventory.listAllMovements();
  final persistedStates = await source.valuation.listStates();
  final persistedEvents = await source.valuation.listEvents();
  final persistedAudit = await source.audit.exportStoredAuditLogs();
  _require(persistedActivation.isSyntheticTestActivated,
      'Synthetic activation did not survive database reopen.');
  _require(!persistedActivation.isActivated,
      'Synthetic activation was confused with production activation.');
  _require(persistedProducts.length == package.rows.length,
      'Product persistence count mismatch.');
  _require(persistedMovements.length == package.rows.length,
      'Opening movement persistence count mismatch.');
  _require(
      persistedStates.length == package.rows.length &&
          persistedEvents.length == package.rows.length,
      'Valuation persistence count mismatch.');
  _require(persistedAudit.length == 1,
      'Synthetic activation audit persistence count mismatch.');

  final customer = await source.customers.createCustomer(
    const CustomerDraft(name: 'عميل اختبار Phase 102J', isActive: true),
  );
  final saleProduct = persistedProducts.first;
  final beforeSaleStock = await source.inventory.currentStockKg(saleProduct.id);
  final beforeSaleValue =
      (await source.valuation.stateForProduct(saleProduct.id))!.totalValueQirsh;
  final sale = await source.sales.createSale(SaleDraft(
    productId: saleProduct.id,
    quantityKg: 100,
    salePriceQirshPerKg: 2500,
    createdByUserId: owner.id,
    customerId: customer.id,
    notes: 'SYNTHETIC_TEST_DATA | PHASE 102J profitability scenario',
  ));
  final reportEnd = sale.createdAt.add(const Duration(microseconds: 1));
  final report = await ProfitabilityReportService(
    inventoryValuationRepository: source.valuation,
    saleRepository: source.sales,
    expenseRepository: LocalExpenseRepository(),
  ).build(
    user: owner,
    start: DateTime(2026, 7, 28),
    end: reportEnd,
  );
  _require(report.activation.isSyntheticTestActivated && report.isAvailable,
      'Synthetic profitability report was not available.');
  _require(
      sale.totalQirsh == 250000 &&
          sale.totalCostOfGoodsSoldQirsh == 187500 &&
          report.grossProfitQirsh == 62500,
      'Synthetic sale profitability did not reconcile.');
  await source.sales.cancelSale(
    saleId: sale.id,
    cancelledByUserId: owner.id,
    cancellationReason: 'PHASE 102J stock/value restoration check',
  );
  final restoredSaleStock =
      await source.inventory.currentStockKg(saleProduct.id);
  final restoredSaleValue =
      (await source.valuation.stateForProduct(saleProduct.id))!.totalValueQirsh;
  _require(
      restoredSaleStock == beforeSaleStock &&
          restoredSaleValue == beforeSaleValue,
      'Sale cancellation did not restore stock and valuation exactly.');

  final postBackup = await source.exportService().createBackup();
  final postSave = await writer.save(
    fileName: 'phase102j_post_activation_backup.json',
    jsonText: postBackup.jsonText,
  );

  final restoreFile = File('${artifactDirectory.path}'
      '${Platform.pathSeparator}phase102j_restore_target.sqlite3');
  final target = _TrialRepositories.open(restoreFile);
  final restore = await target.restoreService().restoreToEmpty(
        user: owner,
        jsonText: postBackup.jsonText,
      );
  _require(restore.success,
      'Official backup restore failed: ${restore.technicalReason}');
  final targetActivation = await target.valuation.getActivation();
  _require(
      targetActivation.isSyntheticTestActivated &&
          !targetActivation.isActivated,
      'Restored activation lost its synthetic-only classification.');
  _require((await target.products.listProducts()).length == package.rows.length,
      'Restored product count mismatch.');
  _require((await target.inventory.listAllMovements()).length == 14,
      'Restored movement count mismatch.');
  _require((await target.valuation.listEvents()).length == 14,
      'Restored valuation event count mismatch.');
  await target.database.close();

  final productionProbe = FoundationDatabase(NativeDatabase.memory());
  final productionProbeActivation =
      await DriftInventoryValuationRepository(productionProbe).getActivation();
  _require(productionProbeActivation.isNotActivated,
      'A fresh production-shaped database must stay ProfitabilityNotActivated.');
  await productionProbe.close();

  final evidence = <String, Object?>{
    'phase': '102J',
    'databaseIdentity':
        SyntheticProfitabilityActivationService.requiredDatabaseIdentity,
    'dataClassification':
        SyntheticProfitabilityActivationService.dataClassification,
    'packagePath': package.file.absolute.path,
    'packageSha256': package.sha256,
    'validatedRows': package.rows.length,
    'quantityTotalKg': package.quantityTotalKg,
    'valueTotalQirsh': package.valueTotalQirsh,
    'importedRows': firstImport.importedRows,
    'rejectedRows': 0,
    'duplicateReplayRows': duplicateReplay.duplicateRows,
    'activationStatus': persistedActivation.status.name,
    'productionActivationBoolean': persistedActivation.isActivated,
    'persistenceAfterReopen': true,
    'auditEntriesAfterReopen': persistedAudit.length,
    'saleScenario': {
      'quantityKg': 100,
      'revenueQirsh': sale.totalQirsh,
      'cogsQirsh': sale.totalCostOfGoodsSoldQirsh,
      'grossProfitQirsh': report.grossProfitQirsh,
      'stockRestoredAfterCancellation': restoredSaleStock == beforeSaleStock,
      'valueRestoredAfterCancellation': restoredSaleValue == beforeSaleValue,
    },
    'preBackupPath': preSave.filePath,
    'preBackupChecksum': preBackup.checksum,
    'postBackupPath': postSave.filePath,
    'postBackupChecksum': postBackup.checksum,
    'restoreSucceeded': restore.success,
    'restoredActivationStatus': targetActivation.status.name,
    'freshProductionProbeStatus': productionProbeActivation.status.name,
    'artifactDirectory': artifactDirectory.path,
  };
  final evidenceFile = File('${artifactDirectory.path}'
      '${Platform.pathSeparator}phase102j_execution_evidence.json');
  await evidenceFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(evidence),
  );
  await source.database.close();
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(evidence));
}

void _require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

class _TrialRepositories {
  _TrialRepositories._({
    required this.database,
    required this.products,
    required this.inventory,
    required this.valuation,
    required this.audit,
    required this.sales,
    required this.suppliers,
    required this.purchases,
    required this.history,
    required this.customers,
  });

  factory _TrialRepositories.open(File file) {
    final database = FoundationDatabase(
      NativeDatabase.createInBackground(
        file,
        setup: (database) {
          database.execute('PRAGMA foreign_keys = ON');
          database.execute('PRAGMA journal_mode = WAL');
        },
      ),
    );
    final products = DriftProductRepository(database);
    final inventory = DriftInventoryRepository(
      database,
      productCatalogReadRepository: DriftProductCatalogReadRepository(database),
    );
    final valuation = DriftInventoryValuationRepository(database);
    final audit = DriftAuditLogRepository(database);
    final sales = DriftSaleRepository(
      database,
      productCatalogReadRepository: DriftProductCatalogReadRepository(database),
      inventoryRepository: inventory,
      inventoryValuationRepository: valuation,
    );
    final suppliers = LocalSupplierRepository();
    final purchases = LocalPurchaseRepository(
      supplierRepository: suppliers,
      productRepository: products,
      inventoryRepository: inventory,
      inventoryValuationRepository: valuation,
    );
    final history = LocalDocumentHistoryRepository(
      purchaseRepository: purchases,
      saleRepository: sales,
      productCatalogReadRepository: DriftProductCatalogReadRepository(database),
      inventoryRepository: inventory,
    );
    return _TrialRepositories._(
      database: database,
      products: products,
      inventory: inventory,
      valuation: valuation,
      audit: audit,
      sales: sales,
      suppliers: suppliers,
      purchases: purchases,
      history: history,
      customers: LocalCustomerRepository(),
    );
  }

  final FoundationDatabase database;
  final DriftProductRepository products;
  final DriftInventoryRepository inventory;
  final DriftInventoryValuationRepository valuation;
  final DriftAuditLogRepository audit;
  final DriftSaleRepository sales;
  final LocalSupplierRepository suppliers;
  final LocalPurchaseRepository purchases;
  final LocalDocumentHistoryRepository history;
  final LocalCustomerRepository customers;

  SyntheticProfitabilityActivationService syntheticService() =>
      SyntheticProfitabilityActivationService(
        productRepository: products,
        inventoryRepository: inventory,
        valuationRepository: valuation,
        auditLogRepository: audit,
        databaseIdentity:
            SyntheticProfitabilityActivationService.requiredDatabaseIdentity,
      );

  BackupExportService exportService() => BackupExportService(
        productCatalogReadRepository:
            DriftProductCatalogReadRepository(database),
        inventoryRepository: inventory,
        supplierRepository: suppliers,
        purchaseRepository: purchases,
        saleRepository: sales,
        documentHistoryRepository: history,
        customerRepository: customers,
        auditLogRepository: audit,
        inventoryValuationRepository: valuation,
      );

  BackupRestoreService restoreService() => BackupRestoreService(
        productRepository: products,
        productCatalogReadRepository:
            DriftProductCatalogReadRepository(database),
        inventoryRepository: inventory,
        supplierRepository: suppliers,
        purchaseRepository: purchases,
        saleRepository: sales,
        documentHistoryRepository: history,
        customerRepository: customers,
        auditLogRepository: audit,
        inventoryValuationRepository: valuation,
      );
}
