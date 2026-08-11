# Phase 108D — Application Command/Query Boundary and Composition-Root Contract Freeze

## 1. Executive Summary

Phase 108D is a documentation and contract-freeze phase. It does not add Supabase, networking, schema changes, production behavior, or UI changes.

The current application has useful command-like controllers and services, a dedicated `ProductCatalogReadRepository`, and several well-characterized local transaction/idempotency mechanisms. It does **not** have a uniform Application Command Boundary or Application Query Boundary. Infrastructure construction is concentrated in `AppRepositories`, but dependency resolution and controller/service construction are distributed across the UI. The result is a static service locator rather than a complete composition root.

The target is a pragmatic command/query boundary:

`UI -> Application Command/Query -> Handler -> Domain Rules -> Infrastructure Port -> Local/Cloud/Hybrid Adapter`

The freeze requires a central, environment-aware composition root; typed command/query envelopes and results; verified `SessionContext`/`BusinessContext`; server-authoritative transactions for accounting/inventory; and an O3 durable outbox/equivalent whose local provisional mutation is atomic with its sync intent.

Current audit evidence:

- 232 Dart files under `lib/`.
- 21 source files declaring repository abstractions (excluding generated Drift code).
- 15 controller source files.
- 43 feature/shared files reference `AppRepositories` directly.
- 152 `AppRepositories.*` references exist in feature/shared code.
- SQLite schema version is 15 with 30 declared Drift tables.
- No production, schema, dependency, or platform file is changed by this phase.

Machine-readable inventories are in [commands.tsv](evidence/commands.tsv), [queries.tsv](evidence/queries.tsv), [composition-root-inventory.tsv](evidence/composition-root-inventory.tsv), and [architectural-violations.tsv](evidence/architectural-violations.tsv).

## 2. Baseline Verification

Required baseline: `259a784c0b3a5e213ccf2c3b67a61901c5a33c65` (`PHASE 108C: freeze cloud operating model and data authority`).

Verification before any phase change:

| Check | Result |
|---|---|
| Initial branch | `codex/phase-107h-governed-14-day-trial-windows-package-acceptance` |
| Initial `HEAD` | `259a784c0b3a5e213ccf2c3b67a61901c5a33c65` |
| Required parent | `5aeb41b7cd5e8c1919d6e0a7cb6544c85d799054` |
| Commits after baseline | `0` |
| Baseline gate | PASS |
| Phase branch | `codex/phase-108d-application-command-query-boundary-composition-root-freeze` |

Recent history at the gate:

```text
259a784 PHASE 108C: freeze cloud operating model and data authority
5aeb41b PHASE 108B: close transfer double-count accounting scenario
e0e4ddf PHASE 108A: re-audit and reorder implementation priorities
e2b425a PHASE 107G: enforce 14-day local trial
7b4da07 PHASE 107F: govern client backup and data-path documentation
```

The intentional Phase 107H leftovers were present and were not treated as failure:

- four modified `test/phase106a*.dart` files;
- untracked `docs/phase-107h/` evidence;
- untracked `tools/phase107h/` scripts.

Their pre-change binary diff hash is `9256c16945f49b36957a204b6dc108c412ade96b`; the per-file SHA-256 inventory is recorded in [preserved-107h-fingerprint-before.txt](evidence/preserved-107h-fingerprint-before.txt). The same calculation is repeated after commit in Section 23.

## 3. Scope / Non-Scope

In scope: source audit; command/query inventories; composition and transaction ownership; direct UI/infrastructure couplings; frozen future contracts; O3 provisional/idempotency/business context/query consistency decisions; violations; and atomic migration sequence.

Out of scope and not performed: Supabase project/client/dependency; SQL/schema/RLS/`business_id` implementation; cloud auth; networking; repository migration; production accounting/inventory behavior changes; sync/outbox implementation; backup/trial behavior changes; UI/Android/platform changes; broad renames or cleanup.

## 4. 108C Governing Decisions

These decisions are inherited without reopening:

- Cloud authority: Supabase is final authority for shared data; SQLite becomes local cache/offline store.
- Sync: S4 hybrid synchronization.
- Offline: O3; offline financial/inventory mutations are provisional until server acceptance.
- Accounting/inventory: server-authoritative, atomic, idempotent, and deterministically conflict-resolved.
- Tenant isolation: Supabase Auth + `business_id` + RLS from the first cloud schema.
- Critical operations: server-side RPC/database function/transactional equivalent, never client-only multi-step writes.
- Backup: export/migration artifact, not authoritative cloud restore.
- Trial/licensing: current 14-day local trial is transitional; future licensing is server-authoritative.

