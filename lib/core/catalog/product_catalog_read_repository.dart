import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';

final class ProductCatalogReadModel {
  const ProductCatalogReadModel({
    required this.id,
    required this.name,
    required this.code,
    required this.unit,
    required this.isActive,
    required this.referenceCostPricePiastersPerKg,
  });

  final String id;
  final String name;

  /// Optional product code. The contract does not define it as a barcode.
  final String? code;
  final GrainUnit unit;
  final bool isActive;
  final int? referenceCostPricePiastersPerKg;
}

abstract interface class ProductCatalogReadRepository {
  /// Returns a complete snapshot ordered by creation time ascending, then id
  /// ascending. Implementations do not cache, append, or merge snapshots.
  ///
  /// When [includeInactive] is false, only active products are returned. When
  /// true, both active and inactive products may be returned.
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  });
}
