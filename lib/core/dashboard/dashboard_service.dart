import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_attention_service.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';

class DashboardData {
  const DashboardData({
    required this.todaySalesQirsh,
    required this.todayCashSalesQirsh,
    required this.todayCreditSalesQirsh,
    required this.todayCollectionsQirsh,
    required this.todaySupplierPaymentsQirsh,
    required this.todayExpensesQirsh,
    required this.cashBalanceQirsh,
    required this.customerReceivablesQirsh,
    required this.supplierPayablesQirsh,
    required this.totalStockKg,
    required this.wheatStockKg,
    required this.stockAlertCount,
    required this.hasData,
  });

  final int todaySalesQirsh;
  final int todayCashSalesQirsh;
  final int todayCreditSalesQirsh;
  final int todayCollectionsQirsh;
  final int todaySupplierPaymentsQirsh;
  final int todayExpensesQirsh;

  int get todayCashInQirsh => todayCashSalesQirsh + todayCollectionsQirsh;
  int get todayCashOutQirsh => todaySupplierPaymentsQirsh + todayExpensesQirsh;
  int get todayNetCashQirsh => todayCashInQirsh - todayCashOutQirsh;

  final int cashBalanceQirsh;
  final int customerReceivablesQirsh;
  final int supplierPayablesQirsh;
  final int totalStockKg;
  final int wheatStockKg;
  final int stockAlertCount;
  final bool hasData;

  factory DashboardData.empty() => const DashboardData(
        todaySalesQirsh: 0,
        todayCashSalesQirsh: 0,
        todayCreditSalesQirsh: 0,
        todayCollectionsQirsh: 0,
        todaySupplierPaymentsQirsh: 0,
        todayExpensesQirsh: 0,
        cashBalanceQirsh: 0,
        customerReceivablesQirsh: 0,
        supplierPayablesQirsh: 0,
        totalStockKg: 0,
        wheatStockKg: 0,
        stockAlertCount: 0,
        hasData: false,
      );
}

class DashboardService {
  DashboardService({
    required SaleRepository saleRepository,
    required InventoryRepository inventoryRepository,
    required ProductRepository productRepository,
    required ExpenseRepository expenseRepository,
    required CustomerAccountRepository customerAccountRepository,
    required FinancialAccountRepository financialAccountRepository,
    SupplierAccountRepository? supplierAccountRepository,
    InventoryAttentionService? inventoryAttentionService,
  })  : _saleRepository = saleRepository,
        _inventoryRepository = inventoryRepository,
        _productRepository = productRepository,
        _expenseRepository = expenseRepository,
        _customerAccountRepository = customerAccountRepository,
        _financialAccountRepository = financialAccountRepository,
        _supplierAccountRepository = supplierAccountRepository,
        _inventoryAttentionService = inventoryAttentionService ??
            InventoryAttentionService(
              productRepository: productRepository,
              inventoryRepository: inventoryRepository,
            );

  final SaleRepository _saleRepository;
  final InventoryRepository _inventoryRepository;
  final ProductRepository _productRepository;
  final ExpenseRepository _expenseRepository;
  final CustomerAccountRepository _customerAccountRepository;
  final FinancialAccountRepository _financialAccountRepository;
  final SupplierAccountRepository? _supplierAccountRepository;
  final InventoryAttentionService _inventoryAttentionService;

  Future<DashboardData> load() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final allSales = await _saleRepository.listSales();
    final products =
        await _productRepository.listProducts(includeInactive: true);
    final todaySales = allSales
        .where((sale) =>
            !sale.isCancelled &&
            !sale.createdAt.isBefore(todayStart) &&
            sale.createdAt.isBefore(todayEnd))
        .toList(growable: false);

    final todaySalesQirsh = todaySales.fold<int>(0, (t, s) => t + s.totalQirsh);
    final todayCashSalesQirsh = todaySales
        .where((s) => s.paymentMode == SalePaymentMode.cash)
        .fold<int>(0, (t, s) => t + s.totalQirsh);
    final todayCreditSalesQirsh = todaySales
        .where((s) => s.isCreditSale)
        .fold<int>(0, (t, s) => t + s.totalQirsh);

    final todayCollections =
        (await _customerAccountRepository.listCollections())
            .where((c) =>
                !c.isCancelled &&
                !c.date.isBefore(todayStart) &&
                c.date.isBefore(todayEnd))
            .fold<int>(0, (t, c) => t + c.amountQirsh);

    final todayExpenses = (await _expenseRepository.listExpenses())
        .where((e) => !e.date.isBefore(todayStart) && e.date.isBefore(todayEnd))
        .fold<int>(0, (t, e) => t + e.amountQirsh);

    final allSupplierPayments =
        await _supplierAccountRepository?.listPayments() ?? [];
    final todaySupplierPayments = allSupplierPayments
        .where((p) =>
            !p.isCancelled &&
            !p.date.isBefore(todayStart) &&
            p.date.isBefore(todayEnd))
        .fold<int>(0, (t, p) => t + p.amountQirsh);

    final accountBalances = await _financialAccountRepository
        .allAccountBalances(includeInactive: true);
    final cashBalanceQirsh = accountBalances.fold<int>(
      0,
      (total, account) => total + account.currentBalanceQirsh,
    );

    final receivablesByCustomer =
        await _customerAccountRepository.balancesByCustomerId();
    final customerReceivablesQirsh = receivablesByCustomer.values
        .where((v) => v > 0)
        .fold<int>(0, (t, v) => t + v);

    final payablesBySupplier =
        await _supplierAccountRepository?.balancesBySupplierId() ??
            const <String, int>{};
    final supplierPayablesQirsh = payablesBySupplier.values
        .where((v) => v > 0)
        .fold<int>(0, (t, v) => t + v);

    final balances = await _inventoryRepository.allProductBalancesKg();
    final totalStockKg = balances.values.fold<int>(0, (t, v) => t + v);

    int wheatStockKg = 0;
    final wheatProduct = products
        .where((p) =>
            p.name.contains('قمح') ||
            p.name.contains(' Wheat') ||
            p.name.contains('wheat'))
        .toList();
    if (wheatProduct.isNotEmpty) {
      wheatStockKg = balances[wheatProduct.first.id] ?? 0;
    }

    final stockAlertCount =
        (await _inventoryAttentionService.loadAttention()).length;

    return DashboardData(
      todaySalesQirsh: todaySalesQirsh,
      todayCashSalesQirsh: todayCashSalesQirsh,
      todayCreditSalesQirsh: todayCreditSalesQirsh,
      todayCollectionsQirsh: todayCollections,
      todaySupplierPaymentsQirsh: todaySupplierPayments,
      todayExpensesQirsh: todayExpenses,
      cashBalanceQirsh: cashBalanceQirsh,
      customerReceivablesQirsh: customerReceivablesQirsh,
      supplierPayablesQirsh: supplierPayablesQirsh,
      totalStockKg: totalStockKg,
      wheatStockKg: wheatStockKg,
      stockAlertCount: stockAlertCount,
      hasData: products.isNotEmpty || allSales.isNotEmpty,
    );
  }
}