## 5. Current Architecture Inventory

The full component inventory is [composition-root-inventory.tsv](evidence/composition-root-inventory.tsv). Important facts from source:

| Area | Current fact | Classification |
|---|---|---|
| Bootstrap | `main()` initializes Flutter, Firebase, `AppRepositories`, local trial, then `TrialAppGate` | Bootstrap/partial root |
| Database | `openProductionDatabase()` opens `grain_warehouse_erp.sqlite3`; `FoundationDatabase` owns Drift schema and `inTransaction` | SQLite adapter/transaction boundary |
| Global registry | `AppRepositories` owns mutable static repositories, DB, and service getters | Service locator/global state |
| App shell | `GrainWarehouseApp.initState` constructs Auth/Theme/BusinessIdentity controllers and two Local repositories | Secondary root inside UI |
| Controllers | 15 `ChangeNotifier` controllers mix screen query state, permission checks, command calls, and localized errors | UI controllers; partial application services |
| Repositories | Interfaces commonly combine reads, commands, restore/wipe, transaction snapshots, and business rules | Mixed CQ/persistence/domain boundary |
| Drift adapters | Implement storage, but several delegate to/subclass local repositories containing business rules | Infrastructure plus business logic |
| Query services | Dashboard/report/profitability services aggregate repositories client-side | Query-handler candidates |
| Trial | `TrialService.production()` constructs file store and clock internally | Transitional licensing composition |
| Auth | Local/Drift repository plus app-scoped `AuthController/AuthScope` | Partial session boundary; no tenant context |

Business logic found inside repositories includes sale minimum-price/stock/COGS/cancellation rules; purchase routing/inventory/payable/cash rules; customer/supplier balance, advance and approval rules; financial transfer/closing/negative-balance rules; and valuation algorithms. This is a migration constraint: rules must be preserved and characterized, then invoked behind handlers; they must not be casually rewritten.

Business/application logic found in UI-facing controllers includes sale multi-repository orchestration, inventory adjustment evidence/valuation/audit orchestration, authorization checks, payment routing, reversal lookup, and localized error translation. Several screens also calculate command inputs and invoke repositories/services directly.

## 6. Current Command Paths

The complete mutation inventory and table/impact classification is [commands.tsv](evidence/commands.tsv). Representative paths are:

```text
SalesScreen
  -> SaleController.createSale
  -> SaleRepository.createSale
  -> InventoryRepository + InventoryValuationRepository
  -> CustomerAccountRepository
  -> FinancialAccountRepository.createEntry
```

`SaleController` is the effective command handler and cross-repository transaction coordinator. It is also a Flutter `ChangeNotifier`, query loader, permission checker, and UI error formatter.

```text
PurchasesScreen
  -> PurchaseController OR NegativeBalanceApprovalWorkflowService
  -> PurchaseRepository.createPurchaseIntake
  -> Inventory + Valuation + SupplierAccount + FinancialAccount + Audit
```

Here the purchase repository implementation is the effective command handler. The controller is thin.

```text
SupplierStatementScreen/SuppliersScreen
  -> SupplierAccountRepository.createPayment directly
  -> Supplier ledger + Financial account + Approval + Audit
```

This is a direct UI-to-write-repository violation.

```text
Inventory screens
  -> InventoryController.createOpeningBalance/manual increase/manual decrease
  -> Inventory + Valuation + Audit
```

`InventoryController` is an application-service candidate but is Flutter-shaped.

```text
NegativeBalanceApprovalRequestsScreen
  -> NegativeBalanceApprovalWorkflowService.approveAndExecute/reject/cancel
  -> auth re-verification + durable request + wrapped financial command + audit
```

The workflow service is the strongest existing application-command precedent: it has explicit orchestration, stale checks, idempotency/fingerprint data, and a supplied durable transaction runner. It is still reached through the global locator and binds directly to many repository verbs.

Absent as separate use cases: sale returns and purchase returns are modeled as cancellation/reversal, not return documents; no warehouse-transfer command was found; no purchase-order/receive split was found; and no general user-management command beyond first-owner/session operations was found.

