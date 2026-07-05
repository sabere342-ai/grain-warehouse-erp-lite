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
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_controller.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_controller.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/features/purchases/purchases_screen.dart';
import 'package:grain_warehouse_erp_lite/features/suppliers/suppliers_screen.dart';

void main() {
  group('Supplier management', () {
    test('owner can create supplier', () async {
      final controller =
          SupplierController(repository: LocalSupplierRepository());

      final created = await controller.createSupplier(
        user: _owner,
        draft: _supplierDraft(name: 'مورد القمح', phone: '01011112222'),
      );

      expect(created, isTrue);
      expect(controller.suppliers, hasLength(1));
      expect(controller.suppliers.single.name, 'مورد القمح');
    });

    test('employee cannot create supplier', () async {
      final controller =
          SupplierController(repository: LocalSupplierRepository());

      final created = await controller.createSupplier(
        user: _employee,
        draft: _supplierDraft(name: 'مورد ذرة'),
      );

      expect(created, isFalse);
      expect(controller.suppliers, isEmpty);
      expect(controller.errorMessage, contains('صلاحية'));
    });

    test('blank supplier name is rejected', () async {
      final repository = LocalSupplierRepository();

      expect(
        () => repository.createSupplier(_supplierDraft(name: ' ')),
        throwsArgumentError,
      );
    });

    test('duplicate supplier name is rejected', () async {
      final repository = LocalSupplierRepository();
      await repository.createSupplier(_supplierDraft(name: 'مورد القمح'));

      expect(
        () => repository.createSupplier(_supplierDraft(name: ' مورد القمح ')),
        throwsStateError,
      );
    });

    test('duplicate supplier phone is rejected when provided', () async {
      final repository = LocalSupplierRepository();
      await repository.createSupplier(
        _supplierDraft(name: 'الأول', phone: '01011112222'),
      );

      expect(
        () => repository.createSupplier(
          _supplierDraft(name: 'الثاني', phone: ' 01011112222 '),
        ),
        throwsStateError,
      );
    });

    test('supplier id is non-empty and stable', () async {
      final repository = LocalSupplierRepository();
      final supplier = await repository.createSupplier(
        _supplierDraft(name: 'مورد ثابت'),
      );
      final id = supplier.id;

      final updated = await repository.updateSupplier(
        supplierId: supplier.id,
        draft: _supplierDraft(name: 'مورد ثابت معدل'),
      );
      final inactive = await repository.setSupplierActive(
        supplierId: supplier.id,
        isActive: false,
      );

      expect(id.trim(), isNotEmpty);
      expect(updated.id, id);
      expect(inactive.id, id);
    });

    test('owner can deactivate supplier', () async {
      final repository = LocalSupplierRepository();
      final controller = SupplierController(repository: repository);
      await controller.createSupplier(
        user: _owner,
        draft: _supplierDraft(name: 'مورد شعير'),
      );
      final supplierId = controller.suppliers.single.id;

      final changed = await controller.setSupplierActive(
        user: _owner,
        supplierId: supplierId,
        isActive: false,
      );

      expect(changed, isTrue);
      expect(controller.suppliers.single.isActive, isFalse);
    });

    test('employee cannot deactivate supplier', () async {
      final repository = LocalSupplierRepository();
      final supplier = await repository.createSupplier(
        _supplierDraft(name: 'مورد فول'),
      );
      final controller = SupplierController(repository: repository);

      final changed = await controller.setSupplierActive(
        user: _employee,
        supplierId: supplier.id,
        isActive: false,
      );
      final suppliers = await repository.listSuppliers();

      expect(changed, isFalse);
      expect(suppliers.single.isActive, isTrue);
    });
  });

  group('Purchase intake', () {
    test('owner can create purchase intake', () async {
      final fixture = await _fixture();

      final created = await fixture.purchaseController.createPurchaseIntake(
        user: _owner,
        draft: _purchaseDraft(fixture),
      );

      expect(created, isTrue);
      expect(fixture.purchaseController.intakes, hasLength(1));
      expect(await fixture.inventory.currentStockKg(fixture.product.id), 1000);
    });

    test('employee cannot create purchase intake', () async {
      final fixture = await _fixture();

      final created = await fixture.purchaseController.createPurchaseIntake(
        user: _employee,
        draft: _purchaseDraft(fixture, createdByUserId: _employee.id),
      );

      expect(created, isFalse);
      expect(await fixture.purchaseRepository.listPurchaseIntakes(), isEmpty);
      expect(await fixture.inventory.listAllMovements(), isEmpty);
    });

    test('purchase intake requires valid active supplier', () async {
      final fixture = await _fixture();

      expect(
        () => fixture.purchaseRepository.createPurchaseIntake(
          _purchaseDraft(fixture, supplierId: 'missing-supplier'),
        ),
        throwsStateError,
      );

      await fixture.suppliers.setSupplierActive(
        supplierId: fixture.supplier.id,
        isActive: false,
      );
      expect(
        () => fixture.purchaseRepository.createPurchaseIntake(
          _purchaseDraft(fixture),
        ),
        throwsStateError,
      );
    });

    test('purchase intake requires valid active product', () async {
      final fixture = await _fixture();

      expect(
        () => fixture.purchaseRepository.createPurchaseIntake(
          _purchaseDraft(fixture, productId: 'missing-product'),
        ),
        throwsStateError,
      );

      await fixture.products.setProductActive(
        productId: fixture.product.id,
        isActive: false,
      );
      expect(
        () => fixture.purchaseRepository.createPurchaseIntake(
          _purchaseDraft(fixture),
        ),
        throwsStateError,
      );
    });

    test('purchase intake rejects zero and negative quantity', () async {
      final fixture = await _fixture();

      expect(
        () => fixture.purchaseRepository.createPurchaseIntake(
          _purchaseDraft(fixture, quantityKg: 0),
        ),
        throwsArgumentError,
      );
      expect(
        () => fixture.purchaseRepository.createPurchaseIntake(
          _purchaseDraft(fixture, quantityKg: -1),
        ),
        throwsArgumentError,
      );
    });

    test('purchase intake rejects zero and negative price', () async {
      final fixture = await _fixture();

      expect(
        () => fixture.purchaseRepository.createPurchaseIntake(
          _purchaseDraft(fixture, unitPricePiastersPerKg: 0),
        ),
        throwsArgumentError,
      );
      expect(
        () => fixture.purchaseRepository.createPurchaseIntake(
          _purchaseDraft(fixture, unitPricePiastersPerKg: -1),
        ),
        throwsArgumentError,
      );
    });

    test('ton input converts to kilograms correctly', () {
      expect(GrainUnitConverter.tonsToKilograms(2), 2000);
    });

    test('total amount equals quantity times unit price', () async {
      final fixture = await _fixture();

      final intake = await fixture.purchaseRepository.createPurchaseIntake(
        _purchaseDraft(
          fixture,
          quantityKg: 2500,
          unitPricePiastersPerKg: 725,
        ),
      );

      expect(intake.totalAmountPiasters, 1812500);
    });

    test('purchase intake stores createdByUserId', () async {
      final fixture = await _fixture();

      final intake = await fixture.purchaseRepository.createPurchaseIntake(
        _purchaseDraft(fixture),
      );

      expect(intake.createdByUserId, _owner.id);
    });

    test('purchase intake id is non-empty and stable', () async {
      final fixture = await _fixture();

      final intake = await fixture.purchaseRepository.createPurchaseIntake(
        _purchaseDraft(fixture),
      );
      final id = intake.id;
      final listed = await fixture.purchaseRepository.listPurchaseIntakes();

      expect(id.trim(), isNotEmpty);
      expect(intake.hasValidId, isTrue);
      expect(listed.single.id, id);
    });

    test('purchase intake increases stock through movement only', () async {
      final fixture = await _fixture();

      await fixture.purchaseRepository.createPurchaseIntake(
        _purchaseDraft(fixture, quantityKg: 750),
      );

      final movements = await fixture.inventory.listAllMovements();
      expect(movements, hasLength(1));
      expect(movements.single.movementType, StockMovementType.purchaseIntake);
      expect(await fixture.inventory.currentStockKg(fixture.product.id), 750);
    });

    test('product balance field is still not introduced', () {
      final productSource = File('lib/core/catalog/product.dart').readAsStringSync();

      expect(
        productSource,
        isNot(matches(RegExp(r'\b(currentStock|stockKg|balanceKg|quantityKg)\b'))),
      );
    });

    test('failed purchase intake does not create partial stock movement',
        () async {
      final fixture = await _fixture();

      expect(
        () => fixture.purchaseRepository.createPurchaseIntake(
          _purchaseDraft(fixture, quantityKg: 0),
        ),
        throwsArgumentError,
      );
      expect(await fixture.purchaseRepository.listPurchaseIntakes(), isEmpty);
      expect(await fixture.inventory.listAllMovements(), isEmpty);
    });

    test('failed stock movement does not save purchase intake', () async {
      final suppliers = LocalSupplierRepository();
      final products = LocalProductRepository();
      final supplier = await suppliers.createSupplier(
        _supplierDraft(name: 'مورد اختبار'),
      );
      final product = await products.createProduct(_productDraft());
      final repository = LocalPurchaseRepository(
        supplierRepository: suppliers,
        productRepository: products,
        inventoryRepository: _FailingInventoryRepository(),
      );

      expect(
        () => repository.createPurchaseIntake(
          PurchaseIntakeDraft(
            supplierId: supplier.id,
            productId: product.id,
            quantityKg: 10,
            entryUnit: GrainUnit.kilogram,
            unitPricePiastersPerKg: 100,
            createdByUserId: _owner.id,
          ),
        ),
        throwsStateError,
      );
      expect(await repository.listPurchaseIntakes(), isEmpty);
    });

    test('inactive supplier cannot be used in purchase intake', () async {
      final fixture = await _fixture();
      await fixture.suppliers.setSupplierActive(
        supplierId: fixture.supplier.id,
        isActive: false,
      );

      expect(
        () => fixture.purchaseRepository.createPurchaseIntake(
          _purchaseDraft(fixture),
        ),
        throwsStateError,
      );
    });
  });

  group('Phase 6 UI permissions', () {
    testWidgets('supplier management actions visible for owner',
        (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final controller =
          SupplierController(repository: LocalSupplierRepository());

      await tester.pumpWidget(
        _supplierHarness(auth: auth, controller: controller),
      );
      await tester.pumpAndSettle();

      expect(find.text('إضافة مورد'), findsOneWidget);
    });

    testWidgets('supplier management actions hidden for employee',
        (tester) async {
      final auth = await _signedInController(
        phone: '01100000000',
        password: 'employee123',
      );
      final controller =
          SupplierController(repository: LocalSupplierRepository());

      await tester.pumpWidget(
        _supplierHarness(auth: auth, controller: controller),
      );
      await tester.pumpAndSettle();

      expect(find.text('إضافة مورد'), findsNothing);
      expect(find.text('عرض الموردين النشطين فقط.'), findsOneWidget);
    });

    testWidgets('purchase intake create action visible for owner',
        (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final fixture = await _fixture();

      await tester.pumpWidget(
        _purchaseHarness(auth: auth, controller: fixture.purchaseController),
      );
      await tester.pumpAndSettle();

      expect(find.text('إضافة استلام شراء'), findsOneWidget);
    });

    testWidgets('purchase intake create action hidden for employee',
        (tester) async {
      final auth = await _signedInController(
        phone: '01100000000',
        password: 'employee123',
      );
      final fixture = await _fixture();

      await tester.pumpWidget(
        _purchaseHarness(auth: auth, controller: fixture.purchaseController),
      );
      await tester.pumpAndSettle();

      expect(find.text('إضافة استلام شراء'), findsNothing);
    });

    testWidgets('purchase UI labels price as piasters per kg',
        (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final fixture = await _fixture();

      await tester.pumpWidget(
        _purchaseHarness(auth: auth, controller: fixture.purchaseController),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('إضافة استلام شراء'));
      await tester.pumpAndSettle();

      expect(find.text('سعر الكيلو قرش/كجم'), findsOneWidget);
    });
  });
}

