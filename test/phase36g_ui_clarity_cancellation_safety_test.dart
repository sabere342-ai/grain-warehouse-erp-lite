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
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/dashboard/dashboard_controller.dart';
import 'package:grain_warehouse_erp_lite/core/dashboard/dashboard_service.dart';
import 'package:grain_warehouse_erp_lite/core/documents/cancellation_metadata.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_controller.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
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
import 'package:grain_warehouse_erp_lite/features/purchases/purchases_screen.dart';
import 'package:grain_warehouse_erp_lite/features/reports/reports_screen.dart';
import 'support/product_catalog_read_repository_test_adapter.dart';

void main() {
  group('Phase 36G - UI clarity & cancellation safety', () {
    group('Purchase cancellation UI', () {
      late LocalSupplierRepository supplierRepo;
      late LocalProductRepository productRepo;
      late LocalInventoryRepository inventoryRepo;
      late LocalSupplierAccountRepository accountRepo;
      late LocalPurchaseRepository purchaseRepo;
      late PurchaseController controller;
      late Supplier supplier;
      late Product product;

      setUp(() async {
        supplierRepo = LocalSupplierRepository();
        productRepo = LocalProductRepository();
        inventoryRepo =
            LocalInventoryRepository(productRepository: productRepo);
        accountRepo = LocalSupplierAccountRepository(
          supplierRepository: supplierRepo,
        );
        purchaseRepo = LocalPurchaseRepository(
          supplierRepository: supplierRepo,
          productRepository: productRepo,
          inventoryRepository: inventoryRepo,
          supplierAccountRepository: accountRepo,
        );
        supplier = await supplierRepo.createSupplier(
          const SupplierDraft(name: 'مورد القمح'),
        );
        product = await productRepo.createProduct(
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
            unitPricePiastersPerKg: 1000,
            createdByUserId: 'owner-1',
          ),
        );
        controller = PurchaseController(
          purchaseRepository: purchaseRepo,
          supplierRepository: supplierRepo,
          productCatalogReadRepository:
              ProductCatalogReadRepositoryTestAdapter(productRepo),
        );
      });

      test('purchase with no supplier payment is cancellable', () async {
        final hasPayments = (await accountRepo.listPayments()).isNotEmpty;
        expect(hasPayments, false);

        final intakes = await purchaseRepo.listPurchaseIntakes();
        expect(intakes.length, 1);

        // Backend allows cancellation
        await purchaseRepo.cancelPurchaseIntake(
          purchaseIntakeId: intakes.first.id,
          cancelledByUserId: 'owner-1',
          cancellationReason: 'اختبار',
        );

        final afterCancel = await accountRepo.balanceForSupplier(supplier.id);
        expect(afterCancel, 0);
      });

      test('cancelling purchase after supplier payment is blocked by backend',
          () async {
        await accountRepo.createPayment(SupplierPaymentDraft(
          supplierId: supplier.id,
          date: DateTime.now(),
          amountQirsh: 500000,
          createdByUserId: 'owner-1',
        ));

        final intakes = await purchaseRepo.listPurchaseIntakes();
        expect(
          () => purchaseRepo.cancelPurchaseIntake(
            purchaseIntakeId: intakes.first.id,
            cancelledByUserId: 'owner-1',
            cancellationReason: 'اختبار',
          ),
          throwsStateError,
        );

        // Stock and supplier balance remain unchanged
        final stock = await inventoryRepo.currentStockKg(product.id);
        expect(stock, 6000);

        final balanceAfterRejectedCancel =
            await accountRepo.balanceForSupplier(supplier.id);
        expect(balanceAfterRejectedCancel, 500000);
      });

      testWidgets('cancel button shows disabled message when payment exists',
          (tester) async {
        final auth = await tester.runAsync(() async {
          await accountRepo.createPayment(SupplierPaymentDraft(
            supplierId: supplier.id,
            date: DateTime.now(),
            amountQirsh: 500000,
            createdByUserId: 'owner-1',
          ));
          await controller.load(_owner);
          return _signedInController(
            phone: '01000000000',
            password: 'owner123',
          );
        });
        if (auth == null) {
          throw StateError(
              'The purchase cancellation fixture did not initialize.');
        }
        addTearDown(auth.dispose);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _purchaseHarness(
              auth: auth, controller: controller, accountRepo: accountRepo),
        );
        await _pumpExpectedState(tester);
        expect(
          find.text('لا يمكن الإلغاء بعد تسجيل دفعة للمورد'),
          findsOneWidget,
        );
        expect(
          find.text('إلغاء مستند الاستلام'),
          findsNothing,
        );
      });

      testWidgets('cancel button shows normal when no payment', (tester) async {
        final auth = await tester.runAsync(() async {
          await controller.load(_owner);
          return _signedInController(
            phone: '01000000000',
            password: 'owner123',
          );
        });
        if (auth == null) {
          throw StateError(
              'The purchase cancellation fixture did not initialize.');
        }
        addTearDown(auth.dispose);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _purchaseHarness(
              auth: auth, controller: controller, accountRepo: accountRepo),
        );
        await _pumpExpectedState(tester);

        expect(
          find.text('إلغاء مستند الاستلام'),
          findsOneWidget,
        );
        expect(
          find.text('لا يمكن الإلغاء بعد تسجيل دفعة للمورد'),
          findsNothing,
        );
      });
    });

    group('Reports label clarity', () {
      testWidgets('report shows clarified labels for owner', (tester) async {
        final auth = await _signedInController(
          phone: '01000000000',
          password: 'owner123',
        );
        final controller = ReportController(
          repository: _reportRepository(
            purchases: [
              _purchase('p1',
                  quantityKg: 1000, total: 700000, createdAt: _midday),
            ],
            sales: [
              _sale('s1', quantityKg: 250, total: 200000, createdAt: _midday),
            ],
          ),
        );

        await tester.pumpWidget(
          _reportsHarness(auth: auth, controller: controller),
        );
        await tester.pumpAndSettle();

        // Clarified net document movement label
        expect(find.text('صافي حركة المستندات'), findsOneWidget);
        expect(
          find.textContaining('وليس رصيد النقدية'),
          findsOneWidget,
        );

        // Customer and supplier helper texts (appear in card caption + explanation)
        expect(
          find.textContaining('مبالغ لنا عند العملاء'),
          findsAtLeastNWidgets(1),
        );
        expect(
          find.textContaining('مبالغ علينا للموردين'),
          findsAtLeastNWidgets(1),
        );

        // Updated summary card titles
        expect(find.text('أرصدة العملاء المستحقة'), findsOneWidget);
        expect(find.text('أرصدة الموردين المستحقة'), findsOneWidget);
      });
    });

    group('Dashboard helper clarity', () {
      testWidgets('dashboard financial balance card shows canonical subtitle',
          (tester) async {
        final auth = await _signedInController(
          phone: '01000000000',
          password: 'owner123',
        );
        final controller = DashboardController(service: _dashboardService());

        await tester.pumpWidget(
          _dashboardHarness(auth: auth, controller: controller),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('الحسابات غير النشطة'),
          findsOneWidget,
        );
      });
    });
  });
}

