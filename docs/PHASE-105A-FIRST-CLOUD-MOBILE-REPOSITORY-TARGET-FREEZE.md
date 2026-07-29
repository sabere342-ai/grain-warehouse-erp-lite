# Phase 105A — First Cloud/Mobile Repository Target Freeze

## Target

- Functional target: **Product Master Catalog Read**
- Read model: `ProductCatalogReadModel`
- Repository contract: `ProductCatalogReadRepository`
- Snapshot: `Future`, not `Stream`

## Proposed model

```dart
final class ProductCatalogReadModel {
  const ProductCatalogReadModel({
    required this.id,
    required this.name,
    required this.unit,
    required this.isActive,
    this.code,
  });

  final String id;
  final String name;
  final String? code;
  final GrainUnit unit;
  final bool isActive;
}
```

- `id`: required, trimmed, non-empty opaque application identity.
- `name`: required, trimmed, non-empty Unicode display name.
- `code`: nullable business code; blank maps to `null`; not defined as a
  barcode.
- `unit`: required domain `GrainUnit` (`kilogram` or `ton`); it carries no
  quantity.
- `isActive`: required master-data status.

The model is independent of Drift. It excludes price, cost, notes, timestamps,
normalized columns, quantity, movements, valuation, COGS, profitability,
backend identity, transport DTOs, sync/version data, and tokens.

## Proposed operation

```dart
abstract interface class ProductCatalogReadRepository {
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  });
}
```

No create, update, activate, delete, restore, wipe, search, pagination, cache,
sync, auth, or provider operation is part of the contract.

## Frozen semantics

- Results are one `Future` snapshot.
- Durable order is `createdAt ASC`, then `id ASC`; those sort columns do not
  enter the presentation model.
- `includeInactive: false` returns active rows only; `true` returns both.
- No search/query exists in v1. Trimming, case-folding, Arabic normalization,
  substring matching and barcode matching are not invented.
- Stored Unicode is preserved exactly; blank optional code maps to `null`.
- Duplicate non-empty IDs fail closed; rows are never silently merged/dropped.
- No data is a successful, non-null, unmodifiable empty list.
- Initial failure settles loading and becomes controlled UI state.
- Refresh failure retains controller-owned last-good data with a warning.
- Retry makes one new call and replaces the entire list without duplicates.
- The repository owns no cache. No offline or staleness guarantee is implied.
- The controller ignores late completion after disposal and prevents stale
  requests from overwriting newer data.
- `AppRepositories` owns the production adapter/database. Internally created
  controllers are screen-owned; injected controllers are caller-owned.

## In scope

- Five-field product master projection.
- Active/include-inactive listing.
- Empty, failure, retry, refresh-cache and lifecycle behavior.
- Fake contract tests, later local Drift adapter, one later controller subread,
  one later production product selector, and real composition acceptance.

## Out of scope

- Every product write or activation change.
- Product pricing, minimum price, reference cost, availability, quantity,
  valuation, COGS, profitability, inventory movement, purchase, sale, return,
  stocktake, opening balance, cancellation, or document history.
- Product-screen pricing/cost presentation.
- Search/barcode semantics, pagination, realtime, synchronization, conflict
  resolution, offline writes, or persistent caching.
- Cloud/backend/provider choice, Firebase/Supabase configuration, packages,
  auth redesign, tenancy, remote IDs, DTOs, tokens, or security rules.
- Mobile layouts, navigation, permissions, camera/scanner, Android/iOS setup.
- Schema and migration changes.

## Constraints and prohibitions

1. No Drift entity or remote DTO may reach presentation.
2. No monetary, stock, persistence, transport, or sync field may be added to
   the model without a separately accepted contract change.
3. The existing `ProductRepository` write/data paths remain untouched.
4. Only one consumer is migrated per atomic phase; no bulk 23-file migration.
5. No generic repository/filter/query framework may be introduced.
6. No cloud adapter starts before the local boundary passes Phase 105G.
7. `code` must not be labeled or matched as a barcode without proven business
   semantics.

## Follow-on phases

- **105B:** model + interface + contract/fake tests only.
- **105C:** local Drift adapter + isolated mapping/parity tests only.
- **105D:** product-selector subread in `PurchaseController` only.
- **105E:** product dropdown in `PurchasesScreen` + composition/widget tests.
- **105F:** retire only that consumer's legacy product-list dependency.
- **105G:** real composition, no-bypass, lifecycle, regressions and local
  architecture acceptance.
- **106A:** only then, cloud-adapter preconditions and backend decision freeze.

## Acceptance criteria

- Exact five-field, persistence-independent model.
- Exact one-operation `Future` contract.
- Local fake and Drift implementations have identical mapping/filter/order.
- Empty/failure/retry/refresh/lifecycle behavior matches the frozen semantics.
- One production consumer uses the boundary with no read bypass.
- No product write, inventory, pricing, accounting, schema, migration, cloud,
  backend, sync, or mobile behavior changes.
- Audit Log, Phase 102J, focused regressions, Full Suite, analyzer and Windows
  Release remain green before the local boundary is accepted.
