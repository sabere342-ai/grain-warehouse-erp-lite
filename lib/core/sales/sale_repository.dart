import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/cancellation_metadata.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';

class MinimumSalePriceViolation implements Exception {
  const MinimumSalePriceViolation({
    required this.productId,
    required this.minimumSalePricePiastersPerKg,
    required this.actualSalePricePiastersPerKg,
  });

  final String productId;
  final int minimumSalePricePiastersPerKg;
  final int actualSalePricePiastersPerKg;
}

abstract class SaleRepository {
  Future<SaleRecord> createSale(SaleDraft draft);

  Future<SaleRecord> cancelSale({
    required String saleId,
    required String cancelledByUserId,
    required String cancellationReason,
  });

  Future<List<SaleRecord>> listSales();
}

abstract class DurableSaleRepository
    implements SaleRepository, TransactionSnapshotProvider {
  Future<void> restoreSalesIntoEmpty(List<SaleRecord> sales);

  Future<void> clearForOwnerDataWipe();
}

class LocalSaleRepository implements DurableSaleRepository {
  LocalSaleRepository({
    required ProductCatalogReadRepository productCatalogReadRepository,
    required InventoryRepository inventoryRepository,
    InventoryValuationRepository? inventoryValuationRepository,
    FinancialAccountRepository? financialAccountRepository,
  })  : _productCatalogReadRepository = productCatalogReadRepository,
        _inventoryRepository = inventoryRepository,
        _inventoryValuationRepository = inventoryValuationRepository,
        _financialAccountRepository = financialAccountRepository;

  static const int _maxSafeTotalQirsh = 9223372036854775807;

  final ProductCatalogReadRepository _productCatalogReadRepository;
  final InventoryRepository _inventoryRepository;
  final InventoryValuationRepository? _inventoryValuationRepository;
  final FinancialAccountRepository? _financialAccountRepository;
  final List<SaleRecord> _sales = [];
  final Map<String, String> _operationRequestIds = {};
  int _generatedIdCounter = 0;