// --- Helpers ---

Widget _purchaseHarness({
  required AuthController auth,
  required PurchaseController controller,
  SupplierAccountRepository? accountRepo,
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
      home: PurchasesScreen(
        controller: controller,
        supplierAccountRepository: accountRepo,
      ),
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

Future<AuthController> _signedInController({
  required String phone,
  required String password,
}) async {
  final controller = AuthController(repository: LocalAuthRepository.demo());
  await controller.initialize();
  await controller.signIn(phone: phone, password: password);
  return controller;
}

Future<void> _pumpExpectedState(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
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

// --- Report helpers ---

final _now = DateTime(2026, 7, 5);
final _midday = DateTime(2026, 7, 5, 12);

final _owner = AppUser(
  id: 'owner-test',
  name: 'مالك',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);

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

PurchaseIntake _purchase(
  String id, {
  required int quantityKg,
  required int total,
  required DateTime createdAt,
  CancellationMetadata? cancellation,
}) {
  return PurchaseIntake(
    id: id,
    supplierId: 'supplier-id',
    productId: _product.id,
    quantityKg: quantityKg,
    entryUnit: GrainUnit.kilogram,
    unitPricePiastersPerKg: 700,
    totalAmountPiasters: total,
    createdByUserId: _owner.id,
    createdAt: createdAt,
    stockMovementId: 'movement-$id',
    cancellation: cancellation,
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

  Future<void> restorePurchaseIntakesIntoEmpty(List<PurchaseIntake> intakes) {
    throw UnimplementedError();
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

  Future<void> restoreSalesIntoEmpty(List<SaleRecord> sales) {
    throw UnimplementedError();
  }
}

class _FakeInventoryRepository implements InventoryRepository {
  const _FakeInventoryRepository(this.movements, this.balances);
  final List<StockMovement> movements;
  final Map<String, int> balances;

  @override
  Future<Map<String, int>> allProductBalancesKg({
    bool activeProductsOnly = false,
  }) async {
    return Map<String, int>.unmodifiable(balances);
  }

  @override
  Future<StockMovement> createMovement(StockMovementDraft draft) {
    throw UnimplementedError();
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
    return movements;
  }

  @override
  Future<List<StockMovement>> listMovementsByProduct(String productId) async {
    return movements.where((m) => m.productId == productId).toList();
  }
}

class _FakeProductRepository implements ProductRepository {
  const _FakeProductRepository(this.products);
  final List<Product> products;

  @override
  Future<Product> createProduct(ProductDraft draft) {
    throw UnimplementedError();
  }

  Future<Product> deactivateProduct(String productId) {
    throw UnimplementedError();
  }

  Future<Product> editProduct(String productId, ProductDraft draft) {
    throw UnimplementedError();
  }

  @override
  Future<List<Product>> listProducts({
    bool includeInactive = false,
  }) async {
    return products;
  }

  @override
  Future<Product> updateProduct({
    required String productId,
    required ProductDraft draft,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Product> setProductActive({
    required String productId,
    required bool isActive,
  }) {
    throw UnimplementedError();
  }
}

LocalReportRepository _reportRepository({
  List<Product>? products,
  List<PurchaseIntake> purchases = const [],
  List<SaleRecord> sales = const [],
  List<StockMovement> movements = const [],
  Map<String, int>? balances,
}) {
  final productRepo = _FakeProductRepository(products ?? [_product]);
  return LocalReportRepository(
    purchaseRepository: _FakePurchaseRepository(purchases),
    saleRepository: _FakeSaleRepository(sales),
    inventoryRepository: _FakeInventoryRepository(movements, balances ?? {}),
    productCatalogReadRepository:
        ProductCatalogReadRepositoryTestAdapter(productRepo),
    expenseRepository: LocalExpenseRepository(),
    customerAccountRepository: LocalCustomerAccountRepository(
      customerRepository: LocalCustomerRepository(),
    ),
    supplierAccountRepository: LocalSupplierAccountRepository(
      supplierRepository: LocalSupplierRepository(),
    ),
  );
}
