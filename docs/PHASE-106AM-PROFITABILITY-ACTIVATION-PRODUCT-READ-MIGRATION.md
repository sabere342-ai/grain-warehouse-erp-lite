# Phase 106AM - Profitability Activation Product Read Migration

## 1. Status

CLOSED - PRC-108 is migrated, every required formatting, analysis, test,
architecture, build, and diff gate passed, and the final commit/tag closure
described below is the required final state.

## 2. Governance

| Evidence | Value |
| --- | --- |
| Starting branch | `codex/phase-106al-migrate-negative-balance-approval-product-fingerprint-read` |
| Starting HEAD | `bc17876148074efab3f2a5ec1a71186eaad4e4c5` |
| Starting worktree | clean |
| Previous verified tag | `phase-106al-negative-balance-approval-product-fingerprint-read-migration-verified` |
| Previous tag type/target | annotated tag / `bc17876148074efab3f2a5ec1a71186eaad4e4c5` |
| Phase-number reservation | no Phase 106AM branch, tag, document, or implementation existed |
| New branch | `codex/phase-106am-migrate-prc-108-product-read` |
| Push | not requested; must not be performed |

The current code, tests, Phase 106AL report, annotated tag, and clean Git state
all agreed with the required baseline before the new branch was created.

## 3. Discovery

PRC-108 is `ProfitabilityActivationService.activate` in
`lib/core/inventory_valuation/profitability_activation_service.dart`. Its sole
legacy product read was `ProductRepository.listProducts(includeInactive:
true)`. The returned complete ordered set controls opening-decision count and
membership validation, inventory quantity/cost/evidence checks, valuation
opening order, and the audited `productCount` inside the atomic valuation/audit
activation.

The existing `ProductCatalogReadRepository.listProductCatalog` contract is a
complete creation-time/id-ordered snapshot, includes inactive rows when asked,
and exposes the required non-null `id`. The Drift implementation uses the same
database products table and deterministic ordering. No contract expansion,
schema change, generated edit, or database migration is required.

Behavior retained: authorization/date/note checks still precede the read;
inactive products remain included; opening IDs remain trimmed, non-empty, and
unique; count and membership errors are unchanged; product iteration still
drives stock validation and valuation opening order; read errors propagate;
transaction boundaries, rollback, audit metadata, financial state, and
inventory behavior are unchanged.

## 4. Implementation

Production changes are confined to:

- `lib/core/inventory_valuation/profitability_activation_service.dart`, which
  replaces only the legacy read dependency and its one call with the canonical
  catalog contract.
- `lib/app/app_repositories.dart`, which injects the existing application
  `productCatalogReadRepository` into PRC-108.

The existing Phase 102B and 102C construction sites use the established test
adapter. The Phase 106AM guard uses direct canonical fakes to distinguish this
boundary from the legacy writer and to prove inactive inclusion, stable order,
error propagation, and absence of unintended writes.

Test changes are confined to the two direct Phase 102 construction sites, the
new `test/phase106am_profitability_activation_product_read_migration_test.dart`
guard, and the existing Phase 106 architecture guards whose live-source
inventories, cumulative allowlists, or lineage metadata had to recognize the
one PRC-108 call movement. Historical commit assertions and historical report
facts remain pinned to their immutable revisions; no historical production
behavior expectation was weakened.

PRC-111 and all infrastructure/test legacy consumers remain unchanged.

## 5. Product-read Migration State

Baseline verified before the change:

```text
Total known consumers: 24
Migrated consumers: 17
Remaining consumers: 7
Production remaining: 2
Infrastructure/Test remaining: 5
Legacy calls: 8
Canonical catalog calls: 18
```

Recount after migrating only PRC-108:

```text
PRC-108: MIGRATED
PRC-111: REMAINING - Production

Total known consumers: 24
Migrated consumers: 18
Remaining consumers: 6
Production remaining: 1
Infrastructure/Test remaining: 5
Legacy calls: 7
Canonical catalog calls: 19
```

The one-call movement is explained exactly by
`ProfitabilityActivationService.activate`: its legacy call disappeared and its
canonical call appeared. The six remaining consumers are PRC-111 and
infrastructure/test PRC-114 through PRC-118; PRC-114 owns two legacy calls.
PRC-109 still owns two canonical calls, so 18 migrated consumers own 19 calls.

## 6. Verification

- `dart format .`: 418 files examined, 0 changed in the final run.
- `flutter analyze --no-pub`: no issues found.
- Focused PRC-108 and affected Phase 102 suites: 46 passed, 0 skipped,
  0 failed.
- All Phase 106 guards, executed in five bounded groups: 370 passed,
  0 skipped, 0 failed (53 + 60 + 77 + 67 + 113).
- Full `flutter test`: 2,361 passed, 1 historical skip, 0 failed.
- `flutter build windows --release --no-pub`: exit 0; release executable built
  in 104.1 seconds at
  `build/windows/x64/runner/Release/grain_warehouse_erp_lite.exe`.
- `git diff --check`: passed; line-ending notices were warnings only.

The Windows build emitted only the existing Firebase CMake deprecation warning
and linker LNK4078 warning about multiple `.voltbl` section attributes. Neither
changed the exit code or artifact production.

Initial sandboxed Dart/Flutter commands exhausted their timeout because the SDK
lock was not available inside the restricted process. Re-running the exact
gates with the required SDK access completed successfully; no repository file
was changed to work around the environment.

## 7. Architecture and Safety Audit

- Schema change: none.
- Database migration: none.
- Generated-file change: none.
- PRC-111 migration: none.
- Unrelated consumer migration: none.
- Business, permission, accounting, inventory, or UI behavior rewrite: none.
- Product write introduced by the canonical contract: impossible; the injected
  boundary exposes only `listProductCatalog`.

## 8. Git Closure

The implementation, tests, guard maintenance, and this report are closed in a
single direct child of the Phase 106AL verified baseline with subject
`PHASE 106AM: migrate profitability activation product read`. The immutable
commit ID and tag-target equality are reported in the final handoff because a
commit cannot embed its own hash without becoming self-referential.

Required annotated tag:
`phase-106am-profitability-activation-product-read-migration-verified`.

The final worktree must be clean. No push was requested or performed.

## 9. Next Phase Recommendation

Do not begin it in Phase 106AM. The next and only remaining production product
read is PRC-111 in `lib/core/sales/sale_repository.dart`; it requires its own
phase because it spans sale validation, inventory, valuation/COGS, accounts,
and rollback behavior.