  @override
  Future<SaleRecord> createSale(SaleDraft draft) async {
    _validateDraft(draft);
    final operationRequestId =
        _normalizedOptionalText(draft.operationRequestId);
    if (draft.paymentAllocations.isNotEmpty && operationRequestId == null) {
      throw ArgumentError.value(
        draft.operationRequestId,
        'operationRequestId',
        'Payment allocations require an operation request id.',
      );
    }
    if (operationRequestId != null &&
        _operationRequestIds.containsKey(operationRequestId)) {
      throw StateError('Sale request was already processed.');
    }

    final items = _buildItems(draft);
    final totalQirsh = _computeTotal(items);

    final now = DateTime.now();
    final saleId = _generateSaleId(now);
    await _financialAccountRepository?.ensureDateIsOpen(now);

    final customerId = _normalizedOptionalText(draft.customerId);

    final products = await _validateAllProducts(items);
    _validateAllMinimumPrices(items, products);

    final stockCheck = await _checkAllStock(items);
    if (stockCheck != null) {
      throw stockCheck;
    }

    final snapshots = <SnapshotHolder>[createTransactionSnapshot()];
    snapshots.add(_requiredSnapshot(_inventoryRepository, 'inventory'));
    if (_inventoryValuationRepository != null) {
      snapshots.add(_requiredSnapshot(
          _inventoryValuationRepository, 'inventory valuation'));
    }

    return RepositoryTransaction.execute(snapshots, () async {
      final movementIds = <String>[];
      final costedItems = <SaleLineItem>[];
      for (final item in items) {
        final product = await _validateProduct(item.productId);
        final movement = await _inventoryRepository.createMovement(
          StockMovementDraft(
            productId: product.id,
            movementType: StockMovementType.sale,
            quantityKg: item.quantityKg,
            createdByUserId: draft.createdByUserId.trim(),
            note: '\u0628\u064a\u0639 $saleId',
            originalDocumentId: saleId,
          ),
        );
        movementIds.add(movement.id);
        final cost = await _inventoryValuationRepository?.recordSale(
          productId: item.productId,
          quantityKg: item.quantityKg,
          sourceDocumentId: saleId,
          effectiveDate: now,
          createdByUserId: draft.createdByUserId.trim(),
        );
        costedItems.add(cost == null
            ? item
            : item.copyWithCostSnapshot(
                valuationEventId: cost.valuationEventId,
                unitCostMicrosQirshPerKg: cost.unitCostMicrosQirshPerKg,
                costOfGoodsSoldQirsh: cost.costOfGoodsSoldQirsh,
                inventoryQuantityBeforeKg: cost.inventoryQuantityBeforeKg,
                inventoryQuantityAfterKg: cost.inventoryQuantityAfterKg,
                inventoryValueBeforeQirsh: cost.inventoryValueBeforeQirsh,
                inventoryValueAfterQirsh: cost.inventoryValueAfterQirsh,
                costAllocationResidualNumerator:
                    cost.allocationResidualNumerator,
                costAllocationResidualDenominator:
                    cost.allocationResidualDenominator,
              ));
      }

      final paidAmountQirsh = _resolvePaidAmount(draft, totalQirsh);
      final paymentAllocations = _resolvePaymentAllocations(
        draft,
        paidAmountQirsh,
      );
      final sale = SaleRecord(
        id: saleId,
        productId: items.first.productId,
        quantityKg: items.first.quantityKg,
        salePriceQirshPerKg: items.first.salePriceQirshPerKg,
        totalQirsh: totalQirsh,
        createdByUserId: draft.createdByUserId.trim(),
        createdByUserName: _normalizedOptionalText(draft.createdByUserName),
        createdAt: now,
        stockMovementId: movementIds.first,
        paymentMode: draft.paymentMode,
        customerId: customerId,
        notes: _normalizedOptionalText(draft.notes),
        items: costedItems,
        paidAmountQirsh: paidAmountQirsh,
        financialAccountId: paymentAllocations.length == 1
            ? paymentAllocations.single.financialAccountId
            : null,
        paymentMethod: paymentAllocations.length == 1
            ? paymentAllocations.single.paymentMethod
            : null,
        paymentAllocations: paymentAllocations,
        operationRequestId: operationRequestId,
      );

      if (!sale.hasValidId) {
        throw StateError('Sale id is required.');
      }
      if (sale.stockMovementId.trim().isEmpty) {
        throw StateError('Sale stock movement id is required.');
      }

      _sales.add(sale);
      if (operationRequestId != null) {
        _operationRequestIds[operationRequestId] = sale.id;
      }
      return sale;
    });
  }