SupplierDraft _supplierDraft({
  required String name,
  String? phone,
}) {
  return SupplierDraft(
    name: name,
    phone: phone,
    address: 'عنوان المورد',
    notes: 'مورد حبوب',
  );
}

ProductDraft _productDraft() {
  return const ProductDraft(
    name: 'قمح',
    unit: GrainUnit.kilogram,
  );
}

PurchaseIntakeDraft _purchaseDraft(
  _PurchaseFixture fixture, {
  String? supplierId,
  String? productId,
  int quantityKg = 1000,
  int unitPricePiastersPerKg = 650,
  String? createdByUserId,
}) {
  return PurchaseIntakeDraft(
    supplierId: supplierId ?? fixture.supplier.id,
    productId: productId ?? fixture.product.id,
    quantityKg: quantityKg,
    entryUnit: GrainUnit.kilogram,
    unitPricePiastersPerKg: unitPricePiastersPerKg,
    createdByUserId: createdByUserId ?? _owner.id,
    notes: 'استلام شراء',
  );
}

Future<_PurchaseFixture> _fixture() async {
  final suppliers = LocalSupplierRepository();
  final products = LocalProductRepository();
  final supplier = await suppliers.createSupplier(
    _supplierDraft(name: 'مورد القمح'),
  );
  final product = await products.createProduct(_productDraft());
  final inventory = LocalInventoryRepository(productRepository: products);
  final purchaseRepository = LocalPurchaseRepository(
    supplierRepository: suppliers,
    productRepository: products,
    inventoryRepository: inventory,
  );
  final purchaseController = PurchaseController(
    purchaseRepository: purchaseRepository,
    supplierRepository: suppliers,
    productRepository: products,
  );
  await purchaseController.load(_owner);

  return _PurchaseFixture(
    suppliers: suppliers,
    products: products,
    inventory: inventory,
    purchaseRepository: purchaseRepository,
    purchaseController: purchaseController,
    supplier: supplier,
    product: product,
  );
}

