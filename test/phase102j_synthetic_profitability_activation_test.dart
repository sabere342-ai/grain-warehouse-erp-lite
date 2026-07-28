import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/synthetic_profitability_activation_service.dart';
import 'package:grain_warehouse_erp_lite/core/profitability/profitability_report_service.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';

void main() {
  group('Phase 102J isolated synthetic profitability activation', () {
    test('imports atomically under a visibly non-production activation state',
        () async {
      final fixture = _fixture();

      final result = await fixture.service.activate(
        user: _owner,
        activationDate: _activationDate,
        packageId: _packageId,
        packageSha256: _packageHash,
        rows: _rows,
      );

      expect(result.importedRows, 2);
      expect(result.duplicateRows, 0);
      expect(result.activation.isActivated, isFalse);
      expect(result.activation.isSyntheticTestActivated, isTrue);
      expect(result.activation.supportsValuationOperations, isTrue);
      expect(await fixture.products.listProducts(), hasLength(2));
      expect(await fixture.inventory.listAllMovements(), hasLength(2));
      expect(await fixture.valuation.listStates(), hasLength(2));
      expect(
        (await fixture.valuation.listStates())
            .fold<int>(0, (sum, state) => sum + state.totalValueQirsh),
        41199500,
      );
      final log = (await fixture.audit.exportStoredAuditLogs()).single;
      expect(log.actionType, 'profitability.synthetic_test_activated');
      expect(log.metadata['dataClassification'], 'SYNTHETIC_TEST_DATA');
      expect(log.metadata['databaseIdentity'],
          SyntheticProfitabilityActivationService.requiredDatabaseIdentity);
    });

    test('same package replay is idempotent and counts every row as duplicate',
        () async {
      final fixture = _fixture();
      await fixture.service.activate(
        user: _owner,
        activationDate: _activationDate,
        packageId: _packageId,
        packageSha256: _packageHash,
        rows: _rows,
      );
      final beforeEvents = await fixture.valuation.listEvents();

      final replay = await fixture.service.activate(
        user: _owner,
        activationDate: _activationDate,
        packageId: _packageId,
        packageSha256: _packageHash,
        rows: _rows,
      );

      expect(replay.importedRows, 0);
      expect(replay.duplicateRows, 2);
      expect(await fixture.products.listProducts(), hasLength(2));
      expect(await fixture.inventory.listAllMovements(), hasLength(2));
      expect(
          await fixture.valuation.listEvents(), hasLength(beforeEvents.length));
      expect(await fixture.audit.exportStoredAuditLogs(), hasLength(1));
    });

    test('rollback removes every partial write when audit persistence fails',
        () async {
      final products = LocalProductRepository();
      final inventory = LocalInventoryRepository(productRepository: products);
      final valuation = LocalInventoryValuationRepository();
      final audit = _FailingAuditRepository();
      final service = SyntheticProfitabilityActivationService(
        productRepository: products,
        inventoryRepository: inventory,
        valuationRepository: valuation,
        auditLogRepository: audit,
        databaseIdentity:
            SyntheticProfitabilityActivationService.requiredDatabaseIdentity,
        clock: () => DateTime(2026, 7, 28, 12),
      );

      await expectLater(
        service.activate(
          user: _owner,
          activationDate: _activationDate,
          packageId: _packageId,
          packageSha256: _packageHash,
          rows: _rows,
        ),
        throwsStateError,
      );
      expect(await products.listProducts(), isEmpty);
      expect(await inventory.listAllMovements(), isEmpty);
      expect((await valuation.getActivation()).isNotActivated, isTrue);
      expect(await valuation.listStates(), isEmpty);
      expect(await valuation.listEvents(), isEmpty);
    });

    test(
        'sandbox activation produces COGS and a synthetic profitability report',
        () async {
      final fixture = _fixture();
      await fixture.service.activate(
        user: _owner,
        activationDate: _activationDate,
        packageId: _packageId,
        packageSha256: _packageHash,
        rows: _rows,
      );
      final product = (await fixture.products.listProducts()).first;
      final sales = LocalSaleRepository(
        productRepository: fixture.products,
        inventoryRepository: fixture.inventory,
        inventoryValuationRepository: fixture.valuation,
      );
      final sale = await sales.createSale(SaleDraft(
        productId: product.id,
        quantityKg: 100,
        salePriceQirshPerKg: 2500,
        createdByUserId: _owner.id,
        customerId: 'phase-102j-synthetic-customer',
      ));
      final report = await ProfitabilityReportService(
        inventoryValuationRepository: fixture.valuation,
        saleRepository: sales,
        expenseRepository: LocalExpenseRepository(),
      ).build(
        user: _owner,
        start: _activationDate,
        end: DateTime(2026, 7, 29),
      );

      expect(sale.totalQirsh, 250000);
      expect(sale.totalCostOfGoodsSoldQirsh, 187500);
      expect(report.isAvailable, isTrue);
      expect(report.activation.isSyntheticTestActivated, isTrue);
      expect(report.salesRevenueQirsh, 250000);
      expect(report.costOfGoodsSoldQirsh, 187500);
      expect(report.grossProfitQirsh, 62500);

      await sales.cancelSale(
        saleId: sale.id,
        cancelledByUserId: _owner.id,
        cancellationReason: 'PHASE 102J restore check',
      );
      expect(await fixture.inventory.currentStockKg(product.id), 12500);
      expect((await fixture.valuation.stateForProduct(product.id))!.quantityKg,
          12500);
      expect(
        (await fixture.valuation.stateForProduct(product.id))!.totalValueQirsh,
        23437500,
      );
    });

    test(
        'cannot execute against any database identity except the approved sandbox',
        () async {
      final fixture = _fixture(databaseIdentity: 'production');
      await expectLater(
        fixture.service.activate(
          user: _owner,
          activationDate: _activationDate,
          packageId: _packageId,
          packageSha256: _packageHash,
          rows: _rows,
        ),
        throwsStateError,
      );
      expect(await fixture.products.listProducts(), isEmpty);
      expect((await fixture.valuation.getActivation()).isNotActivated, isTrue);
    });
  });
}

