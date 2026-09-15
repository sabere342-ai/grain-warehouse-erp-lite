import 'package:drift/drift.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/application/catalog_sync/product_catalog_sync_contracts.dart';
import 'package:grain_warehouse_erp_lite/application/time/application_clock.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;

final class DriftProductCatalogReadRepository
    implements ProductCatalogReadRepository {
  DriftProductCatalogReadRepository(
    this._database, {
    ApplicationClock clock = const SystemApplicationClock(),
  }) : _clock = clock;

  final db.FoundationDatabase _database;
  final ApplicationClock _clock;

  @override
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  }) async {
    final products = _database.products;
    final states = _database.productCatalogSyncStates;
    final query = _database.selectOnly(products).join([
      leftOuterJoin(
        states,
        states.localProductId.equalsExp(products.id),
      ),
    ])
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
        products.createdAt,
        products.updatedAt,
        states.remoteProductId,
        states.acknowledgedEntityVersion,
        states.pendingOperationId,
        states.projectionState,
      ])
      ..orderBy([
        OrderingTerm.asc(products.createdAt),
        OrderingTerm.asc(products.id),
      ]);
    query.where(
      states.projectionState.isNull() |
          states.projectionState
              .isNotValue(ProductCloudDisposition.tombstoned.name),
    );
    if (!includeInactive) {
      query.where(products.isActive.equals(true));
    }

    final binding =
        await (_database.select(_database.productCatalogScopeBindings)
              ..where((row) => row.isActive.equals(true)))
            .getSingleOrNull();
    final checkpoint = binding == null
        ? null
        : await (_database.select(_database.durableSyncCheckpoints)
              ..where((row) =>
                  row.businessId.equals(binding.businessId) &
                  row.scopeKind.equals('businessWide') &
                  row.warehouseId.isNull() &
                  row.sourceAuthority.equals(productCatalogSourceAuthority) &
                  row.streamName.equals(productCatalogStreamName)))
            .getSingleOrNull();
    final lastPull = checkpoint?.updatedAtUtc.toUtc();
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
            createdAt: row.read(products.createdAt)!,
            updatedAt: row.read(products.updatedAt)!,
            cloudDisposition: row.read(states.projectionState) == null
                ? ProductCloudDisposition.localOnly
                : ProductCloudDisposition.values
                    .byName(row.read(states.projectionState)!),
            remoteProductId: row.read(states.remoteProductId),
            acknowledgedEntityVersion:
                row.read(states.acknowledgedEntityVersion),
            pendingOperationId: row.read(states.pendingOperationId),
            lastSuccessfulPullAtUtc: lastPull,
            isStale: row.read(states.remoteProductId) != null &&
                (lastPull == null ||
                    _clock.nowUtc().difference(lastPull) >
                        const Duration(minutes: 15)),
          ),
        )
        .toList(growable: false);
  }
}
