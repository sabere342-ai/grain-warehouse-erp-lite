# Phase 8C — Durable Customer Repository Report

## Status and scope

- Target: `PASS_PHASE_8C_DURABLE_CUSTOMER_REPOSITORY_LOCKED`
- Branch: `dc-u008-durable-customer-repository`
- Baseline: `184c7fecefe82d19f091a11fd539b0a42295ffb5`
- Scope: migrate only `CustomerRepository` to Drift in production.
- Explicit exclusions: supplier and financial repository migration, customer ledger migration, sales/collections/advances/refunds migration, UI redesign, backup-format redesign, schema v4, Phase 8D, deployment, and production release.

## Schema and migration

Schema version changes from 2 to 3. The only new table is `customers`, containing the existing customer-owned profile fields: stable text ID, name and normalized name, optional phone and normalized phone, optional notes, active state, and created/updated timestamps. Existing `foundation_probes`, `products`, and `repository_sequences` tables are preserved. The registered v2-to-v3 migration creates `customers` without destructive fallback.

## Customer ownership map

`CustomerRepository` owns customer identity/profile rows and the `customers` sequence namespace. It reads no financial balances and stores no derived balance. Sales, collections, ledger entries, advances/refunds, and reports retain their existing ownership and continue referencing stable customer IDs.

## Repository behavior and wiring

`DriftCustomerRepository` preserves create, update, active-state, list ordering, validation, normalization, uniqueness, and not-found behavior. Production startup selects it after opening the one application-support database; explicit test composition can still use `LocalCustomerRepository`. IDs retain the `cus-<microseconds>-<sequence>` shape and use the namespaced, transaction-safe `repository_sequences` row. Product and customer sequences are independent.

Restore-to-empty, owner wipe, and repository transaction snapshots use the shared `CustomerDataRepository` maintenance contract. Customer state and sequence participate in rollback. Existing JSON backup fields remain unchanged, and restored customers persist after database reopen.

## Verification evidence

- Focused Phase 8C run 1: 7/7 PASS; final expanded suite: 8/8 PASS with explicit production-wiring coverage.
- Focused Phase 8C run 2: 8/8 PASS.
- Migration/reopen/concurrency/rollback/sequence isolation: covered by `phase8c_durable_customer_repository_test.dart`.
- Phase 8A/8B/ADR regressions: 24/24 PASS. Owner wipe: 16/16 PASS. The selected customer, backup/restore, sales, collections, advances/refunds, and reporting regressions passed in the pre-full-suite regression run.
- Full sequential suite: 968/968 PASS in 2:27.
- Full default suite: 968/968 PASS in 1:00.
- Static analysis: PASS (`No issues found`) before final gate run.
- Diff check: PASS before final gate run.
- Drift generation: two PASS runs; generated database SHA-256 remained `3B5C04136148FEA29FEF49991D227219B3048448D0E123346D08F90CC7640F1D`.
- Windows release build: PASS; produced `build/windows/x64/runner/Release/grain_warehouse_erp_lite.exe`.
- Database artifact audit: clean outside ignored build/tool caches.

## Remaining risks and closure

Only customers and products are durable; mixed durable/in-memory repository rollback uses the existing snapshot coordinator. Phase 8D has not started. No deployment was performed. Commit, tag, remote verification, and final clean-tree evidence are recorded only after every quality gate passes.
