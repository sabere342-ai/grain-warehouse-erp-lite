import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/dashboard/dashboard_controller.dart';
import 'package:grain_warehouse_erp_lite/core/dashboard/dashboard_service.dart';
import 'package:grain_warehouse_erp_lite/core/documents/cancellation_metadata.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
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
  group('Phase 36A - Dashboard live data', () {
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
        financialAccountRepository: LocalFinancialAccountRepository(),
        supplierAccountRepository: supplierAccountRepo,
      );
    });

    test('returns empty data when no data exists', () async {
      final data = await service.load();
      expect(data.hasData, false);
      expect(data.todaySalesQirsh, 0);
      expect(data.cashBalanceQirsh, 0);
      expect(data.totalStockKg, 0);
      expect(data.stockAlertCount, 0);
    });

    test('computes today sales correctly', () async {
      final product = await productRepo.createProduct(
        const ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
      );
      await inventoryRepo.createMovement(
        StockMovementDraft(
          productId: product.id,
          movementType: StockMovementType.openingBalance,
          quantityKg: 1000,
          createdByUserId: 'owner-1',
        ),
      );
      final cashCustomer = await customerRepo.createCustomer(
        const CustomerDraft(name: 'عميل نقدي', isActive: true),
      );

      await saleRepo.createSale(SaleDraft(
        productId: product.id,
        quantityKg: 100,
        salePriceQirshPerKg: 2000,
        createdByUserId: 'owner-1',
        paymentMode: SalePaymentMode.cash,
        customerId: cashCustomer.id,
      ));

      final data = await service.load();
      expect(data.todaySalesQirsh, 200000);
      expect(data.todayCashSalesQirsh, 200000);
      expect(data.hasData, true);
    });

    test('does not infer a financial balance from sales and supplier payments',
        () async {
      final product = await productRepo.createProduct(
        const ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
      );
      await inventoryRepo.createMovement(
        StockMovementDraft(
          productId: product.id,
          movementType: StockMovementType.openingBalance,
          quantityKg: 1000,
          createdByUserId: 'owner-1',
        ),
      );

      final supplier = await supplierRepo.createSupplier(const SupplierDraft(
        name: 'مورد',
      ));
      await supplierAccountRepo.createPurchaseEntry(
        purchase: PurchaseIntake(
          id: 'pin-cb-1',
          supplierId: supplier.id,
          productId: product.id,
          quantityKg: 100,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 1000,
          totalAmountPiasters: 100000,
          createdByUserId: 'owner-1',
          createdAt: DateTime.now(),
          stockMovementId: 'mov-cb',
        ),
      );

      final cashCustomer = await customerRepo.createCustomer(
        const CustomerDraft(name: 'عميل نقدي', isActive: true),
      );
      await saleRepo.createSale(SaleDraft(
        productId: product.id,
        quantityKg: 100,
        salePriceQirshPerKg: 2000,
        createdByUserId: 'owner-1',
        paymentMode: SalePaymentMode.cash,
        customerId: cashCustomer.id,
      ));

      await supplierAccountRepo.createPayment(SupplierPaymentDraft(
        supplierId: supplier.id,
        date: DateTime.now(),
        amountQirsh: 50000,
        createdByUserId: 'owner-1',
      ));

      final data = await service.load();
      expect(data.cashBalanceQirsh, 0);
    });

    test('DashboardController loads and provides data', () async {
      final controller = DashboardController(service: service);
      expect(controller.isLoading, false);
      expect(controller.data.hasData, false);

      await controller.load();
      expect(controller.isLoading, false);
      expect(controller.data.hasData, false);
    });
  });

  group('Phase 36B - Supplier purchase link', () {
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

    test('auto-fills supplier snapshot on create', () async {
      final supplier = await supplierRepo.createSupplier(const SupplierDraft(
        name: 'مورد القمح',
        phone: '0123456789',
        address: 'القاهرة',
      ));
      final product = await productRepo.createProduct(
        const ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
      );
      await inventoryRepo.createMovement(
        StockMovementDraft(
          productId: product.id,
          movementType: StockMovementType.openingBalance,
          quantityKg: 5000,
          createdByUserId: 'owner-1',
        ),
      );

      final purchase = await purchaseRepo.createPurchaseIntake(
        PurchaseIntakeDraft(
          supplierId: supplier.id,
          productId: product.id,
          quantityKg: 1000,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 1500,
          createdByUserId: 'owner-1',
        ),
      );

      expect(purchase.supplierName, 'مورد القمح');
      expect(purchase.supplierPhone, '0123456789');
      expect(purchase.supplierAddress, 'القاهرة');
    });

    test('override supplier snapshot fields', () async {
      final supplier = await supplierRepo.createSupplier(const SupplierDraft(
        name: 'مورد القمح',
        phone: '0123456789',
        address: 'القاهرة',
      ));
      final product = await productRepo.createProduct(
        const ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
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

      final purchases = await purchaseRepo.listPurchaseIntakes();
      expect(purchases.length, 1);
      final purchase = purchases.first;
      expect(purchase.supplierName, 'مورد القمح');
    });

    test('creates supplier ledger entry on purchase', () async {
      final supplier = await supplierRepo.createSupplier(const SupplierDraft(
        name: 'مورد القمح',
      ));
      final product = await productRepo.createProduct(
        const ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
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

      final balance = await supplierAccountRepo.balanceForSupplier(supplier.id);
      expect(balance, 1500000);

      final entries = await supplierAccountRepo.listEntries();
      expect(entries.length, 1);
      expect(entries.first.debitAmountQirsh, 1500000);
      expect(entries.first.creditAmountQirsh, 0);
    });
  });

  group('Phase 36C - Supplier account repository', () {
    late LocalSupplierRepository supplierRepo;
    late LocalSupplierAccountRepository repo;
    late Supplier supplier;

    setUp(() async {
      supplierRepo = LocalSupplierRepository();
      repo = LocalSupplierAccountRepository(
        supplierRepository: supplierRepo,
      );
      supplier = await supplierRepo.createSupplier(const SupplierDraft(
        name: 'مورد',
        phone: '0111111111',
      ));
    });

    test('balance is zero when no entries', () async {
      final balance = await repo.balanceForSupplier(supplier.id);
      expect(balance, 0);
    });

    test('createPurchaseEntry increases balance', () async {
      final purchase = PurchaseIntake(
        id: 'pin-test-1',
        supplierId: supplier.id,
        productId: 'prod-1',
        quantityKg: 100,
        entryUnit: GrainUnit.kilogram,
        unitPricePiastersPerKg: 2000,
        totalAmountPiasters: 200000,
        createdByUserId: 'owner-1',
        createdAt: DateTime.now(),
        stockMovementId: 'mov-1',
      );

      await repo.createPurchaseEntry(purchase: purchase);
      final balance = await repo.balanceForSupplier(supplier.id);
      expect(balance, 200000);
    });

    test('createPayment reduces balance', () async {
      final purchase = PurchaseIntake(
        id: 'pin-test-2',
        supplierId: supplier.id,
        productId: 'prod-1',
        quantityKg: 100,
        entryUnit: GrainUnit.kilogram,
        unitPricePiastersPerKg: 2000,
        totalAmountPiasters: 200000,
        createdByUserId: 'owner-1',
        createdAt: DateTime.now(),
        stockMovementId: 'mov-2',
      );

      await repo.createPurchaseEntry(purchase: purchase);
      await repo.createPayment(SupplierPaymentDraft(
        supplierId: supplier.id,
        date: DateTime.now(),
        amountQirsh: 50000,
        createdByUserId: 'owner-1',
      ));

      final balance = await repo.balanceForSupplier(supplier.id);
      expect(balance, 150000);
    });

    test('payment cannot exceed balance', () async {
      final purchase = PurchaseIntake(
        id: 'pin-test-3',
        supplierId: supplier.id,
        productId: 'prod-1',
        quantityKg: 100,
        entryUnit: GrainUnit.kilogram,
        unitPricePiastersPerKg: 2000,
        totalAmountPiasters: 200000,
        createdByUserId: 'owner-1',
        createdAt: DateTime.now(),
        stockMovementId: 'mov-3',
      );

      await repo.createPurchaseEntry(purchase: purchase);
      expect(
        () => repo.createPayment(SupplierPaymentDraft(
          supplierId: supplier.id,
          date: DateTime.now(),
          amountQirsh: 300000,
          createdByUserId: 'owner-1',
        )),
        throwsStateError,
      );
    });

    test('payment to zero balance is rejected', () async {
      expect(
        () => repo.createPayment(SupplierPaymentDraft(
          supplierId: supplier.id,
          date: DateTime.now(),
          amountQirsh: 100,
          createdByUserId: 'owner-1',
        )),
        throwsStateError,
      );
    });

    test('statement returns correct running balance', () async {
      final purchase1 = PurchaseIntake(
        id: 'pin-test-4a',
        supplierId: supplier.id,
        productId: 'prod-1',
        quantityKg: 100,
        entryUnit: GrainUnit.kilogram,
        unitPricePiastersPerKg: 2000,
        totalAmountPiasters: 200000,
        createdByUserId: 'owner-1',
        createdAt: DateTime.now(),
        stockMovementId: 'mov-4a',
      );
      final purchase2 = PurchaseIntake(
        id: 'pin-test-4b',
        supplierId: supplier.id,
        productId: 'prod-1',
        quantityKg: 50,
        entryUnit: GrainUnit.kilogram,
        unitPricePiastersPerKg: 2000,
        totalAmountPiasters: 100000,
        createdByUserId: 'owner-1',
        createdAt: DateTime.now(),
        stockMovementId: 'mov-4b',
      );

      await repo.createPurchaseEntry(purchase: purchase1);
      await repo.createPurchaseEntry(purchase: purchase2);
      await repo.createPayment(SupplierPaymentDraft(
        supplierId: supplier.id,
        date: DateTime.now(),
        amountQirsh: 50000,
        createdByUserId: 'owner-1',
      ));

      final statement = await repo.statementForSupplier(supplier.id);
      expect(statement.finalBalanceQirsh, 250000);
      expect(statement.lines.length, 3);
      expect(statement.lines[0].runningBalanceQirsh, 200000);
      expect(statement.lines[1].runningBalanceQirsh, 300000);
      expect(statement.lines[2].runningBalanceQirsh, 250000);
    });

    test('reversePurchaseEntry reverses entry on cancellation', () async {
      final purchase = PurchaseIntake(
        id: 'pin-test-cancel',
        supplierId: supplier.id,
        productId: 'prod-1',
        quantityKg: 100,
        entryUnit: GrainUnit.kilogram,
        unitPricePiastersPerKg: 2000,
        totalAmountPiasters: 200000,
        createdByUserId: 'owner-1',
        createdAt: DateTime.now(),
        stockMovementId: 'mov-cancel',
      );

      await repo.createPurchaseEntry(purchase: purchase);
      expect(await repo.balanceForSupplier(supplier.id), 200000);

      final cancelled = purchase.copyWith(
        cancellation: CancellationMetadata(
          cancelledAt: DateTime.now(),
          cancelledByUserId: 'owner-1',
          cancellationReason: 'خطأ في الكمية',
          originalDocumentId: purchase.id,
          reversalMovementIds: ['rev-1'],
        ),
      );

      await repo.reversePurchaseEntry(
        cancelledPurchase: cancelled,
        cancelledByUserId: 'owner-1',
        cancellationReason: 'خطأ في الكمية',
      );

      final balance = await repo.balanceForSupplier(supplier.id);
      expect(balance, 0);

      final entries = await repo.listEntries();
      expect(entries.length, 2);
      expect(entries[1].creditAmountQirsh, 200000);
      expect(entries[1].sourceDocumentType, 'purchaseCancellation');
    });

    test('reversePurchaseEntry prevents reversal when payments made', () async {
      final purchase = PurchaseIntake(
        id: 'pin-test-norev',
        supplierId: supplier.id,
        productId: 'prod-1',
        quantityKg: 100,
        entryUnit: GrainUnit.kilogram,
        unitPricePiastersPerKg: 2000,
        totalAmountPiasters: 200000,
        createdByUserId: 'owner-1',
        createdAt: DateTime.now(),
        stockMovementId: 'mov-norev',
      );

      await repo.createPurchaseEntry(purchase: purchase);
      await repo.createPayment(SupplierPaymentDraft(
        supplierId: supplier.id,
        date: DateTime.now(),
        amountQirsh: 100000,
        createdByUserId: 'owner-1',
      ));

      final cancelled = purchase.copyWith(
        cancellation: CancellationMetadata(
          cancelledAt: DateTime.now(),
          cancelledByUserId: 'owner-1',
          cancellationReason: 'خطأ',
          originalDocumentId: purchase.id,
          reversalMovementIds: ['rev-2'],
        ),
      );

      expect(
        () => repo.reversePurchaseEntry(
          cancelledPurchase: cancelled,
          cancelledByUserId: 'owner-1',
          cancellationReason: 'خطأ',
        ),
        throwsStateError,
      );
    });

    test('duplicate purchase entry is rejected', () async {
      final purchase = PurchaseIntake(
        id: 'pin-test-dup',
        supplierId: supplier.id,
        productId: 'prod-1',
        quantityKg: 100,
        entryUnit: GrainUnit.kilogram,
        unitPricePiastersPerKg: 2000,
        totalAmountPiasters: 200000,
        createdByUserId: 'owner-1',
        createdAt: DateTime.now(),
        stockMovementId: 'mov-dup',
      );

      await repo.createPurchaseEntry(purchase: purchase);
      expect(
        () => repo.createPurchaseEntry(purchase: purchase),
        throwsStateError,
      );
    });

    test('restore and clear work correctly', () async {
      final entry = SupplierAccountEntry(
        id: 'sle-restore-1',
        supplierId: supplier.id,
        date: DateTime.now(),
        type: SupplierAccountEntryType.purchase,
        debitAmountQirsh: 100000,
        creditAmountQirsh: 0,
        sourceDocumentType: 'purchase',
        sourceDocumentId: 'pin-restore',
        descriptionAr: 'مشتريات',
        createdAt: DateTime.now(),
        createdByUserId: 'owner-1',
      );

      await repo.clearForOwnerDataWipe();
      await repo.restoreSupplierAccountsIntoEmpty(
        entries: [entry],
        payments: [],
      );

      final balance = await repo.balanceForSupplier(supplier.id);
      expect(balance, 100000);

      await repo.clearForOwnerDataWipe();
      final balanceAfterClear = await repo.balanceForSupplier(supplier.id);
      expect(balanceAfterClear, 0);
    });

    test('balancesBySupplierId aggregates correctly', () async {
      final supplier2 = await supplierRepo.createSupplier(const SupplierDraft(
        name: 'مورد آخر',
      ));

      final purchase1 = PurchaseIntake(
        id: 'pin-bal-1',
        supplierId: supplier.id,
        productId: 'prod-1',
        quantityKg: 100,
        entryUnit: GrainUnit.kilogram,
        unitPricePiastersPerKg: 2000,
        totalAmountPiasters: 200000,
        createdByUserId: 'owner-1',
        createdAt: DateTime.now(),
        stockMovementId: 'mov-bal-1',
      );
      final purchase2 = PurchaseIntake(
        id: 'pin-bal-2',
        supplierId: supplier2.id,
        productId: 'prod-1',
        quantityKg: 50,
        entryUnit: GrainUnit.kilogram,
        unitPricePiastersPerKg: 1000,
        totalAmountPiasters: 50000,
        createdByUserId: 'owner-1',
        createdAt: DateTime.now(),
        stockMovementId: 'mov-bal-2',
      );

      await repo.createPurchaseEntry(purchase: purchase1);
      await repo.createPurchaseEntry(purchase: purchase2);

      final balances = await repo.balancesBySupplierId();
      expect(balances[supplier.id], 200000);
      expect(balances[supplier2.id], 50000);
    });

    test('cancelled purchase entry is rejected', () async {
      final cancelledPurchase = PurchaseIntake(
        id: 'pin-cancelled',
        supplierId: supplier.id,
        productId: 'prod-1',
        quantityKg: 100,
        entryUnit: GrainUnit.kilogram,
        unitPricePiastersPerKg: 2000,
        totalAmountPiasters: 200000,
        createdByUserId: 'owner-1',
        createdAt: DateTime.now(),
        stockMovementId: 'mov-cancelled',
        cancellation: CancellationMetadata(
          cancelledAt: DateTime.now(),
          cancelledByUserId: 'owner-1',
          cancellationReason: 'إلغاء',
          originalDocumentId: 'pin-cancelled',
          reversalMovementIds: ['rev-c'],
        ),
      );

      expect(
        () => repo.createPurchaseEntry(purchase: cancelledPurchase),
        throwsStateError,
      );
    });

    test('payment with zero or negative amount is rejected', () async {
      expect(
        () => repo.createPayment(SupplierPaymentDraft(
          supplierId: supplier.id,
          date: DateTime.now(),
          amountQirsh: 0,
          createdByUserId: 'owner-1',
        )),
        throwsArgumentError,
      );
    });
  });
}
