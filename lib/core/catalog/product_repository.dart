import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';

abstract class ProductRepository {
  Future<List<Product>> listProducts({bool includeInactive = true});

  Future<Product> createProduct(ProductDraft draft);

  Future<Product> updateProduct({
    required String productId,
    required ProductDraft draft,
  });

  Future<Product> setProductActive({
    required String productId,
    required bool isActive,
  });
}

class LocalProductRepository implements ProductRepository {
  final List<Product> _products = [];
  int _generatedIdCounter = 0;

  @override
  Future<List<Product>> listProducts({bool includeInactive = true}) async {
    final products = includeInactive
        ? _products
        : _products.where((product) => product.isActive).toList();
    return List<Product>.unmodifiable(products);
  }

  @override
  Future<Product> createProduct(ProductDraft draft) async {
    _validateDraft(draft);
    _ensureUniqueName(draft.name);
    _ensureUniqueCode(draft.code);

    final now = DateTime.now();
    final product = Product(
      id: _generateProductId(now),
      name: draft.name.trim(),
      code: _normalizedOptionalText(draft.code),
      unit: draft.unit,
      isActive: true,
      defaultSalePricePiastersPerKg: draft.defaultSalePricePiastersPerKg,
      minimumSalePricePiastersPerKg: draft.minimumSalePricePiastersPerKg,
      notes: _normalizedOptionalText(draft.notes),
      createdAt: now,
      updatedAt: now,
    );

    _products.add(product);
    return product;
  }

  @override
  Future<Product> updateProduct({
    required String productId,
    required ProductDraft draft,
  }) async {
    _validateDraft(draft);
    final index = _indexById(productId);
    final current = _products[index];

    _ensureUniqueName(draft.name, exceptProductId: productId);
    _ensureUniqueCode(draft.code, exceptProductId: productId);

    final updated = Product(
      id: current.id,
      name: draft.name.trim(),
      code: _normalizedOptionalText(draft.code),
      unit: draft.unit,
      isActive: current.isActive,
      defaultSalePricePiastersPerKg: draft.defaultSalePricePiastersPerKg,
      minimumSalePricePiastersPerKg: draft.minimumSalePricePiastersPerKg,
      notes: _normalizedOptionalText(draft.notes),
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );

    _products[index] = updated;
    return updated;
  }

  @override
  Future<Product> setProductActive({
    required String productId,
    required bool isActive,
  }) async {
    final index = _indexById(productId);
    final current = _products[index];
    final updated = current.copyWith(
      isActive: isActive,
      updatedAt: DateTime.now(),
    );
    _products[index] = updated;
    return updated;
  }

  Future<void> restoreProductsIntoEmpty(List<Product> products) async {
    if (_products.isNotEmpty) {
      throw StateError('Products repository is not empty.');
    }
    _validateUniqueRestoredProducts(products);
    _products.addAll(products);
  }

  Future<void> clearForOwnerDataWipe() async {
    _products.clear();
    _generatedIdCounter = 0;
  }

  void _validateDraft(ProductDraft draft) {
    if (draft.name.trim().isEmpty) {
      throw ArgumentError.value(
          draft.name, 'name', 'Product name is required.');
    }

    final defaultPrice = draft.defaultSalePricePiastersPerKg;
    if (defaultPrice != null && defaultPrice <= 0) {
      throw ArgumentError.value(
        defaultPrice,
        'defaultSalePricePiastersPerKg',
        'Default sale price must be positive.',
      );
    }

    final minimumPrice = draft.minimumSalePricePiastersPerKg;
    if (minimumPrice != null && minimumPrice <= 0) {
      throw ArgumentError.value(
        minimumPrice,
        'minimumSalePricePiastersPerKg',
        'Minimum sale price must be positive.',
      );
    }

    if (defaultPrice != null &&
        minimumPrice != null &&
        minimumPrice > defaultPrice) {
      throw ArgumentError.value(
        minimumPrice,
        'minimumSalePricePiastersPerKg',
        'Minimum sale price cannot exceed default sale price.',
      );
    }
  }

  void _ensureUniqueName(String name, {String? exceptProductId}) {
    final normalized = _normalizedKey(name);
    final duplicate = _products.any(
      (product) =>
          product.id != exceptProductId &&
          _normalizedKey(product.name) == normalized,
    );
    if (duplicate) {
      throw StateError('Duplicate product name.');
    }
  }

  void _ensureUniqueCode(String? code, {String? exceptProductId}) {
    final normalizedCode = _normalizedOptionalText(code);
    if (normalizedCode == null) {
      return;
    }

    final duplicate = _products.any(
      (product) =>
          product.id != exceptProductId &&
          product.code != null &&
          _normalizedKey(product.code!) == _normalizedKey(normalizedCode),
    );
    if (duplicate) {
      throw StateError('Duplicate product code.');
    }
  }

  void _validateUniqueRestoredProducts(List<Product> products) {
    final ids = <String>{};
    final names = <String>{};
    final codes = <String>{};
    for (final product in products) {
      if (!product.hasValidId) {
        throw StateError('Product id is required.');
      }
      if (!ids.add(product.id)) {
        throw StateError('Duplicate product id.');
      }
      if (!names.add(_normalizedKey(product.name))) {
        throw StateError('Duplicate product name.');
      }
      final code = product.code;
      if (code != null && !codes.add(_normalizedKey(code))) {
        throw StateError('Duplicate product code.');
      }
    }
  }

  int _indexById(String productId) {
    final index = _products.indexWhere((product) => product.id == productId);
    if (index == -1) {
      throw StateError('Product was not found.');
    }

    return index;
  }

  String _generateProductId(DateTime now) {
    _generatedIdCounter++;
    return 'prd-${now.microsecondsSinceEpoch}-$_generatedIdCounter';
  }

  String _normalizedKey(String value) {
    return value.trim().toLowerCase();
  }

  String? _normalizedOptionalText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}
