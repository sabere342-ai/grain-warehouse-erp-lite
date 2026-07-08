import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_export.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_restore_preview.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

void main() {
  group('Phase 37A - Opening balances', () {
    group('Supplier opening balance', () {
      late LocalSupplierRepository supplierRepo;
      late LocalSupplierAccountRepository repo;

      setUp(() async {
        supplierRepo = LocalSupplierRepository();
        repo = LocalSupplierAccountRepository(
          supplierRepository: supplierRepo,
        );
      });

      test('createOpeningBalanceEntry increases balance', () async {
        final supplier = await supplierRepo.createSupplier(
          SupplierDraft(name: 'مورد', phone: '0111111111'),
        );

        await repo.createOpeningBalanceEntry(
          supplierId: supplier.id,
          amountQirsh: 500000,
          createdByUserId: 'owner-1',
        );

        expect(await repo.balanceForSupplier(supplier.id), 500000);

        final entries = await repo.listEntries();
        expect(entries.length, 1);
        expect(entries.first.type, SupplierAccountEntryType.openingBalance);
        expect(entries.first.debitAmountQirsh, 500000);
        expect(entries.first.creditAmountQirsh, 0);
        expect(entries.first.sourceDocumentType, 'supplierOpeningBalance');
      });

      test('duplicate opening balance is rejected', () async {
        final supplier = await supplierRepo.createSupplier(
          SupplierDraft(name: 'مورد', phone: '0111111112'),
        );

        await repo.createOpeningBalanceEntry(
          supplierId: supplier.id,
          amountQirsh: 500000,
          createdByUserId: 'owner-1',
        );

        expect(
          repo.createOpeningBalanceEntry(
            supplierId: supplier.id,
            amountQirsh: 100000,
            createdByUserId: 'owner-1',
          ),
          throwsStateError,
        );

        expect(await repo.balanceForSupplier(supplier.id), 500000);
      });

      test('hasOpeningBalanceEntry returns correct status', () async {
        final supplier = await supplierRepo.createSupplier(
          SupplierDraft(name: 'مورد', phone: '0111111113'),
        );
        final other = await supplierRepo.createSupplier(
          SupplierDraft(name: 'آخر', phone: '0111111114'),
        );

        expect(await repo.hasOpeningBalanceEntry(supplier.id), isFalse);

        await repo.createOpeningBalanceEntry(
          supplierId: supplier.id,
          amountQirsh: 200000,
          createdByUserId: 'owner-1',
        );

        expect(await repo.hasOpeningBalanceEntry(supplier.id), isTrue);
        expect(await repo.hasOpeningBalanceEntry(other.id), isFalse);
      });

      test('negative amount is rejected', () async {
        final supplier = await supplierRepo.createSupplier(
          SupplierDraft(name: 'مورد', phone: '0111111115'),
        );

        expect(
          repo.createOpeningBalanceEntry(
            supplierId: supplier.id,
            amountQirsh: -50,
            createdByUserId: 'owner-1',
          ),
          throwsArgumentError,
        );
      });

      test('statement shows opening balance entry with running balance',
          () async {
        final supplier = await supplierRepo.createSupplier(
          SupplierDraft(name: 'مورد', phone: '0111111116'),
        );

        await repo.createOpeningBalanceEntry(
          supplierId: supplier.id,
          amountQirsh: 300000,
          createdByUserId: 'owner-1',
        );

        final statement = await repo.statementForSupplier(supplier.id);
        expect(statement.lines.length, 1);
        expect(statement.lines.first.entry.type,
            SupplierAccountEntryType.openingBalance);
        expect(statement.lines.first.entry.descriptionAr,
            'رصيد افتتاحي للمورد');
        expect(statement.lines.first.runningBalanceQirsh, 300000);
        expect(statement.finalBalanceQirsh, 300000);
      });

      test('opening balance combines with purchase in statement', () async {
        final supplier = await supplierRepo.createSupplier(
          SupplierDraft(name: 'مورد', phone: '0111111117'),
        );

        await repo.createOpeningBalanceEntry(
          supplierId: supplier.id,
          amountQirsh: 100000,
          createdByUserId: 'owner-1',
        );

        final purchase = PurchaseIntake(
          id: 'pin-ob-1',
          supplierId: supplier.id,
          productId: 'prod-ob-1',
          quantityKg: 50,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 4000,
          totalAmountPiasters: 200000,
          createdByUserId: 'owner-1',
          createdAt: DateTime.now(),
          stockMovementId: 'mov-ob-1',
        );
        await repo.createPurchaseEntry(purchase: purchase);

        final statement = await repo.statementForSupplier(supplier.id);
        expect(statement.lines.length, 2);
        expect(statement.lines[0].entry.type,
            SupplierAccountEntryType.openingBalance);
        expect(statement.lines[0].runningBalanceQirsh, 100000);
        expect(statement.lines[1].entry.type,
            SupplierAccountEntryType.purchase);
        expect(statement.lines[1].runningBalanceQirsh, 300000);
        expect(statement.finalBalanceQirsh, 300000);
      });
    });

    group('Backup version backward compatibility', () {
      test('backup exports at version 2', () async {
        final productRepo = LocalProductRepository();
        final inventoryRepo = LocalInventoryRepository(
          productRepository: productRepo,
        );
        final supplierRepo = LocalSupplierRepository();

        final product = await productRepo.createProduct(
          ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
        );

        await inventoryRepo.createMovement(
          StockMovementDraft(
            productId: product.id,
            movementType: StockMovementType.openingBalance,
            quantityKg: 500,
            createdByUserId: 'owner-1',
          ),
        );

        final service = BackupExportService(
          productRepository: productRepo,
          inventoryRepository: inventoryRepo,
          supplierRepository: supplierRepo,
          purchaseRepository: LocalPurchaseRepository(
            supplierRepository: supplierRepo,
            productRepository: productRepo,
            inventoryRepository: inventoryRepo,
          ),
          saleRepository: LocalSaleRepository(
            productRepository: productRepo,
            inventoryRepository: inventoryRepo,
          ),
          documentHistoryRepository: LocalDocumentHistoryRepository(
            purchaseRepository: LocalPurchaseRepository(
              supplierRepository: supplierRepo,
              productRepository: productRepo,
              inventoryRepository: inventoryRepo,
            ),
            saleRepository: LocalSaleRepository(
              productRepository: productRepo,
              inventoryRepository: inventoryRepo,
            ),
            productRepository: productRepo,
            inventoryRepository: inventoryRepo,
          ),
          now: () => DateTime(2026, 7, 7, 10, 0, 0),
        );

        final result = await service.createBackup();
        expect(result.backupVersion, 2);
      });

      test('v1 backup is accepted by preview service', () async {
        final v1Json = const JsonEncoder.withIndent('  ').convert({
          'metadata': {
            'app': 'grain-warehouse-erp-lite',
            'backupVersion': 1,
            'generatedAt': '2026-07-06T15:42:30.000Z',
            'fileName': 'grain-warehouse-backup-20260706-154230.json',
            'restoreSupported': false,
            'warning': 'هذه نسخة احتياطية للتصدير والحفظ.',
          },
          'counts': {
            'products': 1,
            'inventoryMovements': 1,
            'suppliers': 1,
            'purchases': 1,
            'sales': 1,
            'documentHistory': 2,
          },
          'data': {
            'products': [
              {
                'id': 'prod-1',
                'name': 'قمح',
                'code': null,
                'unit': 'kilogram',
                'isActive': true,
                'defaultSalePricePiastersPerKg': null,
                'minimumSalePricePiastersPerKg': null,
                'referenceCostPricePiastersPerKg': null,
                'notes': null,
                'createdAt': '2026-07-06T10:00:00.000Z',
                'updatedAt': '2026-07-06T10:00:00.000Z',
              }
            ],
            'inventoryMovements': [
              {
                'id': 'stk-1',
                'productId': 'prod-1',
                'movementType': 'openingBalance',
                'quantityKg': 500,
                'signedQuantityKg': 500,
                'createdByUserId': 'owner-1',
                'createdAt': '2026-07-06T10:00:00.000Z',
                'note': null,
                'isVoided': false,
                'reversedMovementId': null,
                'originalDocumentId': null,
              }
            ],
            'suppliers': [
              {
                'id': 'sup-1',
                'name': 'مورد',
                'phone': '0111111111',
                'address': null,
                'notes': null,
                'isActive': true,
                'createdAt': '2026-07-06T10:00:00.000Z',
                'updatedAt': '2026-07-06T10:00:00.000Z',
              }
            ],
            'purchases': [
              {
                'id': 'pin-1',
                'supplierId': 'sup-1',
                'supplierName': 'مورد',
                'supplierPhone': null,
                'supplierAddress': null,
                'productId': 'prod-1',
                'quantityKg': 100,
                'entryUnit': 'kilogram',
                'unitPricePiastersPerKg': 2000,
                'totalAmountPiasters': 200000,
                'createdByUserId': 'owner-1',
                'createdAt': '2026-07-06T11:00:00.000Z',
                'stockMovementId': 'stk-2',
                'notes': null,
                'isCancelled': false,
                'cancellation': null,
              }
            ],
            'sales': [
              {
                'id': 'sal-1',
                'productId': 'prod-1',
                'quantityKg': 50,
                'salePriceQirshPerKg': 2500,
                'totalQirsh': 125000,
                'createdByUserId': 'owner-1',
                'createdByUserName': null,
                'createdAt': '2026-07-06T12:00:00.000Z',
                'stockMovementId': 'stk-3',
                'paymentMode': 'cash',
                'customerId': null,
                'notes': null,
                'isCancelled': false,
                'cancellation': null,
              }
            ],
            'documentHistory': [
              {
                'id': 'dh-1',
                'type': 'purchase',
                'status': 'active',
                'productId': 'prod-1',
                'productName': 'قمح',
                'partyName': 'مورد',
                'quantityKg': 100,
                'unitPricePiastersPerKg': 2000,
                'totalPiasters': 200000,
                'createdByUserId': 'owner-1',
                'createdByUserName': null,
                'createdAt': '2026-07-06T11:00:00.000Z',
                'notes': null,
                'isCancelled': false,
                'cancellation': null,
                'originalMovementId': null,
                'reversalMovementIds': [],
              },
              {
                'id': 'dh-2',
                'type': 'sale',
                'status': 'active',
                'productId': 'prod-1',
                'productName': 'قمح',
                'partyName': null,
                'quantityKg': 50,
                'unitPricePiastersPerKg': 2500,
                'totalPiasters': 125000,
                'createdByUserId': 'owner-1',
                'createdByUserName': null,
                'createdAt': '2026-07-06T12:00:00.000Z',
                'notes': null,
                'isCancelled': false,
                'cancellation': null,
                'originalMovementId': null,
                'reversalMovementIds': [],
              },
            ],
          },
        });

        final result =
            const BackupRestorePreviewService().preview(v1Json);

        expect(result.isValid, isTrue);
        expect(result.summary!.backupVersion, 1);
      });

      test('v2 backup is accepted by preview service', () async {
        final productRepo = LocalProductRepository();
        final inventoryRepo = LocalInventoryRepository(
          productRepository: productRepo,
        );
        final supplierRepo = LocalSupplierRepository();

        await productRepo.createProduct(
          ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
        );
        await supplierRepo.createSupplier(
          SupplierDraft(name: 'مورد', phone: '0111111119'),
        );

        final service = BackupExportService(
          productRepository: productRepo,
          inventoryRepository: inventoryRepo,
          supplierRepository: supplierRepo,
          purchaseRepository: LocalPurchaseRepository(
            supplierRepository: supplierRepo,
            productRepository: productRepo,
            inventoryRepository: inventoryRepo,
          ),
          saleRepository: LocalSaleRepository(
            productRepository: productRepo,
            inventoryRepository: inventoryRepo,
          ),
          documentHistoryRepository: LocalDocumentHistoryRepository(
            purchaseRepository: LocalPurchaseRepository(
              supplierRepository: supplierRepo,
              productRepository: productRepo,
              inventoryRepository: inventoryRepo,
            ),
            saleRepository: LocalSaleRepository(
              productRepository: productRepo,
              inventoryRepository: inventoryRepo,
            ),
            productRepository: productRepo,
            inventoryRepository: inventoryRepo,
          ),
          now: () => DateTime(2026, 7, 7, 10, 0, 0),
        );

        final result = await service.createBackup();
        final preview =
            const BackupRestorePreviewService().preview(result.jsonText);

        expect(preview.isValid, isTrue);
        expect(preview.summary!.backupVersion, 2);
      });

      test('unsupported version 99 is rejected', () {
        final badJson = const JsonEncoder.withIndent('  ').convert({
          'metadata': {
            'app': 'grain-warehouse-erp-lite',
            'backupVersion': 99,
            'generatedAt': '2026-07-06T15:42:30.000Z',
            'restoreSupported': false,
            'warning': 'تحذير',
          },
          'counts': {
            'products': 0,
            'inventoryMovements': 0,
            'suppliers': 0,
            'purchases': 0,
            'sales': 0,
            'documentHistory': 0,
          },
          'data': {
            'products': [],
            'inventoryMovements': [],
            'suppliers': [],
            'purchases': [],
            'sales': [],
            'documentHistory': [],
          },
        });

        final result =
            const BackupRestorePreviewService().preview(badJson);

        expect(result.isValid, isFalse);
        expect(result.technicalReason, 'unsupported-version');
      });
    });
  });
}
