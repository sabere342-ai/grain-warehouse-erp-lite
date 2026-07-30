import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_collection.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/dashboard/dashboard_controller.dart';
import 'package:grain_warehouse_erp_lite/core/dashboard/dashboard_service.dart';
import 'package:grain_warehouse_erp_lite/core/documents/cancellation_metadata.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/reports/daily_activity_report.dart';
import 'package:grain_warehouse_erp_lite/core/reports/report_controller.dart';
import 'package:grain_warehouse_erp_lite/core/reports/report_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payment.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/features/dashboard/dashboard_screen.dart';
import 'package:grain_warehouse_erp_lite/features/reports/reports_screen.dart';
import 'support/product_catalog_read_repository_test_adapter.dart';

void main() {
  group('Phase 37C - Dashboard and report labels truthfulness', () {
    group('DashboardData model', () {
      test('empty DashboardData has all new fields at zero', () {
        final data = DashboardData.empty();
        expect(data.todaySalesQirsh, 0);
        expect(data.todayCashSalesQirsh, 0);
        expect(data.todayCreditSalesQirsh, 0);
        expect(data.todayCollectionsQirsh, 0);
        expect(data.todaySupplierPaymentsQirsh, 0);
        expect(data.todayExpensesQirsh, 0);
        expect(data.cashBalanceQirsh, 0);
        expect(data.customerReceivablesQirsh, 0);
        expect(data.supplierPayablesQirsh, 0);
        expect(data.totalStockKg, 0);
        expect(data.wheatStockKg, 0);
        expect(data.stockAlertCount, 0);
        expect(data.hasData, false);
        expect(data.todayCashInQirsh, 0);
        expect(data.todayCashOutQirsh, 0);
        expect(data.todayNetCashQirsh, 0);
      });

      test('todayCashInQirsh = cash sales + collections', () {
        const data = DashboardData(
          todaySalesQirsh: 500000,
          todayCashSalesQirsh: 300000,
          todayCreditSalesQirsh: 200000,
          todayCollectionsQirsh: 100000,
          todaySupplierPaymentsQirsh: 50000,
          todayExpensesQirsh: 20000,
          cashBalanceQirsh: 1000000,
          customerReceivablesQirsh: 200000,
          supplierPayablesQirsh: 150000,
          totalStockKg: 5000,
          wheatStockKg: 3000,
          stockAlertCount: 2,
          hasData: true,
        );
        expect(data.todayCashInQirsh, 400000);
        expect(data.todayCashOutQirsh, 70000);
        expect(data.todayNetCashQirsh, 330000);
      });
    });

    group('Dashboard service calculations', () {
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
        inventoryRepo =
            LocalInventoryRepository(productRepository: productRepo);
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
          productCatalogReadRepository:
              ProductCatalogReadRepositoryTestAdapter(productRepo),
          expenseRepository: expenseRepo,
          customerAccountRepository: customerAccountRepo,
          financialAccountRepository: LocalFinancialAccountRepository(),
          supplierAccountRepository: supplierAccountRepo,
        );
      });

      test('todayCollectionsQirsh filters by date, not all-time', () async {
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
        final customer = await customerRepo.createCustomer(
          const CustomerDraft(name: 'عميل', isActive: true),
        );

        await saleRepo.createSale(SaleDraft(
          productId: product.id,
          quantityKg: 10,
          salePriceQirshPerKg: 5000,
          createdByUserId: 'owner-1',
          paymentMode: SalePaymentMode.credit,
          customerId: customer.id,
        ));
        final allSales = await saleRepo.listSales();
        final creditSale = allSales.first;
        await customerAccountRepo.createCreditSaleEntry(
          sale: creditSale,
          customerId: customer.id,
        );

        await customerAccountRepo.createCollection(
          CustomerCollectionDraft(
            customerId: customer.id,
            date: DateTime.now(),
            amountQirsh: 10000,
            createdByUserId: 'owner-1',
          ),
        );

        final data = await service.load();
        expect(data.todayCollectionsQirsh, 10000);
      });

      test('todaySupplierPaymentsQirsh filters by date', () async {
        final supplier = await supplierRepo.createSupplier(
          const SupplierDraft(name: 'مورد'),
        );
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

        await supplierAccountRepo.createPurchaseEntry(
          purchase: PurchaseIntake(
            id: 'pin-test-sp',
            supplierId: supplier.id,
            productId: product.id,
            quantityKg: 100,
            entryUnit: GrainUnit.kilogram,
            unitPricePiastersPerKg: 1000,
            totalAmountPiasters: 100000,
            createdByUserId: 'owner-1',
            createdAt: DateTime.now(),
            stockMovementId: 'mov-sp',
          ),
        );

        await supplierAccountRepo.createPayment(SupplierPaymentDraft(
          supplierId: supplier.id,
          date: DateTime.now(),
          amountQirsh: 30000,
          createdByUserId: 'owner-1',
        ));

        final data = await service.load();
        expect(data.todaySupplierPaymentsQirsh, 30000);
      });

      test('todayExpensesQirsh filters by date', () async {
        await expenseRepo.createExpense(ExpenseDraft(
          accountingClassification: ExpenseAccountingClassification.operating,
          date: DateTime.now(),
          category: 'إيجار',
          amountQirsh: 5000,
          createdByUserId: 'owner-1',
          operationRequestId: 'phase37-expense-today',
        ));

        final data = await service.load();
        expect(data.todayExpensesQirsh, 5000);
      });

      test('customerReceivablesQirsh tracks positive balances only', () async {
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
        final customer = await customerRepo.createCustomer(
          const CustomerDraft(name: 'عميل', isActive: true),
        );

        await saleRepo.createSale(SaleDraft(
          productId: product.id,
          quantityKg: 10,
          salePriceQirshPerKg: 5000,
          createdByUserId: 'owner-1',
          paymentMode: SalePaymentMode.credit,
          customerId: customer.id,
        ));
        final allSales = await saleRepo.listSales();
        final creditSale = allSales.first;
        await customerAccountRepo.createCreditSaleEntry(
          sale: creditSale,
          customerId: customer.id,
        );

        final data = await service.load();
        expect(data.customerReceivablesQirsh, 50000);
      });

      test('supplierPayablesQirsh tracks positive balances only', () async {
        final supplier = await supplierRepo.createSupplier(
          const SupplierDraft(name: 'مورد'),
        );
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

        await supplierAccountRepo.createPurchaseEntry(
          purchase: PurchaseIntake(
            id: 'pin-test-pay',
            supplierId: supplier.id,
            productId: product.id,
            quantityKg: 100,
            entryUnit: GrainUnit.kilogram,
            unitPricePiastersPerKg: 1000,
            totalAmountPiasters: 100000,
            createdByUserId: 'owner-1',
            createdAt: DateTime.now(),
            stockMovementId: 'mov-pay',
          ),
        );

        final data = await service.load();
        expect(data.supplierPayablesQirsh, 100000);
      });

      test('today metrics exclude out-of-range data', () async {
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

        final oldDate = DateTime(2020, 1, 1);
        await expenseRepo.createExpense(ExpenseDraft(
          accountingClassification: ExpenseAccountingClassification.operating,
          date: oldDate,
          category: 'قديم',
          amountQirsh: 99999,
          createdByUserId: 'owner-1',
          operationRequestId: 'phase37-expense-old',
        ));

        final data = await service.load();
        expect(data.todayExpensesQirsh, 0);
        expect(data.cashBalanceQirsh, 0);
      });
    });

    group('DailyActivityReport cash flow getters', () {
      test('cashSalesAmountQirsh = total sales - credit sales', () {
        final report = _report(creditSales: 20000, totalSales: 100000);
        expect(report.cashSalesAmountQirsh, 80000);
      });

      test('cashInQirsh = cash sales + collections', () {
        final report = _report(
          totalSales: 100000,
          creditSales: 20000,
          collections: 15000,
        );
        expect(report.cashInQirsh, 95000);
      });

      test('cashOutQirsh = supplier payments + expenses', () {
        final report = _report(
          supplierPayments: 30000,
          expenses: 5000,
        );
        expect(report.cashOutQirsh, 35000);
      });

      test('netCashQirsh = cashIn - cashOut', () {
        final report = _report(
          totalSales: 100000,
          creditSales: 20000,
          collections: 15000,
          supplierPayments: 30000,
          expenses: 5000,
        );
        expect(report.netCashQirsh, 60000);
      });
    });

    group('Dashboard UI labels', () {
      testWidgets('new metric cards appear on dashboard', (tester) async {
        final auth = await _signedInOwner();
        final controller = DashboardController(service: _dashboardService());

        await tester.pumpWidget(
          _dashboardHarness(auth: auth, controller: controller),
        );
        await tester.pumpAndSettle();

        expect(find.text('مبيعات اليوم'), findsOneWidget);
        expect(find.text('نقد داخل اليوم'), findsOneWidget);
        expect(find.text('المستحق على العملاء'), findsOneWidget);
        expect(find.text('المستحق للموردين'), findsOneWidget);
        expect(find.text('إجمالي أرصدة الحسابات المالية'), findsOneWidget);
        expect(find.text('مخزون القمح'), findsOneWidget);
        expect(find.text('تنبيهات المخزون'), findsOneWidget);
      });
    });

    group('Report cash flow UI labels', () {
      testWidgets('cash flow section labels appear in report', (tester) async {
        final auth = await _signedInOwner();
        final controller = ReportController(
          repository: _reportRepository(
            sales: [
              _sale('s1', quantityKg: 250, total: 200000, createdAt: _midday),
            ],
          ),
        );

        await tester.pumpWidget(
          _reportsHarness(auth: auth, controller: controller),
        );
        await tester.pumpAndSettle();

        expect(find.text('حركة النقد اليوم'), findsOneWidget);
        expect(find.text('نقد داخل اليوم'), findsWidgets);
        expect(find.text('نقد خارج اليوم'), findsWidgets);
        expect(find.text('صافي حركة النقد اليوم'), findsOneWidget);
        expect(find.text('صافي حركة المستندات'), findsOneWidget);
      });
    });
  });
}

