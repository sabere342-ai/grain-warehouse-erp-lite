import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation_repository.dart';

void main() {
  group('Phase 102B moving weighted average engine', () {
    test('remains inactive and never invents cost before owner activation',
        () async {
      final repository = LocalInventoryValuationRepository();

      expect((await repository.getActivation()).isActivated, isFalse);
      expect(
        await repository.recordPurchase(
          productId: 'wheat',
          quantityKg: 10,
          unitCostQirshPerKg: 200,
          sourceDocumentId: 'legacy-purchase',
          effectiveDate: DateTime(2026, 7, 1),
          createdByUserId: 'fixture-owner',
        ),
        isNull,
      );
      expect(
        await repository.recordSale(
          productId: 'wheat',
          quantityKg: 1,
          sourceDocumentId: 'legacy-sale',
          effectiveDate: DateTime(2026, 7, 2),
          createdByUserId: 'fixture-owner',
        ),
        isNull,
      );
      expect(await repository.listStates(), isEmpty);
      expect(await repository.listEvents(), isEmpty);
    });

    test('first and second purchases produce a perpetual weighted average',
        () async {
      final repository = await _activatedRepository(
        quantityKg: 100,
        unitCostQirshPerKg: 100,
      );

      await repository.recordPurchase(
        productId: 'wheat',
        quantityKg: 100,
        unitCostQirshPerKg: 200,
        sourceDocumentId: 'purchase-1',
        effectiveDate: DateTime(2026, 7, 28),
        createdByUserId: 'fixture-owner',
      );

      final state = await repository.stateForProduct('wheat');
      expect(state!.quantityKg, 200);
      expect(state.totalValueQirsh, 30000);
      expect(state.unitCostMicrosQirshPerKg, 150000000);
    });

    test('partial and final sales preserve and fully consume total value',
        () async {
      final repository = await _activatedRepository(
        quantityKg: 100,
        unitCostQirshPerKg: 100,
      );
      await repository.recordPurchase(
        productId: 'wheat',
        quantityKg: 100,
        unitCostQirshPerKg: 200,
        sourceDocumentId: 'purchase-1',
        effectiveDate: DateTime(2026, 7, 28),
        createdByUserId: 'fixture-owner',
      );

      final partial = await repository.recordSale(
        productId: 'wheat',
        quantityKg: 50,
        sourceDocumentId: 'sale-1',
        effectiveDate: DateTime(2026, 7, 29),
        createdByUserId: 'fixture-owner',
      );
      expect(partial!.costOfGoodsSoldQirsh, 7500);
      expect(partial.inventoryValueAfterQirsh, 22500);

      final finalSale = await repository.recordSale(
        productId: 'wheat',
        quantityKg: 150,
        sourceDocumentId: 'sale-2',
        effectiveDate: DateTime(2026, 7, 29),
        createdByUserId: 'fixture-owner',
      );
      expect(finalSale!.costOfGoodsSoldQirsh, 22500);
      final state = await repository.stateForProduct('wheat');
      expect(state!.quantityKg, 0);
      expect(state.totalValueQirsh, 0);
    });

    test('rounding residual stays in inventory and reconciles on depletion',
        () async {
      final repository = await _activatedRepository(
        quantityKg: 2,
        unitCostQirshPerKg: 1,
      );
      await repository.recordPurchase(
        productId: 'wheat',
        quantityKg: 1,
        unitCostQirshPerKg: 2,
        sourceDocumentId: 'purchase-1',
        effectiveDate: DateTime(2026, 7, 28),
        createdByUserId: 'fixture-owner',
      );

      final first = await repository.recordSale(
        productId: 'wheat',
        quantityKg: 1,
        sourceDocumentId: 'sale-1',
        effectiveDate: DateTime(2026, 7, 29),
        createdByUserId: 'fixture-owner',
      );
      final second = await repository.recordSale(
        productId: 'wheat',
        quantityKg: 1,
        sourceDocumentId: 'sale-2',
        effectiveDate: DateTime(2026, 7, 29),
        createdByUserId: 'fixture-owner',
      );
      final third = await repository.recordSale(
        productId: 'wheat',
        quantityKg: 1,
        sourceDocumentId: 'sale-3',
        effectiveDate: DateTime(2026, 7, 29),
        createdByUserId: 'fixture-owner',
      );

      expect(first!.allocationResidualNumerator, 1);
      expect(
        first.costOfGoodsSoldQirsh +
            second!.costOfGoodsSoldQirsh +
            third!.costOfGoodsSoldQirsh,
        4,
      );
    });

    test('sale reversal restores the exact original stored COGS', () async {
      final repository = await _activatedRepository(
        quantityKg: 10,
        unitCostQirshPerKg: 100,
      );
      final sale = await repository.recordSale(
        productId: 'wheat',
        quantityKg: 4,
        sourceDocumentId: 'sale-1',
        effectiveDate: DateTime(2026, 7, 29),
        createdByUserId: 'fixture-owner',
      );
      await repository.recordPurchase(
        productId: 'wheat',
        quantityKg: 4,
        unitCostQirshPerKg: 300,
        sourceDocumentId: 'purchase-1',
        effectiveDate: DateTime(2026, 7, 30),
        createdByUserId: 'fixture-owner',
      );

      final reversal = await repository.reverseSale(
        originalValuationEventId: sale!.valuationEventId,
        sourceDocumentId: 'sale-1',
        effectiveDate: DateTime(2026, 7, 30),
        createdByUserId: 'fixture-owner',
        reason: 'fixture cancellation',
      );
      expect(reversal!.valueDeltaQirsh, sale.costOfGoodsSoldQirsh);
      expect(
          (await repository.stateForProduct('wheat'))!.totalValueQirsh, 2200);
    });

    test('purchase cancellation is allowed only while its event is untouched',
        () async {
      final repository = await _activatedRepository(
        quantityKg: 0,
        unitCostQirshPerKg: 0,
      );
      await repository.recordPurchase(
        productId: 'wheat',
        quantityKg: 10,
        unitCostQirshPerKg: 100,
        sourceDocumentId: 'purchase-1',
        effectiveDate: DateTime(2026, 7, 28),
        createdByUserId: 'fixture-owner',
      );
      expect(await repository.canDirectlyCancelPurchase('purchase-1'), isTrue);
      await repository.recordSale(
        productId: 'wheat',
        quantityKg: 1,
        sourceDocumentId: 'sale-1',
        effectiveDate: DateTime(2026, 7, 29),
        createdByUserId: 'fixture-owner',
      );
      expect(await repository.canDirectlyCancelPurchase('purchase-1'), isFalse);
      expect(
        () => repository.reversePurchase(
          originalPurchaseDocumentId: 'purchase-1',
          sourceDocumentId: 'purchase-1',
          effectiveDate: DateTime(2026, 7, 29),
          createdByUserId: 'fixture-owner',
          reason: 'fixture cancellation',
        ),
        throwsStateError,
      );
    });

    test('valued surplus and shortage require evidence and consume average',
        () async {
      final repository = await _activatedRepository(
        quantityKg: 10,
        unitCostQirshPerKg: 100,
      );
      await repository.recordValuedIncrease(
        productId: 'wheat',
        quantityKg: 2,
        unitCostQirshPerKg: 200,
        type: InventoryValuationEventType.stocktakeSurplus,
        sourceDocumentId: 'stocktake-1',
        effectiveDate: DateTime(2026, 7, 29),
        createdByUserId: 'fixture-owner',
        reason: 'fixture count surplus',
        evidenceReference: 'fixture-evidence',
      );
      final shortage = await repository.recordDecrease(
        productId: 'wheat',
        quantityKg: 3,
        type: InventoryValuationEventType.stocktakeShortage,
        sourceDocumentId: 'stocktake-2',
        effectiveDate: DateTime(2026, 7, 30),
        createdByUserId: 'fixture-owner',
        reason: 'fixture count shortage',
      );
      expect(shortage!.valueDeltaQirsh, -350);
      final state = await repository.stateForProduct('wheat');
      expect(state!.quantityKg, 9);
      expect(state.totalValueQirsh, 1050);
    });

    test('checked arithmetic rejects values outside int64 without mutation',
        () async {
      final repository = await _activatedRepository(
        quantityKg: 0,
        unitCostQirshPerKg: 0,
      );
      expect(
        () => repository.recordPurchase(
          productId: 'wheat',
          quantityKg: InventoryCostPrecision.maxInt64,
          unitCostQirshPerKg: 2,
          sourceDocumentId: 'purchase-overflow',
          effectiveDate: DateTime(2026, 7, 28),
          createdByUserId: 'fixture-owner',
        ),
        throwsArgumentError,
      );
      expect((await repository.stateForProduct('wheat'))!.quantityKg, 0);
    });

    test('fixed-point scaling rejects int64 overflow without mutation',
        () async {
      final repository = LocalInventoryValuationRepository();

      await expectLater(
        repository.activate(
          activationDate: DateTime(2026, 1, 1),
          approvedByUserId: 'fixture-owner',
          evidenceNote: 'TEST FIXTURE ONLY — not owner production data',
          openings: const [
            OpeningValuationInput(
              productId: 'wheat',
              quantityKg: 1,
              unitCostQirshPerKg: InventoryCostPrecision.maxInt64,
              evidenceReference: 'TEST-FIXTURE-EVIDENCE',
            ),
          ],
        ),
        throwsArgumentError,
      );

      expect((await repository.getActivation()).isActivated, isFalse);
      expect(await repository.listStates(), isEmpty);
      expect(await repository.listEvents(), isEmpty);
    });

    test('restore round-trip preserves activation, states and events',
        () async {
      final source = await _activatedRepository(
        quantityKg: 10,
        unitCostQirshPerKg: 100,
      );
      await source.recordSale(
        productId: 'wheat',
        quantityKg: 3,
        sourceDocumentId: 'sale-1',
        effectiveDate: DateTime(2026, 7, 29),
        createdByUserId: 'fixture-owner',
      );

      final restored = LocalInventoryValuationRepository();
      await restored.restoreIntoEmpty(await source.exportRestoreData());

      expect((await restored.getActivation()).isActivated, isTrue);
      expect((await restored.stateForProduct('wheat'))!.totalValueQirsh, 700);
      expect((await restored.listEvents()).length, 2);
    });
  });
}

Future<LocalInventoryValuationRepository> _activatedRepository({
  required int quantityKg,
  required int unitCostQirshPerKg,
}) async {
  final repository = LocalInventoryValuationRepository();
  await repository.activate(
    activationDate: DateTime(2026, 7, 27),
    approvedByUserId: 'fixture-owner',
    evidenceNote: 'TEST FIXTURE ONLY — not owner production data',
    openings: [
      OpeningValuationInput(
        productId: 'wheat',
        quantityKg: quantityKg,
        unitCostQirshPerKg: unitCostQirshPerKg,
        evidenceReference: 'TEST-FIXTURE-EVIDENCE',
      ),
    ],
  );
  return repository;
}
