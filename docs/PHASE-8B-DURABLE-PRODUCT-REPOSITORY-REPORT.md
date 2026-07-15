# Phase 8B — Durable Product Repository Report

- Baseline: `9bf4e67a7e57778c9734377cb601b3a5aa681097`
- Branch: `dc-u008-durable-product-repository`
- Goal: migrate only `ProductRepository` to production SQLite/Drift persistence.
- Schema: version 1 → version 2.
- Added tables: `products`, `repository_sequences`.
- Preserved table: `foundation_probes`, including existing rows during v1 → v2 migration.

## Implementation

`DriftProductRepository` implements the unchanged `ProductRepository` contract and the maintenance/snapshot capabilities required by backup, restore, owner wipe, and repository transactions. Production startup awaits one application-support database and wires this repository before `runApp`. Tests and explicitly isolated compositions may continue using `LocalProductRepository`.

Product IDs retain the `prd-<microseconds>-<counter>` shape. The counter is stored transactionally in `repository_sequences`; create and counter advancement commit or roll back together. Name and optional code uniqueness remain trimmed and case-insensitive through normalized unique columns. Product rows are the sole production source of truth.

Snapshot capture and rollback now allow asynchronous implementations. The Drift snapshot reads durable rows and restores them, including the derived sequence, while existing synchronous in-memory snapshots remain compatible.

## Evidence

- Real v1 database migration preserves a populated `foundation_probes` row and supports create/read/reopen afterward.
- File reopen preserves products; later creates receive distinct IDs.
- Failed repository transaction restores both rows and sequence.
- 20 concurrent creates serialize without duplicate IDs or lost rows.
- Update, active filtering, uniqueness, wipe, restore, backup UI, and existing local contract tests pass.
- Focused Phase 8A/8B suite: 13/13 PASS twice consecutively.
- Drift generation repeated with identical SHA-256 output.

## Quality gates

- Related catalog, backup/restore, owner-wipe, snapshot, transaction, and Phase 7 ADR regressions: PASS.
- Full sequential suite: 960/960 PASS.
- Full default-concurrency suite: 960/960 PASS.
- `flutter analyze`: `No issues found`.
- `git diff --check`: PASS.
- Drift generation reproducibility: PASS; generated file SHA-256 remained `284630FE7670B44445CBCCCD28F39CFBEA707D85B63A91F02B10046968E41F0C`.
- Windows release build: PASS; `grain_warehouse_erp_lite.exe` produced.
- Database artifact audit: no tracked or untracked SQLite database, WAL, or SHM files found; existing `.gitignore` covers these artifacts.

Commit, tag, push, and local/remote verification are completed only after the final diff review.

## Scope and exclusions

Customer, supplier, inventory, sales, purchases, financial, advance, refund, and audit repositories were not migrated. Phase 8C was not started. No deploy was performed. No database file is committed. Durable persistence for the entire system is not claimed.
