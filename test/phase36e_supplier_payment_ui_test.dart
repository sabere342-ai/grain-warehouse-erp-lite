import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/dashboard/dashboard_controller.dart';
import 'package:grain_warehouse_erp_lite/core/dashboard/dashboard_service.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payment.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

void main() {
  group('Phase 36E - Supplier payment UI', () {
    group('Supplier account repository payment', () {
      late LocalSupplierRepository supplierRepo;
      late LocalSupplierAccountRepository repo;

      setUp(() async {
        supplierRepo = LocalSupplierRepository();
        repo = LocalSupplierAccountRepository(
          supplierRepository: supplierRepo,
        );
      });

      test('payment reduces balance correctly', () async {
        final supplier = await supplierRepo.createSupplier(
          SupplierDraft(name: 'مورد', phone: '0111111111'),
        );
        final purchase = PurchaseIntake(
          id: 'pin-pay-1',
          supplierId: supplier.id,
          productId: 'prod-1',
          quantityKg: 100,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 2000,
          totalAmountPiasters: 200000,
          createdByUserId: 'owner-1',
          createdAt: DateTime.now(),
          stockMovementId: 'mov-pay-1',
        );

        await repo.createPurchaseEntry(purchase: purchase);
        expect(await repo.balanceForSupplier(supplier.id), 200000);

        await repo.createPayment(SupplierPaymentDraft(
          supplierId: supplier.id,
          date: DateTime.now(),
          amountQirsh: 80000,
          createdByUserId: 'owner-1',
          notes: 'دفعة نقدية',
        ));

        final balance = await repo.balanceForSupplier(supplier.id);
        expect(balance, 120000);

        final payments = await repo.listPayments();
        expect(payments.length, 1);
        expect(payments.first.amountQirsh, 80000);
        expect(payments.first.notes, 'دفعة نقدية');

        final entries = await repo.listEntries();
        expect(entries.length, 2);
        expect(entries[1].type, SupplierAccountEntryType.payment);
        expect(entries[1].creditAmountQirsh, 80000);
      });

      test('full payment zeros the balance', () async {
        final supplier = await supplierRepo.createSupplier(
          SupplierDraft(name: 'مورد'),
        );
        final purchase = PurchaseIntake(
          id: 'pin-pay-2',
          supplierId: supplier.id,
          productId: 'prod-1',
          quantityKg: 50,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 1000,
          totalAmountPiasters: 50000,
          createdByUserId: 'owner-1',
          createdAt: DateTime.now(),
          stockMovementId: 'mov-pay-2',
        );

        await repo.createPurchaseEntry(purchase: purchase);
        await repo.createPayment(SupplierPaymentDraft(
          supplierId: supplier.id,
          date: DateTime.now(),
          amountQirsh: 50000,
          createdByUserId: 'owner-1',
        ));

        expect(await repo.balanceForSupplier(supplier.id), 0);
      });

      test('balancesBySupplierId after payments', () async {
        final supplier1 = await supplierRepo.createSupplier(
          SupplierDraft(name: 'مورد 1'),
        );
        final supplier2 = await supplierRepo.createSupplier(
          SupplierDraft(name: 'مورد 2'),
        );

        final purchase1 = PurchaseIntake(
          id: 'pin-bal-pay-1',
          supplierId: supplier1.id,
          productId: 'prod-1',
          quantityKg: 100,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 2000,
          totalAmountPiasters: 200000,
          createdByUserId: 'owner-1',
          createdAt: DateTime.now(),
          stockMovementId: 'mov-bal-pay-1',
        );
        final purchase2 = PurchaseIntake(
          id: 'pin-bal-pay-2',
          supplierId: supplier2.id,
          productId: 'prod-1',
          quantityKg: 50,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 1000,
          totalAmountPiasters: 50000,
          createdByUserId: 'owner-1',
          createdAt: DateTime.now(),
          stockMovementId: 'mov-bal-pay-2',
        );

        await repo.createPurchaseEntry(purchase: purchase1);
        await repo.createPurchaseEntry(purchase: purchase2);
        await repo.createPayment(SupplierPaymentDraft(
          supplierId: supplier1.id,
          date: DateTime.now(),
          amountQirsh: 100000,
          createdByUserId: 'owner-1',
        ));

        final balances = await repo.balancesBySupplierId();
        expect(balances[supplier1.id], 100000);
        expect(balances[supplier2.id], 50000);
      });

      test('statement after payment shows running balance', () async {
        final supplier = await supplierRepo.createSupplier(
          SupplierDraft(name: 'مورد'),
        );

        final purchase = PurchaseIntake(
          id: 'pin-stm-pay',
          supplierId: supplier.id,
          productId: 'prod-1',
          quantityKg: 100,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 2000,
          totalAmountPiasters: 200000,
          createdByUserId: 'owner-1',
          createdAt: DateTime.now(),
          stockMovementId: 'mov-stm-pay',
        );

        await repo.createPurchaseEntry(purchase: purchase);
        await repo.createPayment(SupplierPaymentDraft(
          supplierId: supplier.id,
          date: DateTime.now(),
          amountQirsh: 60000,
          createdByUserId: 'owner-1',
        ));

        final statement = await repo.statementForSupplier(supplier.id);
        expect(statement.finalBalanceQirsh, 140000);
        expect(statement.lines.length, 2);
        expect(statement.lines[0].runningBalanceQirsh, 200000);
        expect(statement.lines[1].runningBalanceQirsh, 140000);
      });

      test('payment with empty supplierId is rejected', () async {
        expect(
          () => repo.createPayment(SupplierPaymentDraft(
            supplierId: '  ',
            date: DateTime.now(),
            amountQirsh: 1000,
            createdByUserId: 'owner-1',
          )),
          throwsArgumentError,
        );
      });

      test('payment with empty userId is rejected', () async {
        final supplier = await supplierRepo.createSupplier(
          SupplierDraft(name: 'مورد', phone: '0111111111'),
        );
        final purchase = PurchaseIntake(
          id: 'pin-empty-user',
          supplierId: supplier.id,
          productId: 'prod-1',
          quantityKg: 100,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 2000,
          totalAmountPiasters: 200000,
          createdByUserId: 'owner-1',
          createdAt: DateTime.now(),
          stockMovementId: 'mov-empty-user',
        );
        await repo.createPurchaseEntry(purchase: purchase);

        expect(
          () => repo.createPayment(SupplierPaymentDraft(
            supplierId: supplier.id,
            date: DateTime.now(),
            amountQirsh: 1000,
            createdByUserId: '  ',
          )),
          throwsArgumentError,
        );
      });
    });

    group('Phase 36E - Dashboard with supplier payments', () {
      late LocalProductRepository productRepo;
      late LocalInventoryRepository inventoryRepo;
      late LocalSaleRepository saleRepo;
      late LocalExpenseRepository expenseRepo;
      late LocalCustomerRepository customerRepo;
      late LocalCustomerAccountRepository customerAccountRepo;
      late LocalSupplierRepository supplierRepo;
      late LocalSupplierAccountRepository supplierAccountRepo;
      late DashboardService service;

      setUp(() {
        productRepo = LocalProductRepository();
        inventoryRepo = LocalInventoryRepository(productRepository: productRepo);
        saleRepo = LocalSaleRepository(
          productRepository: productRepo,
          inventoryRepository: inventoryRepo,
        );
        expenseRepo = LocalExpenseRepository();
        customerRepo = LocalCustomerRepository();
        customerAccountRepo = LocalCustomerAccountRepository(
          customerRepository: customerRepo,
        );
        supplierRepo = LocalSupplierRepository();
        supplierAccountRepo = LocalSupplierAccountRepository(
          supplierRepository: supplierRepo,
        );
        service = DashboardService(
          saleRepository: saleRepo,
          inventoryRepository: inventoryRepo,
          productRepository: productRepo,
          expenseRepository: expenseRepo,
          customerAccountRepository: customerAccountRepo,
          supplierAccountRepository: supplierAccountRepo,
        );
      });

      test('cash balance correctly subtracts multiple supplier payments',
          () async {
        final product = await productRepo.createProduct(
          ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
        );
        await inventoryRepo.createMovement(
          StockMovementDraft(
            productId: product.id,
            movementType: StockMovementType.openingBalance,
            quantityKg: 1000,
            createdByUserId: 'owner-1',
          ),
        );

        final supplier = await supplierRepo.createSupplier(
          SupplierDraft(name: 'مورد'),
        );
        await supplierAccountRepo.createPurchaseEntry(
          purchase: PurchaseIntake(
            id: 'pin-dash-pay-1',
            supplierId: supplier.id,
            productId: product.id,
            quantityKg: 100,
            entryUnit: GrainUnit.kilogram,
            unitPricePiastersPerKg: 1000,
            totalAmountPiasters: 100000,
            createdByUserId: 'owner-1',
            createdAt: DateTime.now(),
            stockMovementId: 'mov-dash-pay-1',
          ),
        );

        final cashCustomer = await customerRepo.createCustomer(
          const CustomerDraft(name: 'عميل نقدي', isActive: true),
        );
        await saleRepo.createSale(SaleDraft(
          productId: product.id,
          quantityKg: 200,
          salePriceQirshPerKg: 2000,
          createdByUserId: 'owner-1',
          paymentMode: SalePaymentMode.cash,
          customerId: cashCustomer.id,
        ));

        await supplierAccountRepo.createPayment(SupplierPaymentDraft(
          supplierId: supplier.id,
          date: DateTime.now(),
          amountQirsh: 30000,
          createdByUserId: 'owner-1',
        ));
        await supplierAccountRepo.createPayment(SupplierPaymentDraft(
          supplierId: supplier.id,
          date: DateTime.now(),
          amountQirsh: 20000,
          createdByUserId: 'owner-1',
        ));

        final data = await service.load();
        expect(data.cashBalanceQirsh, 350000);
      });

      test('DashboardController loads data correctly', () async {
        final controller = DashboardController(service: service);
        await controller.load();
        expect(controller.isLoading, false);
        expect(controller.data.hasData, false);
      });
    });

    group('Phase 36E - Purchase repo integration with payments', () {
      late LocalSupplierRepository supplierRepo;
      late LocalProductRepository productRepo;
      late LocalInventoryRepository inventoryRepo;
      late LocalSupplierAccountRepository supplierAccountRepo;
      late LocalPurchaseRepository purchaseRepo;

      setUp(() {
        supplierRepo = LocalSupplierRepository();
        productRepo = LocalProductRepository();
        inventoryRepo = LocalInventoryRepository(productRepository: productRepo);
        supplierAccountRepo = LocalSupplierAccountRepository(
          supplierRepository: supplierRepo,
        );
        purchaseRepo = LocalPurchaseRepository(
          supplierRepository: supplierRepo,
          productRepository: productRepo,
          inventoryRepository: inventoryRepo,
          supplierAccountRepository: supplierAccountRepo,
        );
      });

      test('purchase creates supplier entry and payment reduces balance',
          () async {
        final supplier = await supplierRepo.createSupplier(
          SupplierDraft(name: 'مورد القمح'),
        );
        final product = await productRepo.createProduct(
          ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
        );
        await inventoryRepo.createMovement(
          StockMovementDraft(
            productId: product.id,
            movementType: StockMovementType.openingBalance,
            quantityKg: 5000,
            createdByUserId: 'owner-1',
          ),
        );

        await purchaseRepo.createPurchaseIntake(
          PurchaseIntakeDraft(
            supplierId: supplier.id,
            productId: product.id,
            quantityKg: 1000,
            entryUnit: GrainUnit.kilogram,
            unitPricePiastersPerKg: 1500,
            createdByUserId: 'owner-1',
          ),
        );

        expect(
          await supplierAccountRepo.balanceForSupplier(supplier.id),
          1500000,
        );

        await supplierAccountRepo.createPayment(SupplierPaymentDraft(
          supplierId: supplier.id,
          date: DateTime.now(),
          amountQirsh: 500000,
          createdByUserId: 'owner-1',
        ));

        expect(
          await supplierAccountRepo.balanceForSupplier(supplier.id),
          1000000,
        );
      });

      test('cancelling purchase after payment is blocked', () async {
        final supplier = await supplierRepo.createSupplier(
          SupplierDraft(name: 'مورد'),
        );
        final product = await productRepo.createProduct(
          ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
        );
        await inventoryRepo.createMovement(
          StockMovementDraft(
            productId: product.id,
            movementType: StockMovementType.openingBalance,
            quantityKg: 5000,
            createdByUserId: 'owner-1',
          ),
        );

        await purchaseRepo.createPurchaseIntake(
          PurchaseIntakeDraft(
            supplierId: supplier.id,
            productId: product.id,
            quantityKg: 500,
            entryUnit: GrainUnit.kilogram,
            unitPricePiastersPerKg: 1000,
            createdByUserId: 'owner-1',
          ),
        );

        await supplierAccountRepo.createPayment(SupplierPaymentDraft(
          supplierId: supplier.id,
          date: DateTime.now(),
          amountQirsh: 100000,
          createdByUserId: 'owner-1',
        ));

        final intakes = await purchaseRepo.listPurchaseIntakes();
        expect(intakes.length, 1);

        expect(
          () => purchaseRepo.cancelPurchaseIntake(
            purchaseIntakeId: intakes.first.id,
            cancelledByUserId: 'owner-1',
            cancellationReason: 'اختبار',
          ),
          throwsStateError,
        );
      });
    });
  });
}