## 7. Current Query Paths

The query inventory is [queries.tsv](evidence/queries.tsv). Current query styles are:

1. Controller facade, e.g. `ProductController`, `FinancialAccountController`, `DocumentHistoryController`.
2. Query service, e.g. `DashboardService`, `FinancialReportService`, `ProfitabilityReportService`.
3. Dedicated read repository, currently strongest in `ProductCatalogReadRepository`.
4. Direct screen-to-repository reads, common in dashboard, statements, accounts, reports, payment dialogs, profitability, and alerts.
5. Export/print services reaching `AppRepositories.businessIdentityRepository` globally.

Most current sources of truth are SQLite tables or client-side aggregates over SQLite. Business identity/logo and trial state use local preferences/files. The current auth session is partly in-memory while users are in SQLite.

No current query result carries source provenance, `asOf`, confirmed-through position, staleness, business scope, or provisional-overlay metadata. Therefore a screen cannot reliably distinguish server-confirmed, cached-confirmed, or provisional values.

A concrete wiring hazard is `AppRepositories.reportRepository`: it is `static final`, captures whichever repository instances exist on its first lazy access, and can never be rebound if the environment/business graph changes later. Normal `main()` ordering makes first production access likely occur after initialization, so this audit does not claim a current report failure; the immutable capture is nevertheless a V1 blocker for runtime adapter/business-scope replacement.

## 8. Current Composition Root

### Answers

1. The current root is `main()` + `AppRepositories.initializeProduction()` + `GrainWarehouseApp.initState` + screen-local constructors.
2. It is distributed, not one root. Infrastructure is mostly centralized in a static locator, while presentation/application wiring is distributed.
3. SQLite implementations are created in `AppRepositories.initializeProduction`; the database itself is created by `database_opener.dart`.
4. Abstractions are passed into repository constructors in `AppRepositories`, then controllers/services receive them in app/screen state—usually fetched from the same global locator.
5. Feature UI does not directly instantiate Drift repositories, but `GrainWarehouseApp` directly instantiates Local theme/business identity repositories.
6. Yes. Hidden dependency creation exists through `AppRepositories` getters, screen `initState` controller/service construction, and global static access.
7. The blockers to selectable Local/Cached/Cloud/Hybrid adapters are static globals, undeclared lifetimes, mixed CQ repository contracts, UI-created controllers/services, business workflows embedded in repositories/controllers, and missing Session/BusinessContext/provenance contracts.

### Practical graph

```text
main
├─ FirebaseBootstrap (provider global)
├─ AppRepositories.initializeProduction
│  ├─ FoundationDatabase (process singleton)
│  ├─ Drift repositories (process statics)
│  ├─ Local-only approval/identity pieces
│  └─ transient service getters
├─ TrialService.production (separate local file graph)
└─ GrainWarehouseApp
   ├─ AuthController <- AppRepositories.authRepository
   ├─ ThemeController <- new LocalThemeSettingsRepository
   ├─ BusinessIdentityController <- new LocalBusinessIdentityRepository
   └─ routes -> screens
      ├─ new controllers/services <- AppRepositories statics
      └─ direct AppRepositories queries/commands
```

## 9. Direct UI-to-Infrastructure Couplings

`rg` source evidence finds 43 feature/shared consumer files and 152 direct `AppRepositories.*` references. Exact per-file counts are frozen in [app-repositories-consumers.txt](evidence/app-repositories-consumers.txt); high-risk direct writes are separately listed in [architectural-violations.tsv](evidence/architectural-violations.tsv).

High-risk examples:

- supplier statement/supplier screens call `createPayment` directly;
- supplier screen calls `createOpeningBalanceEntry` directly;
- financial closing screen calls `createClosing`/`reopenClosing` directly;
- profitability screen calls activation service directly;
- approval screen calls workflow resolution directly;
- wipe/restore screens call services resolved from global locator;
- many financial reports and dashboard sections read repositories directly.

The target rule is frozen: UI may construct presentation-only request values and render typed results, but it must never select infrastructure, invent `businessId`, execute a business mutation via a repository, or compose multiple writes.

## 10. Transaction Ownership Findings

Current ownership is inconsistent:

