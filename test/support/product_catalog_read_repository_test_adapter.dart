import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';

final class ProductCatalogReadRepositoryTestAdapter
    implements ProductCatalogReadRepository {
  const ProductCatalogReadRepositoryTestAdapter(this._repository);

  final ProductRepository _repository;

  @override
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  }) async {
    final products = await _repository.listProducts(
      includeInactive: includeInactive,
    );
    return products
        .map(
          (product) => ProductCatalogReadModel(
            id: product.id,
            name: product.name,
            code: product.code,
            unit: product.unit,
            isActive: product.isActive,
            referenceCostPricePiastersPerKg:
                product.referenceCostPricePiastersPerKg,
            defaultSalePricePiastersPerKg:
                product.defaultSalePricePiastersPerKg,
            minimumSalePricePiastersPerKg:
                product.minimumSalePricePiastersPerKg,
            notes: product.notes,
            createdAt: product.createdAt,
            updatedAt: product.updatedAt,
          ),
        )
        .toList(growable: false);
  }
}