  @override
  Future<SaleRecord> cancelSale({
    required String saleId,
    required String cancelledByUserId,
    required String cancellationReason,
  }) async {
    final saleIndex = _sales.indexWhere((sale) => sale.id == saleId);
    if (saleIndex < 0) {
      throw StateError('Sale was not found.');
    }

    final sale = _sales[saleIndex];
    if (sale.isCancelled) {
      return sale;
    }
    final userId = cancelledByUserId.trim();
    if (userId.isEmpty) {
      throw ArgumentError.value(
        cancelledByUserId,
        'cancelledByUserId',
        'Cancelled by user id is required.',
      );
    }
    final reason = _normalizedOptionalText(cancellationReason);
    if (reason == null) {
      throw ArgumentError.value(
        cancellationReason,
        'cancellationReason',
        'Cancellation reason is required.',
      );
    }

    final items = sale.items.isNotEmpty
        ? sale.items
        : [
            SaleLineItem(
              productId: sale.productId,
              quantityKg: sale.quantityKg,
              salePriceQirshPerKg: sale.salePriceQirshPerKg,
              lineTotalQirsh: sale.totalQirsh,
            ),
          ];

    final cancelledAt = DateTime.now();
    await _financialAccountRepository?.ensureDateIsOpen(cancelledAt);
    final snapshots = <SnapshotHolder>[createTransactionSnapshot()];
    snapshots.add(_requiredSnapshot(_inventoryRepository, 'inventory'));
    if (_inventoryValuationRepository != null) {
      snapshots.add(_requiredSnapshot(
          _inventoryValuationRepository, 'inventory valuation'));
    }
    return RepositoryTransaction.execute(snapshots, () async {
      final reversalIds = <String>[];
      for (final item in items) {
        final reversal = await _inventoryRepository.createMovement(
          StockMovementDraft(
            productId: item.productId,
            movementType: StockMovementType.saleCancellation,
            quantityKg: item.quantityKg,
            createdByUserId: userId,
            note:
                '\u0625\u0644\u063a\u0627\u0621 \u0628\u064a\u0639 ${sale.id}: $reason',
            reversedMovementId: sale.stockMovementId,
            originalDocumentId: sale.id,
          ),
        );
        reversalIds.add(reversal.id);
        if (item.valuationEventId != null) {
          await _inventoryValuationRepository?.reverseSale(
            originalValuationEventId: item.valuationEventId!,
            sourceDocumentId: sale.id,
            effectiveDate: cancelledAt,
            createdByUserId: userId,
            reason: reason,
          );
        }
      }

      final cancelled = sale.copyWith(
        cancellation: CancellationMetadata(
          cancelledAt: cancelledAt,
          cancelledByUserId: userId,
          cancellationReason: reason,
          originalDocumentId: sale.id,
          reversalMovementIds: reversalIds,
        ),
      );
      _sales[saleIndex] = cancelled;
      return cancelled;
    });
  }

  @override
  Future<List<SaleRecord>> listSales() async {
    return List<SaleRecord>.unmodifiable(_sales);
  }

  @override
  Future<void> restoreSalesIntoEmpty(List<SaleRecord> sales) async {
    if (_sales.isNotEmpty) {
      throw StateError('Sales repository is not empty.');
    }
    _validateUniqueRestoredSales(sales);
    final requestIds = <String>{};
    for (final sale in sales) {
      final requestId = _normalizedOptionalText(sale.operationRequestId);
      if (requestId != null && !requestIds.add(requestId)) {
        throw StateError('Duplicate sale operation request id.');
      }
    }
    _sales.addAll(sales);
    for (final sale in sales) {
      final requestId = _normalizedOptionalText(sale.operationRequestId);
      if (requestId != null) _operationRequestIds[requestId] = sale.id;
    }
  }

  @override
  Future<void> clearForOwnerDataWipe() async {
    _sales.clear();
    _operationRequestIds.clear();
    _generatedIdCounter = 0;
  }

  @override
  SnapshotHolder createTransactionSnapshot() =>
      ObjectStateSnapshot<(List<SaleRecord>, Map<String, String>, int)>(
        captureState: () => (
          List<SaleRecord>.from(_sales),
          Map<String, String>.from(_operationRequestIds),
          _generatedIdCounter,
        ),
        restoreState: (state) {
          _sales
            ..clear()
            ..addAll(state.$1);
          _operationRequestIds
            ..clear()
            ..addAll(state.$2);
          _generatedIdCounter = state.$3;
        },
      );

  SnapshotHolder _requiredSnapshot(Object repository, String name) {
    if (repository is! TransactionSnapshotProvider) {
      throw StateError(
          'Sale $name repository cannot participate in a transaction.');
    }
    return repository.createTransactionSnapshot();
  }

