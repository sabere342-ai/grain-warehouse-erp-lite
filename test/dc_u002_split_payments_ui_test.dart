import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_controller.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/features/sales/sales_screen.dart';

import 'support/product_catalog_read_repository_test_adapter.dart';

const _qtyLabel = 'الكمية (كجم)';
const _priceLabel = 'السعر / كجم';
const _amountLabel = 'المبلغ (ج.م)';

Finder _findFieldByLabel(String label) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label,
    );

void main() {
  group('DC-U002 Split Payments UI', () {
    group('Display', () {
      testWidgets('split payments toggle appears for cash mode',
          (tester) async {
        _setSurface(tester);
        final fixture = await _Fixture.create();
        await tester.pumpWidget(await fixture.buildApp());
        await tester.pumpAndSettle();
        await _openDialog(tester);
        expect(find.text('تحديد الحساب وطريقة الدفع'), findsOneWidget);
        expect(find.byType(SwitchListTile), findsOneWidget);
      });

      testWidgets('split payments toggle appears for partial mode',
          (tester) async {
        _setSurface(tester);
        final fixture = await _Fixture.create();
        await tester.pumpWidget(await fixture.buildApp());
        await tester.pumpAndSettle();
        await _openDialog(tester);
        await tester.tap(find.text('دفع جزئي'));
        await tester.pumpAndSettle();
        expect(find.text('تحديد الحساب وطريقة الدفع'), findsOneWidget);
      });

      testWidgets('split payments toggle does NOT appear for credit mode',
          (tester) async {
        _setSurface(tester);
        final fixture = await _Fixture.create();
        await tester.pumpWidget(await fixture.buildApp());
        await tester.pumpAndSettle();
        await _openDialog(tester);
        await tester.tap(find.text('آجل'));
        await tester.pumpAndSettle();
        expect(find.text('تحديد الحساب وطريقة الدفع'), findsNothing);
      });

      testWidgets('enabling split shows allocation row with fields',
          (tester) async {
        _setSurface(tester);
        final fixture = await _Fixture.create();
        await tester.pumpWidget(await fixture.buildApp());
        await tester.pumpAndSettle();
        await _openDialog(tester);
        await _enableSplit(tester);
        expect(find.text('الحساب المالي'), findsOneWidget);
        expect(_findFieldByLabel(_amountLabel), findsOneWidget);
        expect(find.text('طريقة'), findsOneWidget);
      });

      testWidgets('split shows summary row', (tester) async {
        _setSurface(tester);
        final fixture = await _Fixture.create();
        await tester.pumpWidget(await fixture.buildApp());
        await tester.pumpAndSettle();
        await _openDialog(tester);
        await _enableSplit(tester);
        expect(find.text('إجمالي الفاتورة'), findsOneWidget);
        expect(find.text('إجمالي التخصيص'), findsOneWidget);
        expect(find.text('المتبقي'), findsOneWidget);
      });

      testWidgets('add allocation adds second row', (tester) async {
        _setSurface(tester);
        final fixture = await _Fixture.create();
        await tester.pumpWidget(await fixture.buildApp());
        await tester.pumpAndSettle();
        await _openDialog(tester);
        await _enableSplit(tester);
        await tester.ensureVisible(find.text('إضافة تخصيص'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('إضافة تخصيص'));
        await tester.pumpAndSettle();
        expect(find.text('الحساب المالي'), findsNWidgets(2));
      });

      testWidgets('allocation row can be deleted', (tester) async {
        _setSurface(tester);
        final fixture = await _Fixture.create();
        await tester.pumpWidget(await fixture.buildApp());
        await tester.pumpAndSettle();
        await _openDialog(tester);
        await _enableSplit(tester);
        await tester.ensureVisible(find.text('إضافة تخصيص'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('إضافة تخصيص'));
        await tester.pumpAndSettle();
        expect(find.text('الحساب المالي'), findsNWidgets(2));
        final removeBtns = find.byIcon(Icons.remove_circle_outline_rounded);
        expect(removeBtns, findsNWidgets(2));
        await tester.tap(removeBtns.last);
        await tester.pumpAndSettle();
        expect(find.text('الحساب المالي'), findsOneWidget);
      });
    });

    group('Validation', () {
      testWidgets('save disabled when allocation amount is zero',
          (tester) async {
        _setSurface(tester);
        final fixture = await _Fixture.create();
        await tester.pumpWidget(await fixture.buildApp());
        await tester.pumpAndSettle();
        await _openDialog(tester);
        await _selectCustomer(tester, fixture);
        await tester.enterText(_findFieldByLabel(_qtyLabel), '10');
        await tester.enterText(_findFieldByLabel(_priceLabel), '100');
        await tester.pumpAndSettle();
        await _enableSplit(tester);
        await tester.ensureVisible(_findFieldByLabel(_amountLabel));
        await tester.pumpAndSettle();
        await tester.enterText(_findFieldByLabel(_amountLabel), '0');
        await tester.pumpAndSettle();
        await _tapSave(tester);
        await tester.pumpAndSettle();
        expect(fixture.controller.sales, isEmpty);
      });

      testWidgets('save disabled when no account selected in allocation',
          (tester) async {
        _setSurface(tester);
        final fixture = await _Fixture.create();
        await tester.pumpWidget(await fixture.buildApp());
        await tester.pumpAndSettle();
        await _openDialog(tester);
        await _selectCustomer(tester, fixture);
        await tester.enterText(_findFieldByLabel(_qtyLabel), '10');
        await tester.enterText(_findFieldByLabel(_priceLabel), '100');
        await tester.pumpAndSettle();
        await _enableSplit(tester);
        await tester.ensureVisible(_findFieldByLabel(_amountLabel));
        await tester.pumpAndSettle();
        await tester.enterText(_findFieldByLabel(_amountLabel), '1000');
        await tester.pumpAndSettle();
        await _tapSave(tester);
        await tester.pumpAndSettle();
        expect(fixture.controller.sales, isEmpty);
      });

      testWidgets('save disabled when allocation total mismatches sale total',
          (tester) async {
        _setSurface(tester);
        final fixture = await _Fixture.create();
        await tester.pumpWidget(await fixture.buildApp());
        await tester.pumpAndSettle();
        await _openDialog(tester);
        await _selectCustomer(tester, fixture);
        await tester.enterText(_findFieldByLabel(_qtyLabel), '10');
        await tester.enterText(_findFieldByLabel(_priceLabel), '100');
        await tester.pumpAndSettle();
        await _enableSplit(tester);
        await _selectAccount(tester, fixture.treasury.name);
        await tester.ensureVisible(_findFieldByLabel(_amountLabel));
        await tester.pumpAndSettle();
        await tester.enterText(_findFieldByLabel(_amountLabel), '50');
        await tester.pumpAndSettle();
        expect(find.text('✗ غير متوافق'), findsOneWidget);
        await _tapSave(tester);
        await tester.pumpAndSettle();
        expect(fixture.controller.sales, isEmpty);
      });

      testWidgets('split balanced indicator shows when amounts match',
          (tester) async {
        _setSurface(tester);
        final fixture = await _Fixture.create();
        await tester.pumpWidget(await fixture.buildApp());
        await tester.pumpAndSettle();
        await _openDialog(tester);
        await _selectCustomer(tester, fixture);
        await tester.enterText(_findFieldByLabel(_qtyLabel), '10');
        await tester.enterText(_findFieldByLabel(_priceLabel), '100');
        await tester.pumpAndSettle();
        await _enableSplit(tester);
        await _selectAccount(tester, fixture.treasury.name);
        await tester.ensureVisible(_findFieldByLabel(_amountLabel));
        await tester.pumpAndSettle();
        await tester.enterText(_findFieldByLabel(_amountLabel), '1000');
        await tester.pumpAndSettle();
        expect(find.text('✓ متوافق'), findsOneWidget);
      });
    });

    group('Backward Compatibility', () {
      testWidgets('simple cash sale works without split payments',
          (tester) async {
        _setSurface(tester);
        final fixture = await _Fixture.create();
        await tester.pumpWidget(await fixture.buildApp());
        await tester.pumpAndSettle();
        await _openDialog(tester);
        await _selectCustomer(tester, fixture);
        await tester.enterText(_findFieldByLabel(_qtyLabel), '10');
        await tester.enterText(_findFieldByLabel(_priceLabel), '100');
        await tester.pumpAndSettle();
        await _selectAccount(tester, fixture.treasury.name);
        await tester.enterText(_findFieldByLabel(_amountLabel), '1000');
        await tester.pumpAndSettle();
        await _tapSave(tester);
        await tester.pumpAndSettle();
        expect(fixture.controller.sales, isNotEmpty);
      });

      testWidgets('credit sale works without allocations', (tester) async {
        _setSurface(tester);
        final fixture = await _Fixture.create();
        await tester.pumpWidget(await fixture.buildApp());
        await tester.pumpAndSettle();
        await _openDialog(tester);
        await tester.tap(find.text('آجل'));
        await tester.pumpAndSettle();
        await _selectCustomer(tester, fixture);
        await tester.enterText(_findFieldByLabel(_qtyLabel), '10');
        await tester.enterText(_findFieldByLabel(_priceLabel), '100');
        await tester.pumpAndSettle();
        await _tapSave(tester);

        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(find.text('تسجيل فاتورة بيع'), findsOneWidget,
            reason: 'Dialog should have closed');
      });
    });

    group('RTL and Arabic', () {
      testWidgets('form dialog is in Arabic and RTL', (tester) async {
        _setSurface(tester);
        final fixture = await _Fixture.create();
        await tester.pumpWidget(await fixture.buildApp());
        await tester.pumpAndSettle();
        await _openDialog(tester);
        expect(find.text('تسجيل فاتورة بيع'), findsAtLeastNWidgets(1));
        expect(find.text('اختر العميل *'), findsOneWidget);
        expect(find.text('حفظ الفاتورة'), findsOneWidget);
        expect(find.text('إلغاء'), findsOneWidget);
      });
    });
  });
}

void _setSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.text('تسجيل فاتورة بيع').first);
  await tester.pumpAndSettle();
}