- Drift repositories frequently own per-repository SQLite transactions.
- `RepositoryTransaction` serializes process operations and captures/rolls back `SnapshotHolder`s; this is in-process compensation, not an authoritative database/cloud transaction.
- `SaleController` owns a multi-repository snapshot boundary.
- purchase/customer/supplier/expense repositories own multi-repository workflows.
- `NegativeBalanceApprovalWorkflowService` owns an application workflow and may receive `database.inTransaction` from the locator.
- `BusinessDataWipeService` receives a DB transaction runner and wraps repository snapshots.
- `BackupRestoreService` uses repository snapshots across many adapters without a supplied single database transaction.

Frozen rules:

1. **A business command owns one logical transaction boundary.**
2. UI never performs repository A/B/C writes.
3. The local adapter may implement that boundary with a database Unit of Work.
4. In cloud authority, one server RPC/function/transactional operation owns the authoritative transaction.
5. Local O3 execution atomically persists the provisional local projection and its durable command/outbox intent.
6. Snapshot rollback may remain a characterized local implementation detail temporarily; it is not the cloud contract.

The Phase 108B transfer invariant remains mandatory: 3,000 EGP moves 10,000→7,000 and 2,000→5,000; combined 12,000; revenue/expense/profit deltas zero; duplicate delivery has no duplicate effect.

## 11. Future Command Boundary Contract

### Naming and shape

- Command: imperative `VerbNounCommand` (`CreateSaleCommand`, `TransferAccountFundsCommand`).
- Handler: `<CommandName>Handler` with `Future<CommandResult<T>> handle(CommandEnvelope<Command>)`.
- Port: use-case-specific (`SaleCommandGateway`), not generic CRUD or a speculative CQRS framework.
- DTOs are immutable, versioned, transport-safe, use integer qirsh/kg units, and contain IDs rather than repository/domain objects.

Conceptual envelope:

```text
CommandEnvelope<T> {
  commandId,              // client-generated at intent creation; stable forever
  commandSchemaVersion,
  businessId,             // copied from verified BusinessContext, server verifies/derives
  actor: { userId, sessionId, membershipId },
  clientCreatedAtUtc,
  effectiveDate?,
  expectedVersions?,
  payload: T
}
```

The UI may not supply trusted permissions, role, server time, or an arbitrary tenant. `businessId` is correlation/routing data, not authorization proof.

### Ownership

- UI: syntactic/presentation validation and intent capture only.
- Handler/application service: use-case orchestration, command policy, DTO/domain mapping, consistency selection.
- Domain policy: accounting, inventory, pricing, COGS, balance, closing and document invariants.
- Server: final authentication/authorization, tenant binding, concurrency checks, authoritative validation and transaction.
- Infrastructure adapter: persistence/transport/idempotent invocation; no new business policy.
- Clock: injected; server stamps authoritative receipt/commit times.

### Result and failure

```text
CommandResult<T> {
  commandId,
  disposition: confirmed | provisional,
  lifecycleStatus,
  value?,
  serverReceipt?,
  confirmedAtUtc?,
  localRecordedAtUtc?,
  version?,
  warnings
}

CommandFailure {
  code,
  category: validation | unauthenticated | unauthorized | conflict |
            closedPeriod | insufficientBalance | insufficientStock |
            approvalRequired | duplicatePayloadMismatch | retryable | fatal,
  fieldErrors,
  retryable,
  commandId,
  latestVersion?,
  safeDisplayMessageKey,
  diagnosticReference
}
```

Exceptions may exist below the boundary, but UI receives the typed result/failure union. Duplicate delivery with an identical fingerprint returns the stored result; different payload under the same key returns `duplicatePayloadMismatch`.

### Required conceptual examples

| Command | Essential payload beyond envelope | Expected outcome |
|---|---|---|
| `CreateSaleCommand` | customer, lines, payment mode/allocations, notes | sale/document id; provisional or confirmed; price/stock/payment failures typed |
| `ReturnSaleCommand` | original sale id, return lines, reason | future return document and reversals; distinct from current cancellation when implemented |
| `RecordExpenseCommand` | date, category, qirsh, account, method, classification | expense id and cash posting status |
| `RecordCustomerPaymentCommand` | customer, qirsh, date, account/method | collection id, new confirmed/provisional balance |
| `RecordSupplierPaymentCommand` | supplier, qirsh, date, account/method | payment id, balance, approval requirement |
| `TransferAccountFundsCommand` | source, destination, qirsh, effective date, reference | transfer id and two balances; net P&L zero |
| `AdjustInventoryCommand` | product, delta/type, reason, cost/evidence | movement/valuation ids and resulting quantity |
| `SetOpeningBalanceCommand` | subject type/id, amount/quantity, effective date | exactly-one opening posting or typed duplicate |