DailyActivityReport _report({
  int totalSales = 0,
  int creditSales = 0,
  int collections = 0,
  int supplierPayments = 0,
  int expenses = 0,
}) {
  return DailyActivityReport(
    start: DateTime(2026, 7, 5),
    end: DateTime(2026, 7, 6),
    totalPurchasedKg: 0,
    totalSoldKg: 0,
    totalPurchaseAmountQirsh: 0,
    totalSalesAmountQirsh: totalSales,
    totalExpenseAmountQirsh: expenses,
    totalCreditSalesAmountQirsh: creditSales,
    totalCollectionsAmountQirsh: collections,
    totalOutstandingReceivablesQirsh: 0,
    estimatedSalesCostQirsh: null,
    estimatedGrossProfitQirsh: null,
    estimatedStockValueQirsh: null,
    hasCompleteSalesCost: true,
    hasCompleteStockValuation: true,
    missingSalesCostProductNames: const [],
    missingStockCostProductNames: const [],
    purchaseCount: 0,
    saleCount: 0,
    stockMovementCount: 0,
    stockBalances: const [],
    recentMovements: const [],
    totalSupplierPaymentsQirsh: supplierPayments,
    totalOutstandingSupplierPayablesQirsh: 0,
  );
}

Widget _dashboardHarness({
  required AuthController auth,
  required DashboardController controller,
}) {
  return AuthScope(
    controller: auth,
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: DashboardScreen(controller: controller),
    ),
  );
}

