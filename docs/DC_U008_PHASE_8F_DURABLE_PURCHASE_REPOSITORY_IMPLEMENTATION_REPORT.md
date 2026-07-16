# DC-U008 Phase 8F — Durable Purchase Repository

## Status and baseline

- Local result: `PASS_PHASE_8F_DURABLE_PURCHASE_REPOSITORY_LOCAL_READY`.
- Remote push remains blocked pending explicit approval.
- Started from commit `99ee81a6986fcf8d87d5007c41390fe40212ff7d`, annotated tag `dc-u008-durable-inventory-repository-pass`, and schema v5.
- Phase 8E local and remote branch targets matched the baseline commit, the remote peeled tag matched it, ahead/behind was `0 0`, and the starting tree was clean.

## Scope decision and dependencies

Production still constructed `LocalPurchaseRepository`, while products, suppliers, and inventory were already Drift-backed. The current purchase aggregate is one `PurchaseIntake` header containing one product line; there is no separate item aggregate in the domain contract. Therefore one durable `purchases` table preserves the actual model without inventing a multi-item rule.

The repository continues to coordinate the existing inventory, supplier-account, financial-account, approval-through-financial-account, and audit effects through `RepositoryTransaction` snapshots. No dependent repository was migrated. Backup restore and owner wipe were changed only from the concrete local purchase type to the durable purchase contract.

No governing document contradicted `Phase 8F = Durable Purchase Repository`, and no multi-repository migration was required. Phase 8G was not started.

## Schema v5 → v6

Migration v6 additively creates `purchases`; no v1–v5 table is rebuilt or removed. It stores the purchase id, historical supplier fields, product, integer kilograms, entry unit, integer piaster/qirsh amounts, creator/time, stock movement link, notes, financial/payment fields, negative-balance approval reference, operation request id and fingerprint, and cancellation metadata/reversal movement ids.

Indexes cover supplier, creation ordering, product, and operation request. The purchase id is the primary key and operation request id is unique when present. Monetary values and quantities remain integers. The independent `purchases` repository sequence is stored in `repository_sequences`.

An authentic schema-v5 file migration test proves the existing probe row remains readable and the new table is empty and available at v6.

## Repository behavior

- `DriftPurchaseRepository` implements the complete existing purchase contract plus durable restore, wipe, and transaction snapshot capabilities.
- Creation validates active supplier/product references and positive exact values, allocates a durable id, creates inventory movement, persists the aggregate, then applies supplier, financial, and audit effects inside the established rollback boundary.
- Request replay returns the original purchase for the same payload, rejects changed payloads, and serializes concurrent calls so only one purchase and movement are created.
- Cancellation preserves the original row, persists cancellation metadata, creates one compensating stock movement, reverses supplier/financial effects, and is idempotent.
- Snapshot rollback restores purchase rows and sequence state. Restore validates ids, exact totals, and supplier/product references before inserting atomically. Wipe clears purchase rows and only the purchase sequence.
- Production initializes one `DriftPurchaseRepository` over the same `FoundationDatabase` and exposes it to reports, document history, backup, restore, and wipe through the shared composition root.
- `LocalPurchaseRepository` remains available for isolated tests and fixtures.

## Verification

- Focused Phase 8F run 1: 7/7 pass.
- Focused Phase 8F run 2: 7/7 pass.
- Durable and affected regression selection: 157/157 pass.
- Full sequential: 989/989 pass.
- Full default concurrency: 989/989 pass.
- Flutter analyze: no issues.
- Windows release build: pass (`grain_warehouse_erp_lite.exe` produced only as ignored build output).
- Drift generation reproducibility: pass; SHA-256 remained `F1CC3B1EC31E053C812D33FCE92484A7B9CA0FD48205F08802C1DF6194E2D2F6` across both generations, and the second produced zero outputs.
- `git diff --check`: pass.
- Database artifact audit: no new runtime database, WAL, SHM, temporary report, executable, secret, or IDE artifact is tracked. Two ignored log files predated this phase and were not modified.

## Exclusions and remaining risk

Sale, supplier-account, financial-account, audit, and approval repositories were not migrated. No accounting, negative-balance, unit, costing, UI, cloud, deployment, release, or remote operation changed.

The established mixed in-memory/Drift coordinator remains snapshot-based rather than a single cross-repository SQL transaction. Phase 8F preserves that existing contract and verifies rollback/replay behavior; a general unit-of-work redesign is outside scope.

No push was performed. The next action is explicit approval to push the Phase 8F branch and annotated tag.
