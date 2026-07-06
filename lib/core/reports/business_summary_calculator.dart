import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';

class BusinessSummaryCalculator {
  const BusinessSummaryCalculator._();

  static BusinessSummary calculate({
    required List<Product> products,
    required List<PurchaseIntake> purchases,
    required List<SaleRecord> sales,
    required Map<String, int> stockBalancesKg,
    int totalExpenseAmountQirsh = 0,
  }) {
    final productsById = {
      for (final product in products) product.id: product,
    };

    final totalPurchaseAmountQirsh = purchases.fold<int>(
      0,
      (total, purchase) => total + purchase.totalAmountPiasters,
    );
    final totalSalesAmountQirsh = sales.fold<int>(
      0,
      (total, sale) => total + sale.totalQirsh,
    );

    var estimatedSalesCostQirsh = 0;
    final missingSalesCostProductNames = <String>{};
    for (final sale in sales) {
      final product = productsById[sale.productId];
      final referenceCost = product?.referenceCostPricePiastersPerKg;
      if (referenceCost == null) {
        missingSalesCostProductNames.add(product?.name ?? 'صنف غير معروف');
        continue;
      }
      estimatedSalesCostQirsh += sale.quantityKg * referenceCost;
    }

    var estimatedStockValueQirsh = 0;
    final missingStockCostProductNames = <String>{};
    for (final product in products) {
      final quantityKg = stockBalancesKg[product.id] ?? 0;
      if (quantityKg <= 0) {
        continue;
      }
      final referenceCost = product.referenceCostPricePiastersPerKg;
      if (referenceCost == null) {
        missingStockCostProductNames.add(product.name);
        continue;
      }
      estimatedStockValueQirsh += quantityKg * referenceCost;
    }

    final hasCompleteSalesCost = missingSalesCostProductNames.isEmpty;
    final hasCompleteStockValuation = missingStockCostProductNames.isEmpty;
    final completeEstimatedSalesCost =
        hasCompleteSalesCost ? estimatedSalesCostQirsh : null;

    return BusinessSummary(
      totalPurchaseAmountQirsh: totalPurchaseAmountQirsh,
      totalSalesAmountQirsh: totalSalesAmountQirsh,
      totalExpenseAmountQirsh: totalExpenseAmountQirsh,
      estimatedSalesCostQirsh: completeEstimatedSalesCost,
      estimatedGrossProfitQirsh: completeEstimatedSalesCost == null
          ? null
          : totalSalesAmountQirsh - completeEstimatedSalesCost,
      estimatedStockValueQirsh:
          hasCompleteStockValuation ? estimatedStockValueQirsh : null,
      hasCompleteSalesCost: hasCompleteSalesCost,
      hasCompleteStockValuation: hasCompleteStockValuation,
      missingSalesCostProductNames:
          List<String>.unmodifiable(missingSalesCostProductNames),
      missingStockCostProductNames:
          List<String>.unmodifiable(missingStockCostProductNames),
    );
  }
}

class BusinessSummary {
  const BusinessSummary({
    required this.totalPurchaseAmountQirsh,
    required this.totalSalesAmountQirsh,
    required this.totalExpenseAmountQirsh,
    required this.estimatedSalesCostQirsh,
    required this.estimatedGrossProfitQirsh,
    required this.estimatedStockValueQirsh,
    required this.hasCompleteSalesCost,
    required this.hasCompleteStockValuation,
    required this.missingSalesCostProductNames,
    required this.missingStockCostProductNames,
  });

  final int totalPurchaseAmountQirsh;
  final int totalSalesAmountQirsh;
  final int totalExpenseAmountQirsh;
  final int? estimatedSalesCostQirsh;
  final int? estimatedGrossProfitQirsh;
  final int? estimatedStockValueQirsh;
  final bool hasCompleteSalesCost;
  final bool hasCompleteStockValuation;
  final List<String> missingSalesCostProductNames;
  final List<String> missingStockCostProductNames;
}
