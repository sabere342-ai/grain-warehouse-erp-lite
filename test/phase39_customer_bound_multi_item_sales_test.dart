import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_export.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_restore_service.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_controller.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

void main() {
  group('Phase 39 - Customer-bound multi-item sales', () {
    group('A. Multi-item sale creation', () {
      test('multi-item sale creates all items correctly', () async {
        final products = LocalProductRepository();
        final p1 = await products.createProduct(
          const ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
        );
        final p2 = await products.createProduct(
          const ProductDraft(name: 'شعير', unit: GrainUnit.kilogram),
        );
        final p3 = await products.createProduct(
          const ProductDraft(name: 'ذرة', unit: GrainUnit.kilogram),
        );
        final inventory = LocalInventoryRepository(productRepository: products);
        for (final p in [p1, p2, p3]) {
          await inventory.createMovement(
            StockMovementDraft(
              productId: p.id,
              movementType: StockMovementType.openingBalance,
              quantityKg: 1000,
              createdByUserId: _owner.id,
            ),
          );
        }
        final customers = LocalCustomerRepository();
        final customer = await customers.createCustomer(
          const CustomerDraft(name: 'عميل اختبار', isActive: true),
        );
        final sales = LocalSaleRepository(
          productRepository: products,
          inventoryRepository: inventory,
        );

        final sale = await sales.createSale(
          SaleDraft(
            productId: p1.id,
            quantityKg: 10,
            salePriceQirshPerKg: 100,
            createdByUserId: _owner.id,
            customerId: customer.id,
            items: [
              SaleLineItemDraft(
                productId: p1.id,
                quantityKg: 10,
                salePriceQirshPerKg: 700,
              ),
              SaleLineItemDraft(
                productId: p2.id,
                quantityKg: 20,
                salePriceQirshPerKg: 500,
              ),
              SaleLineItemDraft(
                productId: p3.id,
                quantityKg: 30,
                salePriceQirshPerKg: 300,
              ),
            ],
          ),
        );

        expect(sale.items, hasLength(3));
        expect(sale.items[0].productId, p1.id);
        expect(sale.items[0].quantityKg, 10);
        expect(sale.items[0].salePriceQirshPerKg, 700);
        expect(sale.items[0].lineTotalQirsh, 7000);
        expect(sale.items[1].productId, p2.id);
        expect(sale.items[1].quantityKg, 20);
        expect(sale.items[1].salePriceQirshPerKg, 500);
        expect(sale.items[1].lineTotalQirsh, 10000);
        expect(sale.items[2].productId, p3.id);
        expect(sale.items[2].quantityKg, 30);
        expect(sale.items[2].salePriceQirshPerKg, 300);
        expect(sale.items[2].lineTotalQirsh, 9000);
        expect(sale.totalQirsh, 26000);
        expect(sale.customerId, customer.id);
        expect(sale.stockMovementId.trim(), isNotEmpty);
      });

      test('multi-item sale reduces stock for all products', () async {
        final products = LocalProductRepository();
        final p1 = await products.createProduct(
          const ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
        );
        final p2 = await products.createProduct(
          const ProductDraft(name: 'شعير', unit: GrainUnit.kilogram),
        );
        final inventory = LocalInventoryRepository(productRepository: products);
        for (final p in [p1, p2]) {
          await inventory.createMovement(
            StockMovementDraft(
              productId: p.id,
              movementType: StockMovementType.openingBalance,
              quantityKg: 1000,
              createdByUserId: _owner.id,
            ),
          );
        }
        final customers = LocalCustomerRepository();
        final customer = await customers.createCustomer(
          const CustomerDraft(name: 'عميل اختبار', isActive: true),
        );
        final sales = LocalSaleRepository(
          productRepository: products,
          inventoryRepository: inventory,
        );

        await sales.createSale(
          SaleDraft(
            productId: p1.id,
            quantityKg: 50,
            salePriceQirshPerKg: 100,
            createdByUserId: _owner.id,
            customerId: customer.id,
            items: [
              SaleLineItemDraft(
                productId: p1.id,
                quantityKg: 50,
                salePriceQirshPerKg: 700,
              ),
              SaleLineItemDraft(
                productId: p2.id,
                quantityKg: 30,
                salePriceQirshPerKg: 500,
              ),
            ],
          ),
        );

        expect(await inventory.currentStockKg(p1.id), 950);
        expect(await inventory.currentStockKg(p2.id), 970);
      });

      test('multi-item sale adjusts inventory balance', () async {
        final products = LocalProductRepository();
        final p1 = await products.createProduct(
          const ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
        );
        final p2 = await products.createProduct(
          const ProductDraft(name: 'شعير', unit: GrainUnit.kilogram),
        );
        final inventory = LocalInventoryRepository(productRepository: products);
        for (final p in [p1, p2]) {
          await inventory.createMovement(
            StockMovementDraft(
              productId: p.id,
              movementType: StockMovementType.openingBalance,
              quantityKg: 1000,
              createdByUserId: _owner.id,
            ),
          );
        }
        final customers = LocalCustomerRepository();
        final customer = await customers.createCustomer(
          const CustomerDraft(name: 'عميل اختبار', isActive: true),
        );
        final sales = LocalSaleRepository(
          productRepository: products,
          inventoryRepository: inventory,
        );

        await sales.createSale(
          SaleDraft(
            productId: p1.id,
            quantityKg: 40,
            salePriceQirshPerKg: 100,
            createdByUserId: _owner.id,
            customerId: customer.id,
            items: [
              SaleLineItemDraft(
                productId: p1.id,
                quantityKg: 40,
                salePriceQirshPerKg: 700,
              ),
              SaleLineItemDraft(
                productId: p2.id,
                quantityKg: 60,
                salePriceQirshPerKg: 500,
              ),
            ],
          ),
        );

        final movements = await inventory.listAllMovements();
        expect(movements, hasLength(4));
        final saleMovements = movements
            .where((m) => m.movementType == StockMovementType.sale)
            .toList();
        expect(saleMovements, hasLength(2));
        final p1movement = saleMovements.firstWhere((m) => m.productId == p1.id);
        expect(p1movement.signedQuantityKg, -40);
        final p2movement = saleMovements.firstWhere((m) => m.productId == p2.id);
        expect(p2movement.signedQuantityKg, -60);
      });

      test('cash sale without customerId is rejected', () async {
        final products = LocalProductRepository();
        final product = await products.createProduct(
          const ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
        );
        final inventory = LocalInventoryRepository(productRepository: products);
        await inventory.createMovement(
          StockMovementDraft(
            productId: product.id,
            movementType: StockMovementType.openingBalance,
            quantityKg: 1000,
            createdByUserId: _owner.id,
          ),
        );
        final sales = LocalSaleRepository(
          productRepository: products,
          inventoryRepository: inventory,
        );

        expect(
          () => sales.createSale(
            SaleDraft(
              productId: product.id,
              quantityKg: 10,
              salePriceQirshPerKg: 700,
              createdByUserId: _owner.id,
              customerId: '',
            ),
          ),
          throwsArgumentError,
        );
      });

      test('credit sale with valid customer creates ledger entry', () async {
        final products = LocalProductRepository();
        final product = await products.createProduct(
          const ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
        );
        final inventory = LocalInventoryRepository(productRepository: products);
        await inventory.createMovement(
          StockMovementDraft(
            productId: product.id,
            movementType: StockMovementType.openingBalance,
            quantityKg: 1000,
            createdByUserId: _owner.id,
          ),
        );
        final customers = LocalCustomerRepository();
        final customer = await customers.createCustomer(
          const CustomerDraft(name: 'عميل اختبار', isActive: true),
        );
        final sales = LocalSaleRepository(
          productRepository: products,
          inventoryRepository: inventory,
        );
        final accountRepo = LocalCustomerAccountRepository(
          customerRepository: customers,
        );
        final controller = SaleController(
          saleRepository: sales,
          productRepository: products,
          inventoryRepository: inventory,
          customerRepository: customers,
          customerAccountRepository: accountRepo,
        );
        await controller.load(_owner);

        final result = await controller.createSale(
          user: _owner,
          productId: product.id,
          quantityKg: 100,
          salePriceQirshPerKg: 700,
          customerId: customer.id,
          paymentMode: SalePaymentMode.credit,
        );

        expect(result, isTrue);
        final entries = await accountRepo.listEntries();
        expect(entries, hasLength(1));
        expect(entries[0].type, CustomerAccountEntryType.creditSale);
        expect(entries[0].debitAmountQirsh, 70000);
        expect(entries[0].creditAmountQirsh, 0);
        expect(entries[0].customerId, customer.id);
      });
    });

    group('B. Validation', () {
      test('empty items list is rejected', () async {
        final products = LocalProductRepository();
        final product = await products.createProduct(
          const ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
        );
        final inventory = LocalInventoryRepository(productRepository: products);
        await inventory.createMovement(
          StockMovementDraft(
            productId: product.id,
            movementType: StockMovementType.openingBalance,
            quantityKg: 1000,
            createdByUserId: _owner.id,
          ),
        );
        final customers = LocalCustomerRepository();
        final customer = await customers.createCustomer(
          const CustomerDraft(name: 'عميل اختبار', isActive: true),
        );
        final sales = LocalSaleRepository(
          productRepository: products,
          inventoryRepository: inventory,
        );

        expect(
          () => sales.createSale(
            SaleDraft(
              productId: product.id,
              quantityKg: 0,
              salePriceQirshPerKg: 0,
              createdByUserId: _owner.id,
              customerId: customer.id,
              items: [],
            ),
          ),
          throwsArgumentError,
        );
      });

      test('item with quantity zero is rejected', () async {
        final products = LocalProductRepository();
        final product = await products.createProduct(
          const ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
        );
        final inventory = LocalInventoryRepository(productRepository: products);
        await inventory.createMovement(
          StockMovementDraft(
            productId: product.id,
            movementType: StockMovementType.openingBalance,
            quantityKg: 1000,
            createdByUserId: _owner.id,
          ),
        );
        final customers = LocalCustomerRepository();
        final customer = await customers.createCustomer(
          const CustomerDraft(name: 'عميل اختبار', isActive: true),
        );
        final sales = LocalSaleRepository(
          productRepository: products,
          inventoryRepository: inventory,
        );

        expect(
          () => sales.createSale(
            SaleDraft(
              productId: product.id,
              quantityKg: 10,
              salePriceQirshPerKg: 700,
              createdByUserId: _owner.id,
              customerId: customer.id,
              items: [
                SaleLineItemDraft(
                  productId: product.id,
                  quantityKg: 0,
                  salePriceQirshPerKg: 700,
                ),
              ],
            ),
          ),
          throwsArgumentError,
        );
      });

      test('item with zero price is rejected', () async {
        final products = LocalProductRepository();
        final product = await products.createProduct(
          const ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
        );
        final inventory = LocalInventoryRepository(productRepository: products);
        await inventory.createMovement(
          StockMovementDraft(
            productId: product.id,
            movementType: StockMovementType.openingBalance,
            quantityKg: 1000,
            createdByUserId: _owner.id,
          ),
        );
        final customers = LocalCustomerRepository();
        final customer = await customers.createCustomer(
          const CustomerDraft(name: 'عميل اختبار', isActive: true),
        );
        final sales = LocalSaleRepository(
          productRepository: products,
          inventoryRepository: inventory,
        );

        expect(
          () => sales.createSale(
            SaleDraft(
              productId: product.id,
              quantityKg: 10,
              salePriceQirshPerKg: 700,
              createdByUserId: _owner.id,
              customerId: customer.id,
              items: [
                SaleLineItemDraft(
                  productId: product.id,
                  quantityKg: 10,
                  salePriceQirshPerKg: 0,
                ),
              ],
            ),
          ),
          throwsArgumentError,
        );
      });

      test('insufficient stock for any item is rejected', () async {
        final products = LocalProductRepository();
        final p1 = await products.createProduct(
          const ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
        );
        final p2 = await products.createProduct(
          const ProductDraft(name: 'شعير', unit: GrainUnit.kilogram),
        );
        final inventory = LocalInventoryRepository(productRepository: products);
        await inventory.createMovement(
          StockMovementDraft(
            productId: p1.id,
            movementType: StockMovementType.openingBalance,
            quantityKg: 100,
            createdByUserId: _owner.id,
          ),
        );
        await inventory.createMovement(
          StockMovementDraft(
            productId: p2.id,
            movementType: StockMovementType.openingBalance,
            quantityKg: 1000,
            createdByUserId: _owner.id,
          ),
        );
        final customers = LocalCustomerRepository();
        final customer = await customers.createCustomer(
          const CustomerDraft(name: 'عميل اختبار', isActive: true),
        );
        final sales = LocalSaleRepository(
          productRepository: products,
          inventoryRepository: inventory,
        );

        expect(
          () => sales.createSale(
            SaleDraft(
              productId: p1.id,
              quantityKg: 10,
              salePriceQirshPerKg: 700,
              createdByUserId: _owner.id,
              customerId: customer.id,
              items: [
                SaleLineItemDraft(
                  productId: p1.id,
                  quantityKg: 10,
                  salePriceQirshPerKg: 700,
                ),
                SaleLineItemDraft(
                  productId: p2.id,
                  quantityKg: 2000,
                  salePriceQirshPerKg: 500,
                ),
              ],
            ),
          ),
          throwsStateError,
        );
        expect(await sales.listSales(), isEmpty);
        expect(await inventory.currentStockKg(p1.id), 100);
        expect(await inventory.currentStockKg(p2.id), 1000);
      });
    });

    group('C. Cancellation with multi-item', () {
      test('cancelling multi-item sale reverses all stock', () async {
        final products = LocalProductRepository();
        final p1 = await products.createProduct(
          const ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
        );
        final p2 = await products.createProduct(
          const ProductDraft(name: 'شعير', unit: GrainUnit.kilogram),
        );
        final inventory = LocalInventoryRepository(productRepository: products);
        for (final p in [p1, p2]) {
          await inventory.createMovement(
            StockMovementDraft(
              productId: p.id,
              movementType: StockMovementType.openingBalance,
              quantityKg: 1000,
              createdByUserId: _owner.id,
            ),
          );
        }
        final customers = LocalCustomerRepository();
        final customer = await customers.createCustomer(
          const CustomerDraft(name: 'عميل اختبار', isActive: true),
        );
        final sales = LocalSaleRepository(
          productRepository: products,
          inventoryRepository: inventory,
        );

        final sale = await sales.createSale(
          SaleDraft(
            productId: p1.id,
            quantityKg: 50,
            salePriceQirshPerKg: 700,
            createdByUserId: _owner.id,
            customerId: customer.id,
            items: [
              SaleLineItemDraft(
                productId: p1.id,
                quantityKg: 50,
                salePriceQirshPerKg: 700,
              ),
              SaleLineItemDraft(
                productId: p2.id,
                quantityKg: 30,
                salePriceQirshPerKg: 500,
              ),
            ],
          ),
        );

        final cancelled = await sales.cancelSale(
          saleId: sale.id,
          cancelledByUserId: _owner.id,
          cancellationReason: 'خطأ في الإدخال',
        );

        final movements = await inventory.listAllMovements();
        expect(cancelled.isCancelled, isTrue);
        expect(cancelled.cancellation!.reversalMovementIds, hasLength(2));
        final reversalMovements = movements
            .where((m) => m.movementType == StockMovementType.saleCancellation)
            .toList();
        expect(reversalMovements, hasLength(2));
        expect(reversalMovements[0].reversedMovementId, sale.stockMovementId);
        expect(reversalMovements[1].reversedMovementId, sale.stockMovementId);
        expect(reversalMovements[0].originalDocumentId, sale.id);
        expect(reversalMovements[1].originalDocumentId, sale.id);
        expect(await inventory.currentStockKg(p1.id), 1000);
        expect(await inventory.currentStockKg(p2.id), 1000);
      });

      test('double cancellation is idempotent', () async {
        final products = LocalProductRepository();
        final p1 = await products.createProduct(
          const ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
        );
        final p2 = await products.createProduct(
          const ProductDraft(name: 'شعير', unit: GrainUnit.kilogram),
        );
        final inventory = LocalInventoryRepository(productRepository: products);
        for (final p in [p1, p2]) {
          await inventory.createMovement(
            StockMovementDraft(
              productId: p.id,
              movementType: StockMovementType.openingBalance,
              quantityKg: 1000,
              createdByUserId: _owner.id,
            ),
          );
        }
        final customers = LocalCustomerRepository();
        final customer = await customers.createCustomer(
          const CustomerDraft(name: 'عميل اختبار', isActive: true),
        );
        final sales = LocalSaleRepository(
          productRepository: products,
          inventoryRepository: inventory,
        );

        final sale = await sales.createSale(
          SaleDraft(
            productId: p1.id,
            quantityKg: 50,
            salePriceQirshPerKg: 700,
            createdByUserId: _owner.id,
            customerId: customer.id,
            items: [
              SaleLineItemDraft(
                productId: p1.id,
                quantityKg: 50,
                salePriceQirshPerKg: 700,
              ),
              SaleLineItemDraft(
                productId: p2.id,
                quantityKg: 30,
                salePriceQirshPerKg: 500,
              ),
            ],
          ),
        );

        final first = await sales.cancelSale(
          saleId: sale.id,
          cancelledByUserId: _owner.id,
          cancellationReason: 'خطأ في الإدخال',
        );
        final second = await sales.cancelSale(
          saleId: sale.id,
          cancelledByUserId: _owner.id,
          cancellationReason: 'محاولة ثانية',
        );

        expect(second.cancellation!.reversalMovementIds,
            first.cancellation!.reversalMovementIds);
        expect(await inventory.listAllMovements(), hasLength(6));
      });

      test('cancelled multi-item sale preserves document history', () async {
        final products = LocalProductRepository();
        final p1 = await products.createProduct(
          const ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
        );
        final p2 = await products.createProduct(
          const ProductDraft(name: 'شعير', unit: GrainUnit.kilogram),
        );
        final inventory = LocalInventoryRepository(productRepository: products);
        for (final p in [p1, p2]) {
          await inventory.createMovement(
            StockMovementDraft(
              productId: p.id,
              movementType: StockMovementType.openingBalance,
              quantityKg: 1000,
              createdByUserId: _owner.id,
            ),
          );
        }
        final customers = LocalCustomerRepository();
        final customer = await customers.createCustomer(
          const CustomerDraft(name: 'عميل اختبار', isActive: true),
        );
        final sales = LocalSaleRepository(
          productRepository: products,
          inventoryRepository: inventory,
        );
        final purchases = LocalPurchaseRepository(
          supplierRepository: LocalSupplierRepository(),
          productRepository: products,
          inventoryRepository: inventory,
        );
        final history = LocalDocumentHistoryRepository(
          purchaseRepository: purchases,
          saleRepository: sales,
          productRepository: products,
          inventoryRepository: inventory,
        );

        final sale = await sales.createSale(
          SaleDraft(
            productId: p1.id,
            quantityKg: 50,
            salePriceQirshPerKg: 700,
            createdByUserId: _owner.id,
            customerId: customer.id,
            items: [
              SaleLineItemDraft(
                productId: p1.id,
                quantityKg: 50,
                salePriceQirshPerKg: 700,
              ),
              SaleLineItemDraft(
                productId: p2.id,
                quantityKg: 30,
                salePriceQirshPerKg: 500,
              ),
            ],
          ),
        );

        final cancelled = await sales.cancelSale(
          saleId: sale.id,
          cancelledByUserId: _owner.id,
          cancellationReason: 'مرتجع',
        );

        expect(cancelled.cancellation!.cancelledByUserId, _owner.id);
        expect(cancelled.cancellation!.cancellationReason, 'مرتجع');
        expect(cancelled.cancellation!.originalDocumentId, sale.id);
        expect(cancelled.cancellation!.reversalMovementIds, hasLength(2));

        final entries = await history.listHistory();
        final saleEntry = entries.firstWhere((e) => e.id == sale.id);
        expect(saleEntry.isCancelled, isTrue);
        expect(saleEntry.cancellation!.originalDocumentId, sale.id);
        expect(saleEntry.cancellation!.reversalMovementIds, hasLength(2));
      });
    });

    group('D. Customer-bound sales', () {
      test('cash sale creates customer account cash entry', () async {
        final products = LocalProductRepository();
        final product = await products.createProduct(
          const ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
        );
        final inventory = LocalInventoryRepository(productRepository: products);
        await inventory.createMovement(
          StockMovementDraft(
            productId: product.id,
            movementType: StockMovementType.openingBalance,
            quantityKg: 1000,
            createdByUserId: _owner.id,
          ),
        );
        final customers = LocalCustomerRepository();
        final customer = await customers.createCustomer(
          const CustomerDraft(name: 'عميل اختبار', isActive: true),
        );
        final sales = LocalSaleRepository(
          productRepository: products,
          inventoryRepository: inventory,
        );
        final accountRepo = LocalCustomerAccountRepository(
          customerRepository: customers,
        );
        final controller = SaleController(
          saleRepository: sales,
          productRepository: products,
          inventoryRepository: inventory,
          customerRepository: customers,
          customerAccountRepository: accountRepo,
        );
        await controller.load(_owner);

        final result = await controller.createSale(
          user: _owner,
          productId: product.id,
          quantityKg: 100,
          salePriceQirshPerKg: 700,
          customerId: customer.id,
          paymentMode: SalePaymentMode.cash,
        );

        expect(result, isTrue);
        final entries = await accountRepo.listEntries();
        expect(entries, hasLength(1));
        expect(entries[0].type, CustomerAccountEntryType.cashSale);
        expect(entries[0].debitAmountQirsh, 70000);
        expect(entries[0].creditAmountQirsh, 70000);
        expect(entries[0].customerId, customer.id);
      });

      test('partial sale creates ledger with correct paid amount', () async {
        final products = LocalProductRepository();
        final product = await products.createProduct(
          const ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
        );
        final inventory = LocalInventoryRepository(productRepository: products);
        await inventory.createMovement(
          StockMovementDraft(
            productId: product.id,
            movementType: StockMovementType.openingBalance,
            quantityKg: 1000,
            createdByUserId: _owner.id,
          ),
        );
        final customers = LocalCustomerRepository();
        final customer = await customers.createCustomer(
          const CustomerDraft(name: 'عميل اختبار', isActive: true),
        );
        final sales = LocalSaleRepository(
          productRepository: products,
          inventoryRepository: inventory,
        );
        final accountRepo = LocalCustomerAccountRepository(
          customerRepository: customers,
        );
        final controller = SaleController(
          saleRepository: sales,
          productRepository: products,
          inventoryRepository: inventory,
          customerRepository: customers,
          customerAccountRepository: accountRepo,
        );
        await controller.load(_owner);

        final result = await controller.createSale(
          user: _owner,
          productId: product.id,
          quantityKg: 100,
          salePriceQirshPerKg: 700,
          customerId: customer.id,
          paymentMode: SalePaymentMode.partial,
          paidAmountQirsh: 30000,
        );

        expect(result, isTrue);
        final entries = await accountRepo.listEntries();
        expect(entries, hasLength(1));
        expect(entries[0].type, CustomerAccountEntryType.cashSale);
        expect(entries[0].debitAmountQirsh, 70000);
        expect(entries[0].creditAmountQirsh, 30000);
        expect(entries[0].customerId, customer.id);
      });
    });

    group('E. Backup/restore', () {
      test('backup includes multi-item data', () async {
        final products = LocalProductRepository();
        final p1 = await products.createProduct(
          const ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
        );
        final inventory = LocalInventoryRepository(productRepository: products);
        await inventory.createMovement(
          StockMovementDraft(
            productId: p1.id,
            movementType: StockMovementType.openingBalance,
            quantityKg: 1000,
            createdByUserId: _owner.id,
          ),
        );
        final customers = LocalCustomerRepository();
        final customer = await customers.createCustomer(
          const CustomerDraft(name: 'عميل اختبار', isActive: true),
        );
        final sales = LocalSaleRepository(
          productRepository: products,
          inventoryRepository: inventory,
        );
        final purchases = LocalPurchaseRepository(
          supplierRepository: LocalSupplierRepository(),
          productRepository: products,
          inventoryRepository: inventory,
        );

        await sales.createSale(
          SaleDraft(
            productId: p1.id,
            quantityKg: 10,
            salePriceQirshPerKg: 700,
            createdByUserId: _owner.id,
            customerId: customer.id,
            items: [
              SaleLineItemDraft(
                productId: p1.id,
                quantityKg: 10,
                salePriceQirshPerKg: 700,
              ),
            ],
            paymentMode: SalePaymentMode.partial,
            paidAmountQirsh: 5000,
          ),
        );

        final history = LocalDocumentHistoryRepository(
          purchaseRepository: purchases,
          saleRepository: sales,
          productRepository: products,
          inventoryRepository: inventory,
        );
        final exportService = BackupExportService(
          productRepository: products,
          inventoryRepository: inventory,
          supplierRepository: LocalSupplierRepository(),
          purchaseRepository: purchases,
          saleRepository: sales,
          documentHistoryRepository: history,
          customerRepository: customers,
          now: () => DateTime.utc(2026, 7, 6, 15, 42, 30),
        );

        final result = await exportService.createBackup();
        final decoded = jsonDecode(result.jsonText) as Map<String, Object?>;
        final data = decoded['data'] as Map<String, Object?>;
        final salesJson = data['sales'] as List<Object?>;
        expect(salesJson, hasLength(1));
        final saleJson = salesJson[0] as Map<String, Object?>;
        expect(saleJson['items'], isA<List<Object?>>());
        final items = saleJson['items'] as List<Object?>;
        expect(items, hasLength(1));
        expect((items[0] as Map<String, Object?>)['productId'], p1.id);
        expect((items[0] as Map<String, Object?>)['quantityKg'], 10);
        expect((items[0] as Map<String, Object?>)['salePriceQirshPerKg'], 700);
        expect((items[0] as Map<String, Object?>)['lineTotalQirsh'], 7000);
        expect(saleJson['paidAmountQirsh'], 5000);
      });

      test('restore preserves multi-item sale', () async {
        final sourceProducts = LocalProductRepository();
        final p1 = await sourceProducts.createProduct(
          const ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
        );
        final p2 = await sourceProducts.createProduct(
          const ProductDraft(name: 'شعير', unit: GrainUnit.kilogram),
        );
        final sourceInventory =
            LocalInventoryRepository(productRepository: sourceProducts);
        for (final p in [p1, p2]) {
          await sourceInventory.createMovement(
            StockMovementDraft(
              productId: p.id,
              movementType: StockMovementType.openingBalance,
              quantityKg: 1000,
              createdByUserId: _owner.id,
            ),
          );
        }
        final sourceCustomers = LocalCustomerRepository();
        final customer = await sourceCustomers.createCustomer(
          const CustomerDraft(name: 'عميل اختبار', isActive: true),
        );
        final sourceSuppliers = LocalSupplierRepository();
        final sourcePurchases = LocalPurchaseRepository(
          supplierRepository: sourceSuppliers,
          productRepository: sourceProducts,
          inventoryRepository: sourceInventory,
        );
        final sourceSales = LocalSaleRepository(
          productRepository: sourceProducts,
          inventoryRepository: sourceInventory,
        );

        await sourceSales.createSale(
          SaleDraft(
            productId: p1.id,
            quantityKg: 30,
            salePriceQirshPerKg: 700,
            createdByUserId: _owner.id,
            customerId: customer.id,
            items: [
              SaleLineItemDraft(
                productId: p1.id,
                quantityKg: 30,
                salePriceQirshPerKg: 700,
              ),
              SaleLineItemDraft(
                productId: p2.id,
                quantityKg: 20,
                salePriceQirshPerKg: 500,
              ),
            ],
          ),
        );

        final sourceHistory = LocalDocumentHistoryRepository(
          purchaseRepository: sourcePurchases,
          saleRepository: sourceSales,
          productRepository: sourceProducts,
          inventoryRepository: sourceInventory,
        );
        final sourceExport = BackupExportService(
          productRepository: sourceProducts,
          inventoryRepository: sourceInventory,
          supplierRepository: sourceSuppliers,
          purchaseRepository: sourcePurchases,
          saleRepository: sourceSales,
          documentHistoryRepository: sourceHistory,
          customerRepository: sourceCustomers,
          now: () => DateTime.utc(2026, 7, 6, 15, 42, 30),
        );
        final jsonText = (await sourceExport.createBackup()).jsonText;

        final targetProducts = LocalProductRepository();
        final targetInventory =
            LocalInventoryRepository(productRepository: targetProducts);
        final targetSuppliers = LocalSupplierRepository();
        final targetPurchases = LocalPurchaseRepository(
          supplierRepository: targetSuppliers,
          productRepository: targetProducts,
          inventoryRepository: targetInventory,
        );
        final targetCustomers = LocalCustomerRepository();
        final targetSales = LocalSaleRepository(
          productRepository: targetProducts,
          inventoryRepository: targetInventory,
        );
        final targetHistory = LocalDocumentHistoryRepository(
          purchaseRepository: targetPurchases,
          saleRepository: targetSales,
          productRepository: targetProducts,
          inventoryRepository: targetInventory,
        );

        final restoreService = BackupRestoreService(
          productRepository: targetProducts,
          inventoryRepository: targetInventory,
          supplierRepository: targetSuppliers,
          purchaseRepository: targetPurchases,
          saleRepository: targetSales,
          documentHistoryRepository: targetHistory,
          customerRepository: targetCustomers,
        );

        final restoreResult = await restoreService.restoreToEmpty(
          user: _owner,
          jsonText: jsonText,
        );

        expect(restoreResult.success, isTrue);
        final restoredSales = await targetSales.listSales();
        expect(restoredSales, hasLength(1));
        final restored = restoredSales[0];
        expect(restored.items, hasLength(2));
        expect(restored.items[0].productId, p1.id);
        expect(restored.items[0].quantityKg, 30);
        expect(restored.items[0].salePriceQirshPerKg, 700);
        expect(restored.items[0].lineTotalQirsh, 21000);
        expect(restored.items[1].productId, p2.id);
        expect(restored.items[1].quantityKg, 20);
        expect(restored.items[1].salePriceQirshPerKg, 500);
        expect(restored.items[1].lineTotalQirsh, 10000);
        expect(restored.totalQirsh, 31000);
        expect(restored.customerId, customer.id);
      });

      test('old single-item backup restores compatibly', () async {
        final backupJson = {
          'metadata': {
            'app': 'grain-warehouse-erp-lite',
            'backupVersion': 2,
            'generatedAt': '2026-07-06T15:42:30.000Z',
            'fileName': 'grain-warehouse-backup-20260706-154230.json',
            'restoreSupported': false,
            'warning':
                '\u0647\u0630\u0647 \u0646\u0633\u062e\u0629 \u0627\u062d\u062a\u064a\u0627\u0637\u064a\u0629 \u0644\u0644\u062a\u0635\u062f\u064a\u0631 \u0648\u0627\u0644\u062d\u0641\u0638.',
          },
          'counts': {
            'products': 1,
            'inventoryMovements': 2,
            'suppliers': 0,
            'purchases': 0,
            'sales': 1,
            'documentHistory': 1,
            'customers': 1,
            'customerLedgerEntries': 0,
            'customerCollections': 0,
            'expenses': 0,
            'auditLogs': 0,
          },
          'data': {
            'products': [
              {
                'id': 'old-product-1',
                'name': '\u0642\u0645\u062d',
                'unit': 'kilogram',
                'isActive': true,
                'createdAt': '2026-01-01T00:00:00.000Z',
                'updatedAt': '2026-01-01T00:00:00.000Z',
              },
            ],
            'inventoryMovements': [
              {
                'id': 'old-movement-1',
                'productId': 'old-product-1',
                'movementType': 'openingBalance',
                'quantityKg': 1000,
                'createdByUserId': 'test-owner',
                'createdAt': '2026-01-01T00:00:00.000Z',
              },
              {
                'id': 'old-movement-2',
                'productId': 'old-product-1',
                'movementType': 'sale',
                'quantityKg': 200,
                'createdByUserId': 'test-owner',
                'createdAt': '2026-01-01T00:00:00.000Z',
                'signedQuantityKg': -200,
                'originalDocumentId': 'old-sale-1',
              },
            ],
            'suppliers': [],
            'purchases': [],
            'sales': [
              {
                'id': 'old-sale-1',
                'productId': 'old-product-1',
                'quantityKg': 200,
                'salePriceQirshPerKg': 800,
                'totalQirsh': 160000,
                'createdByUserId': 'test-owner',
                'createdByUserName': '\u0645\u0627\u0644\u0643',
                'createdAt': '2026-01-01T00:00:00.000Z',
                'stockMovementId': 'old-movement-2',
                'paymentMode': 'cash',
                'customerId': 'old-customer-1',
                'isCancelled': false,
                'cancellation': null,
              },
            ],
            'documentHistory': [
              {
                'id': 'old-history-1',
                'type': 'sale',
                'status': 'active',
                'productId': 'old-product-1',
                'productName': '\u0642\u0645\u062d',
                'quantityKg': 200,
                'unitPricePiastersPerKg': 800,
                'totalPiasters': 160000,
                'createdByUserId': 'test-owner',
                'createdByUserName': '\u0645\u0627\u0644\u0643',
                'createdAt': '2026-01-01T00:00:00.000Z',
                'isCancelled': false,
                'originalMovementId': 'old-movement-2',
                'reversalMovementIds': [],
              },
            ],
            'customers': [
              {
                'id': 'old-customer-1',
                'name': '\u0639\u0645\u064a\u0644 \u0642\u062f\u064a\u0645',
                'isActive': true,
                'createdAt': '2026-01-01T00:00:00.000Z',
                'updatedAt': '2026-01-01T00:00:00.000Z',
              },
            ],
          },
        };

        final products = LocalProductRepository();
        final inventory = LocalInventoryRepository(productRepository: products);
        final suppliers = LocalSupplierRepository();
        final purchases = LocalPurchaseRepository(
          supplierRepository: suppliers,
          productRepository: products,
          inventoryRepository: inventory,
        );
        final customers = LocalCustomerRepository();
        final sales = LocalSaleRepository(
          productRepository: products,
          inventoryRepository: inventory,
        );
        final history = LocalDocumentHistoryRepository(
          purchaseRepository: purchases,
          saleRepository: sales,
          productRepository: products,
          inventoryRepository: inventory,
        );

        final restoreService = BackupRestoreService(
          productRepository: products,
          inventoryRepository: inventory,
          supplierRepository: suppliers,
          purchaseRepository: purchases,
          saleRepository: sales,
          documentHistoryRepository: history,
          customerRepository: customers,
        );

        final result = await restoreService.restoreToEmpty(
          user: _owner,
          jsonText: jsonEncode(backupJson),
        );

        expect(result.success, isTrue);
        final restoredSales = await sales.listSales();
        expect(restoredSales, hasLength(1));
        final restored = restoredSales[0];
        expect(restored.items, isEmpty);
        expect(restored.productId, 'old-product-1');
        expect(restored.quantityKg, 200);
        expect(restored.salePriceQirshPerKg, 800);
        expect(restored.totalQirsh, 160000);
        expect(restored.customerId, 'old-customer-1');
        expect(restored.paidAmountQirsh, isNull);
      });
    });
  });
}

final _now = DateTime(2026, 1, 1);

final _owner = AppUser(
  id: 'test-owner',
  name: '\u0645\u0627\u0644\u0643',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);
