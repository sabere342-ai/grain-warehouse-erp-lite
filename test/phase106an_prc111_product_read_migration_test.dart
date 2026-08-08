import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';

const _salePath = 'lib/core/sales/sale_repository.dart';
const _driftSalePath = 'lib/core/sales/drift_sale_repository.dart';
const _compositionPath = 'lib/app/app_repositories.dart';

void main() {
  test('PRC-111 depends only on the canonical catalog read contract', () {
    final source = File(_salePath).readAsStringSync();
    final validation = _methodBody(
      source,
      'Future<ProductCatalogReadModel> _validateProduct',
    );

    expect(source, contains('product_catalog_read_repository.dart'));
    expect(source, isNot(contains('product_repository.dart')));
    expect(source, isNot(contains('ProductRepository')));
    expect(source, isNot(contains('.listProducts(')));
    expect(_occurrences(source, '.listProductCatalog('), 1);
    expect(
      _compact(validation),
      contains(
        '_productCatalogReadRepository.listProductCatalog('
        'includeInactive:true',
      ),
    );
    expect(validation, contains('if (product.id == productId)'));
    expect(validation, contains('if (!product.isActive)'));
  });

  test('durable delegate and production composition inject the new contract',
      () {
    final drift = File(_driftSalePath).readAsStringSync();
    expect(drift, contains('ProductCatalogReadRepository'));
    expect(drift, contains('productCatalogReadRepository:'));
    expect(drift, isNot(contains('ProductRepository')));
    expect(drift, isNot(contains('productRepository:')));

    final composition = File(_compositionPath).readAsStringSync();
    final production = _construction(composition, 'DriftSaleRepository(');
    final local = _construction(composition, 'LocalSaleRepository(');
    for (final construction in [production, local]) {
      expect(
        construction,
        contains(
          'productCatalogReadRepository: productCatalogReadRepository',
        ),
      );
      expect(construction, isNot(contains('productRepository:')));
    }
  });

  test('canonical reads preserve active validation, prices, and multiplicity',
      () async {
    final fixture = await _fixture(minimumPrice: 600);

    final sale = await fixture.sales.createSale(
      _draft(fixture.product.id, price: 600),
    );

    expect(sale.productId, fixture.product.id);
    expect(fixture.catalog.includeInactiveValues, [true, true]);
    expect(await fixture.inventory.currentStockKg(fixture.product.id), 90);
    expect(await fixture.sales.listSales(), hasLength(1));
  });

  test('minimum-price rejection still occurs without persistence side effects',
      () async {
    final fixture = await _fixture(minimumPrice: 601);

    await expectLater(
      fixture.sales.createSale(_draft(fixture.product.id, price: 600)),
      throwsA(
        isA<MinimumSalePriceViolation>()
            .having((error) => error.productId, 'productId', fixture.product.id)
            .having(
              (error) => error.minimumSalePricePiastersPerKg,
              'minimum price',
              601,
            )
            .having(
              (error) => error.actualSalePricePiastersPerKg,
              'actual price',
              600,
            ),
      ),
    );

    expect(fixture.catalog.includeInactiveValues, [true]);
    expect(await fixture.inventory.currentStockKg(fixture.product.id), 100);
    expect(await fixture.sales.listSales(), isEmpty);
  });

  test('first exact inactive match wins and causes no write', () async {
    final fixture = await _fixture(
      catalogValues: (product) => [
        _model(product, isActive: false),
        _model(product, isActive: true),
      ],
    );

    await expectLater(
      fixture.sales.createSale(_draft(fixture.product.id)),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          '\u0635\u0646\u0641 \u063a\u064a\u0631 \u0646\u0634\u0637 \u0644\u0627 \u064a\u0645\u0643\u0646 \u0628\u064a\u0639\u0647.',
        ),
      ),
    );
    expect(fixture.catalog.includeInactiveValues, [true]);
    expect(await fixture.inventory.currentStockKg(fixture.product.id), 100);
    expect(await fixture.sales.listSales(), isEmpty);
  });

  test('missing product and catalog errors propagate before writes', () async {
    final missing = await _fixture(catalogValues: (_) => const []);
    await expectLater(
      missing.sales.createSale(_draft('missing')),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          '\u0627\u0644\u0635\u0646\u0641 \u063a\u064a\u0631 \u0645\u0648\u062c\u0648\u062f.',
        ),
      ),
    );
    expect(await missing.inventory.currentStockKg(missing.product.id), 100);
    expect(await missing.sales.listSales(), isEmpty);

    final failure = StateError('catalog read failed');
    final throwing = await _fixture(catalogError: failure);
    await expectLater(
      throwing.sales.createSale(_draft(throwing.product.id)),
      throwsA(same(failure)),
    );
    expect(await throwing.inventory.currentStockKg(throwing.product.id), 100);
    expect(await throwing.sales.listSales(), isEmpty);
  });

  test('Phase 106 map reaches zero production holdouts without scope drift',
      () {
    final sources = _dartSources();
    final joined = sources.values.join('\n');
    expect(_occurrences(joined, '.listProducts('), 6);
    expect(_occurrences(joined, '.listProductCatalog('), 20);
    expect(
      sources.entries
          .where((entry) => entry.value.contains('.listProducts('))
          .map((entry) => entry.key)
          .toSet(),
      {
        'lib/app/app_repositories.dart',
        'lib/core/catalog/drift_product_repository.dart',
        'lib/core/inventory/inventory_repository.dart',
        'lib/core/inventory_valuation/synthetic_profitability_activation_service.dart',
        'lib/core/purchases/purchase_repository.dart',
      },
    );
  });
}

