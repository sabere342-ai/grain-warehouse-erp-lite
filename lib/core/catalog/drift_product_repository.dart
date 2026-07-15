import 'package:drift/drift.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart' as domain;
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;

class DriftProductRepository implements ProductDataRepository {
  DriftProductRepository(this._database);

  final db.FoundationDatabase _database;
  static const _sequenceKey = 'products';

  @override
  Future<List<domain.Product>> listProducts(
      {bool includeInactive = true}) async {
    final query = _database.select(_database.products)
      ..orderBy([
        (row) => OrderingTerm.asc(row.createdAt),
        (row) => OrderingTerm.asc(row.id)
      ]);
    if (!includeInactive) query.where((row) => row.isActive.equals(true));
    return (await query.get()).map(_toDomain).toList(growable: false);
  }

  @override
  Future<domain.Product> createProduct(domain.ProductDraft draft) async {
    _validateDraft(draft);
    return _database.transaction(() async {
      await _ensureUnique(draft.name, draft.code);
      final sequence = await _takeSequence();
      final now = DateTime.now();
      final product = domain.Product(
        id: 'prd-${now.microsecondsSinceEpoch}-$sequence',
        name: draft.name.trim(),
        code: _optional(draft.code),
        unit: draft.unit,
        isActive: true,
        defaultSalePricePiastersPerKg: draft.defaultSalePricePiastersPerKg,
        minimumSalePricePiastersPerKg: draft.minimumSalePricePiastersPerKg,
        referenceCostPricePiastersPerKg: draft.referenceCostPricePiastersPerKg,
        notes: _optional(draft.notes),
        createdAt: now,
        updatedAt: now,
      );
      await _database.into(_database.products).insert(_companion(product));
      return product;
    });
  }

  @override
  Future<domain.Product> updateProduct(
      {required String productId, required domain.ProductDraft draft}) async {
    _validateDraft(draft);
    return _database.transaction(() async {
      final current = await _find(productId);
      await _ensureUnique(draft.name, draft.code, exceptId: productId);
      final updated = domain.Product(
        id: current.id,
        name: draft.name.trim(),
        code: _optional(draft.code),
        unit: draft.unit,
        isActive: current.isActive,
        defaultSalePricePiastersPerKg: draft.defaultSalePricePiastersPerKg,
        minimumSalePricePiastersPerKg: draft.minimumSalePricePiastersPerKg,
        referenceCostPricePiastersPerKg: draft.referenceCostPricePiastersPerKg,
        notes: _optional(draft.notes),
        createdAt: current.createdAt,
        updatedAt: DateTime.now(),
      );
      await (_database.update(_database.products)
            ..where((row) => row.id.equals(productId)))
          .write(_companion(updated));
      return updated;
    });
  }

  @override
  Future<domain.Product> setProductActive(
      {required String productId, required bool isActive}) async {
    final current = await _find(productId);
    final updated =
        current.copyWith(isActive: isActive, updatedAt: DateTime.now());
    await (_database.update(_database.products)
          ..where((row) => row.id.equals(productId)))
        .write(_companion(updated));
    return updated;
  }

  @override
  Future<void> restoreProductsIntoEmpty(List<domain.Product> products) async {
    await _database.transaction(() async {
      if (await _database.products.count().getSingle() != 0) {
        throw StateError('Products repository is not empty.');
      }
      _validateRestored(products);
      for (final product in products) {
        await _database.into(_database.products).insert(_companion(product));
      }
      var maximum = 0;
      for (final product in products) {
        final value = int.tryParse(product.id.split('-').last) ?? 0;
        if (value > maximum) maximum = value;
      }
      await _database
          .into(_database.repositorySequences)
          .insertOnConflictUpdate(db.RepositorySequencesCompanion.insert(
              repository: _sequenceKey, nextValue: maximum + 1));
    });
  }

  @override
  Future<void> clearForOwnerDataWipe() => _database.transaction(() async {
        await _database.delete(_database.products).go();
        await (_database.delete(_database.repositorySequences)
              ..where((row) => row.repository.equals(_sequenceKey)))
            .go();
      });

  @override
  SnapshotHolder createTransactionSnapshot() => _DriftProductSnapshot(this);

  Future<int> _takeSequence() async {
    final row = await (_database.select(_database.repositorySequences)
          ..where((r) => r.repository.equals(_sequenceKey)))
        .getSingleOrNull();
    final value = row?.nextValue ?? 1;
    await _database.into(_database.repositorySequences).insertOnConflictUpdate(
        db.RepositorySequencesCompanion.insert(
            repository: _sequenceKey, nextValue: value + 1));
    return value;
  }

