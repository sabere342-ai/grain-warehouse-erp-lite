import 'package:drift/drift.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;

class DriftInventoryRepository implements DurableInventoryRepository {
  DriftInventoryRepository(
    this._database, {
    required ProductRepository productRepository,
    required ProductCatalogReadRepository productCatalogReadRepository,
  })  : _productRepository = productRepository,
        _productCatalogReadRepository = productCatalogReadRepository;

  static const _sequenceKey = 'inventory_movements';
  final db.FoundationDatabase _database;
  final ProductRepository _productRepository;
  final ProductCatalogReadRepository _productCatalogReadRepository;

  @override
  Future<StockMovement> createMovement(StockMovementDraft draft) async {
    return _database.transaction(() async {
      final product = await _validateDraftAndLoadProduct(draft);
      if (draft.movementType == StockMovementType.openingBalance &&
          await hasOpeningBalance(product.id)) {
        throw StateError('Opening balance already exists for this product.');
      }
      final currentStock = await currentStockKg(product.id);
      if (!draft.movementType.increasesStock &&
          draft.quantityKg > currentStock) {
        throw StateError('Stock cannot go below zero.');
      }
      final sequence = await _takeSequence();
      final now = DateTime.now();
      final movement = StockMovement(
        id: 'stk-${now.microsecondsSinceEpoch}-$sequence',
        productId: product.id,
        movementType: draft.movementType,
        quantityKg: draft.quantityKg,
        createdByUserId: draft.createdByUserId.trim(),
        note: _optional(draft.note),
        createdAt: now,
        reversedMovementId: _optional(draft.reversedMovementId),
        originalDocumentId: _optional(draft.originalDocumentId),
      );
      await _database
          .into(_database.inventoryMovements)
          .insert(_companion(movement));
      return movement;
    });
  }

  @override
  Future<List<StockMovement>> listMovementsByProduct(String productId) async {
    final query = _database.select(_database.inventoryMovements)
      ..where((row) => row.productId.equals(productId))
      ..orderBy([
        (row) => OrderingTerm.asc(row.createdAt),
        (row) => OrderingTerm.asc(row.id),
      ]);
    return (await query.get()).map(_toDomain).toList(growable: false);
  }

  @override
  Future<List<StockMovement>> listAllMovements() async {
    final query = _database.select(_database.inventoryMovements)
      ..orderBy([
        (row) => OrderingTerm.asc(row.createdAt),
        (row) => OrderingTerm.asc(row.id),
      ]);
    return (await query.get()).map(_toDomain).toList(growable: false);
  }

