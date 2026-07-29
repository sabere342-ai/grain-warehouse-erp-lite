# Phase 105F — Accept and Freeze the First Product Catalog Read Boundary Pilot

## 1. Outcome

**Outcome A — FULL SUCCESS**

The first Product Catalog read-boundary pilot is accepted and frozen. This
report is the governing architecture record for the accepted pattern.

## 2. Scope

The pilot covers exactly one application consumer:
`LocalDocumentHistoryRepository`. It accepts and freezes the work proved by
Phases 105B–105E. It does not migrate a second consumer and adds no cloud,
sync, mobile, UI, schema, migration, backup-format, or production-data work.

## 3. Accepted runtime path

```text
LocalDocumentHistoryRepository
→ ProductCatalogReadRepository
→ DriftProductCatalogReadRepository
→ Drift / SQLite products table
```

`AppRepositories.initializeProduction` is the sole production composition
root for this path.

## 4. Accepted components

The acceptance manifest is:

- Read model: `ProductCatalogReadModel`.
- Contract: `ProductCatalogReadRepository`.
- Local adapter: `DriftProductCatalogReadRepository`.
- Migrated consumer: `LocalDocumentHistoryRepository`.
- Runtime composition: `AppRepositories`.
- Integration proof: Phase 105E.
- Regression suite: Phases 105B, 105C, 105D, 105E, and 105F.

The governing files are:

- `lib/core/catalog/product_catalog_read_repository.dart`
- `lib/core/catalog/drift_product_catalog_read_repository.dart`
- `lib/core/documents/document_history.dart`
- `lib/app/app_repositories.dart`
- `test/phase105b_product_catalog_read_contract_test.dart`
- `test/phase105c_local_drift_product_catalog_read_adapter_test.dart`
- `test/phase105d_product_catalog_application_read_boundary_migration_test.dart`
- `test/phase105e_genuine_runtime_product_catalog_read_integration_test.dart`
- `test/phase105f_product_catalog_read_boundary_pilot_acceptance_freeze_test.dart`

## 5. Frozen contract

The read model remains exactly:

```text
String id
String name
String? code
GrainUnit unit
bool isActive
```

The narrow repository exposes only:

```dart
Future<List<ProductCatalogReadModel>> listProductCatalog({
  required bool includeInactive,
});
```

No product write method belongs on this contract.

## 6. Frozen mapping

The local adapter mapping is frozen as follows:

```text
products.id       → String id
products.name     → String name
products.code     → String? code
products.unit     → GrainUnit.fromWireName
products.isActive → bool isActive
```

Text IDs remain text, a null code remains null, and unit values remain
`GrainUnit`. An invalid stored unit must fail explicitly; no silent fallback or
silent row omission is accepted. With `includeInactive: false`, the adapter
returns active rows only. With `includeInactive: true`, it returns both active
and inactive rows. Ordering remains creation time ascending and then ID
ascending.

## 7. Frozen consumer behavior

`LocalDocumentHistoryRepository` depends on the narrow contract and calls
`listProductCatalog(includeInactive: true)`. It derives a fresh
`Map<String, String>` from product ID to product name for every history read.
The `true` value is required so historical documents keep the names of
products that later become inactive.

The migration preserves success, empty state, propagated failure, successful
retry, no caching or duplication, document timestamp ordering, product-name
resolution, and inactive-product name preservation.

## 8. Frozen composition rule

The concrete adapter is created in `AppRepositories.initializeProduction` and
stored behind `ProductCatalogReadRepository`. The composition root injects
that interface into `LocalDocumentHistoryRepository` after the real Drift
purchase, sale, inventory, and catalog repositories are ready.

The consumer must never construct the adapter, open a database, query a table,
or select a storage implementation.

## 9. Prohibited regressions

The following changes are prohibited for the accepted consumer:

- Returning to `ProductRepository.listProducts`.
- Importing Drift, SQLite, a database class, or the concrete adapter.
- Converting a product ID to `int`.
- Converting `GrainUnit` to `String` in the read model.
- Replacing null codes or invalid units with silent fallback values.
- Dropping inactive products from historical name resolution.
- Constructing `DriftProductCatalogReadRepository` inside the consumer.
- Bypassing `ProductCatalogReadRepository`.
- Coupling the boundary to a `Widget`, screen, or `BuildContext`.
- Adding product write methods to the read contract.

## 10. Evidence summary

- Phase 105B froze the five-field read model and one-method read contract.
- Phase 105C implemented and behaviorally proved the local Drift adapter,
  filtering, ordering, null fidelity, text identity, typed unit mapping, and
  explicit invalid-unit failure.
- Phase 105D migrated only `LocalDocumentHistoryRepository`, preserving
  success, empty, failure, retry, ordering, and inactive-name behavior.
- Phase 105E proved genuine runtime composition through the real Drift adapter
  and an isolated SQLite database rather than a fake-only path.
