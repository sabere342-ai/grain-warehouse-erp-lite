import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';

abstract class InventoryRepository {
  Future<StockMovement> createMovement(StockMovementDraft draft);

  Future<List<StockMovement>> listMovementsByProduct(String productId);

  Future<List<StockMovement>> listAllMovements();

  Future<int> currentStockKg(String productId);

  Future<bool> hasOpeningBalance(String productId);

  Future<Map<String, int>> allProductBalancesKg(
      {bool activeProductsOnly = false});
}

abstract class DurableInventoryRepository
    implements InventoryRepository, TransactionSnapshotProvider {
  Future<void> restoreMovementsIntoEmpty(List<StockMovement> movements);

  Future<void> clearForOwnerDataWipe();
}

class LocalInventoryRepository implements DurableInventoryRepository {
  LocalInventoryRepository({required ProductRepository productRepository})
      : _productRepository = productRepository;

  final ProductRepository _productRepository;
  final List<StockMovement> _movements = [];
  int _generatedIdCounter = 0;

  @override
  SnapshotHolder createTransactionSnapshot() {
    return ObjectStateSnapshot<(List<StockMovement>, int)>(
      captureState: () =>
          (List<StockMovement>.from(_movements), _generatedIdCounter),
      restoreState: (state) {
        _movements
          ..clear()
          ..addAll(state.$1);
        _generatedIdCounter = state.$2;
      },
    );
  }

  @override
  Future<StockMovement> createMovement(StockMovementDraft draft) async {
    final product = await _validateDraftAndLoadProduct(draft);
    if (draft.movementType == StockMovementType.openingBalance &&
        await hasOpeningBalance(product.id)) {
      throw StateError('Opening balance already exists for this product.');
    }

    final currentStock = await currentStockKg(product.id);
    if (!draft.movementType.increasesStock && draft.quantityKg > currentStock) {
      throw StateError('Stock cannot go below zero.');
    }

    final now = DateTime.now();
    final movement = StockMovement(
      id: _generateMovementId(now),
      productId: product.id,
      movementType: draft.movementType,
      quantityKg: draft.quantityKg,
      createdByUserId: draft.createdByUserId.trim(),
      note: _normalizedOptionalText(draft.note),
      createdAt: now,
      reversedMovementId: _normalizedOptionalText(draft.reversedMovementId),
      originalDocumentId: _normalizedOptionalText(draft.originalDocumentId),
    );
    if (!movement.hasValidId) {
      throw StateError('Movement id is required.');
    }

    _movements.add(movement);
    return movement;
  }

  @override
  Future<List<StockMovement>> listMovementsByProduct(String productId) async {
    return List<StockMovement>.unmodifiable(
      _movements.where((movement) => movement.productId == productId),
    );
  }

  @override
  Future<List<StockMovement>> listAllMovements() async {
    return List<StockMovement>.unmodifiable(_movements);
  }

  @override
  Future<int> currentStockKg(String productId) async {
    final product = await _findProductById(productId);
    if (product == null) {
      throw StateError('Product was not found.');
    }

    final movements = await listMovementsByProduct(productId);
    return movements.fold<int>(
      0,
      (total, movement) => total + movement.signedQuantityKg,
    );
  }

  @override
  Future<bool> hasOpeningBalance(String productId) async {
    final product = await _findProductById(productId);
    if (product == null) {
      throw StateError('Product was not found.');
    }

    return _movements.any(
      (movement) =>
          movement.productId == productId &&
          movement.movementType == StockMovementType.openingBalance &&
          !movement.isVoided,
    );
  }

  @override
  Future<Map<String, int>> allProductBalancesKg({
    bool activeProductsOnly = false,
  }) async {
    final products = await _productRepository.listProducts(
      includeInactive: !activeProductsOnly,
    );
    final balances = <String, int>{};
    for (final product in products) {
      balances[product.id] = await currentStockKg(product.id);
    }

    return Map<String, int>.unmodifiable(balances);
  }

  @override
  Future<void> restoreMovementsIntoEmpty(List<StockMovement> movements) async {
    if (_movements.isNotEmpty) {
      throw StateError('Inventory repository is not empty.');
    }
    _validateUniqueRestoredMovements(movements);
    _movements.addAll(movements);
  }

  @override
  Future<void> clearForOwnerDataWipe() async {
    _movements.clear();
    _generatedIdCounter = 0;
  }

  Future<Product> _validateDraftAndLoadProduct(StockMovementDraft draft) async {
    if (draft.productId.trim().isEmpty) {
      throw ArgumentError.value(
          draft.productId, 'productId', 'Product id is required.');
    }
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

    final product = await _findProductById(draft.productId);
    if (product == null) {
      throw StateError('Product was not found.');
    }
    if (!product.isActive) {
      throw StateError('Inactive product cannot accept stock movements.');
    }

    return product;
  }

  void _validateUniqueRestoredMovements(List<StockMovement> movements) {
    final ids = <String>{};
    for (final movement in movements) {
      if (!movement.hasValidId) {
        throw StateError('Movement id is required.');
      }
      if (!ids.add(movement.id)) {
        throw StateError('Duplicate movement id.');
      }
      if (movement.productId.trim().isEmpty ||
          movement.createdByUserId.trim().isEmpty ||
          movement.quantityKg <= 0) {
        throw StateError('Invalid movement data.');
      }
    }
  }

  Future<Product?> _findProductById(String productId) async {
    final products =
        await _productRepository.listProducts(includeInactive: true);
    for (final product in products) {
      if (product.id == productId) {
        return product;
      }
    }

    return null;
  }

  String _generateMovementId(DateTime now) {
    _generatedIdCounter++;
    return 'stk-${now.microsecondsSinceEpoch}-$_generatedIdCounter';
  }

  String? _normalizedOptionalText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}