Every financial/inventory example includes `commandId`, envelope `businessId`, verified actor, and returns provisional/confirmed status explicitly.

## 12. Future Query Boundary Contract

Query names use `Get/List/Search + Noun + Query`; handlers expose use-case read models, never write repositories or Drift rows.

```text
QueryEnvelope<T> {
  queryId,
  businessId,             // from BusinessContext
  actor: { userId, sessionId, membershipId },
  consistency: serverConfirmed | cachedConfirmed | provisionalOverlay,
  maxStaleness?,
  forceRefresh,
  payload: T
}

QueryResult<T> {
  data,
  source: cloud | cache | hybrid,
  asOfUtc,
  confirmedThrough?,
  isStale,
  includesProvisional,
  provisionalCommandIds,
  refreshFailure?
}
```

Authorization remains server-authoritative. Cache filtering is defense in depth, not tenant security.

Conceptual examples:

| Query | Default source mode | Stale allowed | Provisional overlay |
|---|---|---|---|
| `GetProductCatalogQuery` | hybrid/cache-first | yes, bounded | yes, labeled |
| `GetInventoryPositionQuery` | hybrid | bounded for browsing; no for commit validation | yes, separately totaled |
| `GetCustomerStatementQuery` | cached-confirmed/hybrid | bounded; forced refresh for official export | optional labeled appendix |
| `GetSupplierStatementQuery` | cached-confirmed/hybrid | bounded; forced refresh for official export | optional labeled appendix |
| `GetDashboardSummaryQuery` | server aggregate + cached snapshot | short | optional labeled deltas |
| `GetAccountStatementQuery` | cached-confirmed/hybrid | low; forced refresh for closing/official export | optional, never silently merged |

The first query to migrate is `GetProductCatalogQuery` because a dedicated `ProductCatalogReadRepository` and read model already exist, its cache suitability is high, and the migration can prove the boundary without touching accounting.

## 13. Offline Provisional Contract

Frozen lifecycle:

```text
localDraft
  -> provisionalPending     (local projection + durable command saved atomically)
  -> syncing
     -> serverAccepted
     -> serverRejected
     -> conflict
     -> retryableFailure -> syncing
```

Rules:

- `localDraft` is not posted and may remain UI-local.
- `provisionalPending` may affect explicitly provisional operational views only.
- `syncing` is still provisional.
- `serverAccepted` is the sole transition to authoritative accounting/inventory.
- `serverRejected` and `conflict` are terminal for that command id unless policy defines a new command; payload mutation under the old id is forbidden.
- `retryableFailure` retains the same command id/payload and may retry.
- Rejected/conflicted local effects are removed or compensated in one reconciliation transaction; the command, reason and audit history remain visible.
- UI must badge provisional/rejected/conflict state and provide the server reason/action.
- Official statements, closings, tax/financial reports and authoritative KPIs default to confirmed-only. Operational views may show confirmed plus a separately labeled provisional overlay.
- **Provisional state must never silently masquerade as server-confirmed authoritative accounting state.**

## 14. Idempotency Contract

- The client application layer creates `commandId` before the first durable local save.
- It remains identical across retries, process restarts, reconnects, timeouts and duplicate delivery.
- Server uniqueness scope is `(business_id, command_id)`.
- The server stores payload schema version, canonical payload fingerprint, processing/result state and final response reference.
- A document id is separate from command id. The server may accept a client document candidate, but command identity never depends on a mutable document number.
- Same key + same fingerprint returns the original/in-progress status and never posts again.
- Same key + different fingerprint returns a non-retryable payload-mismatch conflict.
- Timeout after server commit but before acknowledgement is handled by retrying the same envelope or querying command status; no new id is generated.
- Child accounting/inventory entries carry/source-link the authoritative result document/command so uniqueness constraints prevent double posting.
- Transfer behavior proven in Phase 108B is the acceptance pattern for the first migrated command.