Widget _reportsHarness({
  required AuthController auth,
  required ReportController controller,
}) {
  return AuthScope(
    controller: auth,
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: ReportsScreen(controller: controller),
    ),
  );
}

Future<AuthController> _signedInOwner() async {
  final controller = AuthController(repository: LocalAuthRepository.demo());
  await controller.initialize();
  await controller.signIn(phone: '01000000000', password: 'owner123');
  return controller;
}

DashboardService _dashboardService() {
  return DashboardService(
    saleRepository: LocalSaleRepository(
      productRepository: LocalProductRepository(),
      inventoryRepository: LocalInventoryRepository(
        productRepository: LocalProductRepository(),
      ),
    ),
    inventoryRepository: LocalInventoryRepository(
      productRepository: LocalProductRepository(),
    ),
    productRepository: LocalProductRepository(),
    productCatalogReadRepository:
        ProductCatalogReadRepositoryTestAdapter(LocalProductRepository()),
    expenseRepository: LocalExpenseRepository(),
    customerAccountRepository: LocalCustomerAccountRepository(
      customerRepository: LocalCustomerRepository(),
    ),
    financialAccountRepository: LocalFinancialAccountRepository(),
    supplierAccountRepository: LocalSupplierAccountRepository(
      supplierRepository: LocalSupplierRepository(),
    ),
  );
}