Widget _supplierHarness({
  required AuthController auth,
  required SupplierController controller,
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
      home: SuppliersScreen(controller: controller),
    ),
  );
}

Widget _purchaseHarness({
  required AuthController auth,
  required PurchaseController controller,
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
      home: PurchasesScreen(controller: controller),
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

class _PurchaseFixture {
  const _PurchaseFixture({
    required this.suppliers,
    required this.products,
    required this.inventory,
    required this.purchaseRepository,
    required this.purchaseController,
    required this.supplier,
    required this.product,
  });

  final LocalSupplierRepository suppliers;
  final LocalProductRepository products;
  final LocalInventoryRepository inventory;
  final LocalPurchaseRepository purchaseRepository;
  final PurchaseController purchaseController;
  final Supplier supplier;
  final Product product;
}

class _FailingInventoryRepository implements InventoryRepository {
  @override
  Future<StockMovement> createMovement(StockMovementDraft draft) {
    throw StateError('Stock movement failed.');
  }

  @override
  Future<Map<String, int>> allProductBalancesKg({
    bool activeProductsOnly = false,
  }) async {
    return const {};
  }

  @override
  Future<int> currentStockKg(String productId) async {
    return 0;
  }

  @override
  Future<bool> hasOpeningBalance(String productId) async {
    return false;
  }

  @override
  Future<List<StockMovement>> listAllMovements() async {
    return const [];
  }

  @override
  Future<List<StockMovement>> listMovementsByProduct(String productId) async {
    return const [];
  }
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
