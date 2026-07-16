# DC-U008 Phase 8E — Durable Inventory Repository

## Status

`PASS_PHASE_8E_DURABLE_INVENTORY_REPOSITORY_LOCAL_READY`

Remote push remains blocked pending explicit approval. Phase 8F has not started.

## Baseline and scope

- Started from commit `3063f6b17db16f6e34799012f3c01c14d69a2493` and tag `dc-u008-durable-supplier-repository-pass` on schema v4.
- The baseline branch and remote were 0 ahead / 0 behind and the working tree was clean.
- `InventoryRepository` was the next direct dependency after the durable product repository. Production still used `LocalInventoryRepository`; product, customer, and supplier production repositories already used Drift.
- Purchase, sale, customer-account, supplier-account, and financial repositories were not migrated. No UI, cloud, deploy, release, or remote-push work was performed.

## Implementation

- Added `DriftInventoryRepository` while retaining `LocalInventoryRepository` for isolated tests.
- Added `DurableInventoryRepository` for restore, wipe, and transaction-snapshot capabilities without widening the existing read/write interface used by test doubles.
- Production initialization now constructs one Drift inventory repository over the production `FoundationDatabase`; downstream repositories and services receive that shared instance through the existing composition root.
- Backup restore and owner wipe accept the durable inventory contract and preserve their existing format and behavior.

## Schema v4 → v5

- Added the additive `inventory_movements` table. No prior table is dropped or rebuilt.
- Persisted: id, product id, movement type, integer quantity in kilograms, creator id, creation timestamp, note, void flag, reversed movement id, and original document id.
- Added indexes `inventory_movements_product_idx`, `inventory_movements_created_idx`, and `inventory_movements_document_idx`.
- Added the independent `inventory_movements` key in `repository_sequences`.
- No balance/current-stock cache exists. Balances remain sums of signed, non-voided movements.

## Invariants and transactions

- IDs retain the `stk-<microseconds>-<sequence>` contract and the sequence survives reopen and restore.
- Creation validates product existence/activity, positive quantity, one effective opening balance, and non-negative resulting stock.
- Queries are deterministic by creation timestamp then id.
- Inventory history is append-only during normal business operations; cancellations remain compensating movements.
- A create and its sequence update run in one Drift transaction. Repository snapshot rollback restores both rows and the effective next sequence for existing multi-repository coordinators.
- Restore is all-or-nothing into an empty repository; owner wipe removes movement rows and only the inventory sequence. Backup → wipe → restore preserves movement fields and derived balances.

## Files

- Production: persistence schema/migration, generated Drift database, inventory repository implementation/contract, production composition root, backup restore, and owner wipe service.
- Tests: new Phase 8E durability tests and the Phase 8A current-schema fixture updated from v4 to v5.
- Generated file was produced by `build_runner`, not edited manually.

## Verification

- Phase 8E focused run 1: 6/6 pass.
- Phase 8E focused run 2: 6/6 pass.
- Durable persistence Phase 8A–8E: 35/35 pass.
- Related inventory, product, purchase, sale, reports, history, backup, restore, wipe, and atomicity regressions: 211/211 pass.
- Full sequential suite: 982/982 pass.
- Full default-concurrency suite: 982/982 pass.
- `flutter analyze --no-pub`: no issues.
- `git diff --check`: pass.
- Windows release build: pass.
- Code generation reproducibility: pass; generated database SHA-256 remained `BF8675B925CDD425A94FE0671373212862911840263202B0A93036920A6A6695` after the second generation.

## Remaining risk

The legacy repository-wide transaction coordinator still uses repository snapshots for mixed in-memory/Drift participants rather than one cross-repository SQL transaction. Phase 8E preserves and verifies that established rollback contract; a general Unit of Work redesign is intentionally out of scope.

No push, deploy, release, or delivery package was created.