  List<SaleLineItem> _buildItems(SaleDraft draft) {
    if (draft.items.isNotEmpty) {
      final merged = <String, SaleLineItemDraft>{};
      for (final item in draft.items) {
        if (item.quantityKg <= 0) {
          throw ArgumentError.value(
            item.quantityKg,
            'quantityKg',
            'Quantity must be positive.',
          );
        }
        if (item.salePriceQirshPerKg <= 0) {
          throw ArgumentError.value(
            item.salePriceQirshPerKg,
            'salePriceQirshPerKg',
            'Sale price must be positive.',
          );
        }
        if (merged.containsKey(item.productId)) {
          final existing = merged[item.productId]!;
          merged[item.productId] = SaleLineItemDraft(
            productId: item.productId,
            quantityKg: existing.quantityKg + item.quantityKg,
            salePriceQirshPerKg: item.salePriceQirshPerKg,
          );
        } else {
          merged[item.productId] = item;
        }
      }
      return merged.values
          .map((d) => SaleLineItem(
                productId: d.productId,
                quantityKg: d.quantityKg,
                salePriceQirshPerKg: d.salePriceQirshPerKg,
                lineTotalQirsh: _safeTotalQirsh(
                  quantityKg: d.quantityKg,
                  salePriceQirshPerKg: d.salePriceQirshPerKg,
                ),
              ))
          .toList(growable: false);
    }
    return [
      SaleLineItem(
        productId: draft.productId,
        quantityKg: draft.quantityKg,
        salePriceQirshPerKg: draft.salePriceQirshPerKg,
        lineTotalQirsh: _safeTotalQirsh(
          quantityKg: draft.quantityKg,
          salePriceQirshPerKg: draft.salePriceQirshPerKg,
        ),
      ),
    ];
  }

  int _computeTotal(List<SaleLineItem> items) {
    var total = 0;
    for (final item in items) {
      total += item.lineTotalQirsh;
    }
    return total;
  }

  int _resolvePaidAmount(SaleDraft draft, int totalQirsh) {
    if (draft.paidAmountQirsh != null) {
      final paid = draft.paidAmountQirsh!;
      if (paid < 0 || paid > totalQirsh) {
        throw ArgumentError.value(
          paid,
          'paidAmountQirsh',
          'Paid amount must be between 0 and total invoice amount.',
        );
      }
      return paid;
    }
    if (draft.paymentMode == SalePaymentMode.credit) {
      return 0;
    }
    if (draft.paymentMode == SalePaymentMode.partial) {
      throw ArgumentError.value(
        null,
        'paidAmountQirsh',
        'Partial payment requires a paid amount.',
      );
    }
    return totalQirsh;
  }

  List<SalePaymentAllocation> _resolvePaymentAllocations(
    SaleDraft draft,
    int paidAmountQirsh,
  ) {
    final explicit = draft.paymentAllocations;
    if (explicit.isEmpty) {
      final accountId = _normalizedOptionalText(draft.financialAccountId);
      if (accountId == null) return const [];
      if (draft.paymentMode == SalePaymentMode.credit || paidAmountQirsh <= 0) {
        return const [];
      }
      final paymentMethod = draft.paymentMethod;
      if (paymentMethod == null) {
        throw ArgumentError.value(
          paymentMethod,
          'paymentMethod',
          'A payment method is required when a financial account is selected.',
        );
      }
      return [
        SalePaymentAllocation(
          financialAccountId: accountId,
          amountQirsh: paidAmountQirsh,
          paymentMethod: paymentMethod,
        ),
      ];
    }

    if (draft.paymentMode == SalePaymentMode.credit) {
      throw ArgumentError.value(
        explicit,
        'paymentAllocations',
        'Credit sales cannot have payment allocations.',
      );
    }
    if (explicit.length > 5) {
      throw ArgumentError.value(
        explicit,
        'paymentAllocations',
        'At most five payment allocations are allowed.',
      );
    }

    var total = 0;
    final accountIds = <String>{};
    final normalized = <SalePaymentAllocation>[];
    for (final allocation in explicit) {
      final accountId = allocation.financialAccountId.trim();
      if (accountId.isEmpty || allocation.amountQirsh <= 0) {
        throw ArgumentError.value(
          allocation,
          'paymentAllocations',
          'Each payment allocation needs an account and a positive amount.',
        );
      }
      if (!accountIds.add(accountId)) {
        throw ArgumentError.value(
          allocation.financialAccountId,
          'paymentAllocations',
          'A financial account can appear only once per sale payment.',
        );
      }
      if (total > _maxSafeTotalQirsh - allocation.amountQirsh) {
        throw ArgumentError.value(
          allocation.amountQirsh,
          'paymentAllocations',
          'Payment allocation total is too large.',
        );
      }
      total += allocation.amountQirsh;
      normalized.add(SalePaymentAllocation(
        financialAccountId: accountId,
        amountQirsh: allocation.amountQirsh,
        paymentMethod: allocation.paymentMethod,
      ));
    }
    if (total != paidAmountQirsh) {
      throw ArgumentError.value(
        explicit,
        'paymentAllocations',
        'Payment allocation total must equal the paid invoice amount.',
      );
    }
    return List<SalePaymentAllocation>.unmodifiable(normalized);
  }

