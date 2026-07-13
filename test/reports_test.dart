import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/cancellation_metadata.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/reports/report_controller.dart';
import 'package:grain_warehouse_erp_lite/core/reports/report_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payment.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/features/reports/reports_screen.dart';

void main() {
  group('Daily activity reports', () {
    test('empty report returns zero totals', () async {
      final repository = _reportRepository();

      final report = await repository.dailyActivityReport(
        selectedDate: _reportDay,
      );

      expect(report.totalPurchasedKg, 0);
      expect(report.totalSoldKg, 0);
      expect(report.totalPurchaseAmountQirsh, 0);
      expect(report.totalSalesAmountQirsh, 0);
      expect(report.purchaseCount, 0);
      expect(report.saleCount, 0);
      expect(report.stockMovementCount, 0);
    });

    test('purchases appear in purchase totals', () async {
      final repository = _reportRepository(
        purchases: [
          _purchase('p1', quantityKg: 1000, total: 700000, createdAt: _midday),
          _purchase('p2', quantityKg: 500, total: 350000, createdAt: _evening),
        ],
      );

      final report = await repository.dailyActivityReport(
        selectedDate: _reportDay,
      );

      expect(report.totalPurchasedKg, 1500);
      expect(report.totalPurchaseAmountQirsh, 1050000);
      expect(report.purchaseCount, 2);
    });

    test('sales appear in sales totals', () async {
      final repository = _reportRepository(
        sales: [
          _sale('s1', quantityKg: 250, total: 200000, createdAt: _midday),
          _sale('s2', quantityKg: 100, total: 85000, createdAt: _evening),
        ],
      );

      final report = await repository.dailyActivityReport(
        selectedDate: _reportDay,
      );

      expect(report.totalSoldKg, 350);
      expect(report.totalSalesAmountQirsh, 285000);
      expect(report.saleCount, 2);
    });

    test('date filtering includes only selected day records', () async {
      final repository = _reportRepository(
        purchases: [
          _purchase('before', quantityKg: 100, total: 1000, createdAt: _before),
          _purchase('inside', quantityKg: 200, total: 2000, createdAt: _midday),
          _purchase('after', quantityKg: 300, total: 3000, createdAt: _after),
        ],
        sales: [
          _sale('inside', quantityKg: 50, total: 500, createdAt: _evening),
          _sale('after', quantityKg: 75, total: 750, createdAt: _after),
        ],
      );

      final report = await repository.dailyActivityReport(
        selectedDate: _reportDay,
      );

      expect(report.totalPurchasedKg, 200);
      expect(report.totalSoldKg, 50);
      expect(report.purchaseCount, 1);
      expect(report.saleCount, 1);
      expect(report.start, DateTime(2026, 7, 5));
      expect(report.end, DateTime(2026, 7, 6));
    });

    test('stock balances are calculated from existing movements', () async {
      final repository = _reportRepository(
        balances: {_product.id: 725},
      );

      final report = await repository.dailyActivityReport(
        selectedDate: _reportDay,
      );

      expect(report.stockBalances.single.productName, 'قمح');
      expect(report.stockBalances.single.quantityKg, 725);
      expect(report.stockBalances.single.unitLabel, 'كجم');
    });

    test('stock movements list appears in selected period', () async {
      final repository = _reportRepository(
        movements: [
          _movement(
            'old',
            StockMovementType.openingBalance,
            1000,
            _before,
          ),
          _movement(
            'sale',
            StockMovementType.sale,
            100,
            _midday,
            note: 'Sale sal-1',
          ),
        ],
      );

      final report = await repository.dailyActivityReport(
        selectedDate: _reportDay,
      );

      expect(report.stockMovementCount, 1);
      expect(report.recentMovements.single.type, StockMovementType.sale);
      expect(report.recentMovements.single.productName, 'قمح');
      expect(report.recentMovements.single.reference, 'Sale sal-1');
    });

    test('cancelled purchases and sales are excluded from totals', () async {
      final repository = _reportRepository(
        purchases: [
          _purchase('active-purchase',
              quantityKg: 1000, total: 700000, createdAt: _midday),
          _purchase(
            'cancelled-purchase',
            quantityKg: 500,
            total: 350000,
            createdAt: _midday,
            cancellation: _cancellation('cancelled-purchase'),
          ),
        ],
        sales: [
          _sale('active-sale',
              quantityKg: 250, total: 200000, createdAt: _midday),
          _sale(
            'cancelled-sale',
            quantityKg: 100,
            total: 80000,
            createdAt: _midday,
            cancellation: _cancellation('cancelled-sale'),
          ),
        ],
      );

      final report = await repository.dailyActivityReport(
        selectedDate: _reportDay,
      );

      expect(report.totalPurchasedKg, 1000);
      expect(report.totalPurchaseAmountQirsh, 700000);
      expect(report.purchaseCount, 1);
      expect(report.totalSoldKg, 250);
      expect(report.totalSalesAmountQirsh, 200000);
      expect(report.saleCount, 1);
    });

    test('report calculates estimated profit when reference cost is complete',
        () async {
      final repository = _reportRepository(
        products: [_productWithCost],
        sales: [
          _sale('s1', quantityKg: 250, total: 200000, createdAt: _midday),
        ],
        balances: {_product.id: 750},
      );

      final report = await repository.dailyActivityReport(
        selectedDate: _reportDay,
      );

      expect(report.totalSalesAmountQirsh, 200000);
      expect(report.estimatedSalesCostQirsh, 175000);
      expect(report.estimatedGrossProfitQirsh, 25000);
      expect(report.estimatedStockValueQirsh, 525000);
      expect(report.hasCompleteSalesCost, isTrue);
      expect(report.hasCompleteStockValuation, isTrue);
    });

    test('supplier payments appear in report totals', () async {
      final paymentEntry = _paymentEntry(
        creditAmountQirsh: 50000,
        createdAt: _midday,
      );
      final repository = _reportRepository(
        supplierEntries: [paymentEntry],
      );

      final report = await repository.dailyActivityReport(
        selectedDate: _reportDay,
      );

      expect(report.totalSupplierPaymentsQirsh, 50000);
    });

    test('outstanding supplier payables are computed', () async {
      final purchaseEntry = SupplierAccountEntry(
        id: 'sle-purchase-1',
        supplierId: 'supplier-id',
        date: _before,
        type: SupplierAccountEntryType.purchase,
        debitAmountQirsh: 200000,
        creditAmountQirsh: 0,
        sourceDocumentType: 'purchase',
        sourceDocumentId: 'pin-outstanding',
        descriptionAr: 'مشتريات',
        createdAt: _before,
        createdByUserId: _owner.id,
      );
      final paymentEntry = _paymentEntry(
        creditAmountQirsh: 50000,
        createdAt: _midday,
      );
      final repository = _reportRepository(
        supplierEntries: [purchaseEntry, paymentEntry],
      );

      final report = await repository.dailyActivityReport(
        selectedDate: _reportDay,
      );

      expect(report.totalOutstandingSupplierPayablesQirsh, 150000);
    });

    test('authorized user can view reports', () async {
      final controller = ReportController(repository: _reportRepository());

      final loaded = await controller.loadDailyActivity(
        user: _owner,
        selectedDate: _reportDay,
      );

      expect(loaded, isTrue);
      expect(controller.report, isNotNull);
    });

    test('unauthorized user cannot view reports', () async {
      final controller = ReportController(repository: _reportRepository());

      final loaded = await controller.loadDailyActivity(
        user: _employee,
        selectedDate: _reportDay,
      );

      expect(loaded, isFalse);
      expect(controller.report, isNull);
      expect(controller.errorMessage, contains('صلاحية'));
    });
  });

  group('Reports UI', () {
    testWidgets('Arabic UI labels are visible for owner', (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final controller = ReportController(
        repository: _reportRepository(
          purchases: [
            _purchase('p1',
                quantityKg: 1000, total: 700000, createdAt: _midday),
          ],
          sales: [
            _sale('s1', quantityKg: 250, total: 200000, createdAt: _midday),
          ],
          movements: [
            _movement('m1', StockMovementType.purchaseIntake, 1000, _midday),
          ],
          balances: {_product.id: 750},
        ),
      );

      await tester.pumpWidget(
        _reportsHarness(auth: auth, controller: controller),
      );
      await tester.pumpAndSettle();

      expect(find.text('تقارير حركة المخزن'), findsOneWidget);
      expect(
        find.text('ملخص يومي للمشتريات والمبيعات وحركات مخزون الحبوب.'),
        findsOneWidget,
      );
      expect(find.text('اختيار التاريخ'), findsOneWidget);
      expect(find.text('عرض التقرير'), findsOneWidget);
      expect(find.text('المشتريات'), findsOneWidget);
      expect(find.text('المبيعات'), findsOneWidget);
      expect(find.text('المخزون الحالي'), findsOneWidget);
      expect(find.text('حركات المخزون'), findsOneWidget);
      expect(find.text('إجمالي الكمية المشتراة'), findsOneWidget);
      expect(find.text('إجمالي الكمية المباعة'), findsOneWidget);
      expect(find.text('إجمالي قيمة المشتريات'), findsOneWidget);
      expect(find.text('إجمالي قيمة المبيعات'), findsOneWidget);
      expect(find.text('عدد عمليات الشراء'), findsOneWidget);
      expect(find.text('عدد عمليات البيع'), findsOneWidget);
      expect(find.text('حسابات العملاء'), findsOneWidget);
      expect(find.text('إجمالي البيع الآجل'), findsWidgets);
      expect(find.text('إجمالي التحصيلات من العملاء'), findsWidgets);
      expect(find.text('إجمالي أرصدة العملاء المستحقة'), findsWidgets);
      expect(
        find.text(
          'مبالغ لنا عند العملاء. التحصيلات تقلل مديونية العملاء فقط ولا تُحسب كمبيعات أو ربح جديد.',
        ),
        findsOneWidget,
      );
      expect(find.text('حسابات الموردين'), findsOneWidget);
      expect(find.text('إجمالي مدفوعات الموردين'), findsWidgets);
      expect(find.text('إجمالي أرصدة الموردين المستحقة'), findsWidgets);
    });

    testWidgets('employee cannot view report content', (tester) async {
      final auth = await _signedInController(
        phone: '01100000000',
        password: 'employee123',
      );
      final controller = ReportController(repository: _reportRepository());

      await tester.pumpWidget(
        _reportsHarness(auth: auth, controller: controller),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('صلاحية'), findsOneWidget);
      expect(find.text('المشتريات'), findsNothing);
    });
  });
}

