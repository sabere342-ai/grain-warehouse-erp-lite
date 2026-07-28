import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/profitability_activation_service.dart';

void main() {
  group('Phase 102B profitability activation', () {
    test('is owner-only and rejects unauthorized users before repository reads',
        () async {
      final products = _CountingProductRepository();
      final fixture = _service(productRepository: products);

      expect(
        () => fixture.service.activate(
          user: _user(UserRole.employee),
          activationDate: DateTime(2026, 7, 27),
          evidenceNote: 'TEST FIXTURE',
          openings: const [],
        ),
        throwsStateError,
      );
      expect(products.readCount, 0);
    });

    test('requires a reconciled, evidenced decision for every product',
        () async {
      final fixture = await _stockedFixture();

      expect(
        () => fixture.service.activate(
          user: _user(UserRole.owner),
          activationDate: DateTime(2026, 7, 27),
          evidenceNote: 'TEST FIXTURE ONLY',
          openings: [
            OpeningValuationInput(
              productId: fixture.productId,
              quantityKg: 99,
              unitCostQirshPerKg: 100,
              evidenceReference: 'TEST-EVIDENCE',
            ),
          ],
        ),
        throwsStateError,
      );
      expect((await fixture.valuation.getActivation()).isActivated, isFalse);
    });

    test('activates atomically from real-count fixtures and writes audit',
        () async {
      final fixture = await _stockedFixture();

      await fixture.service.activate(
        user: _user(UserRole.owner),
        activationDate: DateTime(2026, 7, 27),
        evidenceNote: 'TEST FIXTURE ONLY — not production owner data',
        openings: [
          OpeningValuationInput(
            productId: fixture.productId,
            quantityKg: 100,
            unitCostQirshPerKg: 250,
            evidenceReference: 'TEST-PURCHASE-EVIDENCE',
          ),
        ],
      );

      final activation = await fixture.valuation.getActivation();
      expect(activation.isActivated, isTrue);
      expect(activation.approvedByUserId, 'owner-fixture');
      expect(
        (await fixture.valuation.stateForProduct(fixture.productId))!
            .totalValueQirsh,
        25000,
      );
      final logs = await fixture.audit.exportStoredAuditLogs();
      expect(logs.single.actionType, 'profitability.activated');
      expect(logs.single.metadata['productCount'], 1);
    });

    test('rejects an activation date in a closed period', () async {
      final fixture = await _stockedFixture(
        ensureDateOpen: (_) async => throw StateError('closed fixture period'),
      );

      expect(
        () => fixture.service.activate(
          user: _user(UserRole.owner),
          activationDate: DateTime(2026, 7, 27),
          evidenceNote: 'TEST FIXTURE ONLY',
          openings: [
            OpeningValuationInput(
              productId: fixture.productId,
              quantityKg: 100,
              unitCostQirshPerKg: 250,
              evidenceReference: 'TEST-PURCHASE-EVIDENCE',
            ),
          ],
        ),
        throwsStateError,
      );
      expect((await fixture.valuation.getActivation()).isActivated, isFalse);
    });
  });
}

class _Fixture {
  const _Fixture({
    required this.service,
    required this.valuation,
    required this.audit,
    required this.productId,
  });

  final ProfitabilityActivationService service;
  final LocalInventoryValuationRepository valuation;
  final LocalAuditLogRepository audit;
  final String productId;
}

Future<_Fixture> _stockedFixture({
  Future<void> Function(DateTime value)? ensureDateOpen,
}) async {
  final products = LocalProductRepository();
  final wheat = await products.createProduct(const ProductDraft(
    name: 'Wheat fixture',
    code: 'W-FIXTURE',
    unit: GrainUnit.kilogram,
  ));
  final inventory = LocalInventoryRepository(productRepository: products);
  await inventory.createMovement(StockMovementDraft(
    productId: wheat.id,
    movementType: StockMovementType.openingBalance,
    quantityKg: 100,
    createdByUserId: 'fixture-owner',
  ));
  return _service(
    productRepository: products,
    inventoryRepository: inventory,
    ensureDateOpen: ensureDateOpen,
    productId: wheat.id,
  );
}

_Fixture _service({
  required ProductRepository productRepository,
  InventoryRepository? inventoryRepository,
  Future<void> Function(DateTime value)? ensureDateOpen,
  String productId = 'wheat',
}) {
  final inventory = inventoryRepository ??
      LocalInventoryRepository(productRepository: productRepository);
  final valuation = LocalInventoryValuationRepository();
  final audit = LocalAuditLogRepository();
  return _Fixture(
    service: ProfitabilityActivationService(
      productRepository: productRepository,
      inventoryRepository: inventory,
      valuationRepository: valuation,
      auditLogRepository: audit,
      ensureDateOpen: ensureDateOpen,
      clock: () => DateTime(2026, 7, 27, 12),
    ),
    valuation: valuation,
    audit: audit,
    productId: productId,
  );
}

AppUser _user(UserRole role) => AppUser(
      id: role == UserRole.owner ? 'owner-fixture' : 'employee-fixture',
      name: 'Fixture user',
      phone: '01000000000',
      role: role,
      isActive: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

class _CountingProductRepository implements ProductRepository {
  int readCount = 0;

  @override
  Future<List<Product>> listProducts({bool includeInactive = false}) async {
    readCount++;
    return const [];
  }

  @override
  Future<Product> createProduct(ProductDraft draft) =>
      throw UnimplementedError();

  @override
  Future<Product> updateProduct({
    required String productId,
    required ProductDraft draft,
  }) =>
      throw UnimplementedError();

  @override
  Future<Product> setProductActive({
    required String productId,
    required bool isActive,
  }) =>
      throw UnimplementedError();
}