  Future<Map<String, ProductCatalogReadModel>> _validateAllProducts(
    List<SaleLineItem> items,
  ) async {
    final products = <String, ProductCatalogReadModel>{};
    for (final item in items) {
      final product = await _validateProduct(item.productId);
      products[item.productId] = product;
    }
    return products;
  }

  void _validateAllMinimumPrices(
    List<SaleLineItem> items,
    Map<String, ProductCatalogReadModel> products,
  ) {
    for (final item in items) {
      final product = products[item.productId]!;
      final minimumPrice = product.minimumSalePricePiastersPerKg;
      if (minimumPrice == null) continue;
      if (item.salePriceQirshPerKg < minimumPrice) {
        throw MinimumSalePriceViolation(
          productId: product.id,
          minimumSalePricePiastersPerKg: minimumPrice,
          actualSalePricePiastersPerKg: item.salePriceQirshPerKg,
        );
      }
    }
  }

  Future<StateError?> _checkAllStock(List<SaleLineItem> items) async {
    for (final item in items) {
      final currentStock = await _inventoryRepository.currentStockKg(
        item.productId,
      );
      if (item.quantityKg > currentStock) {
        return StateError(
            '\u0643\u0645\u064a\u0629 \u063a\u064a\u0631 \u0645\u062a\u0648\u0641\u0631\u0629 \u0644\u0623\u062d\u062f \u0627\u0644\u0623\u0635\u0646\u0627\u0641.');
      }
    }
    return null;
  }

  Future<ProductCatalogReadModel> _validateProduct(String productId) async {
    if (productId.trim().isEmpty) {
      throw ArgumentError.value(
        productId,
        'productId',
        'Product id is required.',
      );
    }

    final products = await _productCatalogReadRepository.listProductCatalog(
      includeInactive: true,
    );
    for (final product in products) {
      if (product.id == productId) {
        if (!product.isActive) {
          throw StateError(
            '\u0635\u0646\u0641 \u063a\u064a\u0631 \u0646\u0634\u0637 \u0644\u0627 \u064a\u0645\u0643\u0646 \u0628\u064a\u0639\u0647.',
          );
        }

        return product;
      }
    }

    throw StateError(
      '\u0627\u0644\u0635\u0646\u0641 \u063a\u064a\u0631 \u0645\u0648\u062c\u0648\u062f.',
    );
  }