- Phase 105F adds final contract, consumer, composition, manifest,
  no-bypass, no-UI-coupling, and governing-report guards.

The acceptance audit found 13 `ProductCatalogReadRepository` symbol
occurrences across four production files. It found three
`DriftProductCatalogReadRepository` symbol occurrences across two production
files, plus one isolated Phase 102J trial composition. There is one relevant
production composition root: `AppRepositories`. The accepted consumer has no
legacy or storage bypass and does not import the concrete adapter.

## 11. Test database isolation

The Phase 105E and Phase 105F integration evidence uses
`openInMemoryTestDatabase`, whose implementation uses
`NativeDatabase.memory`. The database has no production filesystem path. The
production database opener was not used, and the user's database was not
opened, copied, read, migrated, restored, or modified.

## 12. Native Smoke policy

Native smoke not run because production database isolation was not proven.
In-memory integration, the full automated suite, and the Windows release build
are the safe runtime evidence for this phase.

## 13. Reuse rules

Future repository-boundary work must use this sequence:

1. Freeze a need-specific read model.
2. Define a narrow read contract.
3. Implement the local adapter.
4. Migrate exactly one consumer.
5. Prove genuine runtime integration with isolated storage.
6. Accept and freeze the pilot.
7. Never combine multiple consumers in one migration phase.

Concrete adapters belong in a composition root. Consumers depend on the
contract. Each later consumer requires its own discovery and behavior freeze;
acceptance here is not blanket authorization to reuse fields or broaden the
contract.

## 14. Out-of-scope legacy surfaces

The audit found 23 production files containing `listProducts`. They include
controllers, UI screens, reports, inventory and transaction validation,
backup/restore/wipe services, and the legacy repository itself. They remain
outside this pilot. Their existence does not make them accepted, frozen, or
automatically migrated, and this report does not claim that every Product read
has been migrated.

`ProductRepository` remains in the application for those legacy and write
boundaries. Phase 105F neither removes nor approves those surfaces.

## 15. Next-step constraints

The only proposed next scope is:

> **Phase 106A — Discover and Freeze the Second Product Read Consumer Migration Target**

Phase 106A may inventory remaining reads, select one consumer, document the
selection, and freeze current behavior. It must not perform the migration or
introduce cloud, sync, API, mobile UI, or a broad repository redesign.

## 16. Git evidence

| Item | Value |
| --- | --- |
| Branch | `codex/phase-105f-accept-freeze-first-product-catalog-read-boundary-pilot` |
| Baseline | `6d274673f7b803a22cd9a79707f453e0ff0c4be1` |
| Final commit | The single Phase 105F commit; its hash is recorded in the final handoff because a commit cannot contain its own hash |
| Commit message | `PHASE 105F: accept and freeze product catalog read boundary pilot` |
| Files changed | 2: one test and this report; no production files |
| Diff stat | 2 files changed, 608 insertions, 0 deletions |
| Commit count | Exactly one commit after the baseline |
| Final worktree | Clean after the single commit |
| Push | Not performed |
| Tag | Not created |

## Verification gates

| Gate | Executed result |
| --- | --- |
| Phase 105F focused | PASS — 6 passed, 0 failed, 0 skipped |
| Phase 105E | PASS — 8 passed, 0 failed, 0 skipped |
| Phase 105D | PASS — 11 passed, 0 failed, 0 skipped |
| Phase 105C | PASS — 9 passed, 0 failed, 0 skipped |
| Phase 105B | PASS — 3 passed, 0 failed, 0 skipped |
| Selected-consumer regressions | PASS — 213 passed across 19 files, 0 failed, 0 skipped |
| Audit Log reference boundary | PASS — 46 passed across 8 files, 0 failed, 0 skipped |
| Phase 102J | PASS — 5 passed, 0 failed, 0 skipped |
| Related Phase 102B/C | PASS — 56 passed, 0 failed, 0 skipped; 61 including the separately executed Phase 102J tests |
| Full suite | PASS — 1985 passed, 0 failed, 1 unchanged historical skip; 143.1 s wall time |
| Formatter | PASS — 378 Dart files checked, 0 changed; 4.44 s |
| Analyzer | PASS — no issues found; 84.6 s |
| Windows release | PASS — 45.8 s Flutter build time; exit 0 |
| Native smoke | NOT RUN — production database isolation for native launch was not proven |

The sole historical skip remains the baseline skip in
`test/phase9a_inflows_outflows_reports_test.dart`; no skip was added. The
successful Windows build emitted the existing Firebase CMake minimum-version
deprecation warning and `.voltbl` linker warning. Two earlier sandboxed build
attempts timed out before compilation and did not update an artifact; the
required host-permitted build then completed successfully.

Windows release artifact:

- Path:
  `C:\dev\multi-pos\grain-warehouse-erp-lite\build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`
- Size: `784384` bytes.
- SHA-256:
  `961909D6367D297B02D9F74F6AA38BE3420600D6D9E4DCA6D2884B72793EACF3`.
