import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/cancellation_metadata.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
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

class LocalSaleRepository implements SaleRepository {
  LocalSaleRepository({
    required ProductRepository productRepository,
    required InventoryRepository inventoryRepository,
  })  : _productRepository = productRepository,
        _inventoryRepository = inventoryRepository;

  static const int _maxSafeTotalQirsh = 9223372036854775807;

  final ProductRepository _productRepository;
  final InventoryRepository _inventoryRepository;
  final List<SaleRecord> _sales = [];
  int _generatedIdCounter = 0;

  @override
  Future<SaleRecord> createSale(SaleDraft draft) async {
    _validateDraft(draft);

    final items = _buildItems(draft);
    final totalQirsh = _computeTotal(items);

    final now = DateTime.now();
    final saleId = _generateSaleId(now);

    final customerId = _normalizedOptionalText(draft.customerId);

    final products = await _validateAllProducts(items);
    _validateAllMinimumPrices(items, products);

    final stockCheck = await _checkAllStock(items);
    if (stockCheck != null) {
      throw stockCheck;
    }

    final movementIds = <String>[];
    try {
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
      }
    } catch (_) {
      rethrow;
    }

    final paidAmountQirsh = _resolvePaidAmount(draft, totalQirsh);

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
      items: items,
      paidAmountQirsh: paidAmountQirsh,
    );

    if (!sale.hasValidId) {
      throw StateError('Sale id is required.');
    }
    if (sale.stockMovementId.trim().isEmpty) {
      throw StateError('Sale stock movement id is required.');
    }

    _sales.add(sale);
    return sale;
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

    final items = sale.items.isNotEmpty ? sale.items : [
      SaleLineItem(
        productId: sale.productId,
        quantityKg: sale.quantityKg,
        salePriceQirshPerKg: sale.salePriceQirshPerKg,
        lineTotalQirsh: sale.totalQirsh,
      ),
    ];

    final reversalIds = <String>[];
    for (final item in items) {
      final reversal = await _inventoryRepository.createMovement(
        StockMovementDraft(
          productId: item.productId,
          movementType: StockMovementType.saleCancellation,
          quantityKg: item.quantityKg,
          createdByUserId: userId,
          note: '\u0625\u0644\u063a\u0627\u0621 \u0628\u064a\u0639 ${sale.id}: $reason',
          reversedMovementId: sale.stockMovementId,
          originalDocumentId: sale.id,
        ),
      );
      reversalIds.add(reversal.id);
    }

    final cancelled = sale.copyWith(
      cancellation: CancellationMetadata(
        cancelledAt: DateTime.now(),
        cancelledByUserId: userId,
        cancellationReason: reason,
        originalDocumentId: sale.id,
        reversalMovementIds: reversalIds,
      ),
    );
    _sales[saleIndex] = cancelled;
    return cancelled;
  }

  @override
  Future<List<SaleRecord>> listSales() async {
    return List<SaleRecord>.unmodifiable(_sales);
  }

  Future<void> restoreSalesIntoEmpty(List<SaleRecord> sales) async {
    if (_sales.isNotEmpty) {
      throw StateError('Sales repository is not empty.');
    }
    _validateUniqueRestoredSales(sales);
    _sales.addAll(sales);
  }

  Future<void> clearForOwnerDataWipe() async {
    _sales.clear();
    _generatedIdCounter = 0;
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
      return merged.values.map((d) => SaleLineItem(
        productId: d.productId,
        quantityKg: d.quantityKg,
        salePriceQirshPerKg: d.salePriceQirshPerKg,
        lineTotalQirsh: _safeTotalQirsh(
          quantityKg: d.quantityKg,
          salePriceQirshPerKg: d.salePriceQirshPerKg,
        ),
      )).toList(growable: false);
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

  int? _resolvePaidAmount(SaleDraft draft, int totalQirsh) {
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

  Future<Map<String, Product>> _validateAllProducts(
    List<SaleLineItem> items,
  ) async {
    final products = <String, Product>{};
    for (final item in items) {
      final product = await _validateProduct(item.productId);
      products[item.productId] = product;
    }
    return products;
  }

  void _validateAllMinimumPrices(
    List<SaleLineItem> items,
    Map<String, Product> products,
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
        return StateError('\u0643\u0645\u064a\u0629 \u063a\u064a\u0631 \u0645\u062a\u0648\u0641\u0631\u0629 \u0644\u0623\u062d\u062f \u0627\u0644\u0623\u0635\u0646\u0627\u0641.');
      }
    }
    return null;
  }

  Future<Product> _validateProduct(String productId) async {
    if (productId.trim().isEmpty) {
      throw ArgumentError.value(
        productId,
        'productId',
        'Product id is required.',
      );
    }

    final products =
        await _productRepository.listProducts(includeInactive: true);
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
