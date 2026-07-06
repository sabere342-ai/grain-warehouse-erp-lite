import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/cancellation_metadata.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

abstract class PurchaseRepository {
  Future<PurchaseIntake> createPurchaseIntake(PurchaseIntakeDraft draft);

  Future<PurchaseIntake> cancelPurchaseIntake({
    required String purchaseIntakeId,
    required String cancelledByUserId,
    required String cancellationReason,
  });

  Future<List<PurchaseIntake>> listPurchaseIntakes();
}

class LocalPurchaseRepository implements PurchaseRepository {
  LocalPurchaseRepository({
    required SupplierRepository supplierRepository,
    required ProductRepository productRepository,
    required InventoryRepository inventoryRepository,
  })  : _supplierRepository = supplierRepository,
        _productRepository = productRepository,
        _inventoryRepository = inventoryRepository;

  final SupplierRepository _supplierRepository;
  final ProductRepository _productRepository;
  final InventoryRepository _inventoryRepository;
  final List<PurchaseIntake> _intakes = [];
  int _generatedIdCounter = 0;

  @override
  Future<PurchaseIntake> createPurchaseIntake(
    PurchaseIntakeDraft draft,
  ) async {
    final supplier = await _validateSupplier(draft.supplierId);
    final product = await _validateProduct(draft.productId);
    _validateDraft(draft);

    final now = DateTime.now();
    final intake = PurchaseIntake(
      id: _generatePurchaseIntakeId(now),
      supplierId: supplier.id,
      productId: product.id,
      quantityKg: draft.quantityKg,
      entryUnit: draft.entryUnit,
      unitPricePiastersPerKg: draft.unitPricePiastersPerKg,
      totalAmountPiasters: draft.totalAmountPiasters,
      createdByUserId: draft.createdByUserId.trim(),
      createdAt: now,
      stockMovementId: 'pending',
      notes: _normalizedOptionalText(draft.notes),
    );

    if (!intake.hasValidId) {
      throw StateError('Purchase intake id is required.');
    }

    final movement = await _inventoryRepository.createMovement(
      StockMovementDraft(
        productId: intake.productId,
        movementType: StockMovementType.purchaseIntake,
        quantityKg: intake.quantityKg,
        createdByUserId: intake.createdByUserId,
        note: 'Purchase intake ${intake.id}',
        originalDocumentId: intake.id,
      ),
    );

    final postedIntake = intake.copyWith(stockMovementId: movement.id);
    _intakes.add(postedIntake);
    return postedIntake;
  }

  @override
  Future<PurchaseIntake> cancelPurchaseIntake({
    required String purchaseIntakeId,
    required String cancelledByUserId,
    required String cancellationReason,
  }) async {
    final intakeIndex =
        _intakes.indexWhere((intake) => intake.id == purchaseIntakeId);
    if (intakeIndex < 0) {
      throw StateError('Purchase intake was not found.');
    }

    final intake = _intakes[intakeIndex];
    if (intake.isCancelled) {
      return intake;
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
    await _validatePurchaseCancellationStock(intake);

    final reversal = await _inventoryRepository.createMovement(
      StockMovementDraft(
        productId: intake.productId,
        movementType: StockMovementType.purchaseCancellation,
        quantityKg: intake.quantityKg,
        createdByUserId: userId,
        note: 'Cancel purchase intake ${intake.id}: $reason',
        reversedMovementId: intake.stockMovementId,
        originalDocumentId: intake.id,
      ),
    );
    final cancelled = intake.copyWith(
      cancellation: CancellationMetadata(
        cancelledAt: DateTime.now(),
        cancelledByUserId: userId,
        cancellationReason: reason,
        originalDocumentId: intake.id,
        reversalMovementIds: [reversal.id],
      ),
    );
    _intakes[intakeIndex] = cancelled;
    return cancelled;
  }

  Future<void> _validatePurchaseCancellationStock(PurchaseIntake intake) async {
    final currentStock = await _inventoryRepository.currentStockKg(
      intake.productId,
    );
    if (currentStock < intake.quantityKg) {
      throw StateError(
        'Purchase cancellation would make stock negative for product '
        '${intake.productId}.',
      );
    }
  }

  @override
  Future<List<PurchaseIntake>> listPurchaseIntakes() async {
    return List<PurchaseIntake>.unmodifiable(_intakes);
  }

  Future<void> restorePurchaseIntakesIntoEmpty(
    List<PurchaseIntake> intakes,
  ) async {
    if (_intakes.isNotEmpty) {
      throw StateError('Purchase repository is not empty.');
    }
    _validateUniqueRestoredIntakes(intakes);
    _intakes.addAll(intakes);
  }

  Future<Supplier> _validateSupplier(String supplierId) async {
    if (supplierId.trim().isEmpty) {
      throw ArgumentError.value(
        supplierId,
        'supplierId',
        'Supplier id is required.',
      );
    }

    final suppliers =
        await _supplierRepository.listSuppliers(includeInactive: true);
    for (final supplier in suppliers) {
      if (supplier.id == supplierId) {
        if (!supplier.isActive) {
          throw StateError('Inactive supplier cannot be used.');
        }

        return supplier;
      }
    }

    throw StateError('Supplier was not found.');
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
          throw StateError('Inactive product cannot be used.');
        }

        return product;
      }
    }

    throw StateError('Product was not found.');
  }

  void _validateDraft(PurchaseIntakeDraft draft) {
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
    if (draft.unitPricePiastersPerKg <= 0) {
      throw ArgumentError.value(
        draft.unitPricePiastersPerKg,
        'unitPricePiastersPerKg',
        'Unit price must be positive.',
      );
    }
  }

  void _validateUniqueRestoredIntakes(List<PurchaseIntake> intakes) {
    final ids = <String>{};
    for (final intake in intakes) {
      if (!intake.hasValidId || !ids.add(intake.id)) {
        throw StateError('Invalid purchase intake id.');
      }
      if (intake.supplierId.trim().isEmpty ||
          intake.productId.trim().isEmpty ||
          intake.quantityKg <= 0 ||
          intake.unitPricePiastersPerKg <= 0 ||
          intake.totalAmountPiasters <= 0 ||
          intake.createdByUserId.trim().isEmpty ||
          intake.stockMovementId.trim().isEmpty) {
        throw StateError('Invalid purchase intake data.');
      }
    }
  }

  String _generatePurchaseIntakeId(DateTime now) {
    _generatedIdCounter++;
    return 'pin-${now.microsecondsSinceEpoch}-$_generatedIdCounter';
  }

  String? _normalizedOptionalText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}
