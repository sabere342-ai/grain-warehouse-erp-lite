import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_controller.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/features/products/products_screen.dart';

void main() {
  group('ProductRepository', () {
    test('owner can create product through controller', () async {
      final controller =
          ProductController(repository: LocalProductRepository());
      final created = await controller.createProduct(
        user: _owner,
        draft: _draft(name: 'قمح بلدي', code: 'WHEAT-1'),
      );

      expect(created, isTrue);
      expect(controller.products, hasLength(1));
      expect(controller.products.single.name, 'قمح بلدي');
      expect(controller.products.single.id.trim(), isNotEmpty);
    });

    test('employee cannot create product', () async {
      final controller =
          ProductController(repository: LocalProductRepository());
      final created = await controller.createProduct(
        user: _employee,
        draft: _draft(name: 'ذرة صفراء'),
      );

      expect(created, isFalse);
      expect(controller.products, isEmpty);
      expect(controller.errorMessage, contains('صلاحية'));
    });

    test('blank product name is rejected', () async {
      final repository = LocalProductRepository();

      expect(
        () => repository.createProduct(_draft(name: ' ')),
        throwsArgumentError,
      );
    });

    test('duplicate product name is rejected', () async {
      final repository = LocalProductRepository();
      await repository.createProduct(_draft(name: 'قمح بلدي'));

      expect(
        () => repository.createProduct(_draft(name: ' قمح بلدي ')),
        throwsStateError,
      );
    });

    test('duplicate product code is rejected when code is provided', () async {
      final repository = LocalProductRepository();
      await repository.createProduct(_draft(name: 'قمح', code: 'GR-1'));

      expect(
        () => repository.createProduct(_draft(name: 'ذرة', code: ' gr-1 ')),
        throwsStateError,
      );
    });

    test('product id is non-empty and stable', () async {
      final repository = LocalProductRepository();
      final product = await repository.createProduct(_draft(name: 'أرز شعير'));
      final id = product.id;

      final updated = await repository.updateProduct(
        productId: product.id,
        draft: _draft(name: 'أرز شعير ممتاز'),
      );
      final inactive = await repository.setProductActive(
        productId: product.id,
        isActive: false,
      );

      expect(id.trim(), isNotEmpty);
      expect(updated.id, id);
      expect(inactive.id, id);
    });

    test('product can be deactivated by owner', () async {
      final controller =
          ProductController(repository: LocalProductRepository());
      await controller.createProduct(user: _owner, draft: _draft(name: 'شعير'));
      final productId = controller.products.single.id;

      final changed = await controller.setProductActive(
        user: _owner,
        productId: productId,
        isActive: false,
      );

      expect(changed, isTrue);
      expect(controller.products.single.isActive, isFalse);
    });

    test('employee cannot deactivate product', () async {
      final repository = LocalProductRepository();
      final product = await repository.createProduct(_draft(name: 'فول'));
      final controller = ProductController(repository: repository);

      final changed = await controller.setProductActive(
        user: _employee,
        productId: product.id,
        isActive: false,
      );
      final products = await repository.listProducts();

      expect(changed, isFalse);
      expect(products.single.isActive, isTrue);
    });

    test('inactive products can be hidden from employee-facing lists',
        () async {
      final repository = LocalProductRepository();
      final active = await repository.createProduct(_draft(name: 'قمح'));
      final inactive = await repository.createProduct(_draft(name: 'ذرة'));
      await repository.setProductActive(
          productId: inactive.id, isActive: false);

      final controller = ProductController(repository: repository);
      await controller.loadProducts(_employee);

      expect(controller.products, hasLength(1));
      expect(controller.products.single.id, active.id);
    });

    test('ton to kilogram conversion equals 1000 kg', () {
      expect(GrainUnitConverter.tonsToKilograms(1), 1000);
      expect(GrainUnitConverter.tonsToKilograms(2), 2000);
    });

    test('minimum sale price cannot exceed default sale price', () async {
      final repository = LocalProductRepository();

      expect(
        () => repository.createProduct(
          _draft(
            name: 'عدس',
            defaultSalePricePiastersPerKg: 1000,
            minimumSalePricePiastersPerKg: 1200,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('invalid prices are rejected', () async {
      final repository = LocalProductRepository();

      expect(
        () => repository.createProduct(
          _draft(name: 'فاصوليا', defaultSalePricePiastersPerKg: 0),
        ),
        throwsArgumentError,
      );
      expect(
        () => repository.createProduct(
          _draft(name: 'لوبيا', minimumSalePricePiastersPerKg: -1),
        ),
        throwsArgumentError,
      );
    });

    test('product creation does not create stock quantity', () async {
      final repository = LocalProductRepository();
      final product = await repository.createProduct(_draft(name: 'سمسم'));

      expect(product.id, isNotEmpty);
      expect(product.defaultSalePricePiastersPerKg, 1000);
      expect(product.minimumSalePricePiastersPerKg, 900);
    });
  });

  group('ProductsScreen permissions', () {
    testWidgets('owner sees product management actions', (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final products = ProductController(repository: LocalProductRepository());

      await tester.pumpWidget(_productHarness(auth: auth, products: products));
      await tester.pumpAndSettle();

      expect(find.text('إضافة صنف'), findsOneWidget);
    });

    testWidgets('employee does not see product management actions',
        (tester) async {
      final auth = await _signedInController(
          phone: '01100000000', password: 'employee123');
      final products = ProductController(repository: LocalProductRepository());

      await tester.pumpWidget(_productHarness(auth: auth, products: products));
      await tester.pumpAndSettle();

      expect(find.text('إضافة صنف'), findsNothing);
      expect(find.text('عرض الأصناف النشطة فقط.'), findsOneWidget);
    });
  });
}

ProductDraft _draft({
  required String name,
  String? code,
  int? defaultSalePricePiastersPerKg = 1000,
  int? minimumSalePricePiastersPerKg = 900,
}) {
  return ProductDraft(
    name: name,
    code: code,
    unit: GrainUnit.kilogram,
    defaultSalePricePiastersPerKg: defaultSalePricePiastersPerKg,
    minimumSalePricePiastersPerKg: minimumSalePricePiastersPerKg,
    notes: 'صنف حبوب',
  );
}

Widget _productHarness({
  required AuthController auth,
  required ProductController products,
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
      home: ProductsScreen(controller: products),
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
