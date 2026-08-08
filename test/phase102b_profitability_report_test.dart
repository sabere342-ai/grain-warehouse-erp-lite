import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation_repository.dart';
import 'package:grain_warehouse_erp_lite/core/profitability/profitability_report.dart';
import 'package:grain_warehouse_erp_lite/core/profitability/profitability_report_service.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';

import 'support/product_catalog_read_repository_test_adapter.dart';

void main() {
  group('Phase 102B profitability reporting', () {
    test('permission is checked before any financial repository read',
        () async {
      final valuation = _CountingValuationRepository();
      final sales = _CountingSaleRepository();
      final expenses = _CountingExpenseRepository();
      final service = ProfitabilityReportService(
        inventoryValuationRepository: valuation,
        saleRepository: sales,
        expenseRepository: expenses,
      );

      await expectLater(
        service.build(
          user: _employee,
          start: DateTime(2026),
          end: DateTime(2027),
        ),
        throwsStateError,
      );
      expect(valuation.activationReads, 0);
      expect(sales.listReads, 0);
      expect(expenses.listReads, 0);
    });

    test('inactive state returns the frozen Arabic message without data reads',
        () async {
      final valuation = _CountingValuationRepository();
      final sales = _CountingSaleRepository();
      final expenses = _CountingExpenseRepository();
      final report = await ProfitabilityReportService(
        inventoryValuationRepository: valuation,
        saleRepository: sales,
        expenseRepository: expenses,
      ).build(
        user: _owner,
        start: DateTime(2026),
        end: DateTime(2027),
      );

      expect(report.isAvailable, isFalse);
      expect(
          report.messageAr, ProfitabilityReport.unavailableBeforeActivationAr);
      expect(sales.listReads, 0);
      expect(expenses.listReads, 0);
    });

    test('uses transaction COGS and only operating expense classification',
        () async {
      final fixture = await _fixture();
      final sale = await fixture.sales.createSale(SaleDraft(
        productId: fixture.productId,
        quantityKg: 10,
        salePriceQirshPerKg: 800,
        createdByUserId: _owner.id,
        customerId: 'TEST-CUSTOMER-FIXTURE',
      ));
      expect(sale.totalCostOfGoodsSoldQirsh, 5000);
      await fixture.expenses.createExpense(ExpenseDraft(
        date: DateTime.now(),
        category: 'TEST OPERATING FIXTURE',
        amountQirsh: 1000,
        createdByUserId: _owner.id,
        operationRequestId: 'TEST-EXP-OPERATING',
        accountingClassification: ExpenseAccountingClassification.operating,
      ));
      await fixture.expenses.createExpense(ExpenseDraft(
        date: DateTime.now(),
        category: 'TEST CAPITAL FIXTURE',
        amountQirsh: 2000,
        createdByUserId: _owner.id,
        operationRequestId: 'TEST-EXP-CAPITAL',
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
      expect(report.cashWarning, ProfitabilityReport.cashWarningAr);
    });

    test('sale cancellation reverses the exact original revenue and COGS',
        () async {
      final fixture = await _fixture();
      final sale = await fixture.sales.createSale(SaleDraft(
        productId: fixture.productId,
        quantityKg: 10,
        salePriceQirshPerKg: 800,
        createdByUserId: _owner.id,
        customerId: 'TEST-CUSTOMER-FIXTURE',
      ));
      await fixture.sales.cancelSale(
        saleId: sale.id,
        cancelledByUserId: _owner.id,
        cancellationReason: 'TEST CANCELLATION FIXTURE',
      );

      final report = await fixture.service.build(
        user: _owner,
        start: fixture.activationDate,
        end: DateTime.now().add(const Duration(days: 1)),
      );
      expect(report.salesRevenueQirsh, 0);
      expect(report.costOfGoodsSoldQirsh, 0);
      expect(report.netOperatingProfitQirsh, 0);
    });
  });
}

Future<_Fixture> _fixture() async {
  final products = LocalProductRepository();
  final product = await products.createProduct(const ProductDraft(
    name: 'TEST WHEAT FIXTURE',
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
    evidenceNote: 'TEST FIXTURE ONLY — physical count evidence',
    openings: [
      OpeningValuationInput(
        productId: product.id,
        quantityKg: 100,
        unitCostQirshPerKg: 500,
        evidenceReference: 'TEST FIXTURE ONLY — supplier invoice',
      ),
    ],
  );
  final sales = LocalSaleRepository(
    productCatalogReadRepository:
        ProductCatalogReadRepositoryTestAdapter(products),
    inventoryRepository: inventory,
    inventoryValuationRepository: valuation,
  );
  final expenses = LocalExpenseRepository();
  return _Fixture(
    productId: product.id,
    activationDate: activationDate,
    sales: sales,
    expenses: expenses,
    service: ProfitabilityReportService(
      inventoryValuationRepository: valuation,
      saleRepository: sales,
      expenseRepository: expenses,
    ),
  );
}

class _Fixture {
  const _Fixture({
    required this.productId,
    required this.activationDate,
    required this.sales,
    required this.expenses,
    required this.service,
  });
  final String productId;
  final DateTime activationDate;
  final LocalSaleRepository sales;
  final LocalExpenseRepository expenses;
  final ProfitabilityReportService service;
}

class _CountingValuationRepository extends LocalInventoryValuationRepository {
  int activationReads = 0;
  @override
  Future<ProfitabilityActivation> getActivation() {
    activationReads++;
    return super.getActivation();
  }
}

class _CountingSaleRepository extends LocalSaleRepository {
  _CountingSaleRepository()
      : super(
          productCatalogReadRepository: ProductCatalogReadRepositoryTestAdapter(
            LocalProductRepository(),
          ),
          inventoryRepository: LocalInventoryRepository(
            productRepository: LocalProductRepository(),
          ),
        );
  int listReads = 0;
  @override
  Future<List<SaleRecord>> listSales() {
    listReads++;
    return super.listSales();
  }
}

class _CountingExpenseRepository extends LocalExpenseRepository {
  int listReads = 0;
  @override
  Future<List<ExpenseRecord>> listExpenses() {
    listReads++;
    return super.listExpenses();
  }
}

final _owner = AppUser(
  id: 'TEST-OWNER-FIXTURE',
  name: 'Test Owner Fixture',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _employee = AppUser(
  id: 'TEST-EMPLOYEE-FIXTURE',
  name: 'Test Employee Fixture',
  phone: '01100000000',
  role: UserRole.employee,
  isActive: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