  @override
  Future<int> currentStockKg(String productId) async {
    if (await _findProductById(productId) == null) {
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
    if (await _findProductById(productId) == null) {
      throw StateError('Product was not found.');
    }
    final rows = await (_database.select(_database.inventoryMovements)
          ..where((row) =>
              row.productId.equals(productId) &
              row.movementType.equals(StockMovementType.openingBalance.name) &
              row.isVoided.equals(false)))
        .get();
    return rows.isNotEmpty;
  }

  @override
  Future<Map<String, int>> allProductBalancesKg({
    bool activeProductsOnly = false,
  }) async {
    final products = await _productCatalogReadRepository.listProductCatalog(
      includeInactive: !activeProductsOnly,
    );
    final balances = <String, int>{};
    for (final product in products) {
      final movements = await listMovementsByProduct(product.id);
      balances[product.id] = movements.fold<int>(
        0,
        (total, movement) => total + movement.signedQuantityKg,
      );
    }
    return Map<String, int>.unmodifiable(balances);
  }

  @override
  Future<void> restoreMovementsIntoEmpty(List<StockMovement> movements) async {
    await _database.transaction(() async {
      if (await _database.inventoryMovements.count().getSingle() != 0) {
        throw StateError('Inventory repository is not empty.');
      }
      _validateRestored(movements);
      for (final movement in movements) {
        await _database
            .into(_database.inventoryMovements)
            .insert(_companion(movement));
      }
      var maximum = 0;
      for (final movement in movements) {
        final value = int.tryParse(movement.id.split('-').last) ?? 0;
        if (value > maximum) maximum = value;
      }
      await _database
          .into(_database.repositorySequences)
          .insertOnConflictUpdate(
            db.RepositorySequencesCompanion.insert(
              repository: _sequenceKey,
              nextValue: maximum + 1,
            ),
          );
    });
  }

  @override
  Future<void> clearForOwnerDataWipe() => _database.transaction(() async {
        await _database.delete(_database.inventoryMovements).go();
        await (_database.delete(_database.repositorySequences)
              ..where((row) => row.repository.equals(_sequenceKey)))
            .go();
      });

  @override
  SnapshotHolder createTransactionSnapshot() => _DriftInventorySnapshot(this);

  Future<int> _takeSequence() async {
    final row = await (_database.select(_database.repositorySequences)
          ..where((r) => r.repository.equals(_sequenceKey)))
        .getSingleOrNull();
    final value = row?.nextValue ?? 1;
    await _database.into(_database.repositorySequences).insertOnConflictUpdate(
          db.RepositorySequencesCompanion.insert(
            repository: _sequenceKey,
            nextValue: value + 1,
          ),
        );
    return value;
  }

  Future<Product> _validateDraftAndLoadProduct(StockMovementDraft draft) async {
    if (draft.productId.trim().isEmpty) {
      throw ArgumentError.value(
          draft.productId, 'productId', 'Product id is required.');
    }
    if (draft.createdByUserId.trim().isEmpty) {
      throw ArgumentError.value(draft.createdByUserId, 'createdByUserId',
          'Created by user id is required.');
    }
    if (draft.quantityKg <= 0) {
      throw ArgumentError.value(
          draft.quantityKg, 'quantityKg', 'Quantity must be positive.');
    }
    final product = await _findProductById(draft.productId);
    if (product == null) throw StateError('Product was not found.');
    if (!product.isActive) {
      throw StateError('Inactive product cannot accept stock movements.');
    }
    return product;
  }

  Future<Product?> _findProductById(String id) async {
    final products =
        await _productRepository.listProducts(includeInactive: true);
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  db.InventoryMovementsCompanion _companion(StockMovement movement) =>
      db.InventoryMovementsCompanion(
        id: Value(movement.id),
        productId: Value(movement.productId),
        movementType: Value(movement.movementType.name),
        quantityKg: Value(movement.quantityKg),
        createdByUserId: Value(movement.createdByUserId),
        createdAt: Value(movement.createdAt),
        note: Value(movement.note),
        isVoided: Value(movement.isVoided),
        reversedMovementId: Value(movement.reversedMovementId),
        originalDocumentId: Value(movement.originalDocumentId),
      );

  StockMovement _toDomain(db.InventoryMovement row) => StockMovement(
        id: row.id,
        productId: row.productId,
        movementType: StockMovementType.values.byName(row.movementType),
        quantityKg: row.quantityKg,
        createdByUserId: row.createdByUserId,
        createdAt: row.createdAt,
        note: row.note,
        isVoided: row.isVoided,
        reversedMovementId: row.reversedMovementId,
        originalDocumentId: row.originalDocumentId,
      );

  void _validateRestored(List<StockMovement> movements) {
    final ids = <String>{};
    for (final movement in movements) {
      if (!movement.hasValidId) throw StateError('Movement id is required.');
      if (!ids.add(movement.id)) throw StateError('Duplicate movement id.');
      if (movement.productId.trim().isEmpty ||
          movement.createdByUserId.trim().isEmpty ||
          movement.quantityKg <= 0) {
        throw StateError('Invalid movement data.');
      }
    }
  }

  String? _optional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

class _DriftInventorySnapshot extends SnapshotHolder {
  _DriftInventorySnapshot(this.repository);
  final DriftInventoryRepository repository;
  List<StockMovement>? movements;

  @override
  Future<void> capture() async {
    movements = await repository.listAllMovements();
  }

  @override
  Future<void> rollback() async {
    final state = movements;
    if (state == null) return;
    await repository.clearForOwnerDataWipe();
    await repository.restoreMovementsIntoEmpty(state);
  }
}
