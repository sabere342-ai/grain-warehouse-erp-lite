import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';

void main() {
  test('read model preserves the five frozen fields and governing types', () {
    const model = ProductCatalogReadModel(
      id: 'prd-123456789-1',
      name: 'Wheat',
      code: 'WH-1',
      unit: GrainUnit.ton,
      isActive: true,
    );

    final String id = model.id;
    final String name = model.name;
    final String? code = model.code;
    final GrainUnit unit = model.unit;
    final bool isActive = model.isActive;

    expect(id, 'prd-123456789-1');
    expect(name, 'Wheat');
    expect(code, 'WH-1');
    expect(unit, GrainUnit.ton);
    expect(isActive, isTrue);
  });

  test('optional product code accepts null without changing other fields', () {
    const model = ProductCatalogReadModel(
      id: 'prd-987654321-2',
      name: 'Corn',
      code: null,
      unit: GrainUnit.kilogram,
      isActive: false,
    );

    expect(model.id, 'prd-987654321-2');
    expect(model.code, isNull);
    expect(model.unit, GrainUnit.kilogram);
    expect(model.isActive, isFalse);
  });

  test('repository is a Future snapshot contract with required visibility',
      () async {
    const snapshot = <ProductCatalogReadModel>[
      ProductCatalogReadModel(
        id: 'prd-1-1',
        name: 'First',
        code: null,
        unit: GrainUnit.kilogram,
        isActive: true,
      ),
      ProductCatalogReadModel(
        id: 'prd-2-2',
        name: 'Second',
        code: 'SECOND',
        unit: GrainUnit.ton,
        isActive: false,
      ),
    ];
    final fake = _FakeProductCatalogReadRepository(snapshot);
    final ProductCatalogReadRepository repository = fake;

    final Future<List<ProductCatalogReadModel>> future =
        repository.listProductCatalog(includeInactive: false);
    final result = await future;

    expect(fake.receivedIncludeInactive, [false]);
    expect(identical(result, snapshot), isTrue);
    expect(result.map((model) => model.id), ['prd-1-1', 'prd-2-2']);

    final secondResult =
        await repository.listProductCatalog(includeInactive: true);
    expect(fake.receivedIncludeInactive, [false, true]);
    expect(identical(secondResult, snapshot), isTrue);
  });
}

final class _FakeProductCatalogReadRepository
    implements ProductCatalogReadRepository {
  _FakeProductCatalogReadRepository(this.snapshot);

  final List<ProductCatalogReadModel> snapshot;
  final List<bool> receivedIncludeInactive = <bool>[];

  @override
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  }) async {
    receivedIncludeInactive.add(includeInactive);
    return snapshot;
  }
}
