import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/reports/daily_activity_report.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';

abstract class ReportRepository {
  Future<DailyActivityReport> dailyActivityReport({
    required DateTime selectedDate,
  });
}

class LocalReportRepository implements ReportRepository {
  const LocalReportRepository({
    required PurchaseRepository purchaseRepository,
    required SaleRepository saleRepository,
    required InventoryRepository inventoryRepository,
    required ProductRepository productRepository,
  })  : _purchaseRepository = purchaseRepository,
        _saleRepository = saleRepository,
        _inventoryRepository = inventoryRepository,
        _productRepository = productRepository;

  final PurchaseRepository _purchaseRepository;
  final SaleRepository _saleRepository;
  final InventoryRepository _inventoryRepository;
  final ProductRepository _productRepository;

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
    final products = await _productRepository.listProducts(includeInactive: true);
    final productNames = {
      for (final product in products) product.id: product.name,
    };

    final purchases = (await _purchaseRepository.listPurchaseIntakes())
        .where((purchase) => _isInRange(purchase.createdAt, start, end))
        .toList(growable: false);
    final sales = (await _saleRepository.listSales())
        .where((sale) => _isInRange(sale.createdAt, start, end))
        .toList(growable: false);
    final movements = (await _inventoryRepository.listAllMovements())
        .where((movement) => _isInRange(movement.createdAt, start, end))
        .toList(growable: false);

    final balances = await _inventoryRepository.allProductBalancesKg();
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
