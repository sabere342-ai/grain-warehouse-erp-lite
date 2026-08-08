# Phase 106AL - Negative Balance Approval Product Fingerprint Read Migration

## 1. Status

CLOSED - PRC-105 is migrated, every required verification gate passed, and the
single-commit/tag Git closure described below is the required final state.

## 2. Governance

| Evidence | Value |
| --- | --- |
| Starting branch | `codex/phase-106ak-reaudit-freeze-next-product-read-migration-target` |
| Starting HEAD | `43384cdf3a2252b2e8b793ef3c2ce8aa5e23052c` |
| Starting subject | `PHASE 106AK: freeze next product read migration target` |
| Starting worktree | clean |
| Phase 106AK tag | none exists; Phase 106AK explicitly closed without a tag |
| Phase 106AK tag type/target | N/A |
| Phase-number reservation | no existing Phase 106AL branch, tag, document, or implementation; only the 106AK recommendation existed |
| New branch | `codex/phase-106al-migrate-negative-balance-approval-product-fingerprint-read` |
| Push | not requested and not performed |

The current code, tests, schema, and Phase 106AK frozen inventory all agreed:
PRC-105 was the sole frozen target. There was no baseline mismatch.

## 3. Discovery

PRC-105 consists of
`NegativeBalanceApprovalWorkflowService._findProduct/_requireProduct` in
`lib/core/financial_accounts/negative_balance_approval_workflow_service.dart`.
`submitPurchase` uses the required lookup to validate an active product and
persist its identity and timestamp fingerprint in a pending paid-purchase
request. `_staleReason` uses the same lookup during approval to detect a
missing, inactive, or timestamp-changed product before any execution writes.

The legacy dependency was `ProductRepository _productRepository`; the only
source call was `listProducts(includeInactive: true)` inside `_findProduct`.
The operation consumes only non-null `id`, `isActive`, and `updatedAt`.
Its purposes are validation, durable fingerprint evidence, audit/history
identity preservation, and stale/conflict detection.

The existing `ProductCatalogReadRepository.listProductCatalog` contract is the
canonical replacement. `ProductCatalogReadModel` already carries all three
required fields, and the Drift adapter reads them directly from the products
table in creation-time/id order. No API, contract, schema, generated file, or
database migration was needed.

Frozen behavior retained: blank input returns null before a read; nonblank
input is trimmed; the first exact returned ID wins; inactive rows are included;
missing and inactive required products retain the same error; the exact UTC ISO
timestamp is stored and compared; read failures propagate; and validation,
authorization, transaction, accounting, inventory, audit, and write ordering
remain unchanged.

## 4. Implementation

Production changes are confined to exactly two files:

- `lib/core/financial_accounts/negative_balance_approval_workflow_service.dart`
  replaces the read-only product dependency, helper return types, and single
  list call with the existing catalog contract. No control flow or write path
  changed.
- `lib/app/app_repositories.dart` injects the already-existing production
  `productCatalogReadRepository` into the workflow. The legacy product writer
  and all unrelated consumers remain unchanged.

Three direct test composition sites receive the existing test adapter. The
Phase 82 workflow suite additionally injects a controllable catalog fake so
its assertions distinguish the canonical snapshot from the legacy product
repository rather than merely observing equivalent adapter output.

## 5. Tests

Migration-specific behavioral coverage proves:

- a paid-purchase request stores the canonical catalog timestamp even when it
  differs from the legacy repository timestamp;
- `includeInactive: true` and first-exact-match behavior are retained;
- an inactive first duplicate, blank ID, missing product, and read error create
  no request, purchase, inventory movement, or financial balance change;
- a changed canonical timestamp marks approval stale without executing writes;
- the request payload/history retains the product ID;
- the production source has no PRC-105 legacy read and composition injects the
  canonical repository.

Final verification results:

- Focused PRC-105/Phase 82 run: 37 passed, 0 skipped, 0 failed.
- Phase 106 guard suites, run in five bounded groups: 362 passed, 0 skipped,
  0 failed (77 + 82 + 107 + 60 + 36).
- Full `flutter test`: 2,353 passed, 1 historical skip, 0 failed.

## 6. Static and Build Gates

- `dart format .`: 417 files examined, 0 changed.
- `flutter analyze --no-pub`: no issues found.
- Focused tests: 37 passed, 0 skipped, 0 failed.
- Phase 106 guards: 362 passed, 0 skipped, 0 failed.
- Full `flutter test`: 2,353 passed, 1 historical skip, 0 failed.
- `flutter build windows --release --no-pub`: exit 0; release executable built
  in 103.9 seconds. The Firebase CMake deprecation and linker LNK4078 messages
  were warnings only.
- `git diff --check`: passed.

Two earlier sandboxed build attempts timed out because Flutter could not write
its SDK lockfile outside the workspace. A direct Dart diagnostic exposed that
permission error; rerunning the same Flutter build with the required SDK access
completed successfully. No product source or project configuration was changed
to work around the environment restriction.

## 7. Product-read Migration State

```text
PRC-105: MIGRATED
PRC-108: REMAINING - Production
PRC-111: REMAINING - Production

Total known consumers: 24
Migrated consumers: 17
Remaining consumers: 7
Production remaining: 2
Infrastructure/Test remaining: 5
Legacy calls: 8
Canonical catalog calls: 18
```

The seven remaining consumers are PRC-108, PRC-111, and infrastructure/test
PRC-114 through PRC-118. PRC-105 owns one migrated catalog call. The 17
migrated consumers own 18 catalog calls because PRC-109 owns two. The seven
remaining consumers own eight legacy calls because PRC-114 owns two.

## 8. Git Closure

The implementation, tests, and this report are intentionally closed in the
single direct child of the Phase 106AK baseline, with subject:
`PHASE 106AL: migrate negative balance approval product fingerprint read`.
The immutable commit ID and tag-target equality are reported in the final
handoff after Git creates them; embedding a commit's own hash in its contents
would be self-referential.

Required and verified annotated tag:
`phase-106al-negative-balance-approval-product-fingerprint-read-migration-verified`.

The final worktree must be clean. No push was requested or performed.

## 9. Follow-ups

No out-of-scope product defect was identified. The only incidental issue was
the sandbox denial on Flutter's SDK lockfile described in the build gates; the
authorized rerun passed and requires no repository change.

## 10. Next Phase Recommendation

Do not begin it in Phase 106AL. The smallest remaining Production product-read
migration target is PRC-108,
`ProfitabilityActivationService.activate`, because PRC-111 retains the wider
sale/inventory/COGS/accounts/rollback surface. PRC-108 requires its own
accounting-focused freeze and migration phase.
