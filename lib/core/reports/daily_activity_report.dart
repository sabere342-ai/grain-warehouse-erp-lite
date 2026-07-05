import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';

class DailyActivityReport {
  const DailyActivityReport({
    required this.start,
    required this.end,
    required this.totalPurchasedKg,
    required this.totalSoldKg,
    required this.totalPurchaseAmountQirsh,
    required this.totalSalesAmountQirsh,
    required this.purchaseCount,
    required this.saleCount,
    required this.stockMovementCount,
    required this.stockBalances,
    required this.recentMovements,
  });

  final DateTime start;
  final DateTime end;
  final int totalPurchasedKg;
  final int totalSoldKg;
  final int totalPurchaseAmountQirsh;
  final int totalSalesAmountQirsh;
  final int purchaseCount;
  final int saleCount;
  final int stockMovementCount;
  final List<ProductStockBalance> stockBalances;
  final List<ReportStockMovement> recentMovements;
}

class ProductStockBalance {
  const ProductStockBalance({
    required this.productId,
    required this.productName,
    required this.quantityKg,
    required this.unitLabel,
  });

  final String productId;
  final String productName;
  final int quantityKg;
  final String unitLabel;
}

class ReportStockMovement {
  const ReportStockMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantityKg,
    required this.createdAt,
    this.reference,
  });

  final String id;
  final String productId;
  final String productName;
  final StockMovementType type;
  final int quantityKg;
  final DateTime createdAt;
  final String? reference;
}
