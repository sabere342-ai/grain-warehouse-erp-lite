# Phase 105B — Product Catalog Read Contract Freeze

## Frozen model

```dart
final class ProductCatalogReadModel {
  const ProductCatalogReadModel({
    required this.id,
    required this.name,
    required this.code,
    required this.unit,
    required this.isActive,
  });

  final String id;
  final String name;
  final String? code;
  final GrainUnit unit;
  final bool isActive;
}
```

- `id` remains the exact opaque textual product ID.
- `unit` reuses `core/catalog/grain_unit.dart` without conversion.
- `code` is nullable and is not defined as a barcode.
- No other field is permitted in this read model.

## Frozen contract

```dart
abstract interface class ProductCatalogReadRepository {
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  });
}
```

- This is the only method.
- `includeInactive` is required with no default.
- `false` means active only; `true` allows active and inactive products.
- Every success is a complete `Future` snapshot.
- A retry replaces; it never appends or merges.
- The repository has no cache.
- No stream, search, pagination, sorting parameter, or write exists.

## Implementation obligation

The Phase 105C local Drift adapter must order by `createdAt ASC`, then
`id ASC`. `createdAt` remains an adapter sort key and must not enter the model.

## Prohibitions

- No numeric conversion, parsing, hashing, or replacement of product IDs.
- No `String` replacement for `GrainUnit` and no duplicate unit enum.
- No barcode, price, cost, quantity, availability, valuation, COGS,
  profitability, persistence, transport, cache, sync, or backend field.
- No controller, UI, selector, composition, schema, migration, cloud, API, or
  mobile change as part of the contract.
- No existing repository implements this contract in Phase 105B.

Phase 105C is limited to the local Drift adapter. Controller and UI migration
remain outside its scope.
