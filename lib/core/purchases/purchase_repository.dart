import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

abstract class PurchaseRepository {
  Future<PurchaseIntake> createPurchaseIntake(PurchaseIntakeDraft draft);

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
      notes: _normalizedOptionalText(draft.notes),
    );

    if (!intake.hasValidId) {
      throw StateError('Purchase intake id is required.');
    }

    await _inventoryRepository.createMovement(
      StockMovementDraft(
        productId: intake.productId,
        movementType: StockMovementType.purchaseIntake,
        quantityKg: intake.quantityKg,
        createdByUserId: intake.createdByUserId,
        note: 'Purchase intake ${intake.id}',
      ),
    );

    _intakes.add(intake);
    return intake;
  }

  @override
  Future<List<PurchaseIntake>> listPurchaseIntakes() async {
    return List<PurchaseIntake>.unmodifiable(_intakes);
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

    final products = await _productRepository.listProducts(includeInactive: true);
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