  void _validateDraft(SaleDraft draft) {
    if (draft.createdByUserId.trim().isEmpty) {
      throw ArgumentError.value(
        draft.createdByUserId,
        'createdByUserId',
        'Created by user id is required.',
      );
    }
    if (_normalizedOptionalText(draft.customerId) == null) {
      throw ArgumentError.value(
        draft.customerId,
        'customerId',
        '\u0643\u0644 \u0641\u0627\u062a\u0648\u0631\u0629 \u0628\u064a\u0639 \u062a\u062a\u0637\u0644\u0628 \u0639\u0645\u064a\u0644\u0627 \u0645\u0633\u062c\u0644\u0627.',
      );
    }
    if (draft.items.isNotEmpty) {
      for (final item in draft.items) {
        if (item.quantityKg <= 0) {
          throw ArgumentError.value(
            item.quantityKg,
            'quantityKg',
            'Quantity must be positive.',
          );
        }
        if (item.salePriceQirshPerKg <= 0) {
          throw ArgumentError.value(
            item.salePriceQirshPerKg,
            'salePriceQirshPerKg',
            'Sale price must be positive.',
          );
        }
      }
    } else {
      if (draft.quantityKg <= 0) {
        throw ArgumentError.value(
          draft.quantityKg,
          'quantityKg',
          'Quantity must be positive.',
        );
      }
      if (draft.salePriceQirshPerKg <= 0) {
        throw ArgumentError.value(
          draft.salePriceQirshPerKg,
          'salePriceQirshPerKg',
          'Sale price must be positive.',
        );
      }
    }
  }

  void _validateUniqueRestoredSales(List<SaleRecord> sales) {
    final ids = <String>{};
    for (final sale in sales) {
      if (!sale.hasValidId || !ids.add(sale.id)) {
        throw StateError('Invalid sale id.');
      }
      if (sale.productId.trim().isEmpty ||
          sale.quantityKg <= 0 ||
          sale.salePriceQirshPerKg <= 0 ||
          sale.totalQirsh <= 0 ||
          sale.createdByUserId.trim().isEmpty ||
          sale.stockMovementId.trim().isEmpty) {
        throw StateError('Invalid sale data.');
      }
      if (sale.items.isNotEmpty) {
        var computedTotal = 0;
        for (final item in sale.items) {
          if (item.productId.trim().isEmpty ||
              item.quantityKg <= 0 ||
              item.salePriceQirshPerKg <= 0 ||
              item.lineTotalQirsh <= 0) {
            throw StateError('Invalid sale item data.');
          }
          computedTotal += item.lineTotalQirsh;
        }
        if (computedTotal != sale.totalQirsh) {
          throw StateError('Sale total does not match items total.');
        }
      } else {
        if (sale.totalQirsh != sale.quantityKg * sale.salePriceQirshPerKg) {
          throw StateError('Invalid sale data.');
        }
      }
      var allocationTotal = 0;
      final allocationAccountIds = <String>{};
      for (final allocation in sale.paymentAllocations) {
        if (allocation.financialAccountId.trim().isEmpty ||
            allocation.amountQirsh <= 0 ||
            !allocationAccountIds.add(allocation.financialAccountId)) {
          throw StateError('Invalid sale payment allocation.');
        }
        allocationTotal += allocation.amountQirsh;
      }
      if (allocationTotal != 0 &&
          allocationTotal != sale.effectivePaidAmountQirsh) {
        throw StateError('Sale payment allocations do not match paid amount.');
      }
    }
  }

  int _safeTotalQirsh({
    required int quantityKg,
    required int salePriceQirshPerKg,
  }) {
    if (quantityKg > _maxSafeTotalQirsh ~/ salePriceQirshPerKg) {
      throw ArgumentError.value(
        quantityKg,
        'quantityKg',
        'Sale total is too large.',
      );
    }

    final total = quantityKg * salePriceQirshPerKg;
    if (total <= 0) {
      throw ArgumentError.value(total, 'totalQirsh', 'Sale total is invalid.');
    }

    return total;
  }

  String _generateSaleId(DateTime now) {
    _generatedIdCounter++;
    return 'sal-${now.microsecondsSinceEpoch}-$_generatedIdCounter';
  }

  String? _normalizedOptionalText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}
