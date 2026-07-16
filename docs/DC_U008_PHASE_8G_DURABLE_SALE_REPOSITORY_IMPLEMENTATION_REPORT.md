# DC-U008 Phase 8G — Durable Sale Repository

## Status and baseline

- Local result: `PASS_PHASE_8G_DURABLE_SALE_REPOSITORY_LOCAL_READY`.
- Baseline branch, remote branch, and peeled tag all matched `c92076eed64f9fe1d69886477337bb75bfd0c5f5` with ahead/behind `0/0` and a clean worktree.
- Baseline tag: `dc-u008-durable-purchase-repository-pass`; baseline schema: v6.
- Phase branch: `dc-u008-durable-sale-repository`.

## Scope and contract

The existing `SaleRepository` contract remains `createSale`, `cancelSale`, and `listSales`. `DurableSaleRepository` only exposes the existing backup/wipe capabilities already implemented by `LocalSaleRepository`. No sales UI, pricing, inventory, account, financial, audit, return, payment, report, or authorization business rule was redesigned or migrated.

The actual aggregate is a multi-item `SaleRecord` with embedded `SaleLineItem` and `SalePaymentAllocation` lists. It carries customer and creator metadata, exact integer-qirsh totals, a primary stock movement reference, payment mode and paid amount, optional financial account/payment method, operation request ID, and cancellation metadata with reversal movement IDs. There is no separate invoice-number sequence and no return state owned by `SaleRepository`.

## Schema v6 → v7 and migration

Schema v7 adds one `sales` table. Scalar aggregate fields are columns; the two immutable embedded lists and cancellation reversal IDs are losslessly encoded as JSON text. The primary key is the existing sale ID. The operation request ID is unique when present. Indexes cover customer, creation order, request ID, and cancellation time.

Migration v6→v7 is additive and only creates `sales`. The focused migration fixture creates and populates the current schema, removes the v7-only table, marks it as v6, then proves upgrade preserves foundation and purchase rows and creates an empty usable sales table. No previous table, ID, sequence, or row is deleted or rebuilt.

## Repository and production wiring

`DriftSaleRepository` delegates validation, totals, item merging, minimum-price enforcement, stock effects, payment normalization, errors, and cancellation behavior to the characterized `LocalSaleRepository`. It changes only serialization and durability. Production initialization now replaces the local sale repository with `DriftSaleRepository` on the same `FoundationDatabase` and existing durable inventory/product repositories.

Operations are serialized without sleeps or retries. Writes use the shared Drift transaction, so durable inventory movements and the sale row commit together. The existing repository snapshot boundary remains available to `SaleController`; in-memory customer/financial participants continue to roll back through their snapshots. A durable sale snapshot restores rows after downstream participant failure. The existing time-plus-counter sale ID format is unchanged; restart safety follows the timestamp component, and no new invoice or sequence system was invented.

Restart tests prove scalar fields, item lines, payment allocations, creator/customer metadata, request IDs, ordering, cancellation state, reversal IDs, and inventory balance survive reopen. A repeated request after restart retains the characterized `StateError` behavior. Concurrent identical requests yield one logical sale. Wipe/restore preserves IDs and request metadata.

Backup restore and owner wipe now depend on `DurableSaleRepository`, preserving the existing backup JSON representation without changing its public format.

## Files

- Schema/migration/generated: `foundation_database.dart`, `foundation_database.g.dart`, `migration_strategy.dart`.
- Durable repository/contract: `drift_sale_repository.dart`, `sale_repository.dart`.
- Production wiring: `app_repositories.dart`.
- Backup/wipe integration: `backup_restore_service.dart`, `business_data_wipe_service.dart`.
- Tests: `phase8g_durable_sale_repository_test.dart` plus schema-version assertions in Phase 8A and Phase 8F.
- Documentation: this report.

## Verification evidence

- Focused Phase 8G run 1: 7/7 pass.
- Focused Phase 8G run 2: 7/7 pass.
- Direct sales, cancellation, multi-item, and Phase 8A–8F regressions: 86/86 pass.
- Full sequential suite: 996/996 pass in 179.4 seconds.
- Full default-concurrency suite: 996/996 pass in 99.7 seconds.
- Flutter analyzer: no issues found.
- Windows release build: pass in 75.7 seconds; `build/windows/x64/runner/Release/grain_warehouse_erp_lite.exe` produced as ignored build output. Only upstream CMake deprecation and linker section warnings were emitted.
- Drift generation reproducibility: SHA-256 stayed `A2ACD44477DDF7AF3F23ACD74EAC26508C1990DE212D927352D53982DF77528F` after a clean cache regeneration.
- `git diff --check`: pass before commit.
- Database artifact audit: no runtime database, WAL, SHM, or test database is tracked or staged.

## Scope audit and residual risk

The transaction coordinator remains a hybrid shared-Drift plus snapshot boundary; Phase 8G does not introduce a distributed transaction architecture. The durable adapter intentionally reuses the existing local domain implementation, reducing parity risk but retaining its time-based sale ID design. There is no separate invoice number in the current model.

Phase 8H was not started. No push, tag, merge, deploy, release, or remote mutation was performed.
