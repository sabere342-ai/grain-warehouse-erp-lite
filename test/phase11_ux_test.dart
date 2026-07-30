import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_controller.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history_controller.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/reports/report_controller.dart';
import 'package:grain_warehouse_erp_lite/core/reports/report_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_controller.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/features/documents/document_history_screen.dart';
import 'package:grain_warehouse_erp_lite/features/products/products_screen.dart';
import 'package:grain_warehouse_erp_lite/features/reports/reports_screen.dart';
import 'package:grain_warehouse_erp_lite/features/sales/sales_screen.dart';

import 'support/product_catalog_read_repository_test_adapter.dart';

void main() {
  group('Phase 11 Arabic UX clarity', () {
    testWidgets('shows clear Arabic empty state labels', (tester) async {
      final auth = await _signedInOwner();
      final products = ProductController(repository: LocalProductRepository());
      final salesFixture = await _salesFixture(createSale: false);

      await tester.pumpWidget(
        _harness(auth: auth, child: ProductsScreen(controller: products)),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('لا توجد أصناف حبوب مسجلة بعد'),
        findsOneWidget,
      );
      expect(
        find.text('أضف صنفا مثل قمح أو ذرة قبل تسجيل المخزون.'),
        findsOneWidget,
      );

      await tester.pumpWidget(
        _harness(
          auth: auth,
          child: SalesScreen(controller: salesFixture.controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('لا توجد فواتير بيع'), findsOneWidget);
      expect(
        find.text('ستظهر هنا فواتير البيع بعد تنفيذها.'),
        findsOneWidget,
      );
    });

    testWidgets('shows practical Arabic validation messages', (tester) async {
      final auth = await _signedInOwner();
      final fixture = await _salesFixture(createSale: false);

      await tester.pumpWidget(
        _harness(
            auth: auth, child: SalesScreen(controller: fixture.controller)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('تسجيل فاتورة بيع'));
      await tester.pumpAndSettle();

      expect(find.text('حفظ الفاتورة'), findsOneWidget);
    });

    testWidgets('employee sees owner-only guidance text', (tester) async {
      final auth = await _signedInEmployee();
      final products = ProductController(repository: LocalProductRepository());

      await tester.pumpWidget(
        _harness(auth: auth, child: ProductsScreen(controller: products)),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('عرض الأصناف النشطة فقط. إضافة وتعديل الأصناف للمالك فقط.'),
        findsOneWidget,
      );
      expect(find.text('إضافة صنف حبوب'), findsNothing);
    });

    testWidgets('cancellation confirmation explains stock reversal',
        (tester) async {
      final auth = await _signedInOwner();
      final fixture = await _salesFixture(createSale: true);

      await tester.pumpWidget(
        _harness(
            auth: auth, child: SalesScreen(controller: fixture.controller)),
      );
      await tester.pumpAndSettle();
      final cancelButton = find.text('إلغاء مستند البيع');
      await tester.drag(find.byType(ListView), const Offset(0, -360));
      await tester.pumpAndSettle();
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'تحذير مهم: سيتم إنشاء حركات مخزون عكسية لإلغاء أثر هذا البيع. لن يتم حذف مستند البيع الأصلي أو الحركة الأصلية، وسيظهر الإلغاء في سجل المستندات للمالك.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('document history shows no results state', (tester) async {
      final auth = await _signedInOwner();
      final controller = DocumentHistoryController(
        repository: _EmptyDocumentHistoryRepository(),
      );

      await tester.pumpWidget(
        _harness(
            auth: auth, child: DocumentHistoryScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('لا توجد نتائج'),
        findsOneWidget,
      );
    });

    testWidgets('reports show empty state for selected date', (tester) async {
      final auth = await _signedInOwner();
      final controller = ReportController(repository: _emptyReportRepository());

      await tester.pumpWidget(
        _harness(auth: auth, child: ReportsScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'لا توجد حركة في التاريخ المحدد. لا توجد مشتريات أو مبيعات أو حركات مخزون لهذا اليوم.',
        ),
        findsOneWidget,
      );
    });
  });
}

Future<_SalesFixture> _salesFixture({required bool createSale}) async {
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
      createdByUserId: 'owner-demo',
    ),
  );
  final customers = LocalCustomerRepository();
  final customer = await customers.createCustomer(
    const CustomerDraft(name: 'عميل', isActive: true),
  );
  final sales = LocalSaleRepository(
    productRepository: products,
    inventoryRepository: inventory,
  );
  SaleRecord? sale;
  if (createSale) {
    sale = await sales.createSale(
      SaleDraft(
        productId: product.id,
        quantityKg: 100,
        salePriceQirshPerKg: 700,
        createdByUserId: 'owner-demo',
        createdByUserName: 'مالك المخزن',
        customerId: customer.id,
      ),
    );
  }
  final controller = SaleController(
    saleRepository: sales,
    productRepository: products,
    inventoryRepository: inventory,
    customerRepository: customers,
  );
  final owner = (await LocalAuthRepository.demo().signIn(
    phone: '01000000000',
    password: 'owner123',
  ))!;
  await controller.load(owner);

  return _SalesFixture(controller: controller, sale: sale);
}

LocalReportRepository _emptyReportRepository() {
  final products = LocalProductRepository();
  final inventory = LocalInventoryRepository(productRepository: products);
  return LocalReportRepository(
    purchaseRepository: LocalPurchaseRepository(
      supplierRepository: LocalSupplierRepository(),
      productRepository: products,
      inventoryRepository: inventory,
    ),
    saleRepository: LocalSaleRepository(
      productRepository: products,
      inventoryRepository: inventory,
    ),
    inventoryRepository: inventory,
    productCatalogReadRepository:
        ProductCatalogReadRepositoryTestAdapter(products),
  );
}

Widget _harness({
  required AuthController auth,
  required Widget child,
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
      home: child,
    ),
  );
}

Future<AuthController> _signedInOwner() {
  return _signedInController(phone: '01000000000', password: 'owner123');
}

Future<AuthController> _signedInEmployee() {
  return _signedInController(phone: '01100000000', password: 'employee123');
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

class _SalesFixture {
  const _SalesFixture({
    required this.controller,
    required this.sale,
  });

  final SaleController controller;
  final SaleRecord? sale;
}

class _EmptyDocumentHistoryRepository implements DocumentHistoryRepository {
  @override
  Future<List<DocumentHistoryEntry>> listHistory({
    DocumentHistoryFilter filter = const DocumentHistoryFilter(),
  }) async {
    return const [];
  }
}
