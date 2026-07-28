import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation_repository.dart';
import 'package:grain_warehouse_erp_lite/core/profitability/profitability_report.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';

class ProfitabilityReportService {
  const ProfitabilityReportService({
    required InventoryValuationRepository inventoryValuationRepository,
    required SaleRepository saleRepository,
    required ExpenseRepository expenseRepository,
  })  : _inventoryValuationRepository = inventoryValuationRepository,
        _saleRepository = saleRepository,
        _expenseRepository = expenseRepository;

  final InventoryValuationRepository _inventoryValuationRepository;
  final SaleRepository _saleRepository;
  final ExpenseRepository _expenseRepository;

  Future<ProfitabilityReport> build({
    required AppUser user,
    required DateTime start,
    required DateTime end,
  }) async {
    // This authorization gate deliberately precedes every repository read.
    if (!user.isActive || !user.permissions.canViewFinancialReports) {
      throw StateError('ليس لديك صلاحية عرض التقارير المالية.');
    }
    if (!start.isBefore(end)) {
      throw ArgumentError('Report start must be before report end.');
    }

    final activation = await _inventoryValuationRepository.getActivation();
    if (!activation.supportsValuationOperations) {
      return ProfitabilityReport.notAvailable(
        messageAr: ProfitabilityReport.unavailableBeforeActivationAr,
        activation: activation,
      );
    }
    final activationDate = activation.activationDate!;
    if (start.isBefore(activationDate)) {
      throw StateError('لا يمكن أن يبدأ تقرير الربحية قبل تاريخ التفعيل.');
    }

    final sales = await _saleRepository.listSales();
    final expenses = await _expenseRepository.listExpenses();
    var revenue = 0;
    var cashRevenue = 0;
    var creditRevenue = 0;
    var cogs = 0;

    for (final sale in sales) {
      if (_inRange(sale.createdAt, start, end)) {
        _requireCostSnapshot(sale);
        revenue += sale.totalQirsh;
        cashRevenue += sale.effectivePaidAmountQirsh;
        creditRevenue += sale.remainingAmountQirsh;
        cogs += sale.totalCostOfGoodsSoldQirsh!;
      }
      final cancellationDate = sale.cancellation?.cancelledAt;
      if (cancellationDate != null && _inRange(cancellationDate, start, end)) {
        _requireCostSnapshot(sale);
        revenue -= sale.totalQirsh;
        cashRevenue -= sale.effectivePaidAmountQirsh;
        creditRevenue -= sale.remainingAmountQirsh;
        cogs -= sale.totalCostOfGoodsSoldQirsh!;
      }
    }

    final operatingExpenses = expenses
        .where((expense) =>
            expense.affectsOperatingProfit &&
            _inRange(expense.date, start, end))
        .fold<int>(0, (total, expense) => total + expense.amountQirsh);
    final grossProfit = revenue - cogs;
    return ProfitabilityReport.available(
      activation: activation,
      start: start,
      end: end,
      salesRevenueQirsh: revenue,
      cashRevenueQirsh: cashRevenue,
      creditRevenueQirsh: creditRevenue,
      costOfGoodsSoldQirsh: cogs,
      grossProfitQirsh: grossProfit,
      operatingExpensesQirsh: operatingExpenses,
      netOperatingProfitQirsh: grossProfit - operatingExpenses,
    );
  }

  void _requireCostSnapshot(SaleRecord sale) {
    if (!sale.hasCompleteCostSnapshots) {
      throw StateError(
        'غير متاحة محاسبيًا — توجد حركة بيع بلا لقطة تكلفة معتمدة.',
      );
    }
  }

  bool _inRange(DateTime value, DateTime start, DateTime end) =>
      !value.isBefore(start) && value.isBefore(end);
}