LocalReportRepository _reportRepository({
  List<Product>? products,
  List<PurchaseIntake> purchases = const [],
  List<SaleRecord> sales = const [],
  List<StockMovement> movements = const [],
  Map<String, int> balances = const {},
  List<SupplierAccountEntry> supplierEntries = const [],
  List<SupplierPaymentRecord> supplierPayments = const [],
}) {
  return LocalReportRepository(
    purchaseRepository: _FakePurchaseRepository(purchases),
    saleRepository: _FakeSaleRepository(sales),
    inventoryRepository: _FakeInventoryRepository(
      movements: movements,
      balances: balances,
    ),
    productRepository: _FakeProductRepository(products ?? [_product]),
    supplierAccountRepository: _FakeSupplierAccountRepository(
      entries: supplierEntries,
      payments: supplierPayments,
    ),
  );
}

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

CancellationMetadata _cancellation(String documentId) {
  return CancellationMetadata(
    cancelledAt: _evening,
    cancelledByUserId: _owner.id,
    cancellationReason: 'خطأ في الإدخال',
    originalDocumentId: documentId,
    reversalMovementIds: ['reversal-$documentId'],
  );
}

SupplierAccountEntry _paymentEntry({
  required int creditAmountQirsh,
  required DateTime createdAt,
}) {
  return SupplierAccountEntry(
    id: 'sle-$creditAmountQirsh-${createdAt.microsecondsSinceEpoch}',
    supplierId: 'supplier-id',
    date: createdAt,
    type: SupplierAccountEntryType.payment,
    debitAmountQirsh: 0,
    creditAmountQirsh: creditAmountQirsh,
    sourceDocumentType: 'supplierPayment',
    sourceDocumentId: 'spy-test',
    descriptionAr: 'مدفوع للمورد',
    createdAt: createdAt,
    createdByUserId: _owner.id,
  );
}

