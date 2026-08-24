import 'package:grain_warehouse_erp_lite/application/queries/application_query.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';

final class LoadProductCatalogQuery {
  const LoadProductCatalogQuery({required this.includeInactive});

  final bool includeInactive;
}

final class LoadProductCatalogQueryHandler
    implements
        ApplicationQueryHandler<LoadProductCatalogQuery,
            List<ProductCatalogReadModel>> {
  const LoadProductCatalogQueryHandler({
    required ProductCatalogReadRepository repository,
  }) : _repository = repository;

  final ProductCatalogReadRepository _repository;

  @override
  Future<ApplicationQueryResult<List<ProductCatalogReadModel>>> execute(
    LoadProductCatalogQuery query,
  ) async {
    final products = await _repository.listProductCatalog(
      includeInactive: query.includeInactive,
    );
    return ApplicationQueryResult(
      value: products,
      metadata: const LocalQueryResultMetadata(),
    );
  }
}