## 15. BusinessContext Contract

`BusinessIdentity` is current branding, not tenant context. The target has two immutable scopes:

```text
SessionContext {
  sessionId, userId, authProviderSubject, authenticatedAtUtc, expiresAtUtc
}

BusinessContext {
  businessId, membershipId, role, permissions, membershipVersion,
  selectedAtUtc, sessionContext
}
```

The composition root creates a session-scoped container after authentication and a business-scoped container after verified business selection/membership load. Switching business disposes the old business scope, cache subscriptions, handlers and sync coordinator before constructing a new one.

Propagation rules:

- UI receives a business-scoped `ApplicationBoundary`; it does not invent or manually thread arbitrary `businessId` values.
- Command/query envelopes copy context identity automatically.
- Local cache adapters are opened/namespaced for the current business and reject cross-scope keys.
- Cloud adapters authenticate with session credentials; the server derives/verifies user and business membership and RLS enforces `business_id`.
- Repository implementations never default, guess, generate, or override `businessId`.
- Permission values sent by clients are never authoritative; server loads current membership/role.

## 16. Composition Root Contract

One root, outside widgets, owns construction of:

- database and business-scoped cache adapters;
- Supabase client (future, not in 108D);
- auth/session provider and BusinessContext resolver;
- local/cloud/hybrid command gateways;
- command handlers and query handlers;
- sync coordinator/outbox;
- licensing service;
- clock, logger/telemetry and connectivity abstractions;
- application facade/boundary passed into UI.

No screen/controller constructs an infrastructure implementation or reads a global locator.

Frozen lifetimes:

| Lifetime | Objects |
|---|---|
| Process singleton | provider client configuration, logger sink, clock, connectivity monitor, database engine factory |
| Session scoped | authenticated session, auth gateway, license evaluation/session telemetry |
| Business scoped | `BusinessContext`, business cache/database handle, repositories/gateways, handlers, query services, outbox/sync coordinator |
| Screen/presentation scoped | Flutter controllers/view models only |
| Command/request scoped | envelope, Unit of Work, domain aggregates/policies, trace/span, result mapping |

The local-only implementation must be placeable behind exactly the same `ApplicationBoundary` before cloud code is introduced. Adapter selection (`Local`, `Cached`, `Cloud`, `Hybrid`) is an environment/business-scope root decision, never a UI decision.

## 17. Cache / Cloud / Hybrid Read Contract

Three result modes are frozen:

- `serverConfirmed`: returned/confirmed by cloud authority; required for close/reopen, command precondition validation and forced official refresh.
- `cachedConfirmed`: previously confirmed server data with `asOfUtc`/cursor; allowed by per-query maximum staleness.
- `provisionalOverlay`: confirmed base plus local pending effects, with command ids/status and separate totals.

Policy families:

| Family | Cached confirmed | Pending overlay | Stale | Forced server refresh |
|---|---|---|---|---|
| Catalog/party lists | yes | yes, labeled | bounded | optional |
| Operational inventory/dashboard | yes | yes, labeled | short | before authoritative command checks |
| Statements | yes | optional section | low | official export/on demand |
| Financial/profitability reports | immutable confirmed snapshot | appendix only | low | official report/closing |
| Closing/approval action queues | only as non-actionable display | no silent overlay | effectively zero | mandatory before action |
| Audit history | yes | local pending events segregated | bounded | owner refresh/on demand |

## 18. Outbox / Durable Command Requirement Decision

**YES. S4 + O3 requires a durable outbox or semantically equivalent command queue.** An in-memory queue cannot preserve intent across crash/offline restart and cannot prove exactly-once effects.

Frozen durable record fields:

```text
commandId, businessId, actorUserId, membershipId,
commandType, payloadSchemaVersion, canonicalPayload, payloadFingerprint,
clientCreatedAtUtc, localRecordedAtUtc,
lifecycleStatus, attemptCount, nextAttemptAtUtc, lastAttemptAtUtc,
lastErrorCode, serverReceipt, resultDocumentId, confirmedAtUtc,
reconciliationStatus, localProjectionReferences
```

Required atomic write: local provisional projection + outbox record + local audit/provenance metadata. No table/schema is added in 108D.

## 19. Architectural Violations Register

The complete register is [architectural-violations.tsv](evidence/architectural-violations.tsv).

