# Phase 106Z — Migrate Profitability Report Activation Product Read

## 1. Outcome

**Outcome A — FULL SUCCESS**.

Phase 106Z migrated exactly PRC-113,
`_ProfitabilityReportScreenState._activate(AppUser user)`, from the legacy
product read to the existing Product Catalog read boundary. No other product
consumer, write path, business rule, or production file was migrated.

## 2. Git identity and lineage

| Evidence | Value |
| --- | --- |
| Branch | `codex/phase-106z-migrate-profitability-report-activation-product-read` |
| Starting HEAD | `fe549ecde9eba4de9c3d4916f611eae8fb58720e` |
| Required commit subject | `PHASE 106Z: migrate profitability report activation product read` |
| Commits after the baseline | exactly one |
| Final HEAD | recorded from the post-commit repository in the final handoff; a commit cannot truthfully contain its own hash |

The branch was created directly from the exact Phase 106Y baseline after a
clean-tree check. No merge, rebase, reset, history repair, Push, or Tag was
performed.

## 3. Atomic objective

The only production objective was to replace the PRC-113 product enumeration
inside `_activate` while preserving all activation behavior.

Before:

```dart
AppRepositories.productRepository.listProducts(
  includeInactive: true,
)
```

After:

```dart
AppRepositories.productCatalogReadRepository.listProductCatalog(
  includeInactive: true,
)
```

The dialog list type changed from `List<Product>` to
`List<ProductCatalogReadModel>`. The old `product.dart` import was replaced by
`product_catalog_read_repository.dart` because no other `Product` symbol
remained in the file.

## 4. Contract fit and fields used

`ProductCatalogReadModel` already contains the complete PRC-113 requirement:

- `String id`
- `String name`

The activation dialog uses `id` for balance/controller keys and submitted
`OpeningValuationInput.productId`; it uses `name` for the visible product
label. A focused source guard enumerates every `product.<field>` access in the
dialog and proves the set is exactly `{id, name}`.

Neither value is trimmed, normalized, defaulted, converted, or reconstructed.
No nullable catalog field participates in this path.

## 5. Inactive and ordering semantics

The call remains exactly `includeInactive: true`, so active and inactive rows
remain available for complete opening-valuation decisions.

The existing Drift Catalog adapter orders rows by `createdAt ASC`, then
`id ASC`, which matches the frozen legacy ordering. The screen adds no sort,
filter, cache, merge, fallback, dual-read, or feature flag.

## 6. Behavioral preservation

The focused Phase 106Z guard proves that the production file is byte-for-byte
the Phase 106Y version after only four substitutions:

1. the import;
2. the `AppRepositories` read accessor;
3. `listProducts` to `listProductCatalog`;
4. `List<Product>` to `List<ProductCatalogReadModel>`.

Consequently, balances, dialog construction, cancellation, loading state,
validation, messages, navigation, success handling, failure handling,
activation inputs, quantity/cost parsing, evidence handling, permissions, and
visible Arabic text are unchanged.

## 7. Production scope

Exactly one production file changed:

```text
lib/features/financial_reports/profitability_report_screen.dart
```

`git diff --name-only fe549ecde9eba4de9c3d4916f611eae8fb58720e -- lib`
reconciles to that path only.

## 8. Explicitly unchanged production surfaces

- PRC-108 `ProfitabilityActivationService.activate` remains on
  `ProductRepository.listProducts(includeInactive: true)` for its authoritative
  validation and atomic write workflow.
- All other remaining product-read consumers retain their prior boundaries.
- Product create/update/activation writes remain on `ProductRepository`.
- Profitability activation business rules and validation are unchanged.
- Accounting, inventory valuation, COGS, monetary values, and unit conversions
  are unchanged.
- No constructor, widget API, controller, service, schema, migration,
  generated file, backup format, dependency, lockfile, platform file, or
  persistence version changed.

## 9. Contract non-expansion proof

`ProductCatalogReadModel` remains the same nine-field model present at the
Phase 106Y baseline. No field or method was added. The read repository still
exposes only `listProductCatalog` and exposes no create, update, delete, or
write operation.

Diffs from the Phase 106Y baseline are empty for:

