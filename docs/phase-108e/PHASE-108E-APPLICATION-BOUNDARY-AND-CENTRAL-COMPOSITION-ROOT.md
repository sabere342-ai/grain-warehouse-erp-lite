# Phase 108E — Application Boundary and Central Composition Root

## 1. Final Outcome

**Outcome B — architecture complete / preserved harness blocker.**

The application now has explicit command and query contracts, an immutable application dependency bundle, a central production composition root, a shared-instance compatibility bridge, and one production command slice. Production behavior is preserved. The only full-suite failures are the same four protected Phase 107H branch-allowlist checks.

## 2. Baseline

- Required and actual baseline: `fe155b3d408fb84741cbf2b54a53956c07d467f3`.
- Baseline subject: `PHASE 108D: freeze application command query and composition root contracts`.
- Parent: `259a784c0b3a5e213ccf2c3b67a61901c5a33c65`.
- Branch: `codex/phase-108e-application-boundary-central-composition-root`.
- The intentional Phase 107H working-tree leftovers were present at the gate and were treated as protected baseline state.

## 3. Scope

Implemented the smallest viable boundary and composition infrastructure. No Supabase, outbox implementation, schema change, dependency change, Android change, accounting change, inventory change, or broad consumer migration was performed.

## 4. Pre-implementation inventory

| Candidate | Caller | Current access | Kind | Transaction/state | Financial impact | Inventory impact | Complexity |
|---|---|---|---|---|---|---|---|
| Dashboard guidance | `DashboardScreen` | Three `AppRepositories` reads | Query | None | Counts sales only | Counts movements only | Medium because protected historical source guards freeze this file |
| Trial evaluation/checkpoint | `main` and `TrialAppGate` | `TrialService` / `TrialEvaluator` | Command | Existing local trial-state checkpoint | None | None | Low; existing evaluator contract supports an injected bridge |
| Owner alerts | `DashboardScreen` | Six locator dependencies | Query | None | Reads balances | Reads low stock | Medium/high due fan-out |
| Audit-log load | `AuditLogsScreen` | Locator repository | Query | None | None | None | Low, but bootstrap trial slice provides stronger root proof with fewer production files |

## 5. Selected migration target

The selected target is trial evaluation/checkpoint. Although evaluation returns state, it may initialize or advance the durable local trial checkpoint, so it is correctly modeled as `EvaluateTrialCommand`, not as a query. It has no accounting, financial, inventory, schema, or domain-calculation impact. The existing `TrialEvaluator` behavior remains the implementation behind the handler.

## 6. Application Command Boundary

`ApplicationCommandRequest<C>` carries a typed command plus optional `BusinessContext` and idempotency key. `ApplicationCommandHandler<C, R>` exposes explicit execution. `EvaluateTrialCommandHandler` is the first concrete production handler and receives `TrialEvaluator` through its constructor; it does not access the locator.

## 7. Application Query Boundary

`ApplicationQueryHandler<Q, R>` and `ApplicationQueryResult<T>` are separate from command contracts. `QueryResultMetadata` is an extensible typed seam; `LocalQueryResultMetadata` describes current local results without freezing future server/cache/provisional semantics. No production query was migrated in this phase.

## 8. ApplicationDependencies design

`ApplicationDependencies` is immutable and grouped into:

- repositories: product catalog reads, inventory, and sales;
- services: the shared `TrialEvaluator`;
- runtime: a typed `BusinessContextProvider`.

Only dependencies needed to establish the real boundary and the next migration seams were included.

## 9. Composition Root design

`AppCompositionRoot.initializeProduction()` is the production assembly entry point. It initializes the existing repository graph, creates the production trial service, captures shared dependencies through the bridge, injects them into `EvaluateTrialCommandHandler`, and returns `ApplicationBoundary`. `main()` no longer initializes `AppRepositories` or `TrialService` independently.

## 10. Legacy compatibility bridge

`LegacyApplicationDependencyBridge.captureSharedInstances()` adapts the existing static repository registry into `ApplicationDependencies`. Legacy consumers continue to use `AppRepositories`; new handlers receive explicit dependencies. This establishes one production assembly authority while consumption migrates incrementally.

## 11. Shared instance proof

Tests assert identity, not only type equality:

- application product catalog repository is `same(AppRepositories.productCatalogReadRepository)`;
- application inventory repository is `same(AppRepositories.inventoryRepository)`;
- application sales repository is `same(AppRepositories.saleRepository)`;
- application trial service and injected evaluator are the same object;
- application and legacy bridge share the same database.

## 12. BusinessContext extension seam

`BusinessContext` contains typed `businessId` and `userId` fields. `BusinessContextProvider` is part of runtime dependencies. Phase 108E uses `NoBusinessContextProvider`, which returns `null` and changes no current behavior. Branding is not treated as tenant identity.

## 13. Idempotency extension seam

`ApplicationCommandRequest.idempotencyKey` is optional. No fake identifier is generated and no current command is required to provide one. Future local-outbox or server handlers can carry a stable real key without changing handler signatures.

## 14. Query provenance extension seam