| Severity | Count | Meaning in this audit |
|---|---:|---|
| V0 | 8 | Must be addressed before reliable cloud authority/offline migration |
| V1 | 9 | High-risk coupling threatening accounting/inventory or causing major rewrite |
| V2 | 6 | Medium coupling that can follow the core boundary |
| V3 | 2 | Low-risk cleanup/documented ambiguity |

The V0 count does not mean production is currently failing. It means those shapes cannot safely carry the frozen cloud model unchanged.

## 20. Migration Dependency Graph

```text
108E ApplicationBoundary + central dependency bundle/lifetimes
  ├─ 108F TransferAccountFunds command through local adapter
  ├─ 108G SessionContext + BusinessContext
  │    └─ 108H Durable outbox + provisional lifecycle persistence
  │         └─ 108I Create/Cancel Sale command migration
  │              └─ 108J Purchase/payment/advance command families
  └─ 108K Product Catalog query boundary
       └─ 108L Dashboard/statements/financial query boundaries
            └─ 108M Remove residual UI locator reads and stale query captures

Only after command/query/context/outbox seams exist:
  Supabase foundation -> Auth/business/RLS -> cloud query adapters
  -> authoritative financial/inventory RPCs -> hybrid sync rollout
```

`BusinessContext` precedes durable outbox schema because every durable command is tenant-scoped. The first local command migration may precede cloud context to prove the handler/adapter seam without changing authority.

## 21. Recommended Atomic Follow-up Phases

1. **Phase 108E — Introduce Application Boundary and Central Composition-Root Dependency Bundle.** Add minimal command/query dispatch interfaces, typed common results, explicit lifetime bundle, and local adapter wiring; no Cloud.
2. **Phase 108F — Migrate TransferAccountFunds Through the Local Command Boundary.** Use the Phase 108B invariant/idempotency evidence; remove UI/repository exposure for this use case only.
3. **Phase 108G — Introduce SessionContext and BusinessContext Boundary.** No schema/RLS yet; eliminate invented tenant identity paths.
4. **Phase 108H — Introduce Durable Outbox and Provisional Lifecycle Persistence.** Atomically couple local projection and command intent for one characterized command.
5. **Phase 108I — Migrate CreateSale and CancelSale Command Ownership.** Preserve price, stock, customer ledger, cash and COGS behavior.
6. **Phase 108J — Migrate Purchase, Expense, Customer/Supplier Payment and Advance Commands.** Split per atomic use case.
7. **Phase 108K — Introduce GetProductCatalogQuery Boundary.** Reuse the existing dedicated read model/port and add provenance.
8. **Phase 108L — Introduce Dashboard, Statement and Financial Report Query Boundaries.** Add consistency policies and confirmed/provisional separation.
9. **Phase 108M — Remove Residual UI Service-Locator Coupling.** Resolve the static-final report capture and screen-local service construction.
10. Then start scoped Supabase foundation/auth/business/RLS work, followed by server-side financial/inventory RPCs and hybrid adapters.

Each phase must be one small, characterized change with rollback and no opportunistic redesign.

## 22. Validation Results

| Check | Result |
|---|---|
| Formatter | PASS via the bundled SDK executable over `lib test tool`: **428 files, 0 changed**, 8.96s |
| `flutter analyze` | PASS: **No issues found**, 51.7s |
| `flutter test` | **FAIL: 2,414 passed, 0 skipped, 4 failed**, 4m45s |
| Four-file targeted rerun | **31 passed, 4 failed**; every failure is a preserved branch-name allowlist rejecting the required Phase 108D branch |
| `flutter build windows --release` | PASS: release EXE built in 34.4s; existing CMake deprecation and LNK4078 warnings emitted |
| `git diff --check` | PASS for worktree and staged patch; repeated for baseline..commit after commit |

Baseline reference: formatter 428 files; analyzer clean; 2,418 tests passed; 0 skipped; 0 failed; Windows release build PASS.

The exact `dart format --output=none --set-exit-if-changed .` invocation through Flutter's `dart.bat` wrapper timed out twice without formatter output because the wrapper could not complete its SDK cache-lock startup in the workspace sandbox. Direct `dart.exe --version` succeeded, and the equivalent deterministic source-set invocation using the same bundled SDK formatted all 428 repository Dart files with zero changes. Flutter commands were then run with the required SDK-cache access.