const _packageId = 'phase_102j_synthetic_inventory_test_package.xlsx';
const _packageHash =
    '461F3EE16B2895E3AC898352384EA0D927A49688912A3B6DB4C7C62B96271DFC';
final _activationDate = DateTime(2026, 7, 28);
final _owner = AppUser(
  id: 'phase-102j-owner',
  name: 'Phase 102J Owner',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _activationDate,
  updatedAt: _activationDate,
);

const _rows = [
  SyntheticInventoryRow(
    rowId: 'TST-001',
    sku: 'GRAIN-WHEAT-LOCAL',
    productNameAr: 'قمح محلي',
    quantityKg: 12500,
    unitCostQirshPerKg: 1875,
    totalValueQirsh: 23437500,
    evidenceReference: 'SYN-ROW-001',
  ),
  SyntheticInventoryRow(
    rowId: 'TST-002',
    sku: 'GRAIN-WHEAT-IMPORTED',
    productNameAr: 'قمح مستورد',
    quantityKg: 8300,
    unitCostQirshPerKg: 2140,
    totalValueQirsh: 17762000,
    evidenceReference: 'SYN-ROW-002',
  ),
];

_Fixture _fixture({
  String databaseIdentity =
      SyntheticProfitabilityActivationService.requiredDatabaseIdentity,
}) {
  final products = LocalProductRepository();
  final inventory = LocalInventoryRepository(productRepository: products);
  final valuation = LocalInventoryValuationRepository();
  final audit = LocalAuditLogRepository();
  return _Fixture(
    products: products,
    inventory: inventory,
    valuation: valuation,
    audit: audit,
    service: SyntheticProfitabilityActivationService(
      productRepository: products,
      inventoryRepository: inventory,
      valuationRepository: valuation,
      auditLogRepository: audit,
      databaseIdentity: databaseIdentity,
      clock: () => DateTime(2026, 7, 28, 12),
    ),
  );
}

class _Fixture {
  const _Fixture({
    required this.products,
    required this.inventory,
    required this.valuation,
    required this.audit,
    required this.service,
  });

  final LocalProductRepository products;
  final LocalInventoryRepository inventory;
  final LocalInventoryValuationRepository valuation;
  final LocalAuditLogRepository audit;
  final SyntheticProfitabilityActivationService service;
}

class _FailingAuditRepository extends LocalAuditLogRepository {
  @override
  Future<AuditLogEntry> record(AuditLogDraft draft) {
    throw StateError('simulated audit persistence failure');
  }
}
