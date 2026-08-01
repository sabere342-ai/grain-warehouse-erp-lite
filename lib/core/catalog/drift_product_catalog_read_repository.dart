import 'package:drift/drift.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;

final class DriftProductCatalogReadRepository
    implements ProductCatalogReadRepository {
  DriftProductCatalogReadRepository(this._database);

  final db.FoundationDatabase _database;

  @override
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  }) async {
    final products = _database.products;
    final query = _database.selectOnly(products)
      ..addColumns([
        products.id,
        products.name,
        products.code,
        products.unit,
        products.isActive,
        products.referenceCostPricePiastersPerKg,
        products.defaultSalePricePiastersPerKg,
        products.minimumSalePricePiastersPerKg,
        products.notes,
      ])
      ..orderBy([
        OrderingTerm.asc(products.createdAt),
        OrderingTerm.asc(products.id),
      ]);
    if (!includeInactive) {
      query.where(products.isActive.equals(true));
    }

    final rows = await query.get();
    return rows
        .map(
          (row) => ProductCatalogReadModel(
            id: row.read(products.id)!,
            name: row.read(products.name)!,
            code: row.read(products.code),
            unit: GrainUnit.fromWireName(row.read(products.unit)!),
            isActive: row.read(products.isActive)!,
            referenceCostPricePiastersPerKg:
                row.read(products.referenceCostPricePiastersPerKg),
            defaultSalePricePiastersPerKg:
                row.read(products.defaultSalePricePiastersPerKg),
            minimumSalePricePiastersPerKg:
                row.read(products.minimumSalePricePiastersPerKg),
            notes: row.read(products.notes),
          ),
        )
        .toList(growable: false);
  }
}