The four failures are not caused by Phase 108D source changes. They are these intentional, unstaged Phase 107H leftovers:

- `test/phase106aj_migrate_drift_purchase_product_validation_reads_test.dart:318`
- `test/phase106ak_reaudit_freeze_next_product_read_migration_target_test.dart:115`
- `test/phase106al_negative_balance_approval_product_fingerprint_read_migration_test.dart:159`
- `test/phase106am_profitability_activation_product_read_migration_test.dart:253`

Each expects a hard-coded branch-name allowlist ending at `codex/phase-107h-governed-14-day-trial-windows-package-acceptance`; actual is the required `codex/phase-108d-application-command-query-boundary-composition-root-freeze`. The phase instruction forbids modifying or committing these files. Therefore they remain byte-identical and Phase 108D is honestly Outcome B.

## 23. Git Evidence

Pre-commit expected diff classification:

| Area | Expected |
|---|---|
| Production (`lib/`) | empty |
| Schema (`foundation_database*`, migrations) | empty |
| Dependencies (`pubspec.*`) | empty |
| Platforms (`android/`, `windows/`) | empty |
| Phase artifacts | `docs/phase-108d/**` only |

Verified before commit: production/schema/dependency/platform name lists are empty. The staged patch contains exactly 8 new files under `docs/phase-108d/`, 843 insertions, and passes `git diff --cached --check`.

Post-commit evidence is populated after the single phase commit:

| Check | Result |
|---|---|
| Commit | Recorded in the final handoff after creating the artifact commit; a commit cannot contain its own hash without amendment |
| Parent | must equal `259a784c0b3a5e213ccf2c3b67a61901c5a33c65` |
| Count baseline..HEAD | must equal `1` |
| Merge commits baseline..HEAD | must equal `0` |
| Preserved 107H tracked diff hash | must remain `9256c16945f49b36957a204b6dc108c412ade96b` |
| Preserved 107H file hashes | 33 compared; 0 mismatches before commit; repeated after commit |

## 24. Final Outcome

Classification: **Outcome B — contract freeze complete, validation blocked by four immutable Phase 107H branch-name guards.** The architecture inventory, contracts and migration sequence are complete; formatter, analyzer and Windows build pass; production/schema/dependency/platform diffs are empty. Outcome A is not claimed because the mandatory full test suite is not green. The preserved files are not edited to conceal the failure.

### Critical decision questions

| # | Answer | Evidence/decision |
|---:|---|---|
| 1 | **NO** | Controllers/services cover subsets, but direct repository writes and mixed repository workflows remain. |
| 2 | **NO** | Product catalog has a read port and reports have services, but no uniform query envelopes/provenance/consistency boundary exists. |
| 3 | **YES** | UI constructs Local theme/identity repositories in app state and 43 feature/shared files resolve `AppRepositories`; feature screens do not construct Drift adapters directly. |
| 4 | **YES** | Sale controller and several repositories orchestrate multiple repositories with snapshot boundaries rather than a uniform command transaction owner. |
| 5 | **NO** | `main`, `AppRepositories`, app `initState`, and screen `initState` share construction duties. |
| 6 | **NO** | Static locator reads, mixed interfaces and UI service construction require UI/application rewiring before SQLite can be generally swapped. |
| 7 | **NO** | `AuthScope` exists, but no business membership/context scope; globals would force manual/global leakage. |
| 8 | **YES** | O3 requires crash-durable command intent, stable ids, retries and reconciliation. |
| 9 | **YES** | Accounting/inventory commands require server-owned authoritative transactions/RPC equivalents. |
| 10 | **YES, after boundary extraction** | Existing Local/Drift behavior can be wrapped behind stable command/query ports; it cannot safely remain the UI-facing contract. |
| 11 | **`TransferAccountFundsCommand`** | Small contained financial use case, current client request id, exact invariant and duplicate evidence from Phase 108B. |
| 12 | **`GetProductCatalogQuery`** | Dedicated current read interface/model, broad reuse and low accounting risk. |
| 13 | **Phase 108E** | A minimal central ApplicationBoundary/dependency bundle removes the architectural choke point needed by every later migration. |

The frozen outcome is: **stable UI/Application contracts; replaceable infrastructure; server-authoritative financial/inventory state; explicitly provisional offline effects.**
