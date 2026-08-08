import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_controller.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/profitability_activation_service.dart';
import 'package:grain_warehouse_erp_lite/core/profitability/profitability_report.dart';
import 'package:grain_warehouse_erp_lite/core/profitability/profitability_report_service.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';

import 'support/product_catalog_read_repository_test_adapter.dart';

void main() {
  group('Phase 102C — Scenario A: activation state', () {
    test('re-activation is rejected after first successful activation',
        () async {
      final valuation = LocalInventoryValuationRepository();
      await valuation.activate(
        activationDate: DateTime(2026, 7, 1),
        approvedByUserId: 'owner',
        evidenceNote: 'first activation',
        openings: const [
          OpeningValuationInput(
            productId: 'wheat',
            quantityKg: 100,
            unitCostQirshPerKg: 500,
            evidenceReference: 'evidence-1',
          ),
        ],
      );
      expect((await valuation.getActivation()).isActivated, isTrue);

      expect(
        () => valuation.activate(
          activationDate: DateTime(2026, 8, 1),
          approvedByUserId: 'owner',
          evidenceNote: 'second activation',
          openings: const [
            OpeningValuationInput(
              productId: 'wheat',
              quantityKg: 200,
              unitCostQirshPerKg: 600,
              evidenceReference: 'evidence-2',
            ),
          ],
        ),
        throwsStateError,
      );
      expect((await valuation.getActivation()).isActivated, isTrue);
      final state = await valuation.stateForProduct('wheat');
      expect(state!.quantityKg, 100);
      expect(state.totalValueQirsh, 50000);
    });

    test('activation persists activation date and approved-by user', () async {
      final valuation = LocalInventoryValuationRepository();
      await valuation.activate(
        activationDate: DateTime(2026, 7, 15),
        approvedByUserId: 'owner-123',
        evidenceNote: 'physical count fixture',
        openings: const [
          OpeningValuationInput(
            productId: 'rice',
            quantityKg: 50,
            unitCostQirshPerKg: 300,
            evidenceReference: 'invoice-001',
          ),
        ],
      );
      final activation = await valuation.getActivation();
      expect(activation.isActivated, isTrue);
      expect(activation.activationDate, DateTime(2026, 7, 15));
      expect(activation.approvedByUserId, 'owner-123');
      expect(activation.evidenceNote, 'physical count fixture');
    });
  });

  group('Phase 102C — Scenario B: opening inventory integrity', () {
    test('total opening value equals sum of product values', () async {
      final valuation = LocalInventoryValuationRepository();
      await valuation.activate(
        activationDate: DateTime(2026, 7, 1),
        approvedByUserId: 'owner',
        evidenceNote: 'fixture',
        openings: const [
          OpeningValuationInput(
            productId: 'wheat',
            quantityKg: 100,
            unitCostQirshPerKg: 500,
            evidenceReference: 'inv-w',
          ),
          OpeningValuationInput(
            productId: 'rice',
            quantityKg: 200,
            unitCostQirshPerKg: 300,
            evidenceReference: 'inv-r',
          ),
          OpeningValuationInput(
            productId: 'corn',
            quantityKg: 0,
            unitCostQirshPerKg: 0,
            evidenceReference: 'inv-c',
          ),
        ],
      );
      final wheat = await valuation.stateForProduct('wheat');
      final rice = await valuation.stateForProduct('rice');
      final corn = await valuation.stateForProduct('corn');
      expect(wheat!.totalValueQirsh, 50000);
      expect(rice!.totalValueQirsh, 60000);
      expect(corn!.totalValueQirsh, 0);
      expect(
        wheat.totalValueQirsh + rice.totalValueQirsh + corn.totalValueQirsh,
        110000,
      );
    });

    test('opening zero-quantity product has zero value and no cost required',
        () async {
      final valuation = LocalInventoryValuationRepository();
      await valuation.activate(
        activationDate: DateTime(2026, 7, 1),
        approvedByUserId: 'owner',
        evidenceNote: 'fixture',
        openings: const [
          OpeningValuationInput(
            productId: 'empty',
            quantityKg: 0,
            unitCostQirshPerKg: 0,
            evidenceReference: 'zero-evidence',
          ),
        ],
      );
      final state = await valuation.stateForProduct('empty');
      expect(state!.quantityKg, 0);
      expect(state.totalValueQirsh, 0);
    });

    test('evidence reference is stored in the opening event', () async {
      final valuation = LocalInventoryValuationRepository();
      await valuation.activate(
        activationDate: DateTime(2026, 7, 1),
        approvedByUserId: 'owner',
        evidenceNote: 'fixture',
        openings: const [
          OpeningValuationInput(
            productId: 'wheat',
            quantityKg: 10,
            unitCostQirshPerKg: 100,
            evidenceReference: 'purchase-invoice-42',
          ),
        ],
      );
      final events = await valuation.listEvents();
      expect(events, hasLength(1));
      expect(events.first.evidenceReference, 'purchase-invoice-42');
    });
  });

  group('Phase 102C — Scenario C: first purchase after activation', () {
    test('new purchase updates moving weighted average correctly', () async {
      final valuation = LocalInventoryValuationRepository();
      await valuation.activate(
        activationDate: DateTime(2026, 7, 1),
        approvedByUserId: 'owner',
        evidenceNote: 'fixture',
        openings: const [
          OpeningValuationInput(
            productId: 'wheat',
            quantityKg: 100,
            unitCostQirshPerKg: 100,
            evidenceReference: 'evidence',
          ),
        ],
      );
      await valuation.recordPurchase(
        productId: 'wheat',
        quantityKg: 100,
        unitCostQirshPerKg: 300,
        sourceDocumentId: 'purchase-1',
        effectiveDate: DateTime(2026, 7, 5),
        createdByUserId: 'owner',
      );
      final state = await valuation.stateForProduct('wheat');
      expect(state!.quantityKg, 200);
      expect(state.totalValueQirsh, 40000);
      expect(state.unitCostMicrosQirshPerKg, 200000000);
    });

    test('residual is preserved after non-divisible purchase', () async {
      final valuation = LocalInventoryValuationRepository();
      await valuation.activate(
        activationDate: DateTime(2026, 7, 1),
        approvedByUserId: 'owner',
        evidenceNote: 'fixture',
        openings: const [
          OpeningValuationInput(
            productId: 'wheat',
            quantityKg: 3,
            unitCostQirshPerKg: 100,
            evidenceReference: 'evidence',
          ),
        ],
      );
      await valuation.recordPurchase(
        productId: 'wheat',
        quantityKg: 1,
        unitCostQirshPerKg: 50,
        sourceDocumentId: 'purchase-1',
        effectiveDate: DateTime(2026, 7, 5),
        createdByUserId: 'owner',
      );
      final state = await valuation.stateForProduct('wheat');
      expect(state!.quantityKg, 4);
      expect(state.totalValueQirsh, 350);
    });
  });

  group('Phase 102C — Scenario D: cash sale', () {
    test('cash sale records COGS snapshot and revenue correctly', () async {
      final fixture = await _salesFixture();
      final sale = await fixture.sales.createSale(SaleDraft(
        productId: fixture.productId,
        quantityKg: 10,
        salePriceQirshPerKg: 800,
        createdByUserId: _owner.id,
        customerId: 'CASH-CUSTOMER',
      ));
      expect(sale.totalQirsh, 8000);
      expect(sale.effectivePaidAmountQirsh, 8000);
      expect(sale.remainingAmountQirsh, 0);
      expect(sale.hasCompleteCostSnapshots, isTrue);
      expect(sale.totalCostOfGoodsSoldQirsh, 5000);

      final report = await fixture.service.build(
        user: _owner,
        start: fixture.activationDate,
        end: DateTime.now().add(const Duration(days: 1)),
      );
      expect(report.salesRevenueQirsh, 8000);
      expect(report.costOfGoodsSoldQirsh, 5000);
      expect(report.grossProfitQirsh, 3000);
    });

    test('COGS snapshot is immutable per sale line item', () async {
      final fixture = await _salesFixture();
      final sale = await fixture.sales.createSale(SaleDraft(
        productId: fixture.productId,
        quantityKg: 10,
        salePriceQirshPerKg: 800,
        createdByUserId: _owner.id,
        customerId: 'CASH-CUSTOMER',
      ));
      expect(sale.items, hasLength(1));
      final item = sale.items.first;
      expect(item.valuationEventId, isNotNull);
      expect(item.costOfGoodsSoldQirsh, isNotNull);
      expect(item.inventoryQuantityBeforeKg, 100);
      expect(item.inventoryQuantityAfterKg, 90);
      expect(item.inventoryValueBeforeQirsh, 50000);
      expect(item.inventoryValueAfterQirsh, 45000);
    });
  });

  group('Phase 102C — Scenario E: credit sale', () {
    test('credit sale recognizes revenue and COGS at sale time', () async {
      final fixture = await _salesFixture();
      final sale = await fixture.sales.createSale(SaleDraft(
        productId: fixture.productId,
        quantityKg: 10,
        salePriceQirshPerKg: 800,
        createdByUserId: _owner.id,
        customerId: 'CREDIT-CUSTOMER',
        paymentMode: SalePaymentMode.credit,
      ));
      expect(sale.paymentMode, SalePaymentMode.credit);
      expect(sale.effectivePaidAmountQirsh, 0);
      expect(sale.remainingAmountQirsh, 8000);
      expect(sale.hasCompleteCostSnapshots, isTrue);
      expect(sale.totalCostOfGoodsSoldQirsh, 5000);

      final report = await fixture.service.build(
        user: _owner,
        start: fixture.activationDate,
        end: DateTime.now().add(const Duration(days: 1)),
      );
      expect(report.salesRevenueQirsh, 8000);
      expect(report.costOfGoodsSoldQirsh, 5000);
      expect(report.creditRevenueQirsh, 8000);
      expect(report.cashRevenueQirsh, 0);
      expect(report.grossProfitQirsh, 3000);
    });

    test('credit collection does not create additional revenue', () async {
      final fixture = await _salesFixture();
      await fixture.sales.createSale(SaleDraft(
        productId: fixture.productId,
        quantityKg: 10,
        salePriceQirshPerKg: 800,
        createdByUserId: _owner.id,
        customerId: 'CREDIT-CUSTOMER',
        paymentMode: SalePaymentMode.credit,
      ));
      final reportBefore = await fixture.service.build(
        user: _owner,
        start: fixture.activationDate,
        end: DateTime.now().add(const Duration(days: 1)),
      );
      expect(reportBefore.salesRevenueQirsh, 8000);

      final reportAfter = await fixture.service.build(
        user: _owner,
        start: fixture.activationDate,
        end: DateTime.now().add(const Duration(days: 2)),
      );
      expect(reportAfter.salesRevenueQirsh, 8000);
      expect(reportAfter.grossProfitQirsh, 3000);
    });
  });

  group('Phase 102C — Scenario F: sale cancellation', () {
    test('cancellation reverses original COGS not current average', () async {
      final fixture = await _salesFixture();
      final sale1 = await fixture.sales.createSale(SaleDraft(
        productId: fixture.productId,
        quantityKg: 10,
        salePriceQirshPerKg: 800,
        createdByUserId: _owner.id,
        customerId: 'CANCEL-CUSTOMER',
      ));
      expect(sale1.totalCostOfGoodsSoldQirsh, 5000);

      await fixture.valuation.recordPurchase(
        productId: fixture.productId,
        quantityKg: 100,
        unitCostQirshPerKg: 1000,
        sourceDocumentId: 'new-purchase',
        effectiveDate: DateTime.now(),
        createdByUserId: _owner.id,
      );

      await fixture.sales.cancelSale(
        saleId: sale1.id,
        cancelledByUserId: _owner.id,
        cancellationReason: 'fixture cancellation',
      );
      final state = await fixture.valuation.stateForProduct(fixture.productId);
      expect(state!.quantityKg, 200);
      expect(state.totalValueQirsh, 50000 + 100000);
    });

    test('cancellation restores quantity and total value in valuation state',
        () async {
      final fixture = await _salesFixture();
      final sale = await fixture.sales.createSale(SaleDraft(
        productId: fixture.productId,
        quantityKg: 10,
        salePriceQirshPerKg: 800,
        createdByUserId: _owner.id,
        customerId: 'QTY-CUSTOMER',
      ));
      final beforeCancel = await fixture.valuation.stateForProduct(
        fixture.productId,
      );
      final qtyBeforeCancel = beforeCancel!.quantityKg;
      final valBeforeCancel = beforeCancel.totalValueQirsh;

      await fixture.sales.cancelSale(
        saleId: sale.id,
        cancelledByUserId: _owner.id,
        cancellationReason: 'fixture',
      );

      final afterCancel =
          await fixture.valuation.stateForProduct(fixture.productId);
      expect(afterCancel!.quantityKg, qtyBeforeCancel + 10);
      expect(afterCancel.totalValueQirsh, valBeforeCancel + 5000);
    });

    test('double cancellation of the same sale is idempotent', () async {
      final fixture = await _salesFixture();
      final sale = await fixture.sales.createSale(SaleDraft(
        productId: fixture.productId,
        quantityKg: 10,
        salePriceQirshPerKg: 800,
        createdByUserId: _owner.id,
        customerId: 'DOUBLE-CANCEL',
      ));
      await fixture.sales.cancelSale(
        saleId: sale.id,
        cancelledByUserId: _owner.id,
        cancellationReason: 'first',
      );
      final second = await fixture.sales.cancelSale(
        saleId: sale.id,
        cancelledByUserId: _owner.id,
        cancellationReason: 'second',
      );
      expect(second.isCancelled, isTrue);
    });
  });

  group('Phase 102C — Scenario G: stocktake shortage', () {
    test('shortage consumes current average and affects profitability',
        () async {
      final fixture = await _salesFixture();
      final audit = LocalAuditLogRepository();
      final controller = InventoryController(
        inventoryRepository: fixture.inventory,
        productCatalogReadRepository:
            ProductCatalogReadRepositoryTestAdapter(fixture.products),
        inventoryValuationRepository: fixture.valuation,
        auditLogRepository: audit,
      );
      final decreased = await controller.createManualDecrease(
        user: _owner,
        productId: fixture.productId,
        quantityKg: 5,
        note: 'fixture shortage',
        isStocktake: true,
      );
      expect(decreased, isTrue);
      final state = await fixture.valuation.stateForProduct(fixture.productId);
      expect(state!.quantityKg, 95);
      expect(state.totalValueQirsh, 47500);

      final events = await fixture.valuation.listEvents();
      final shortageEvent = events.firstWhere(
          (e) => e.type == InventoryValuationEventType.stocktakeShortage);
      expect(shortageEvent.quantityDeltaKg, -5);
      expect(shortageEvent.valueDeltaQirsh, -2500);

      final logs = await audit.exportStoredAuditLogs();
      expect(logs, isNotEmpty);
    });
  });

  group('Phase 102C — Scenario H: stocktake surplus', () {
    test('surplus requires cost, evidence, reason, and owner approval',
        () async {
      final fixture = await _salesFixture();
      final controller = InventoryController(
        inventoryRepository: fixture.inventory,
        productCatalogReadRepository:
            ProductCatalogReadRepositoryTestAdapter(fixture.products),
        inventoryValuationRepository: fixture.valuation,
        auditLogRepository: LocalAuditLogRepository(),
      );

      expect(
        await controller.createManualIncrease(
          user: _owner,
          productId: fixture.productId,
          quantityKg: 5,
          note: 'no cost surplus',
          isStocktake: true,
        ),
        isFalse,
      );
      final before = await fixture.inventory.currentStockKg(fixture.productId);

      final increased = await controller.createManualIncrease(
        user: _owner,
        productId: fixture.productId,
        quantityKg: 5,
        note: 'fixture surplus',
        unitCostQirshPerKg: 500,
        evidenceReference: 'fixture count sheet',
        isStocktake: true,
      );
      expect(increased, isTrue);
      expect(
        await fixture.inventory.currentStockKg(fixture.productId),
        before + 5,
      );
    });

    test('employee cannot create stocktake surplus', () async {
      final fixture = await _salesFixture();
      final controller = InventoryController(
        inventoryRepository: fixture.inventory,
        productCatalogReadRepository:
            ProductCatalogReadRepositoryTestAdapter(fixture.products),
        inventoryValuationRepository: fixture.valuation,
        auditLogRepository: LocalAuditLogRepository(),
      );
      expect(
        await controller.createManualIncrease(
          user: _employee,
          productId: fixture.productId,
          quantityKg: 5,
          note: 'employee surplus attempt',
          unitCostQirshPerKg: 500,
          evidenceReference: 'employee evidence',
          isStocktake: true,
        ),
        isFalse,
      );
    });
  });

  group('Phase 102C — Scenario I: expense classification', () {
    test('nonOperating expense does not affect operating profit', () async {
      final fixture = await _salesFixture();
      await fixture.sales.createSale(SaleDraft(
        productId: fixture.productId,
        quantityKg: 10,
        salePriceQirshPerKg: 800,
        createdByUserId: _owner.id,
        customerId: 'EXP-CUSTOMER',
      ));
      await fixture.expenses.createExpense(ExpenseDraft(
        date: DateTime.now(),
        category: 'NON-OP FIXTURE',
        amountQirsh: 500,
        createdByUserId: _owner.id,
        operationRequestId: 'non-op-1',
        accountingClassification: ExpenseAccountingClassification.nonOperating,
      ));
      await fixture.expenses.createExpense(ExpenseDraft(
        date: DateTime.now(),
        category: 'OPERATING FIXTURE',
        amountQirsh: 1000,
        createdByUserId: _owner.id,
        operationRequestId: 'op-1',
        accountingClassification: ExpenseAccountingClassification.operating,
      ));
      await fixture.expenses.createExpense(ExpenseDraft(
        date: DateTime.now(),
        category: 'CAPITAL FIXTURE',
        amountQirsh: 2000,
        createdByUserId: _owner.id,
        operationRequestId: 'cap-1',
        accountingClassification: ExpenseAccountingClassification.capital,
      ));

      final report = await fixture.service.build(
        user: _owner,
        start: fixture.activationDate,
        end: DateTime.now().add(const Duration(days: 1)),
      );
      expect(report.salesRevenueQirsh, 8000);
      expect(report.costOfGoodsSoldQirsh, 5000);
      expect(report.grossProfitQirsh, 3000);
      expect(report.operatingExpensesQirsh, 1000);
      expect(report.netOperatingProfitQirsh, 2000);
    });

    test('system does not infer classification from expense category text',
        () async {
      final fixture = await _salesFixture();
      final expense = await fixture.expenses.createExpense(ExpenseDraft(
        date: DateTime.now(),
        category: 'Operating rent payment',
        amountQirsh: 3000,
        createdByUserId: _owner.id,
        operationRequestId: 'text-inference-test',
        accountingClassification: ExpenseAccountingClassification.capital,
      ));
      expect(expense.affectsOperatingProfit, isFalse);
      expect(expense.accountingClassification,
          ExpenseAccountingClassification.capital);
    });
  });

  group('Phase 102C — Scenario J: reporting period', () {
    test('period starting exactly at activation date is allowed', () async {
      final fixture = await _salesFixture();
      await fixture.sales.createSale(SaleDraft(
        productId: fixture.productId,
        quantityKg: 10,
        salePriceQirshPerKg: 800,
        createdByUserId: _owner.id,
        customerId: 'PERIOD-CUSTOMER',
      ));
      final report = await fixture.service.build(
        user: _owner,
        start: fixture.activationDate,
        end: fixture.activationDate.add(const Duration(days: 7)),
      );
      expect(report.isAvailable, isTrue);
      expect(report.salesRevenueQirsh, 8000);
    });

    test('period ending before activation date is blocked', () async {
      final fixture = await _salesFixture();
      expect(
        () => fixture.service.build(
          user: _owner,
          start: fixture.activationDate.subtract(const Duration(days: 10)),
          end: fixture.activationDate.subtract(const Duration(days: 1)),
        ),
        throwsStateError,
      );
    });

    test('overlapping period before activation date is blocked', () async {
      final fixture = await _salesFixture();
      expect(
        () => fixture.service.build(
          user: _owner,
          start: fixture.activationDate.subtract(const Duration(days: 5)),
          end: fixture.activationDate.add(const Duration(days: 5)),
        ),
        throwsStateError,
      );
    });
  });

  group('Phase 102C — Scenario K: backup and restore', () {
    test('restore preserves activation and opening valuation', () async {
      final source = LocalInventoryValuationRepository();
      await source.activate(
        activationDate: DateTime(2026, 7, 1),
        approvedByUserId: 'owner',
        evidenceNote: 'fixture',
        openings: const [
          OpeningValuationInput(
            productId: 'wheat',
            quantityKg: 100,
            unitCostQirshPerKg: 500,
            evidenceReference: 'evidence',
          ),
        ],
      );
      await source.recordPurchase(
        productId: 'wheat',
        quantityKg: 50,
        unitCostQirshPerKg: 700,
        sourceDocumentId: 'purchase-1',
        effectiveDate: DateTime(2026, 7, 5),
        createdByUserId: 'owner',
      );
      await source.recordSale(
        productId: 'wheat',
        quantityKg: 20,
        sourceDocumentId: 'sale-1',
        effectiveDate: DateTime(2026, 7, 10),
        createdByUserId: 'owner',
      );

      final target = LocalInventoryValuationRepository();
      await target.restoreIntoEmpty(await source.exportRestoreData());

      final activation = await target.getActivation();
      expect(activation.isActivated, isTrue);
      expect(activation.activationDate, DateTime(2026, 7, 1));
      final state = await target.stateForProduct('wheat');
      expect(state!.quantityKg, 130);
      final events = await target.listEvents();
      expect(events, hasLength(3));
    });

    test('restore into non-empty repository is rejected', () async {
      final source = LocalInventoryValuationRepository();
      await source.activate(
        activationDate: DateTime(2026, 7, 1),
        approvedByUserId: 'owner',
        evidenceNote: 'fixture',
        openings: const [
          OpeningValuationInput(
            productId: 'wheat',
            quantityKg: 10,
            unitCostQirshPerKg: 100,
            evidenceReference: 'evidence',
          ),
        ],
      );
      final target = LocalInventoryValuationRepository();
      await target.activate(
        activationDate: DateTime(2026, 7, 1),
        approvedByUserId: 'owner',
        evidenceNote: 'existing',
        openings: const [
          OpeningValuationInput(
            productId: 'wheat',
            quantityKg: 5,
            unitCostQirshPerKg: 50,
            evidenceReference: 'existing',
          ),
        ],
      );
      final data = await source.exportRestoreData();
      expect(
        () => target.restoreIntoEmpty(data),
        throwsStateError,
      );
    });

    test('fresh system starts with profitability not activated', () async {
      final valuation = LocalInventoryValuationRepository();
      expect((await valuation.getActivation()).isActivated, isFalse);
      expect(await valuation.listStates(), isEmpty);
      expect(await valuation.listEvents(), isEmpty);
    });

    test('clearForOwnerDataWipe resets to inactive state', () async {
      final valuation = LocalInventoryValuationRepository();
      await valuation.activate(
        activationDate: DateTime(2026, 7, 1),
        approvedByUserId: 'owner',
        evidenceNote: 'fixture',
        openings: const [
          OpeningValuationInput(
            productId: 'wheat',
            quantityKg: 10,
            unitCostQirshPerKg: 100,
            evidenceReference: 'evidence',
          ),
        ],
      );
      await valuation.clearForOwnerDataWipe();
      expect((await valuation.getActivation()).isActivated, isFalse);
      expect(await valuation.listStates(), isEmpty);
      expect(await valuation.listEvents(), isEmpty);
    });
  });

  group('Phase 102C — Scenario L: permissions', () {
    test('employee is rejected before valuation repository reads', () async {
      final valuation = _CountingValuation();
      final sales = _CountingSaleRepo();
      final expenses = _CountingExpenseRepo();
      final service = ProfitabilityReportService(
        inventoryValuationRepository: valuation,
        saleRepository: sales,
        expenseRepository: expenses,
      );
      expect(
        () => service.build(
          user: _employee,
          start: DateTime(2026),
          end: DateTime(2027),
        ),
        throwsStateError,
      );
      expect(valuation.readCount, 0);
      expect(sales.readCount, 0);
      expect(expenses.readCount, 0);
    });

    test('activation service rejects employee before any product read',
        () async {
      final products = _CountingProductRepo();
      final service = ProfitabilityActivationService(
        productCatalogReadRepository:
            ProductCatalogReadRepositoryTestAdapter(products),
        inventoryRepository: LocalInventoryRepository(
          productRepository: products,
        ),
        valuationRepository: LocalInventoryValuationRepository(),
        auditLogRepository: LocalAuditLogRepository(),
      );
      expect(
        () => service.activate(
          user: _employee,
          activationDate: DateTime(2026, 7, 27),
          evidenceNote: 'test',
          openings: const [],
        ),
        throwsStateError,
      );
      expect(products.readCount, 0);
    });

    test('profitability report blocks before activation date', () async {
      final service = ProfitabilityReportService(
        inventoryValuationRepository: LocalInventoryValuationRepository(),
        saleRepository: _CountingSaleRepo(),
        expenseRepository: _CountingExpenseRepo(),
      );
      final report = await service.build(
        user: _owner,
        start: DateTime(2020),
        end: DateTime(2021),
      );
      expect(report.isAvailable, isFalse);
      expect(
          report.messageAr, ProfitabilityReport.unavailableBeforeActivationAr);
    });
  });

  group('Phase 102C — accounting invariant', () {
    test(
        'Opening Value + Purchase Cost + Adjustments - COGS - Adjustments = Closing Value',
        () async {
      final valuation = LocalInventoryValuationRepository();
      await valuation.activate(
        activationDate: DateTime(2026, 7, 1),
        approvedByUserId: 'owner',
        evidenceNote: 'invariant fixture',
        openings: const [
          OpeningValuationInput(
            productId: 'wheat',
            quantityKg: 100,
            unitCostQirshPerKg: 100,
            evidenceReference: 'evidence',
          ),
        ],
      );
      const openingValue = 10000;

      const purchaseValue = 50 * 200;
      await valuation.recordPurchase(
        productId: 'wheat',
        quantityKg: 50,
        unitCostQirshPerKg: 200,
        sourceDocumentId: 'purchase-1',
        effectiveDate: DateTime(2026, 7, 5),
        createdByUserId: 'owner',
      );
      final afterPurchase = await valuation.stateForProduct('wheat');
      expect(afterPurchase!.quantityKg, 150);
      expect(afterPurchase.totalValueQirsh, openingValue + purchaseValue);

      final sale = await valuation.recordSale(
        productId: 'wheat',
        quantityKg: 60,
        sourceDocumentId: 'sale-1',
        effectiveDate: DateTime(2026, 7, 10),
        createdByUserId: 'owner',
      );
      final cogs = sale!.costOfGoodsSoldQirsh;
      final afterSale = await valuation.stateForProduct('wheat');
      expect(afterSale!.quantityKg, 90);
      expect(
        afterSale.totalValueQirsh,
        openingValue + purchaseValue - cogs,
      );

      final shortage = await valuation.recordDecrease(
        productId: 'wheat',
        quantityKg: 5,
        type: InventoryValuationEventType.stocktakeShortage,
        sourceDocumentId: 'stocktake-1',
        effectiveDate: DateTime(2026, 7, 15),
        createdByUserId: 'owner',
        reason: 'fixture shortage',
      );
      final shortageValue = shortage!.valueDeltaQirsh;
      final afterShortage = await valuation.stateForProduct('wheat');
      expect(afterShortage!.quantityKg, 85);
      expect(
        afterShortage.totalValueQirsh,
        openingValue + purchaseValue - cogs + shortageValue,
      );

      await valuation.recordValuedIncrease(
        productId: 'wheat',
        quantityKg: 3,
        unitCostQirshPerKg: 250,
        type: InventoryValuationEventType.stocktakeSurplus,
        sourceDocumentId: 'stocktake-2',
        effectiveDate: DateTime(2026, 7, 20),
        createdByUserId: 'owner',
        reason: 'fixture surplus',
        evidenceReference: 'surplus-evidence',
      );
      final afterSurplus = await valuation.stateForProduct('wheat');
      expect(afterSurplus!.quantityKg, 88);
      expect(
        afterSurplus.totalValueQirsh,
        openingValue + purchaseValue - cogs + shortageValue + 750,
      );

      final reversal = await valuation.reverseSale(
        originalValuationEventId: sale.valuationEventId,
        sourceDocumentId: 'sale-cancel',
        effectiveDate: DateTime(2026, 7, 25),
        createdByUserId: 'owner',
        reason: 'fixture cancel',
      );
      expect(reversal, isNotNull);
      final afterCancel = await valuation.stateForProduct('wheat');
      expect(afterCancel!.quantityKg, 148);
      expect(
        afterCancel.totalValueQirsh,
        openingValue + purchaseValue - cogs + shortageValue + 750 + cogs,
      );
    });

    test('negative cost is never formed by any operation', () async {
      final valuation = LocalInventoryValuationRepository();
      await valuation.activate(
        activationDate: DateTime(2026, 7, 1),
        approvedByUserId: 'owner',
        evidenceNote: 'negative-cost fixture',
        openings: const [
          OpeningValuationInput(
            productId: 'wheat',
            quantityKg: 1,
            unitCostQirshPerKg: 1,
            evidenceReference: 'evidence',
          ),
        ],
      );
      final events = await valuation.listEvents();
      for (final event in events) {
        expect(event.valueDeltaQirsh, greaterThanOrEqualTo(0));
      }
      final state = await valuation.stateForProduct('wheat');
      expect(state!.totalValueQirsh, greaterThanOrEqualTo(0));
    });
  });
}