- `lib/core/catalog/product_catalog_read_repository.dart`;
- `lib/core/catalog/drift_product_catalog_read_repository.dart`;
- `lib/core/inventory_valuation/profitability_activation_service.dart`;
- `lib/core/persistence/`.

## 10. Tests and guard maintenance

Added:

```text
test/phase106z_profitability_report_activation_product_read_migration_test.dart
```

The nine focused tests prove lineage, the one-file production allowlist, the
exact four-part source delta, `includeInactive: true`, removal of the legacy
screen read, exact `id`/`name` use, adapter inactive/order semantics, no
contract expansion or write method, unchanged activation handling and PRC-108,
and the updated inventory.

Historical Phase 106O–106Y guards that intentionally track the live catalog
caller set or linear HEAD were extended narrowly to admit exactly this
transition. Frozen historical reports, phase-specific snapshots, original
allowlists, classifications, and prior migration claims were not rewritten.
The Phase 106Y guard now reads its frozen source from the immutable Phase 106Y
commit, preserving the truth that Phase 106Y selected but did not migrate
PRC-113.

## 11. Verification results

| Verification | Result |
| --- | --- |
| Phase 106Z focused test | PASS — 9 passed |
| Phase 106Y freeze guard | PASS — 17 passed |
| Relevant Phase 106O lineage guard | PASS — 8 passed |
| Existing profitability/report batch | PASS — 40 passed |
| Updated Phase 106P–106R guard batch | PASS — 37 passed |
| Updated Phase 106S–106U guard batch | PASS — 40 passed |
| Updated Phase 106V–106X guard batch | PASS — 38 passed |
| Full `flutter test` | PASS — 2252 passed, 1 skipped, 0 failed |
| `flutter analyze` | PASS — no issues |
| Repository-wide formatter | PASS — 405 files checked, 0 changed on the clean verification run |
| `git diff --check` | PASS |

The Windows `dart.bat` wrapper stalled once without output, matching the
environment behavior recorded in Phase 106Y. The same Flutter SDK's direct
`dart.exe` formatter was used successfully; this did not alter formatter
semantics.

An initial full-suite run exposed 17 stale live-inventory/lineage assertions
in earlier Phase 106 guards. The failures accounted exactly for historical
guards that stopped at Phase 106X or still expected PRC-113 in the live legacy
set. After the narrow timeline/current-inventory updates described above, all
17 passed in focused batches and the exact full suite passed.

## 12. Updated inventory and reconciliation

The source was recounted after the migration:

| Measure | Count |
| --- | ---: |
| Total logical product-read units | 24 |
| Migrated and accepted | 11 |
| Remaining classified units | 13 |
| Legacy `.listProducts(` call sites in `lib/` | 15 |
| Catalog `.listProductCatalog(` call sites in `lib/` | 11 |

Governing equation:

```text
24 = 11 + 13
```

The 15 legacy calls map to 13 remaining logical units because PRC-109 and
PRC-114 each retain two calls inside one stable workflow. The 11 catalog calls
map one-to-one to 11 migrated units. Exactly PRC-113 moved; no other stable PRC
identifier changed classification.

Remaining classification totals are:

```text
A=0, B=0, C=0, D=0, E=7, F=0, G=2, H=3, I=1
0 + 0 + 0 + 0 + 7 + 0 + 2 + 3 + 1 = 13
```

PRC-108 remains out of scope on the legacy validation read, and activation
writes remain out of scope.

## 13. Final repository state and release actions

The post-commit handoff records the actual full Final HEAD, verifies exactly
one commit after the baseline, verifies the required subject, verifies the
clean worktree, and verifies the one-file `lib/` delta. These values cannot be
self-embedded in the commit without changing the commit hash.

No Push was performed. No Tag was created.

## 14. Risks and next recommendation

The Phase 106Z tests provide strong structural proof plus existing runtime
coverage of the unchanged profitability activation/report services. They do
not claim a new deep widget-to-real-SQLite runtime proof for the private
activation dialog. The independently frozen Phase 106Y recommendation names
that deeper proof as Phase 106AA; the next phase should re-audit and execute
that proof independently without inferring permission to migrate another
consumer.