StockMovement _movement(
  String id,
  StockMovementType type,
  int quantityKg,
  DateTime createdAt, {
  String? note,
}) {
  return StockMovement(
    id: id,
    productId: _product.id,
    movementType: type,
    quantityKg: quantityKg,
    createdByUserId: _owner.id,
    createdAt: createdAt,
    note: note,
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

Future<AuthController> _signedInController({
  required String phone,
  required String password,
}) async {
  final controller = AuthController(repository: LocalAuthRepository.demo());
  await controller.initialize();
  await controller.signIn(phone: phone, password: password);
  return controller;
}

class _FakePurchaseRepository implements PurchaseRepository {
  const _FakePurchaseRepository(this.purchases);

  final List<PurchaseIntake> purchases;

  @override
  Future<PurchaseIntake> createPurchaseIntake(PurchaseIntakeDraft draft) {
    throw UnsupportedError('Reports test fake is read-only.');
  }

  @override
  Future<PurchaseIntake> cancelPurchaseIntake({
    required String purchaseIntakeId,
    required String cancelledByUserId,
    required String cancellationReason,
  }) {
    throw UnsupportedError('Reports test fake is read-only.');
  }

  @override
  Future<List<PurchaseIntake>> listPurchaseIntakes() async {
    return List<PurchaseIntake>.unmodifiable(purchases);
  }
}

class _FakeSaleRepository implements SaleRepository {
  const _FakeSaleRepository(this.sales);

  final List<SaleRecord> sales;

  @override
  Future<SaleRecord> createSale(SaleDraft draft) {
    throw UnsupportedError('Reports test fake is read-only.');
  }

  @override
  Future<SaleRecord> cancelSale({
    required String saleId,
    required String cancelledByUserId,
    required String cancellationReason,
  }) {
    throw UnsupportedError('Reports test fake is read-only.');
  }

  @override
  Future<List<SaleRecord>> listSales() async {
    return List<SaleRecord>.unmodifiable(sales);
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
    throw UnsupportedError('Reports test fake is read-only.');
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

class _FakeSupplierAccountRepository implements SupplierAccountRepository {
  const _FakeSupplierAccountRepository({
    required this.entries,
    required this.payments,
  });

  final List<SupplierAccountEntry> entries;
  final List<SupplierPaymentRecord> payments;

  @override
  Future<List<SupplierAccountEntry>> listEntries() async =>
      List<SupplierAccountEntry>.unmodifiable(entries);

  @override
  Future<List<SupplierPaymentRecord>> listPayments() async =>
      List<SupplierPaymentRecord>.unmodifiable(payments);

  @override
  Future<int> balanceForSupplier(String supplierId) async => 0;

  @override
  Future<Map<String, int>> balancesBySupplierId() async {
    final result = <String, int>{};
    for (final entry in entries) {
      result[entry.supplierId] =
          (result[entry.supplierId] ?? 0) + entry.signedBalanceImpactQirsh;
    }
    return result;
  }

  @override
  Future<SupplierStatement> statementForSupplier(String supplierId) async {
    throw UnsupportedError('Reports test fake.');
  }

  @override
  Future<SupplierAccountEntry> createPurchaseEntry({
    required PurchaseIntake purchase,
  }) {
    throw UnsupportedError('Reports test fake is read-only.');
  }

  @override
  Future<SupplierPaymentRecord> createPayment(SupplierPaymentDraft draft) {
    throw UnsupportedError('Reports test fake is read-only.');
  }

  @override
  Future<SupplierPaymentCancellation> cancelPayment({
    required dynamic user,
    required String paymentId,
    required String reason,
    required String operationRequestId,
  }) {
    throw UnsupportedError('Reports test fake is read-only.');
  }

  @override
  Future<SupplierAccountEntry> reversePurchaseEntry({
    required PurchaseIntake cancelledPurchase,
    required String cancelledByUserId,
    required String cancellationReason,
  }) {
    throw UnsupportedError('Reports test fake is read-only.');
  }

  @override
  Future<SupplierAccountEntry> createOpeningBalanceEntry({
    required String supplierId,
    required int amountQirsh,
    required String createdByUserId,
  }) {
    throw UnsupportedError('Reports test fake is read-only.');
  }

  @override
  Future<bool> hasOpeningBalanceEntry(String supplierId) async => false;
}

class _FakeProductRepository implements ProductRepository {
  const _FakeProductRepository(this.products);

  final List<Product> products;

  @override
  Future<Product> createProduct(ProductDraft draft) {
    throw UnsupportedError('Reports test fake is read-only.');
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
    throw UnsupportedError('Reports test fake is read-only.');
  }

  @override
  Future<Product> updateProduct({
    required String productId,
    required ProductDraft draft,
  }) {
    throw UnsupportedError('Reports test fake is read-only.');
  }
}

final _reportDay = DateTime(2026, 7, 5, 9);
final _before = DateTime(2026, 7, 4, 23, 59);
final _midday = DateTime(2026, 7, 5, 12);
final _evening = DateTime(2026, 7, 5, 18);
final _after = DateTime(2026, 7, 6);
final _now = DateTime(2026, 1, 1);

final _product = Product(
  id: 'product-id',
  name: 'قمح',
  unit: GrainUnit.kilogram,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);

final _productWithCost = Product(
  id: 'product-id',
  name: 'قمح',
  unit: GrainUnit.kilogram,
  isActive: true,
  referenceCostPricePiastersPerKg: 700,
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

final _employee = AppUser(
  id: 'employee-test',
  name: 'موظف',
  phone: '01100000000',
  role: UserRole.employee,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);