  Future<domain.Product> _find(String id) async {
    final row = await (_database.select(_database.products)
          ..where((r) => r.id.equals(id)))
        .getSingleOrNull();
    if (row == null) {
      throw StateError('Product was not found.');
    }
    return _toDomain(row);
  }

  Future<void> _ensureUnique(String name, String? code,
      {String? exceptId}) async {
    final normalizedName = _key(name);
    final normalizedCode = _optional(code) == null ? null : _key(code!);
    final rows = await _database.select(_database.products).get();
    if (rows
        .any((r) => r.id != exceptId && r.normalizedName == normalizedName)) {
      throw StateError('Duplicate product name.');
    }
    if (normalizedCode != null &&
        rows.any(
            (r) => r.id != exceptId && r.normalizedCode == normalizedCode)) {
      throw StateError('Duplicate product code.');
    }
  }

  db.ProductsCompanion _companion(domain.Product p) => db.ProductsCompanion(
      id: Value(p.id),
      name: Value(p.name),
      normalizedName: Value(_key(p.name)),
      code: Value(p.code),
      normalizedCode: Value(p.code == null ? null : _key(p.code!)),
      unit: Value(p.unit.wireName),
      isActive: Value(p.isActive),
      defaultSalePricePiastersPerKg: Value(p.defaultSalePricePiastersPerKg),
      minimumSalePricePiastersPerKg: Value(p.minimumSalePricePiastersPerKg),
      referenceCostPricePiastersPerKg: Value(p.referenceCostPricePiastersPerKg),
      notes: Value(p.notes),
      createdAt: Value(p.createdAt),
      updatedAt: Value(p.updatedAt));

  domain.Product _toDomain(db.Product r) => domain.Product(
      id: r.id,
      name: r.name,
      code: r.code,
      unit: GrainUnit.fromWireName(r.unit),
      isActive: r.isActive,
      defaultSalePricePiastersPerKg: r.defaultSalePricePiastersPerKg,
      minimumSalePricePiastersPerKg: r.minimumSalePricePiastersPerKg,
      referenceCostPricePiastersPerKg: r.referenceCostPricePiastersPerKg,
      notes: r.notes,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt);

  void _validateDraft(domain.ProductDraft d) {
    if (d.name.trim().isEmpty) {
      throw ArgumentError.value(d.name, 'name', 'Product name is required.');
    }
    if (d.defaultSalePricePiastersPerKg != null &&
        d.defaultSalePricePiastersPerKg! <= 0) {
      throw ArgumentError.value(
          d.defaultSalePricePiastersPerKg,
          'defaultSalePricePiastersPerKg',
          'Default sale price must be positive.');
    }
    if (d.minimumSalePricePiastersPerKg != null &&
        d.minimumSalePricePiastersPerKg! <= 0) {
      throw ArgumentError.value(
          d.minimumSalePricePiastersPerKg,
          'minimumSalePricePiastersPerKg',
          'Minimum sale price must be positive.');
    }
    if (d.defaultSalePricePiastersPerKg != null &&
        d.minimumSalePricePiastersPerKg != null &&
        d.minimumSalePricePiastersPerKg! > d.defaultSalePricePiastersPerKg!) {
      throw ArgumentError.value(
          d.minimumSalePricePiastersPerKg,
          'minimumSalePricePiastersPerKg',
          'Minimum sale price cannot exceed default sale price.');
    }
    if (d.referenceCostPricePiastersPerKg != null &&
        d.referenceCostPricePiastersPerKg! <= 0) {
      throw ArgumentError.value(
          d.referenceCostPricePiastersPerKg,
          'referenceCostPricePiastersPerKg',
          'Reference cost price must be positive.');
    }
  }

  void _validateRestored(List<domain.Product> products) {
    final ids = <String>{}, names = <String>{}, codes = <String>{};
    for (final p in products) {
      if (!p.hasValidId) {
        throw StateError('Product id is required.');
      }
      if (!ids.add(p.id)) {
        throw StateError('Duplicate product id.');
      }
      if (!names.add(_key(p.name))) {
        throw StateError('Duplicate product name.');
      }
      if (p.code != null && !codes.add(_key(p.code!))) {
        throw StateError('Duplicate product code.');
      }
    }
  }

  String _key(String value) => value.trim().toLowerCase();
  String? _optional(String? value) {
    final v = value?.trim();
    return v == null || v.isEmpty ? null : v;
  }
}

class _DriftProductSnapshot extends SnapshotHolder {
  _DriftProductSnapshot(this.repository);
  final DriftProductRepository repository;
  List<domain.Product>? products;

  @override
  Future<void> capture() async {
    products = await repository.listProducts();
  }

  @override
  Future<void> rollback() async {
    final state = products;
    if (state == null) return;
    await repository.clearForOwnerDataWipe();
    await repository.restoreProductsIntoEmpty(state);
  }
}