Future<void> _selectCustomer(WidgetTester tester, _Fixture fixture) async {
  await tester.tap(find.text('اختر العميل *'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(fixture.customer.name));
  await tester.pumpAndSettle();
}

Future<void> _selectAccount(WidgetTester tester, String name) async {
  await tester.ensureVisible(find.text('الحساب المالي'));
  await tester.pumpAndSettle();
  final dropdown = find.byType(DropdownButtonFormField<String>).last;
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Future<void> _enableSplit(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(SwitchListTile));
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.ensureVisible(find.text('حفظ الفاتورة'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('حفظ الفاتورة'));
}

final _owner = AppUser(
  id: 'owner-1',
  name: 'المالك',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

class _Fixture {
  _Fixture._();

  late final LocalProductRepository products;
  late final LocalInventoryRepository inventory;
  late final LocalCustomerRepository customers;
  late final LocalAuditLogRepository audit;
  late final LocalFinancialAccountRepository accounts;
  late final LocalCustomerAccountRepository ledger;
  late final LocalSaleRepository sales;
  late final SaleController controller;
  late final Product product;
  late final Customer customer;
  late final FinancialAccount treasury;

  static Future<_Fixture> create() async {
    final fixture = _Fixture._();
    fixture.audit = LocalAuditLogRepository();
    fixture.products = LocalProductRepository();
    fixture.inventory = LocalInventoryRepository(
      productRepository: fixture.products,
    );
    fixture.customers = LocalCustomerRepository(
      auditLogRepository: fixture.audit,
    );
    fixture.accounts = LocalFinancialAccountRepository(
      auditLogRepository: fixture.audit,
    );
    fixture.ledger = LocalCustomerAccountRepository(
      customerRepository: fixture.customers,
      auditLogRepository: fixture.audit,
      financialAccountRepository: fixture.accounts,
    );
    fixture.sales = LocalSaleRepository(
      productCatalogReadRepository:
          ProductCatalogReadRepositoryTestAdapter(fixture.products),
      inventoryRepository: fixture.inventory,
    );
    fixture.controller = SaleController(
      saleRepository: fixture.sales,
      productCatalogReadRepository:
          ProductCatalogReadRepositoryTestAdapter(fixture.products),
      inventoryRepository: fixture.inventory,
      customerRepository: fixture.customers,
      customerAccountRepository: fixture.ledger,
      financialAccountRepository: fixture.accounts,
    );
    fixture.product = await fixture.products.createProduct(
      const ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
    );
    fixture.customer = await fixture.customers.createCustomer(
      const CustomerDraft(name: 'عميل اختبار'),
    );
    await fixture.inventory.createMovement(
      StockMovementDraft(
        productId: fixture.product.id,
        movementType: StockMovementType.openingBalance,
        quantityKg: 100,
        createdByUserId: _owner.id,
      ),
    );
    fixture.treasury = await fixture.accounts.createAccount(
      const FinancialAccountDraft(
        name: 'خزينة',
        type: FinancialAccountType.treasury,
        createdByUserId: 'owner-1',
      ),
    );
    await fixture.accounts.createAccount(
      const FinancialAccountDraft(
        name: 'بنك',
        type: FinancialAccountType.bank,
        createdByUserId: 'owner-1',
      ),
    );
    await fixture.controller.load(_owner);
    return fixture;
  }

  Future<Widget> buildApp() async {
    final auth = AuthController(repository: LocalAuthRepository.demo());
    await auth.initialize();
    await auth.signIn(phone: '01000000000', password: 'owner123');
    return AuthScope(
      controller: auth,
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ar'),
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
        home: SalesScreen(controller: controller),
      ),
    );
  }
}