LocalReportRepository _reportRepository({
  List<Product>? products,
  List<PurchaseIntake> purchases = const [],
  List<SaleRecord> sales = const [],
  List<StockMovement> movements = const [],
  Map<String, int> balances = const {},
}) {
  return LocalReportRepository(
    purchaseRepository: _FakePurchaseRepository(purchases),
    saleRepository: _FakeSaleRepository(sales),
    inventoryRepository: _FakeInventoryRepository(
      movements: movements,
      balances: balances,
    ),
    productRepository: _FakeProductRepository(products ?? [_product]),
    supplierAccountRepository: LocalSupplierAccountRepository(
      supplierRepository: LocalSupplierRepository(),
    ),
  );
}

SaleRecord _sale(
  String id, {
  required int quantityKg,
  required int total,
  required DateTime createdAt,
  CancellationMetadata? cancellation,
}) {
  return SaleRecord(
    id: id,
    productId: _product.id,
    quantityKg: quantityKg,
    salePriceQirshPerKg: 800,
    totalQirsh: total,
    createdByUserId: _owner.id,
    createdAt: createdAt,
    stockMovementId: 'movement-$id',
    cancellation: cancellation,
  );
}

final _now = DateTime(2026, 7, 5);
final _midday = DateTime(2026, 7, 5, 12);

final _product = Product(
  id: 'prod-1',
  name: 'قمح',
  unit: GrainUnit.kilogram,
  defaultSalePricePiastersPerKg: 1000,
  minimumSalePricePiastersPerKg: 800,
  referenceCostPricePiastersPerKg: 700,
  code: null,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);

final _owner = AppUser(
  id: 'owner-test',
  name: 'مالك',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);

class _FakePurchaseRepository implements PurchaseRepository {
  const _FakePurchaseRepository(this.purchases);
  final List<PurchaseIntake> purchases;

  @override
  Future<PurchaseIntake> cancelPurchaseIntake({
    required String purchaseIntakeId,
    required String cancelledByUserId,
    required String cancellationReason,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PurchaseIntake> createPurchaseIntake(PurchaseIntakeDraft draft) {
    throw UnimplementedError();
  }

  @override
  Future<List<PurchaseIntake>> listPurchaseIntakes() async {
    return purchases;
  }
}

class _FakeSaleRepository implements SaleRepository {
  const _FakeSaleRepository(this.sales);
  final List<SaleRecord> sales;

  @override
  Future<SaleRecord> cancelSale({
    required String saleId,
    required String cancelledByUserId,
    required String cancellationReason,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SaleRecord> createSale(SaleDraft draft) {
    throw UnimplementedError();
  }

  @override
  Future<List<SaleRecord>> listSales() async {
    return sales;
  }
}

class _FakeInventoryRepository implements InventoryRepository {
  const _FakeInventoryRepository({
    required this.movements,
    required this.balances,
  });

  final List<StockMovement> movements;
  final Map<String, int> balances;

  @override
  Future<StockMovement> createMovement(StockMovementDraft draft) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, int>> allProductBalancesKg({
    bool activeProductsOnly = false,
  }) async {
    return Map<String, int>.unmodifiable(balances);
  }

  @override
  Future<int> currentStockKg(String productId) async {
    return balances[productId] ?? 0;
  }

  @override
  Future<bool> hasOpeningBalance(String productId) async {
    return false;
  }

  @override
  Future<List<StockMovement>> listAllMovements() async {
    return List<StockMovement>.unmodifiable(movements);
  }

  @override
  Future<List<StockMovement>> listMovementsByProduct(String productId) async {
    return List<StockMovement>.unmodifiable(
      movements.where((movement) => movement.productId == productId),
    );
  }
}

class _FakeProductRepository implements ProductRepository {
  const _FakeProductRepository(this.products);
  final List<Product> products;

  @override
  Future<Product> createProduct(ProductDraft draft) {
    throw UnimplementedError();
  }

  @override
  Future<List<Product>> listProducts({bool includeInactive = true}) async {
    return List<Product>.unmodifiable(
      includeInactive
          ? products
          : products.where((product) => product.isActive),
    );
  }

  @override
  Future<Product> setProductActive({
    required String productId,
    required bool isActive,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Product> updateProduct({
    required String productId,
    required ProductDraft draft,
  }) {
    throw UnimplementedError();
  }
}
