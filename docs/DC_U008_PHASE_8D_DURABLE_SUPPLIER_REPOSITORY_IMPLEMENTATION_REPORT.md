# DC-U008 Phase 8D — Durable Supplier Repository

## Baseline and scope

- Baseline: `573c44810f35b7d421f77ef51a2da914ff68ed54`
- Branch: `dc-u008-durable-supplier-repository`
- Scope: migrate only `SupplierRepository` from the local in-memory production wiring to the shared Drift/SQLite database.
- Schema transition: version 3 to version 4.
- Excluded: supplier financial ledgers, purchases, inventory, sales, UI redesign, Phase 8E, deployment, and release publication.

The governing documents lock Phase 8C to durable customers on schema version 3 and state that Phase 8D had not started. Together with the already durable product and customer repositories and the remaining local supplier repository, the architecture and phase sequence establish the supplier repository as the next durable repository migration without a conflicting documented scope.

## Implementation

- Added the `suppliers` Drift table with the existing supplier domain fields and normalized uniqueness keys.
- Added the version 4 migration without recreating or deleting prior tables.
- Added `DriftSupplierRepository` with the existing create, update, active-state, ordering, validation, restore, wipe, and snapshot contracts.
- Reused `repository_sequences` under the independent `suppliers` namespace.
- Updated production composition to use `DriftSupplierRepository`.
- Generalized backup restore and owner wipe dependencies to `SupplierDataRepository`; the local implementation remains available for tests and fixtures.
- Regenerated `foundation_database.g.dart` reproducibly.

## Migration and transaction behavior

The v3-to-v4 migration creates only the suppliers table. Migration coverage proves preservation of foundation probes, customer rows, and existing repository sequences. File-backed reopen coverage proves supplier persistence and sequence continuation. Snapshot rollback coverage proves that supplier rows and the supplier sequence return to their pre-operation state after a failed repository transaction.

## Verification

- Focused Phase 8D before commit: `8/8 PASS` twice consecutively.
- Persistence Phase 8A–8D: `29/29 PASS`.
- Related supplier, purchase, transaction, restore, and owner-wipe regressions: `92/92 PASS`.
- Full sequential: `976/976 PASS`.
- Full default: `976/976 PASS`.
- Static analysis: `No issues found`.
- Drift generation reproducibility: PASS.
- Generated database SHA-256: `FD6B503C7FD707C761299E13E9E91CB9A28683005F85B1687717A54DA3938464`.
- Windows release build: PASS; Flutter log ended with `exiting with code 0` and produced `build/windows/x64/runner/Release/grain_warehouse_erp_lite.exe`.
- Release executable SHA-256: `79AC154C6F275A28FE53F78A5630A36AC07EFA286F3E840F9AFEAE23B75E8867`.
- Post-build focused Phase 8D: `8/8 PASS`.
- Post-build static analysis: `No issues found`.
- Database artifact audit: clean.

The Windows build recovery removed only the generated `build/windows/x64` cache. Visual Studio Build Tools 2026, MSVC 19.51, MSBuild 18.6, and Windows SDK 10.0.26100 were discovered successfully. The clean build completed with zero errors; no production or test source changes were made during toolchain recovery.

No deployment, release publication, push, or tag was performed. Phase 8E was not started.