Every application query result carries `QueryResultMetadata`. Future server-confirmed, cached, or provisional metadata can be added as new implementations without changing consumer result shape.

## 15. Future outbox extension seam

The `ApplicationCommandHandler` contract can be decorated by a durable intent/outbox handler before delegating to local or server execution. The concrete command handler does not know about global lookup or transport, so adding that decorator does not require rewriting the command request or UI call site. No outbox was implemented.

## 16. Transaction ownership impact

No accounting or inventory transaction ownership changed. Trial checkpoint persistence remains owned by the existing `TrialService`; the UI no longer selects that implementation. The application handler owns the command boundary and delegates the existing atomicity/state behavior unchanged.

## 17. Migrated production consumer

Startup executes `EvaluateTrialCommand` through `application.commands.trialEvaluation`. `TrialAppGate` receives the same handler as its `TrialEvaluator`, so every minute checkpoint follows:

`TrialAppGate -> EvaluateTrialCommandHandler -> injected TrialEvaluator -> existing trial state infrastructure`

This is the single Phase 108E production slice.

## 18. Behavior parity evidence

- The handler returns the exact evaluation object produced by its injected evaluator.
- Existing Phase 107G trial state-machine, expiry, rollback, corruption, persistence, and UI-gate tests pass unchanged.
- The initial evaluation and runtime checkpoint use the same handler and shared service instance.
- No trial state algorithm or message was changed.

## 19. Tests added

`test/phase108e_application_boundary_composition_root_test.dart` adds nine checks covering root construction, shared identity, handler injection, production adoption, behavior parity, legacy compatibility, command context/idempotency seams, query metadata seam, and no hidden locator access.

The superseded Phase 104J bootstrap source assertion was updated to recognize `AppCompositionRoot`; no Phase 107H protected test was edited.

## 20. Formatter

Final formatter command examined 11 affected Dart files and changed 0. An earlier implementation pass examined 14 files and changed 4; the final authoritative pass was clean after the slice was narrowed.

## 21. Analyzer

`flutter analyze`: **PASS — No issues found**.

## 22. Full tests

- Passed: **2,423**
- Skipped: **0**
- Failed: **4**

The four failures are exactly the protected branch-allowlist checks in:

- `phase106aj_migrate_drift_purchase_product_validation_reads_test.dart`;
- `phase106ak_reaudit_freeze_next_product_read_migration_target_test.dart`;
- `phase106al_negative_balance_approval_product_fingerprint_read_migration_test.dart`;
- `phase106am_profitability_activation_product_read_migration_test.dart`.

All fail because the current branch is Phase 108E instead of their last accepted Phase 107H branch. The related historical guard run produced 111 passes and exactly these 4 failures. There is no fifth failure.

## 23. Windows release build

`flutter build windows --release`: **PASS**. Artifact: `build/windows/x64/runner/Release/grain_warehouse_erp_lite.exe`.

CMake emitted an upstream minimum-version deprecation warning and MSVC emitted the existing multiple-`.voltbl` linker warning; neither failed the build.

## 24. Protected Phase 107H status

- Tracked binary diff hash: `9256c16945f49b36957a204b6dc108c412ade96b` (unchanged).
- Files compared: 33.
- SHA-256 mismatches: 0.
- Protected mutations by Phase 108E: 0.

## 25. Production diff

Expected production changes are limited to:

- `lib/main.dart`;
- `lib/application/**`;
- `lib/composition/**`.

Unrelated production diff: **0**. Trial implementation, dashboard, app shell, repositories, accounting, and inventory behavior are unchanged.

## 26. Schema diff

**0**. No database, generated Drift, migration, or schema-version file changed.

## 27. Dependency diff

**0**. `pubspec.yaml` and lockfiles are unchanged; no DI framework or other package was added.

## 28. Platform diff

**0**. No Windows, Android, mobile, or other platform source/configuration file changed.

## 29. Remaining legacy composition-root consumers

- Before: 43 feature/shared files, 152 `AppRepositories.*` references.
- After: 43 feature/shared files, 152 references.
- Migrated in 108E: one trial UI/bootstrap command slice; it was outside the 108D feature/shared locator inventory.
- Remaining: all 43 inventoried files / 152 references.

The count is intentionally unchanged: Phase 108E establishes central construction and one explicit boundary path, not a locator-removal campaign.

## 30. Risks / unresolved items

- Repository object creation still occurs inside the legacy `AppRepositories.initializeProduction()` bridge. The new root is the sole production caller, but construction should move outward incrementally in later phases.
- The first migrated slice is a local licensing command; no repository-backed business query has yet moved behind the query handler contract.
- `NoBusinessContextProvider` is deliberately non-tenant-aware.
- Idempotency, server execution, durable outbox, cloud consistency, and Supabase remain unimplemented.
- The 43 feature/shared locator consumers remain migration work.

## 31. Recommended next phase

Phase 108F should migrate one read-only, low-fan-out `AppRepositories` UI query into `ApplicationQueryHandler`, add concrete local provenance metadata, and pass its handler explicitly from the composition root. It should preserve the bridge and avoid accounting/inventory mutation, schema work, Supabase, or broad consumer migration.