Future<_SalesFixture> _salesFixture() async {
  final products = LocalProductRepository();
  final product = await products.createProduct(const ProductDraft(
    name: 'TEST 102C WHEAT',
    unit: GrainUnit.kilogram,
  ));
  final inventory = LocalInventoryRepository(productRepository: products);
  await inventory.createMovement(StockMovementDraft(
    productId: product.id,
    movementType: StockMovementType.openingBalance,
    quantityKg: 100,
    createdByUserId: _owner.id,
  ));
  final activationDate = DateTime.now().subtract(const Duration(days: 1));
  final valuation = LocalInventoryValuationRepository();
  await valuation.activate(
    activationDate: activationDate,
    approvedByUserId: _owner.id,
    evidenceNote: 'TEST FIXTURE ONLY — not production data',
    openings: [
      OpeningValuationInput(
        productId: product.id,
        quantityKg: 100,
        unitCostQirshPerKg: 500,
        evidenceReference: 'TEST FIXTURE ONLY — invoice',
      ),
    ],
  );
  final sales = LocalSaleRepository(
    productRepository: products,
    inventoryRepository: inventory,
    inventoryValuationRepository: valuation,
  );
  final expenses = LocalExpenseRepository();
  return _SalesFixture(
    productId: product.id,
    activationDate: activationDate,
    products: products,
    inventory: inventory,
    valuation: valuation,
    sales: sales,
    expenses: expenses,
    service: ProfitabilityReportService(
      inventoryValuationRepository: valuation,
      saleRepository: sales,
      expenseRepository: expenses,
    ),
  );
}

