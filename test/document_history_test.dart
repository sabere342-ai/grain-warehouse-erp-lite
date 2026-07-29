import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history_controller.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/features/documents/document_history_screen.dart';
import 'support/product_catalog_read_repository_test_adapter.dart';

void main() {
  group('Document history', () {
    test('purchase history includes active and cancelled documents', () async {
      final fixture = await _fixture();
      final active = await fixture.purchases.createPurchaseIntake(
        _purchaseDraft(fixture, quantityKg: 200),
      );
      final cancelled = await fixture.purchases.createPurchaseIntake(
        _purchaseDraft(fixture, quantityKg: 300),
      );
      await fixture.purchases.cancelPurchaseIntake(
        purchaseIntakeId: cancelled.id,
        cancelledByUserId: _owner.id,
        cancellationReason: _reason,
      );

      final entries = await fixture.history.listHistory(
        filter: const DocumentHistoryFilter(
          type: DocumentHistoryType.purchaseIntake,
        ),
      );

      expect(entries.map((entry) => entry.id),
          containsAll([active.id, cancelled.id]));
      expect(entries.map((entry) => entry.status),
          contains(DocumentHistoryStatus.active));
      expect(entries.map((entry) => entry.status),
          contains(DocumentHistoryStatus.cancelled));
    });

    test('sale history includes active and cancelled documents', () async {
      final fixture = await _fixture();
      final active = await fixture.sales.createSale(_saleDraft(fixture));
      final cancelled = await fixture.sales.createSale(
        _saleDraft(fixture, quantityKg: 150),
      );
      await fixture.sales.cancelSale(
        saleId: cancelled.id,
        cancelledByUserId: _owner.id,
        cancellationReason: _reason,
      );

      final entries = await fixture.history.listHistory(
        filter: const DocumentHistoryFilter(type: DocumentHistoryType.sale),
      );

      expect(entries.map((entry) => entry.id),
          containsAll([active.id, cancelled.id]));
      expect(entries.map((entry) => entry.status),
          contains(DocumentHistoryStatus.active));
      expect(entries.map((entry) => entry.status),
          contains(DocumentHistoryStatus.cancelled));
    });

    test('filters by date range', () async {
      final fixture = await _fixture();
      final sale = await fixture.sales.createSale(_saleDraft(fixture));

      final matching = await fixture.history.listHistory(
        filter: DocumentHistoryFilter(
          from: sale.createdAt.subtract(const Duration(minutes: 1)),
          to: sale.createdAt.add(const Duration(minutes: 1)),
        ),
      );
      final outside = await fixture.history.listHistory(
        filter: DocumentHistoryFilter(
          from: sale.createdAt.add(const Duration(days: 1)),
          to: sale.createdAt.add(const Duration(days: 2)),
        ),
      );

      expect(matching.map((entry) => entry.id), contains(sale.id));
      expect(outside, isEmpty);
    });

    test('filters by cancelled and active status', () async {
      final fixture = await _fixture();
      final active = await fixture.sales.createSale(_saleDraft(fixture));
      final cancelled = await fixture.sales.createSale(
        _saleDraft(fixture, quantityKg: 150),
      );
      await fixture.sales.cancelSale(
        saleId: cancelled.id,
        cancelledByUserId: _owner.id,
        cancellationReason: _reason,
      );

      final activeEntries = await fixture.history.listHistory(
        filter: const DocumentHistoryFilter(
          status: DocumentHistoryStatus.active,
        ),
      );
      final cancelledEntries = await fixture.history.listHistory(
        filter: const DocumentHistoryFilter(
          status: DocumentHistoryStatus.cancelled,
        ),
      );

      expect(activeEntries.map((entry) => entry.id), contains(active.id));
      expect(activeEntries.map((entry) => entry.id),
          isNot(contains(cancelled.id)));
      expect(cancelledEntries.map((entry) => entry.id), contains(cancelled.id));
      expect(cancelledEntries.map((entry) => entry.id),
          isNot(contains(active.id)));
    });

    test('cancelled document shows Arabic cancelled label', () async {
      final fixture = await _fixture();
      final sale = await fixture.sales.createSale(_saleDraft(fixture));
      await fixture.sales.cancelSale(
        saleId: sale.id,
        cancelledByUserId: _owner.id,
        cancellationReason: _reason,
      );

      final entries = await fixture.history.listHistory(
        filter: const DocumentHistoryFilter(
          status: DocumentHistoryStatus.cancelled,
        ),
      );

      expect(entries.single.status.labelAr, 'ملغي');
    });

    test('cancellation metadata is visible to owner', () async {
      final fixture = await _fixture();
      final sale = await fixture.sales.createSale(_saleDraft(fixture));
      await fixture.sales.cancelSale(
        saleId: sale.id,
        cancelledByUserId: _owner.id,
        cancellationReason: _reason,
      );
      final controller = DocumentHistoryController(repository: fixture.history);

      await controller.load(_owner);

      expect(controller.canViewOwnerAudit, isTrue);
      expect(
          controller.entries.single.cancellation!.cancellationReason, _reason);
      expect(
          controller.entries.single.cancellation!.cancelledByUserId, _owner.id);
    });

    test('linked original and reversal stock movements are shown', () async {
      final fixture = await _fixture();
      final sale = await fixture.sales.createSale(_saleDraft(fixture));
      await fixture.sales.cancelSale(
        saleId: sale.id,
        cancelledByUserId: _owner.id,
        cancellationReason: _reason,
      );

      final entries = await fixture.history.listHistory(
        filter: const DocumentHistoryFilter(
          status: DocumentHistoryStatus.cancelled,
        ),
      );
      final entry = entries.single;

      expect(entry.originalMovement!.id, sale.stockMovementId);
      expect(entry.originalMovement!.movementType, StockMovementType.sale);
      expect(entry.reversalMovements.single.movementType,
          StockMovementType.saleCancellation);
      expect(entry.reversalMovements.single.reversedMovementId,
          sale.stockMovementId);
    });

    testWidgets('employee cannot access owner-only audit details',
        (tester) async {
      final fixture = await _fixture();
      final sale = await fixture.sales.createSale(_saleDraft(fixture));
      await fixture.sales.cancelSale(
        saleId: sale.id,
        cancelledByUserId: _owner.id,
        cancellationReason: _reason,
      );
      final controller = DocumentHistoryController(repository: fixture.history);
      final auth = await _signedInController(
        phone: '01100000000',
        password: 'employee123',
      );

      await tester
          .pumpWidget(_historyHarness(auth: auth, controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ExpansionTile).first);
      await tester.pumpAndSettle();

      expect(controller.canViewOwnerAudit, isFalse);
      expect(find.text('سبب الإلغاء: $_reason'), findsNothing);
      expect(find.text('ملغي'), findsOneWidget);
    });
  });
}

