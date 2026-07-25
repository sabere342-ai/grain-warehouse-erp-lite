import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/features/dashboard/dashboard_alerts_section.dart';

void main() {
  group('Phase 64 - Owner dashboard alerts data', () {
    group('OwnerAlertData.empty()', () {
      test('returns empty data with no alerts', () {
        final data = OwnerAlertData.empty();
        expect(data.hasAnyAlert, false);
        expect(data.customerAlerts, isEmpty);
        expect(data.supplierAlerts, isEmpty);
        expect(data.stockAlerts, isEmpty);
      });
    });

    group('OwnerAlertData.load()', () {
      late LocalProductRepository productRepo;
      late LocalInventoryRepository inventoryRepo;
      late LocalCustomerRepository customerRepo;
      late LocalCustomerAccountRepository customerAccountRepo;
      late LocalSupplierRepository supplierRepo;
      late LocalSupplierAccountRepository supplierAccountRepo;

      setUp(() {
        productRepo = LocalProductRepository();
        inventoryRepo =
            LocalInventoryRepository(productRepository: productRepo);
        customerRepo = LocalCustomerRepository();
        customerAccountRepo = LocalCustomerAccountRepository(
          customerRepository: customerRepo,
        );
        supplierRepo = LocalSupplierRepository();
        supplierAccountRepo = LocalSupplierAccountRepository(
          supplierRepository: supplierRepo,
        );
      });

      test('returns empty data when no customers, suppliers, or products exist',
          () async {
        final data = await OwnerAlertData.load(
          customerRepository: customerRepo,
          supplierRepository: supplierRepo,
          customerAccountRepository: customerAccountRepo,
          supplierAccountRepository: supplierAccountRepo,
          productRepository: productRepo,
          inventoryRepository: inventoryRepo,
        );
        expect(data.hasAnyAlert, false);
      });

      test('detects customer with outstanding balance', () async {
        await customerRepo.createCustomer(
          const CustomerDraft(name: 'عميل واحد'),
        );
        final customers = await customerRepo.listCustomers();
        await customerAccountRepo.createOpeningBalanceEntry(
          customerId: customers.first.id,
          amountQirsh: 10000000,
          createdByUserId: 'test-user',
        );

        final data = await OwnerAlertData.load(
          customerRepository: customerRepo,
          supplierRepository: supplierRepo,
          customerAccountRepository: customerAccountRepo,
          supplierAccountRepository: supplierAccountRepo,
          productRepository: productRepo,
          inventoryRepository: inventoryRepo,
        );
        expect(data.customerAlerts.length, 1);
        expect(data.customerAlerts.first.customerName, 'عميل واحد');
        expect(data.customerAlerts.first.balanceQirsh, 10000000);
        expect(data.supplierAlerts, isEmpty);
        expect(data.stockAlerts, isEmpty);
        expect(data.hasAnyAlert, true);
      });

      test('ignores customer with zero balance', () async {
        await customerRepo.createCustomer(
          const CustomerDraft(name: 'عميل صفر'),
        );

        final data = await OwnerAlertData.load(
          customerRepository: customerRepo,
          supplierRepository: supplierRepo,
          customerAccountRepository: customerAccountRepo,
          supplierAccountRepository: supplierAccountRepo,
          productRepository: productRepo,
          inventoryRepository: inventoryRepo,
        );
        expect(data.customerAlerts, isEmpty);
      });

      test('detects supplier with outstanding payable', () async {
        await supplierRepo.createSupplier(
          const SupplierDraft(name: 'مورد واحد'),
        );
        final suppliers = await supplierRepo.listSuppliers();
        await supplierAccountRepo.createOpeningBalanceEntry(
          supplierId: suppliers.first.id,
          amountQirsh: 5000000,
          createdByUserId: 'test-user',
        );

        final data = await OwnerAlertData.load(
          customerRepository: customerRepo,
          supplierRepository: supplierRepo,
          customerAccountRepository: customerAccountRepo,
          supplierAccountRepository: supplierAccountRepo,
          productRepository: productRepo,
          inventoryRepository: inventoryRepo,
        );
        expect(data.supplierAlerts.length, 1);
        expect(data.supplierAlerts.first.supplierName, 'مورد واحد');
        expect(data.supplierAlerts.first.payableQirsh, 5000000);
        expect(data.customerAlerts, isEmpty);
        expect(data.hasAnyAlert, true);
      });

      test('ignores supplier with zero balance', () async {
        await supplierRepo.createSupplier(
          const SupplierDraft(name: 'مورد صفر'),
        );

        final data = await OwnerAlertData.load(
          customerRepository: customerRepo,
          supplierRepository: supplierRepo,
          customerAccountRepository: customerAccountRepo,
          supplierAccountRepository: supplierAccountRepo,
          productRepository: productRepo,
          inventoryRepository: inventoryRepo,
        );
        expect(data.supplierAlerts, isEmpty);
      });

      test('detects low stock product (> 0 && <= 5 kg)', () async {
        await productRepo.createProduct(
          const ProductDraft(
            name: 'قمح',
            unit: GrainUnit.kilogram,
          ),
        );
        final products = await productRepo.listProducts();
        await inventoryRepo.createMovement(StockMovementDraft(
          productId: products.first.id,
          movementType: StockMovementType.openingBalance,
          quantityKg: 3,
          createdByUserId: 'test-user',
        ));

        final data = await OwnerAlertData.load(
          customerRepository: customerRepo,
          supplierRepository: supplierRepo,
          customerAccountRepository: customerAccountRepo,
          supplierAccountRepository: supplierAccountRepo,
          productRepository: productRepo,
          inventoryRepository: inventoryRepo,
        );
        expect(data.stockAlerts.length, 1);
        expect(data.stockAlerts.first.productName, 'قمح');
        expect(data.stockAlerts.first.stockKg, 3);
        expect(data.hasAnyAlert, true);
      });

      test('ignores stock above threshold (> 5 kg)', () async {
        await productRepo.createProduct(
          const ProductDraft(
            name: 'قمح',
            unit: GrainUnit.kilogram,
          ),
        );
        final products = await productRepo.listProducts();
        await inventoryRepo.createMovement(StockMovementDraft(
          productId: products.first.id,
          movementType: StockMovementType.openingBalance,
          quantityKg: 100,
          createdByUserId: 'test-user',
        ));

        final data = await OwnerAlertData.load(
          customerRepository: customerRepo,
          supplierRepository: supplierRepo,
          customerAccountRepository: customerAccountRepo,
          supplierAccountRepository: supplierAccountRepo,
          productRepository: productRepo,
          inventoryRepository: inventoryRepo,
        );
        expect(data.stockAlerts, isEmpty);
      });

      test('ignores zero stock', () async {
        await productRepo.createProduct(
          const ProductDraft(
            name: 'قمح',
            unit: GrainUnit.kilogram,
          ),
        );

        final data = await OwnerAlertData.load(
          customerRepository: customerRepo,
          supplierRepository: supplierRepo,
          customerAccountRepository: customerAccountRepo,
          supplierAccountRepository: supplierAccountRepo,
          productRepository: productRepo,
          inventoryRepository: inventoryRepo,
        );
        expect(data.stockAlerts, isEmpty);
      });

      test('sorts customer alerts descending by balance', () async {
        await customerRepo.createCustomer(const CustomerDraft(name: 'عميل أ'));
        await customerRepo.createCustomer(const CustomerDraft(name: 'عميل ب'));
        await customerRepo.createCustomer(const CustomerDraft(name: 'عميل ج'));
        final customers = await customerRepo.listCustomers();
        await customerAccountRepo.createOpeningBalanceEntry(
          customerId: customers[0].id,
          amountQirsh: 3000000,
          createdByUserId: 'test-user',
        );
        await customerAccountRepo.createOpeningBalanceEntry(
          customerId: customers[1].id,
          amountQirsh: 10000000,
          createdByUserId: 'test-user',
        );
        await customerAccountRepo.createOpeningBalanceEntry(
          customerId: customers[2].id,
          amountQirsh: 5000000,
          createdByUserId: 'test-user',
        );

        final data = await OwnerAlertData.load(
          customerRepository: customerRepo,
          supplierRepository: supplierRepo,
          customerAccountRepository: customerAccountRepo,
          supplierAccountRepository: supplierAccountRepo,
          productRepository: productRepo,
          inventoryRepository: inventoryRepo,
        );
        expect(data.customerAlerts.length, 3);
        expect(data.customerAlerts[0].balanceQirsh, 10000000);
        expect(data.customerAlerts[1].balanceQirsh, 5000000);
        expect(data.customerAlerts[2].balanceQirsh, 3000000);
      });

      test('returns all customers with balances (UI limits display)', () async {
        for (int i = 1; i <= 7; i++) {
          await customerRepo.createCustomer(CustomerDraft(name: 'عميل $i'));
        }
        final customers = await customerRepo.listCustomers();
        for (int i = 0; i < customers.length; i++) {
          await customerAccountRepo.createOpeningBalanceEntry(
            customerId: customers[i].id,
            amountQirsh: (i + 1) * 1000000,
            createdByUserId: 'test-user',
          );
        }

        final data = await OwnerAlertData.load(
          customerRepository: customerRepo,
          supplierRepository: supplierRepo,
          customerAccountRepository: customerAccountRepo,
          supplierAccountRepository: supplierAccountRepo,
          productRepository: productRepo,
          inventoryRepository: inventoryRepo,
        );
        expect(data.customerAlerts.length, 7);
      });

      test('sorts supplier alerts descending by payable', () async {
        await supplierRepo.createSupplier(const SupplierDraft(name: 'مورد أ'));
        await supplierRepo.createSupplier(const SupplierDraft(name: 'مورد ب'));
        await supplierRepo.createSupplier(const SupplierDraft(name: 'مورد ج'));
        final suppliers = await supplierRepo.listSuppliers();
        await supplierAccountRepo.createOpeningBalanceEntry(
          supplierId: suppliers[0].id,
          amountQirsh: 8000000,
          createdByUserId: 'test-user',
        );
        await supplierAccountRepo.createOpeningBalanceEntry(
          supplierId: suppliers[1].id,
          amountQirsh: 2000000,
          createdByUserId: 'test-user',
        );
        await supplierAccountRepo.createOpeningBalanceEntry(
          supplierId: suppliers[2].id,
          amountQirsh: 6000000,
          createdByUserId: 'test-user',
        );

        final data = await OwnerAlertData.load(
          customerRepository: customerRepo,
          supplierRepository: supplierRepo,
          customerAccountRepository: customerAccountRepo,
          supplierAccountRepository: supplierAccountRepo,
          productRepository: productRepo,
          inventoryRepository: inventoryRepo,
        );
        expect(data.supplierAlerts.length, 3);
        expect(data.supplierAlerts[0].payableQirsh, 8000000);
        expect(data.supplierAlerts[1].payableQirsh, 6000000);
        expect(data.supplierAlerts[2].payableQirsh, 2000000);
      });

      test('returns all suppliers with payables (UI limits display)', () async {
        for (int i = 1; i <= 6; i++) {
          await supplierRepo.createSupplier(SupplierDraft(name: 'مورد $i'));
        }
        final suppliers = await supplierRepo.listSuppliers();
        for (int i = 0; i < suppliers.length; i++) {
          await supplierAccountRepo.createOpeningBalanceEntry(
            supplierId: suppliers[i].id,
            amountQirsh: (i + 1) * 1000000,
            createdByUserId: 'test-user',
          );
        }

        final data = await OwnerAlertData.load(
          customerRepository: customerRepo,
          supplierRepository: supplierRepo,
          customerAccountRepository: customerAccountRepo,
          supplierAccountRepository: supplierAccountRepo,
          productRepository: productRepo,
          inventoryRepository: inventoryRepo,
        );
        expect(data.supplierAlerts.length, 6);
      });

      test('is read-only - does not modify any repository', () async {
        final initialCustomers = await customerRepo.listCustomers();
        final initialSuppliers = await supplierRepo.listSuppliers();
        final initialProducts = await productRepo.listProducts();

        await OwnerAlertData.load(
          customerRepository: customerRepo,
          supplierRepository: supplierRepo,
          customerAccountRepository: customerAccountRepo,
          supplierAccountRepository: supplierAccountRepo,
          productRepository: productRepo,
          inventoryRepository: inventoryRepo,
        );

        expect(await customerRepo.listCustomers(), initialCustomers);
        expect(await supplierRepo.listSuppliers(), initialSuppliers);
        expect(await productRepo.listProducts(), initialProducts);
      });

      test('combines customer, supplier, and stock alerts', () async {
        await customerRepo.createCustomer(
          const CustomerDraft(name: 'عميل واحد'),
        );
        final customers = await customerRepo.listCustomers();
        await customerAccountRepo.createOpeningBalanceEntry(
          customerId: customers.first.id,
          amountQirsh: 10000000,
          createdByUserId: 'test-user',
        );

        await supplierRepo.createSupplier(
          const SupplierDraft(name: 'مورد واحد'),
        );
        final suppliers = await supplierRepo.listSuppliers();
        await supplierAccountRepo.createOpeningBalanceEntry(
          supplierId: suppliers.first.id,
          amountQirsh: 5000000,
          createdByUserId: 'test-user',
        );

        await productRepo.createProduct(
          const ProductDraft(name: 'شعير', unit: GrainUnit.kilogram),
        );
        final products = await productRepo.listProducts();
        await inventoryRepo.createMovement(StockMovementDraft(
          productId: products.first.id,
          movementType: StockMovementType.openingBalance,
          quantityKg: 3,
          createdByUserId: 'test-user',
        ));

        final data = await OwnerAlertData.load(
          customerRepository: customerRepo,
          supplierRepository: supplierRepo,
          customerAccountRepository: customerAccountRepo,
          supplierAccountRepository: supplierAccountRepo,
          productRepository: productRepo,
          inventoryRepository: inventoryRepo,
        );
        expect(data.customerAlerts.length, 1);
        expect(data.supplierAlerts.length, 1);
        expect(data.stockAlerts.length, 1);
        expect(data.hasAnyAlert, true);
      });
    });
  });
}