class _SalesFixture {
  const _SalesFixture({
    required this.productId,
    required this.activationDate,
    required this.products,
    required this.inventory,
    required this.valuation,
    required this.sales,
    required this.expenses,
    required this.service,
  });

  final String productId;
  final DateTime activationDate;
  final LocalProductRepository products;
  final LocalInventoryRepository inventory;
  final LocalInventoryValuationRepository valuation;
  final LocalSaleRepository sales;
  final LocalExpenseRepository expenses;
  final ProfitabilityReportService service;
}

final _owner = AppUser(
  id: 'TEST-102C-OWNER',
  name: 'Test Owner 102C',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _employee = AppUser(
  id: 'TEST-102C-EMPLOYEE',
  name: 'Test Employee 102C',
  phone: '01100000000',
  role: UserRole.employee,
  isActive: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class _CountingValuation extends LocalInventoryValuationRepository {
  int readCount = 0;
  @override
  Future<ProfitabilityActivation> getActivation() {
    readCount++;
    return super.getActivation();
  }
}

class _CountingSaleRepo extends LocalSaleRepository {
  _CountingSaleRepo()
      : super(
          productRepository: LocalProductRepository(),
          inventoryRepository: LocalInventoryRepository(
            productRepository: LocalProductRepository(),
          ),
        );
  int readCount = 0;
  @override
  Future<List<SaleRecord>> listSales() {
    readCount++;
    return super.listSales();
  }
}

class _CountingExpenseRepo extends LocalExpenseRepository {
  int readCount = 0;
  @override
  Future<List<ExpenseRecord>> listExpenses() {
    readCount++;
    return super.listExpenses();
  }
}

class _CountingProductRepo implements ProductRepository {
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