Future<_Fixture> _fixture({
  int? minimumPrice,
  List<ProductCatalogReadModel> Function(Product product)? catalogValues,
  Object? catalogError,
}) async {
  final products = LocalProductRepository();
  final product = await products.createProduct(
    ProductDraft(
      name: 'Wheat',
      unit: GrainUnit.kilogram,
      defaultSalePricePiastersPerKg: 700,
      minimumSalePricePiastersPerKg: minimumPrice,
    ),
  );
  final inventory = LocalInventoryRepository(productRepository: products);
  await inventory.createMovement(
    StockMovementDraft(
      productId: product.id,
      movementType: StockMovementType.openingBalance,
      quantityKg: 100,
      createdByUserId: 'owner',
    ),
  );
  final catalog = _CatalogSpy(
    catalogValues?.call(product) ?? [_model(product)],
    error: catalogError,
  );
  return _Fixture(
    product: product,
    inventory: inventory,
    catalog: catalog,
    sales: LocalSaleRepository(
      productCatalogReadRepository: catalog,
      inventoryRepository: inventory,
    ),
  );
}

SaleDraft _draft(String productId, {int price = 600}) => SaleDraft(
      productId: productId,
      quantityKg: 10,
      salePriceQirshPerKg: price,
      createdByUserId: 'owner',
      customerId: 'customer-1',
    );

ProductCatalogReadModel _model(
  Product product, {
  bool isActive = true,
}) =>
    ProductCatalogReadModel(
      id: product.id,
      name: product.name,
      code: product.code,
      unit: product.unit,
      isActive: isActive,
      referenceCostPricePiastersPerKg: product.referenceCostPricePiastersPerKg,
      defaultSalePricePiastersPerKg: product.defaultSalePricePiastersPerKg,
      minimumSalePricePiastersPerKg: product.minimumSalePricePiastersPerKg,
      notes: product.notes,
      createdAt: product.createdAt,
      updatedAt: product.updatedAt,
    );

final class _CatalogSpy implements ProductCatalogReadRepository {
  _CatalogSpy(this.values, {this.error});

  final List<ProductCatalogReadModel> values;
  final Object? error;
  final List<bool> includeInactiveValues = [];

  @override
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  }) async {
    includeInactiveValues.add(includeInactive);
    if (error != null) throw error!;
    return values;
  }
}

final class _Fixture {
  const _Fixture({
    required this.product,
    required this.inventory,
    required this.catalog,
    required this.sales,
  });

  final Product product;
  final LocalInventoryRepository inventory;
  final _CatalogSpy catalog;
  final LocalSaleRepository sales;
}

Map<String, String> _dartSources() {
  final sources = <String, String>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    sources[entity.path.replaceAll('\\', '/')] = entity.readAsStringSync();
  }
  return sources;
}

String _methodBody(String source, String declaration) {
  final start = source.indexOf(declaration);
  if (start < 0) throw StateError('Missing declaration: $declaration');
  final openBrace = source.indexOf('{', start);
  var depth = 0;
  for (var index = openBrace; index < source.length; index++) {
    if (source[index] == '{') depth++;
    if (source[index] == '}') depth--;
    if (depth == 0) return source.substring(start, index + 1);
  }
  throw StateError('Missing closing brace: $declaration');
}

String _construction(String source, String marker) {
  final start = source.indexOf(marker);
  if (start < 0) throw StateError('Missing construction: $marker');
  var depth = 0;
  var opened = false;
  for (var index = start; index < source.length; index++) {
    if (source[index] == '(') {
      depth++;
      opened = true;
    }
    if (source[index] == ')') depth--;
    if (opened && depth == 0) return source.substring(start, index + 1);
  }
  throw StateError('Missing construction close: $marker');
}

int _occurrences(String source, String pattern) =>
    RegExp(RegExp.escape(pattern)).allMatches(source).length;

String _compact(String source) => source.replaceAll(RegExp(r'\s+'), '');