Future<_Fixture> _fixture() async {
  final suppliers = LocalSupplierRepository();
  final products = LocalProductRepository();
  final supplier = await suppliers.createSupplier(
    const SupplierDraft(name: 'مورد القمح'),
  );
  final product = await products.createProduct(
    const ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
  );
  final customers = LocalCustomerRepository();
  final customer = await customers.createCustomer(
    const CustomerDraft(name: 'عميل اختبار', isActive: true),
  );
  final inventory = LocalInventoryRepository(productRepository: products);
  await inventory.createMovement(
    StockMovementDraft(
      productId: product.id,
      movementType: StockMovementType.openingBalance,
      quantityKg: 2000,
      createdByUserId: _owner.id,
    ),
  );
  final purchases = LocalPurchaseRepository(
    supplierRepository: suppliers,
    productRepository: products,
    inventoryRepository: inventory,
  );
  final sales = LocalSaleRepository(
    productRepository: products,
    inventoryRepository: inventory,
  );
  final history = LocalDocumentHistoryRepository(
    purchaseRepository: purchases,
    saleRepository: sales,
    productCatalogReadRepository:
        ProductCatalogReadRepositoryTestAdapter(products),
    inventoryRepository: inventory,
  );

  return _Fixture(
    supplier: supplier,
    product: product,
    purchases: purchases,
    sales: sales,
    history: history,
    customer: customer,
  );
}

PurchaseIntakeDraft _purchaseDraft(
  _Fixture fixture, {
  int quantityKg = 100,
}) {
  return PurchaseIntakeDraft(
    supplierId: fixture.supplier.id,
    productId: fixture.product.id,
    quantityKg: quantityKg,
    entryUnit: GrainUnit.kilogram,
    unitPricePiastersPerKg: 650,
    createdByUserId: _owner.id,
  );
}

SaleDraft _saleDraft(
  _Fixture fixture, {
  int quantityKg = 100,
  String? customerId,
}) {
  return SaleDraft(
    productId: fixture.product.id,
    quantityKg: quantityKg,
    salePriceQirshPerKg: 700,
    createdByUserId: _owner.id,
    createdByUserName: _owner.name,
    customerId: customerId ?? fixture.customer.id,
  );
}

Widget _historyHarness({
  required AuthController auth,
  required DocumentHistoryController controller,
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
      home: DocumentHistoryScreen(controller: controller),
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

class _Fixture {
  const _Fixture({
    required this.supplier,
    required this.product,
    required this.purchases,
    required this.sales,
    required this.history,
    required this.customer,
  });

  final Supplier supplier;
  final Product product;
  final LocalPurchaseRepository purchases;
  final LocalSaleRepository sales;
  final LocalDocumentHistoryRepository history;
  final Customer customer;
}

const _reason = 'خطأ في الإدخال';
final _now = DateTime(2026, 1, 1);

final _owner = AppUser(
  id: 'owner-test',
  name: 'مالك',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);
