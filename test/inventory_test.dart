import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_controller.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/features/inventory/inventory_screen.dart';

void main() {
  group('InventoryRepository and controller', () {
    test('owner can create the first opening balance', () async {
      final fixture = await _fixture();

      final created = await fixture.controller.createOpeningBalance(
        user: _owner,
        productId: fixture.product.id,
        quantityKg: 1000,
        note: 'بداية المخزون',
      );

      expect(created, isTrue);
      expect(fixture.controller.balanceForProduct(fixture.product.id), 1000);
      expect(fixture.controller.movements, hasLength(1));
      expect(fixture.controller.hasOpeningBalance(fixture.product.id), isTrue);
    });

    test('owner cannot create a second opening balance for same product',
        () async {
      final fixture = await _fixture();

      expect(
        await fixture.controller.createOpeningBalance(
          user: _owner,
          productId: fixture.product.id,
          quantityKg: 1000,
        ),
        isTrue,
      );

      expect(
        await fixture.controller.createOpeningBalance(
          user: _owner,
          productId: fixture.product.id,
          quantityKg: 500,
        ),
        isFalse,
      );
      expect(fixture.controller.balanceForProduct(fixture.product.id), 1000);
      expect(fixture.controller.movements, hasLength(1));
    });

    test('repository rejects a second opening balance', () async {
      final fixture = await _fixture();
      await fixture.inventory.createMovement(
        _draft(productId: fixture.product.id, quantityKg: 400),
      );

      expect(
        () => fixture.inventory.createMovement(
          _draft(productId: fixture.product.id, quantityKg: 100),
        ),
        throwsStateError,
      );
      expect(await fixture.inventory.currentStockKg(fixture.product.id), 400);
    });

    test('employee cannot create opening balance', () async {
      final fixture = await _fixture();

      final created = await fixture.controller.createOpeningBalance(
        user: _employee,
        productId: fixture.product.id,
        quantityKg: 1000,
      );

      expect(created, isFalse);
      expect(await fixture.inventory.currentStockKg(fixture.product.id), 0);
    });

    test('owner can create manual increase and decrease', () async {
      final fixture = await _fixture();

      expect(
        await fixture.controller.createOpeningBalance(
          user: _owner,
          productId: fixture.product.id,
          quantityKg: 1000,
        ),
        isTrue,
      );
      expect(
        await fixture.controller.createManualIncrease(
          user: _owner,
          productId: fixture.product.id,
          quantityKg: 250,
        ),
        isTrue,
      );
      expect(
        await fixture.controller.createManualDecrease(
          user: _owner,
          productId: fixture.product.id,
          quantityKg: 100,
        ),
        isTrue,
      );

      expect(fixture.controller.balanceForProduct(fixture.product.id), 1150);
    });

    test('manual increase still works after opening balance exists', () async {
      final fixture = await _fixture();
      await fixture.controller.createOpeningBalance(
        user: _owner,
        productId: fixture.product.id,
        quantityKg: 1000,
      );

      expect(
        await fixture.controller.createManualIncrease(
          user: _owner,
          productId: fixture.product.id,
          quantityKg: 250,
        ),
        isTrue,
      );
      expect(fixture.controller.balanceForProduct(fixture.product.id), 1250);
    });

    test('manual decrease still works after opening balance when sufficient',
        () async {
      final fixture = await _fixture();
      await fixture.controller.createOpeningBalance(
        user: _owner,
        productId: fixture.product.id,
        quantityKg: 1000,
      );

      expect(
        await fixture.controller.createManualDecrease(
          user: _owner,
          productId: fixture.product.id,
          quantityKg: 250,
        ),
        isTrue,
      );
      expect(fixture.controller.balanceForProduct(fixture.product.id), 750);
    });

    test('employee cannot create manual increase or decrease', () async {
      final fixture = await _fixture();
      await fixture.controller.createOpeningBalance(
        user: _owner,
        productId: fixture.product.id,
        quantityKg: 1000,
      );

      expect(
        await fixture.controller.createManualIncrease(
          user: _employee,
          productId: fixture.product.id,
          quantityKg: 100,
        ),
        isFalse,
      );
      expect(
        await fixture.controller.createManualDecrease(
          user: _employee,
          productId: fixture.product.id,
          quantityKg: 100,
        ),
        isFalse,
      );
      expect(await fixture.inventory.currentStockKg(fixture.product.id), 1000);
    });

    test('stock balance is calculated from movements', () async {
      final fixture = await _fixture();
      await fixture.inventory.createMovement(
        _draft(
          productId: fixture.product.id,
          movementType: StockMovementType.openingBalance,
          quantityKg: 400,
        ),
      );
      await fixture.inventory.createMovement(
        _draft(
          productId: fixture.product.id,
          movementType: StockMovementType.manualIncrease,
          quantityKg: 50,
        ),
      );
      await fixture.inventory.createMovement(
        _draft(
          productId: fixture.product.id,
          movementType: StockMovementType.manualDecrease,
          quantityKg: 25,
        ),
      );

      expect(await fixture.inventory.currentStockKg(fixture.product.id), 425);
    });

    test('product stock cannot go below zero', () async {
      final fixture = await _fixture();
      await fixture.inventory.createMovement(
        _draft(
          productId: fixture.product.id,
          movementType: StockMovementType.openingBalance,
          quantityKg: 10,
        ),
      );

      expect(
        () => fixture.inventory.createMovement(
          _draft(
            productId: fixture.product.id,
            movementType: StockMovementType.manualDecrease,
            quantityKg: 11,
          ),
        ),
        throwsStateError,
      );
    });

    test('zero and negative quantities are rejected', () async {
      final fixture = await _fixture();

      expect(
        () => fixture.inventory.createMovement(
          _draft(productId: fixture.product.id, quantityKg: 0),
        ),
        throwsArgumentError,
      );
      expect(
        () => fixture.inventory.createMovement(
          _draft(productId: fixture.product.id, quantityKg: -1),
        ),
        throwsArgumentError,
      );
    });

    test('movement requires valid product id', () async {
      final fixture = await _fixture();

      expect(
        () => fixture.inventory.createMovement(
          _draft(productId: 'missing-product', quantityKg: 1),
        ),
        throwsStateError,
      );
      expect(
        () => fixture.inventory.currentStockKg('missing-product'),
        throwsStateError,
      );
    });

    test('movement rejects inactive product', () async {
      final fixture = await _fixture();
      await fixture.products.setProductActive(
        productId: fixture.product.id,
        isActive: false,
      );

      expect(
        () => fixture.inventory.createMovement(
          _draft(productId: fixture.product.id, quantityKg: 1),
        ),
        throwsStateError,
      );
    });

    test('movement stores createdByUserId', () async {
      final fixture = await _fixture();

      final movement = await fixture.inventory.createMovement(
        _draft(productId: fixture.product.id, quantityKg: 10),
      );

      expect(movement.createdByUserId, _owner.id);
    });

    test('movement id is non-empty and stable', () async {
      final fixture = await _fixture();

      final movement = await fixture.inventory.createMovement(
        _draft(productId: fixture.product.id, quantityKg: 10),
      );
      final id = movement.id;
      final listed = await fixture.inventory.listMovementsByProduct(
        fixture.product.id,
      );

      expect(movement.hasValidId, isTrue);
      expect(id.trim(), isNotEmpty);
      expect(listed.single.id, id);
    });

    test('movement id is not derived from product or user identity', () async {
      final products = LocalProductRepository();
      final product = await products.createProduct(
        const ProductDraft(
          name: 'قمح خاص',
          code: 'WHEAT-OWNER-CODE',
          unit: GrainUnit.kilogram,
        ),
      );
      final inventory = LocalInventoryRepository(productRepository: products);

      final movement = await inventory.createMovement(
        StockMovementDraft(
          productId: product.id,
          movementType: StockMovementType.openingBalance,
          quantityKg: 10,
          createdByUserId: _owner.id,
          note: _owner.name,
        ),
      );

      expect(movement.id, isNot(contains(product.name)));
      expect(movement.id, isNot(contains(product.code!)));
      expect(movement.id, isNot(contains(_owner.name)));
      expect(movement.id, isNot(contains(_owner.id)));
    });

    test('blank movement ids are invalid', () {
      final movement = StockMovement(
        id: ' ',
        productId: 'product-id',
        movementType: StockMovementType.openingBalance,
        quantityKg: 1,
        createdByUserId: _owner.id,
        createdAt: _now,
      );

      expect(movement.hasValidId, isFalse);
    });

    test('current stock is not stored by editing a product', () async {
      final fixture = await _fixture();
      await fixture.inventory.createMovement(
        _draft(productId: fixture.product.id, quantityKg: 10),
      );
      await fixture.products.updateProduct(
        productId: fixture.product.id,
        draft: const ProductDraft(
          name: 'قمح معدل',
          unit: GrainUnit.kilogram,
        ),
      );

      expect(await fixture.inventory.currentStockKg(fixture.product.id), 10);
    });

    test('product model has no direct stock or balance field', () {
      final productSource =
          File('lib/core/catalog/product.dart').readAsStringSync();

      expect(
        productSource,
        isNot(matches(
            RegExp(r'\b(currentStock|stockKg|balanceKg|quantityKg)\b'))),
      );
    });

    test('product creation still creates no stock', () async {
      final products = LocalProductRepository();
      final inventory = LocalInventoryRepository(productRepository: products);
      final product = await products.createProduct(_productDraft('ذرة'));

      expect(await inventory.currentStockKg(product.id), 0);
      expect(await inventory.listAllMovements(), isEmpty);
    });

    test('ton input converts to kilograms correctly', () {
      expect(GrainUnitConverter.tonsToKilograms(1), 1000);
      expect(GrainUnitConverter.tonsToKilograms(3), 3000);
    });

    test('all product balances are derived from movements', () async {
      final fixture = await _fixture();
      final second = await fixture.products.createProduct(_productDraft('ذرة'));
      await fixture.inventory.createMovement(
        _draft(productId: fixture.product.id, quantityKg: 10),
      );
      await fixture.inventory.createMovement(
        _draft(productId: second.id, quantityKg: 20),
      );

      final balances = await fixture.inventory.allProductBalancesKg();

      expect(balances[fixture.product.id], 10);
      expect(balances[second.id], 20);
    });
  });

  group('InventoryScreen permissions', () {
    testWidgets('inventory UI shows adjustment actions for owner',
        (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final fixture = await _fixture();

      await tester.pumpWidget(
        _inventoryHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();

      expect(find.text('إضافة حركة مخزون'), findsOneWidget);
    });

    testWidgets('inventory UI hides adjustment actions for employee',
        (tester) async {
      final auth = await _signedInController(
        phone: '01100000000',
        password: 'employee123',
      );
      final fixture = await _fixture();

      await tester.pumpWidget(
        _inventoryHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();

      expect(find.text('إضافة حركة مخزون'), findsNothing);
      expect(
        find.text(
            'الأرصدة للعرض فقط. تعديل المخزون وإضافة الحركات للمالك فقط.'),
        findsOneWidget,
      );
    });

    testWidgets('inventory UI hides opening balance after one exists',
        (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final fixture = await _fixture();
      await fixture.controller.createOpeningBalance(
        user: _owner,
        productId: fixture.product.id,
        quantityKg: 1000,
      );

      await tester.pumpWidget(
        _inventoryHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('إضافة حركة مخزون'));
      await tester.pumpAndSettle();

      expect(find.text(StockMovementType.openingBalance.labelAr), findsNothing);
      expect(
          find.text(StockMovementType.manualIncrease.labelAr), findsOneWidget);
      await tester.tap(find.text(StockMovementType.manualIncrease.labelAr));
      await tester.pumpAndSettle();

      expect(find.text(StockMovementType.openingBalance.labelAr), findsNothing);
      expect(
          find.text(StockMovementType.manualDecrease.labelAr), findsOneWidget);
    });
  });
}

StockMovementDraft _draft({
  required String productId,
  StockMovementType movementType = StockMovementType.openingBalance,
  required int quantityKg,
}) {
  return StockMovementDraft(
    productId: productId,
    movementType: movementType,
    quantityKg: quantityKg,
    createdByUserId: _owner.id,
    note: 'اختبار',
  );
}

ProductDraft _productDraft(String name) {
  return ProductDraft(
    name: name,
    unit: GrainUnit.kilogram,
  );
}

Future<_InventoryFixture> _fixture() async {
  final products = LocalProductRepository();
  final product = await products.createProduct(_productDraft('قمح'));
  final inventory = LocalInventoryRepository(productRepository: products);
  final controller = InventoryController(
    inventoryRepository: inventory,
    productRepository: products,
  );
  await controller.load(_owner);

  return _InventoryFixture(
    products: products,
    inventory: inventory,
    controller: controller,
    product: product,
  );
}

Widget _inventoryHarness({
  required AuthController auth,
  required InventoryController controller,
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
      home: InventoryScreen(controller: controller),
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

class _InventoryFixture {
  const _InventoryFixture({
    required this.products,
    required this.inventory,
    required this.controller,
    required this.product,
  });

  final LocalProductRepository products;
  final LocalInventoryRepository inventory;
  final InventoryController controller;
  final Product product;
}

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

final _employee = AppUser(
  id: 'employee-test',
  name: 'موظف',
  phone: '01100000000',
  role: UserRole.employee,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);
