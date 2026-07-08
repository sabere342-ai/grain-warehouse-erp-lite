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
    final product = await _validateProduct(draft.productId);
    _validateDraft(draft);
    _validateMinimumSalePrice(product: product, draft: draft);

    final now = DateTime.now();
    final saleId = _generateSaleId(now);
    final totalQirsh = _safeTotalQirsh(
      quantityKg: draft.quantityKg,
      salePriceQirshPerKg: draft.salePriceQirshPerKg,
    );

    final currentStock = await _inventoryRepository.currentStockKg(product.id);
    if (draft.quantityKg > currentStock) {
      throw StateError('Insufficient stock.');
    }

    final movement = await _inventoryRepository.createMovement(
      StockMovementDraft(
        productId: product.id,
        movementType: StockMovementType.sale,
        quantityKg: draft.quantityKg,
        createdByUserId: draft.createdByUserId.trim(),
        note: 'بيع $saleId',
        originalDocumentId: saleId,
      ),
    );

    final sale = SaleRecord(
      id: saleId,
      productId: product.id,
      quantityKg: draft.quantityKg,
      salePriceQirshPerKg: draft.salePriceQirshPerKg,
      totalQirsh: totalQirsh,
      createdByUserId: draft.createdByUserId.trim(),
      createdByUserName: _normalizedOptionalText(draft.createdByUserName),
      createdAt: now,
      stockMovementId: movement.id,
      paymentMode: draft.paymentMode,
      customerId: _normalizedOptionalText(draft.customerId),
      notes: _normalizedOptionalText(draft.notes),
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

    final reversal = await _inventoryRepository.createMovement(
      StockMovementDraft(
        productId: sale.productId,
        movementType: StockMovementType.saleCancellation,
        quantityKg: sale.quantityKg,
        createdByUserId: userId,
        note: 'إلغاء بيع ${sale.id}: $reason',
        reversedMovementId: sale.stockMovementId,
        originalDocumentId: sale.id,
      ),
    );
    final cancelled = sale.copyWith(
      cancellation: CancellationMetadata(
        cancelledAt: DateTime.now(),
        cancelledByUserId: userId,
        cancellationReason: reason,
        originalDocumentId: sale.id,
        reversalMovementIds: [reversal.id],
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
          throw StateError('Inactive product cannot be sold.');
        }

        return product;
      }
    }

    throw StateError('Product was not found.');
  }

  void _validateDraft(SaleDraft draft) {
    if (draft.createdByUserId.trim().isEmpty) {
      throw ArgumentError.value(
        draft.createdByUserId,
        'createdByUserId',
        'Created by user id is required.',
      );
    }
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
    if (draft.paymentMode == SalePaymentMode.credit &&
        _normalizedOptionalText(draft.customerId) == null) {
      throw ArgumentError.value(
        draft.customerId,
        'customerId',
        'Credit sale requires customer id.',
      );
    }
  }

  void _validateMinimumSalePrice({
    required Product product,
    required SaleDraft draft,
  }) {
    final minimumPrice = product.minimumSalePricePiastersPerKg;
    if (minimumPrice == null) {
      return;
    }
    if (draft.salePriceQirshPerKg < minimumPrice) {
      throw MinimumSalePriceViolation(
        productId: product.id,
        minimumSalePricePiastersPerKg: minimumPrice,
        actualSalePricePiastersPerKg: draft.salePriceQirshPerKg,
      );
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
          sale.stockMovementId.trim().isEmpty ||
          (sale.paymentMode == SalePaymentMode.credit &&
              _normalizedOptionalText(sale.customerId) == null)) {
        throw StateError('Invalid sale data.');
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
