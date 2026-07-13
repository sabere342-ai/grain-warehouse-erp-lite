import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_collection.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/reports/business_summary_calculator.dart';
import 'package:grain_warehouse_erp_lite/core/reports/daily_activity_report.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';

abstract class ReportRepository {
  Future<DailyActivityReport> dailyActivityReport({
    required DateTime selectedDate,
  });
}

class LocalReportRepository implements ReportRepository {
  LocalReportRepository({
    required PurchaseRepository purchaseRepository,
    required SaleRepository saleRepository,
    required InventoryRepository inventoryRepository,
    required ProductRepository productRepository,
    ExpenseRepository? expenseRepository,
    CustomerAccountRepository? customerAccountRepository,
    SupplierAccountRepository? supplierAccountRepository,
  })  : _purchaseRepository = purchaseRepository,
        _saleRepository = saleRepository,
        _inventoryRepository = inventoryRepository,
        _productRepository = productRepository,
        _expenseRepository = expenseRepository ?? LocalExpenseRepository(),
        _customerAccountRepository = customerAccountRepository,
        _supplierAccountRepository = supplierAccountRepository;

  final PurchaseRepository _purchaseRepository;
  final SaleRepository _saleRepository;
  final InventoryRepository _inventoryRepository;
  final ProductRepository _productRepository;
  final ExpenseRepository _expenseRepository;
  final CustomerAccountRepository? _customerAccountRepository;
  final SupplierAccountRepository? _supplierAccountRepository;

  @override
  Future<DailyActivityReport> dailyActivityReport({
    required DateTime selectedDate,
  }) async {
    final start = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final end = start.add(const Duration(days: 1));
    final products =
        await _productRepository.listProducts(includeInactive: true);
    final productNames = {
      for (final product in products) product.id: product.name,
    };

    final purchases = (await _purchaseRepository.listPurchaseIntakes())
        .where((purchase) =>
            !purchase.isCancelled && _isInRange(purchase.createdAt, start, end))
        .toList(growable: false);
    final sales = (await _saleRepository.listSales())
        .where((sale) =>
            !sale.isCancelled && _isInRange(sale.createdAt, start, end))
        .toList(growable: false);
    final movements = (await _inventoryRepository.listAllMovements())
        .where((movement) => _isInRange(movement.createdAt, start, end))
        .toList(growable: false);

    final balances = await _inventoryRepository.allProductBalancesKg();
    final totalExpensesQirsh = await _expenseRepository.totalExpensesQirsh(
      start: start,
      end: end,
    );
    final creditSales =
        sales.where((sale) => sale.isCreditSale).toList(growable: false);
    final customerCollections = (await _customerAccountRepository
                ?.listCollections() ??
            const <CustomerCollectionRecord>[])
        .where((collection) =>
            !collection.isCancelled && _isInRange(collection.date, start, end))
        .toList(growable: false);
    final receivablesByCustomer =
        await _customerAccountRepository?.balancesByCustomerId() ??
            const <String, int>{};
    final totalOutstandingReceivablesQirsh = receivablesByCustomer.values
        .where((value) => value > 0)
        .fold<int>(0, (total, value) => total + value);
    final supplierPayments =
        await _supplierAccountRepository?.listPayments() ?? const [];
    final cancelledSupplierPaymentIds = supplierPayments
        .where((payment) => payment.isCancelled)
        .map((payment) => payment.id)
        .toSet();
    final supplierEntries = await _supplierAccountRepository?.listEntries() ??
        const <SupplierAccountEntry>[];
    final totalSupplierPaymentsQirsh = supplierEntries
        .where((entry) =>
            entry.type == SupplierAccountEntryType.payment &&
            !cancelledSupplierPaymentIds.contains(entry.sourceDocumentId) &&
            _isInRange(entry.date, start, end))
        .fold<int>(0, (total, entry) => total + entry.creditAmountQirsh);
    final payablesBySupplier =
        await _supplierAccountRepository?.balancesBySupplierId() ??
            const <String, int>{};
    final totalOutstandingSupplierPayablesQirsh = payablesBySupplier.values
        .where((value) => value > 0)
        .fold<int>(0, (total, value) => total + value);
    final summary = BusinessSummaryCalculator.calculate(
      products: products,
      purchases: purchases,
      sales: sales,
      stockBalancesKg: balances,
    );
    final stockBalances = [
      for (final product in products)
        ProductStockBalance(
          productId: product.id,
          productName: product.name,
          quantityKg: balances[product.id] ?? 0,
          unitLabel: product.unit.labelAr,
        ),
    ];

    final recentMovements = [
      for (final movement in movements.reversed)
        ReportStockMovement(
          id: movement.id,
          productId: movement.productId,
          productName: productNames[movement.productId] ?? 'صنف غير معروف',
          type: movement.movementType,
          quantityKg: movement.quantityKg,
          createdAt: movement.createdAt,
          reference: movement.note,
        ),
    ];

    return DailyActivityReport(
      start: start,
      end: end,
      totalPurchasedKg: purchases.fold<int>(
        0,
        (total, purchase) => total + purchase.quantityKg,
      ),
      totalSoldKg: sales.fold<int>(
        0,
        (total, sale) => total + sale.quantityKg,
      ),
      totalPurchaseAmountQirsh: purchases.fold<int>(
        0,
        (total, purchase) => total + purchase.totalAmountPiasters,
      ),
      totalSalesAmountQirsh: sales.fold<int>(
        0,
        (total, sale) => total + sale.totalQirsh,
      ),
      totalExpenseAmountQirsh: totalExpensesQirsh,
      totalCreditSalesAmountQirsh:
          creditSales.fold<int>(0, (total, sale) => total + sale.totalQirsh),
      totalCollectionsAmountQirsh: customerCollections.fold<int>(
          0, (total, collection) => total + collection.amountQirsh),
      totalOutstandingReceivablesQirsh: totalOutstandingReceivablesQirsh,
      totalSupplierPaymentsQirsh: totalSupplierPaymentsQirsh,
      totalOutstandingSupplierPayablesQirsh:
          totalOutstandingSupplierPayablesQirsh,
      estimatedSalesCostQirsh: summary.estimatedSalesCostQirsh,
      estimatedGrossProfitQirsh: summary.estimatedGrossProfitQirsh,
      estimatedStockValueQirsh: summary.estimatedStockValueQirsh,
      hasCompleteSalesCost: summary.hasCompleteSalesCost,
      hasCompleteStockValuation: summary.hasCompleteStockValuation,
      missingSalesCostProductNames: summary.missingSalesCostProductNames,
      missingStockCostProductNames: summary.missingStockCostProductNames,
      purchaseCount: purchases.length,
      saleCount: sales.length,
      stockMovementCount: movements.length,
      stockBalances: List<ProductStockBalance>.unmodifiable(stockBalances),
      recentMovements: List<ReportStockMovement>.unmodifiable(recentMovements),
    );
  }

  bool _isInRange(DateTime value, DateTime start, DateTime end) {
    return !value.isBefore(start) && value.isBefore(end);
  }
}
