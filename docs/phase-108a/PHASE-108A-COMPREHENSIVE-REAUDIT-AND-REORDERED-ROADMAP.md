# Phase 108A — Comprehensive Re-audit, Remaining-Work Reconciliation & Priority Reordering

Run ID: `20260811-021812`

## 1. Final Outcome

**Outcome A — FULL SUCCESS.**

The current committed Windows/local application is functionally stable for its
declared single-device scope. No current R0 financial defect was found. Fresh
validation passed formatting, analysis, 2,417 tests with one explicit skip,
and a Windows release build. Phase 107B through 107G remain technically intact.
Phase 107H remains **NOT ACCEPTED**: its package and persistence observations
are useful evidence, but interactive second-launch login was not governed to
acceptance.

The main remaining risk is architectural, not a missing local feature. The
current system has no tenant/organization/warehouse/device scope, globally safe
IDs, server time, remote session, RLS, sync/outbox, conflict model, or
server-authoritative accounting command boundary. Presentation still has 152
direct `AppRepositories` references across 43 feature/shared files. Therefore
Supabase must be treated as a new operating model, not as a SQLite driver swap.

No production behavior was changed in Phase 108A.

## 2. Repository Baseline & Provenance

| Field | Evidence |
| --- | --- |
| Starting HEAD | `e2b425ac272665eb9c0f59894799984e206146f3` — `PHASE 107G: enforce 14-day local trial` |
| Requested known baseline | Same exact hash — confirmed |
| Starting/final branch | `codex/phase-107h-governed-14-day-trial-windows-package-acceptance` |
| Commit after baseline before 108A | None |
| Phase 107H commit | None |
| Starting state | Dirty: four modified lineage tests plus untracked `docs/phase-107h/` and `tools/phase107h/` |
| Phase 108A commit | One documentation/evidence-only commit is authorized after final gates; exact hash is reported at handoff because a commit cannot contain its own hash |
| Push/tag/merge/rebase | None |

The dirty starting paths are preserved 107H work. The four test changes only
allow the exact 107H branch in historical lineage guards. The untracked 107H
paths contain package/runtime evidence and an acceptance harness. Phase 108A
did not edit or claim them.

Production diff attributable to 108A is empty: `lib/`, `test/`, `windows/`,
`android/`, `pubspec.yaml`, and `pubspec.lock` received no 108A changes. The
pre-existing four test diffs remain separately attributable to 107H.

Evidence: `evidence/20260811-021812/01-repository-truth.txt`.

## 3. Validation Results

| Gate | Result | Totals / duration |
| --- | --- | --- |
| `dart format --output=none --set-exit-if-changed .` | PASS | 428 files, 0 changed, 16.82s |
| `flutter analyze` | PASS | No issues, 39.7s |
| `flutter test` | PASS | 2,417 passed, 1 skipped, 0 failed, 231.2s wall time |
| `flutter build windows --release` | PASS | EXE built, 25.9s Flutter build time |
| `git diff --check` at entry | PASS | CRLF notices only; no whitespace error |

Flutter's wrapper initially waited on an SDK-cache lock outside the workspace.
The equivalent SDK executable/tool snapshot completed after approved cache
access. This is an execution-environment note, not a product failure. The build
retained the existing non-fatal CMake deprecation and LNK4078 warnings.

Evidence: `evidence/20260811-021812/02-validation-summary.txt`.

## 4. Current System Capability Matrix

| Capability | Status | Current evidence and boundary |
| --- | --- | --- |
| Owner/employee authentication and permissions | VERIFIED COMPLETE | Durable local Argon2id credentials, role guards, tests; session remains process-local |
| Products and pricing | VERIFIED COMPLETE | Durable CRUD/catalog read contract and pricing tests |
| Inventory, opening stock, stock take/adjustment | VERIFIED COMPLETE | Movement-led quantity, durable transactions and tests |
| Purchases and supplier balances | VERIFIED COMPLETE | Stock/payable/payment/valuation atomic tests |
| Sales, cancellation, customer balances | VERIFIED COMPLETE | Stock/receivable/cash/COGS/reversal atomic tests |
| Customer and supplier advances/refunds | VERIFIED COMPLETE | Idempotency, approval and reversal suites |
| Expenses and financial routing | VERIFIED COMPLETE | Account routing and classification tests |
| Inventory valuation, COGS, gross/net profit | VERIFIED COMPLETE | Moving weighted average, immutable COGS and reporting suites |
| Financial accounts/transfers/period closing | VERIFIED COMPLETE | Durable ledger, closing and negative-balance approval tests |
| Audit logs/document history | VERIFIED COMPLETE | Durable append/read boundaries and history tests |
| Atomic business-data wipe | VERIFIED COMPLETE | 107B durable transaction + snapshots; full regressions pass |
| Backup v8 / restore v1–v8 / checksum | VERIFIED COMPLETE | 107C checksum gate, compatibility and rollback tests pass |
| Trial 14×24h/UTC/rollback/sticky expiry | VERIFIED COMPLETE | 107G gates and full regressions pass |
| Governed Windows build/installer/fresh profile | VERIFIED COMPLETE | 107D/107E accepted; current release build passes |
| Trial package acceptance (107H) | IMPLEMENTED BUT NOT FULLY VERIFIED | Artifacts and data persistence observed; interactive second-login acceptance missing |
| PDF/CSV/print/WhatsApp surfaces | IMPLEMENTED BUT NOT FULLY VERIFIED | Builders and tests exist; cross-platform capability/runtime acceptance absent |
| Responsive/Arabic design foundation | PARTIAL | Shared tokens/adaptive shell plus selected migrations; many screens remain dense/not runtime-accepted on Android |
| Settings/business identity/theme | PARTIAL | Local identity/logo/theme and backup entry only; no cloud/device/invoice/licensing policy model |
| Supabase/cloud/multi-device | NOT PRESENT | No dependency, project config, tenant/RLS/sync/server command model |
| Android product | INCOMPLETE | Scaffolding only; placeholder ID, debug release signing, no device acceptance |
| Customer-ready commercial product | DEFERRED | No cloud/mobile authority, signed delivery, current client acceptance, or reconciled client docs |

Implemented, verified, and accepted remain distinct. In particular, successful
107H builds/artifacts do not convert 107H to an accepted phase.

## 5. Phase 107B–107H Reconciliation

| Phase | Implemented | Verified | Accepted | Current state |
| --- | --- | --- | --- | --- |
| 107B atomic wipe | Yes | Yes, current full suite | Yes | Remains closed |
| 107C checksum verification | Yes | Yes, current full suite | Yes | Remains closed |
| 107D governed Windows installer | Yes | Yes, accepted D1–D10 evidence | Yes | Internal governed package baseline remains useful |
| 107E fresh-profile runtime | Evidence/harness | Yes, E1–E19 | Yes | Fresh-profile risk remains closed |
| 107F documentation governance | Report only | Identifier mismatch proven | Accepted as a blocked governance report, not remediation | R1-005 and R1-006 remained open |
| 107G local 14-day trial | Yes | Yes, 36 trial tests and current full suite | Yes | Local trial contract intact |
| 107H trial package acceptance | Harness/artifacts exist | Partially | **No** | Second-launch data persisted, but interactive login path was not accepted |

### Historical risk reconciliation

| Old Risk | Previous State | Current Evidence | Current State | New Severity | Action |
| --- | --- | --- | --- | --- | --- |
| R1-001 atomic wipe | Open defect | 107B transaction/snapshot boundary and current suite | Closed | — | Preserve regressions |
| R1-002 backup checksum | Open defect | 107C preview checksum verification and current suite | Closed | — | Preserve regressions |
| R1-003 current package | Open gap | 107D accepted installer/package | Closed for internal governed artifact | R2 delivery | Regenerate only after target product contract changes |
| R1-004 fresh profile | Unverified | 107E accepted runtime | Closed | — | Preserve evidence |
| R1-005 genuine client acceptance | Open | No named client A–H acceptance exists | Still open | R1 | Defer to customer-ready candidate |
| R1-006 client docs | Open defect | v3 and wrong data path text remains | Still open | R2 | Correct when the next deliverable contract is frozen; do not publish current stale docs |
| R2-001 plaintext DB/backups | Open risk | Still plaintext local files | Still open | R2 | Threat model during Cloud foundation |
| R2-002 missing business FKs | Open risk | App enforcement remains broader than DB FKs | Still open | R2 | Reassess in Supabase schema/RLS design |
| R2-003 skipped transfer test | Open gap | Full suite still has exactly one skip | Still open | R1 | **Freeze as Phase 108B** |
| R2-004 broad visual runtime | Unverified | Selected responsive tests only | Partially closed | R2 | Android/device and screen-batch acceptance |
| R2-005 silent catches/observability | Open risk | Broad safe catches still common | Still open | R2 | Add redacted telemetry policy with Cloud work |
| R2-006 demo credentials in production tree | Open hygiene | Local fallback/demo support remains | Still open | R3 | Retire with composition refactor |
| R2-007 global singleton coupling | Open debt | 152 references in 43 UI/shared files | Still open, more precisely measured | R1 | Architecture boundary wave |
| R3-001 cloud absent | Future gap | Still absent | Promoted by owner priority | R1 | Cloud foundation waves |
| R3-002 mobile absent | Future gap | Android scaffolding only | Promoted by owner priority | R1 | After Cloud contracts stabilize |
| R3-101…105 product reads | Five infrastructure consumers | Same 6 calls/5 consumers | Deferred intentionally | R3 | Fold into owning refactors |

## 6. Phase 107H Disposition

**H-D — Preserve current artifacts only.**

Reasoning:

1. 107G already proves the local trial engine, UTC boundary, sticky expiry,
   rollback behavior, and data preservation.
2. 107H adds useful package/hash/install/reinstall observations. Its evidence
   shows the trial start and business database survived reinstall/uninstall.
3. The mandatory interactive second-launch login path was not accepted, so
   resuming merely to “close the number” would misstate the evidence.
4. 107H does not block the skipped accounting proof or the Cloud architecture.
5. Cloud identity/licensing may materially replace device-local trial policy.
   Investing in another local package acceptance cycle now has high rework risk.
6. H-C is premature because no replacement licensing contract is frozen yet.
   Preserve the artifacts until the Cloud/licensing decision explicitly
   supersedes or reuses them.

The current 107H output is an **internal QA trial artifact**, not a
customer-ready artifact.

## 7. Product Read Migration Current Inventory

Current truth is **24 consumers: 19 migrated, 5 remaining**. There are 20
catalog-backed calls and six legacy calls; PRC-109 and PRC-114 each own two
calls. All remaining consumers are infrastructure/test/composition. Production
legacy consumers: **zero**.

| Remaining consumer | Classification | Decision |
| --- | --- | --- |
| PRC-114 local inventory repository | Can remain temporarily | Migrate/retire with local data-source refactor |
| PRC-115 local purchase repository | Should migrate during Cloud refactor | Avoid isolated pre-Cloud rewrite |
| PRC-116 synthetic activation | Can remain temporarily | Deliberate test-only exception is acceptable |
| PRC-117 compatibility wrapper | Should migrate during Cloud refactor | Retire before remote catalog becomes authoritative |
| PRC-118 rollback snapshot self-read | Can remain temporarily | Reassess with cache/outbox transaction model |

Completing all five before Cloud is not rational: it would edit fallback and
snapshot mechanisms likely to change again. Details and paths are in
`evidence/20260811-021812/04-product-read-inventory.md`.

## 8. Financial / Data Integrity Remaining Risks

No current financial result was shown incorrect. The suite directly covers
stock, payable/receivable, payments, advances/refunds, transfers, negative
balance approvals, closings, valuation, COGS, gross profit, net-profit inputs,
restore, and rollback.

Remaining concerns:

- One transfer double-count scenario is explicitly skipped. Related tests pass,
  but indirect evidence is not equivalent to executing that edge. This is the
  only current accounting verification gap and is next.
- Current atomicity is excellent inside one SQLite transaction. It is not a
  multi-device atomicity model. Replicating rows independently would allow
  double posting, divergent stock/COGS, or closing bypass.
- IDs and many request keys use local time/local sequences. They are not global
  identities and are collision/order risks across devices.
- Most timestamps use local `DateTime.now()`; only the trial has an explicit UTC
  clock. Server commit time and organization business timezone are absent.
- Backup/restore is one local-business snapshot. It is not a tenant-scoped
  import, cache recovery, or server disaster-recovery contract.
- Business identity is a local file saved from within restore but is not itself
  covered by the database snapshot boundary; an error after file replacement
  can leave identity state different from rolled-back database state. This is
  non-ledger R2 data-integrity debt.
- Local JSON/file settings use a separate path from the database/trial store,
  complicating device replacement and cloud ownership.

## 9. Cloud Readiness Findings

Recommended operating model: **hybrid/offline-capable with server-authoritative
financial commands**, subject to owner approval in the architecture freeze.
Pure cloud-first is operationally fragile for warehouse connectivity; pure
offline-first with peer conflict resolution is unsafe for stock, valuation,
ledger, closing, and approvals.

### What remains local

- Deterministic domain calculations and validation that can be shared/tested.
- SQLite as an encrypted-or-scoped cache, durable outbox, and offline read
  model—not final authority for multi-device financial truth.
- Device preferences such as theme; platform capability selection.
- Provisional previews clearly distinguished from server-committed results.

### What must sit behind boundaries

- Presentation access to queries/commands; remove direct static repository use.
- Drift adapters as local data sources.
- File paths, export/open/print/share, secure storage, connectivity, and clock.
- Auth session and organization/warehouse context.

### What moves to Supabase/server authority

- Identity/session, organization membership and server-side authorization/RLS.
- Shared reference data, business documents, ledger/audit records and versions.
- Atomic sale/purchase/expense/payment/transfer/approval/closing commands.
- Idempotency record + payload fingerprint + immutable committed response.
- Ordered inventory valuation/COGS and server commit timestamps.
- Organization export/import orchestration and cloud recovery policy.

### Required decisions before implementation

- Organization, branch, warehouse and device scope.
- Single-writer versus multi-device writer model.
- Server command location (database functions/edge/service) and transaction
  isolation/locking/retry rules.
- UUIDv7/equivalent entity and operation IDs; legacy ID mapping.
- Client occurred time, server received/committed time, and organization timezone.
- Mutable-reference versioning/tombstones and conflict behavior.
- Offline queue visibility, retry/cancel policy and provisional-state UX.
- RLS policy matrix and secrets/environment strategy.
- Legacy backup import versus device-cache recovery versus server backup.
- Trial/licensing relationship to Supabase auth and offline grace.

Existing Firebase bootstrap/dependency is inactive and must not silently become
the target architecture. Provider choice and removal/coexistence are explicit
decisions, not incidental dependency edits.

## 10. Android Readiness Findings

Android Flutter scaffolding exists, but no Android product is accepted.

- `applicationId` is still `com.example.grain_warehouse_erp_lite`.
- Release builds use debug signing.
- No genuine device runtime, lifecycle, database, secure-storage, print/share,
  picker, backup, or trial/licensing acceptance exists.
- Explicit Windows backslash joins are used throughout PDF/CSV exports.
- Business identity/theme storage reads Windows environment paths.
- 15 screen files show responsive/layout awareness, but the app has 42+ screen
  surfaces and many dense tables/forms/dialogs.
- Android must consume the same Cloud command/query contracts; it must not
  create a second data architecture.

Start Android only after Cloud authority, identity/time, repository boundaries,
and one server-backed vertical slice are stable. Platform adapters and build
identity/signing may then precede screen-by-screen polish.

## 11. Printing / PDF / Sharing Findings

Existing foundations are substantial: Arabic-font PDF sales/purchase invoices,
customer/supplier statements, report PDFs/CSVs, business identity/logo, printing
package integration, file opening, and WhatsApp-assisted messages.

They are not yet a cross-platform professional document subsystem:

- invoice number is the local record ID rather than a frozen human numbering
  and server uniqueness contract;
- no stable invoice DTO/version independent of local repository aggregates;
- export paths use Windows backslashes;
- open/print/share are mixed into UI/static services rather than capability
  adapters;
- Android share-sheet and permission/storage behavior are unaccepted;
- cancellation/reissue/legal/tax numbering policy is not frozen;
- runtime printer/PDF/WhatsApp acceptance remains incomplete.

Freeze the invoice data contract after Cloud entity/numbering ownership, then
reuse the current PDF layout work behind platform adapters. Do not redesign the
PDFs before document IDs, branding ownership and Android delivery paths settle.

## 12. UI/UX & Design-System Findings

Phase 83 created real value: semantic colors/tokens, theme modes/presets,
adaptive shell, shared headers/state/search/status widgets, and responsive tests.
Selected high-risk screens were modernized. This is a foundation, not a full
professional redesign.

Remaining work is screen-batch migration, touch ergonomics, density, text
scaling, consistent dialogs/forms/tables, and Android runtime visual acceptance.
The correct order is:

```text
Android/responsive runtime constraints
  -> shared design-system/component contracts
  -> screen batches with RTL/viewport/touch acceptance
```

Do not rewrite every screen before Android navigation and Cloud loading/offline/
conflict states exist; that would repeat state and layout work.

## 13. Settings 2.0 Findings

Current Settings contains appearance, business identity/profile/logo, and an
owner backup entry. It is not Settings 2.0.

| Timing | Settings work |
| --- | --- |
| Before Cloud | Classify every setting as device/user/organization/warehouse/commercial; define versioned keys and capability interfaces |
| During Cloud | Organization identity, account/session, sync status, device, offline queue, cloud/backup policy and server-owned business settings |
| After Cloud | Invoice/print/share preferences once document contract is stable; Android platform preferences |
| After Android | Full responsive Settings IA, advanced appearance and polish |
| Commercial wave | Licensing/trial/grace/update/support settings after the commercial contract is chosen |

Theme may remain device-local. Business identity/logo should be organization
data with cached assets. Accounting policy switches must be allow-listed and
server-authorized; arbitrary toggles cannot alter posted financial truth.

## 14. Cross-platform Architecture Blockers

1. Global static composition: 152 `AppRepositories` references in 43 UI/shared
   files.
2. Single local database is the only authority and transaction coordinator.
3. No tenant/organization/branch/warehouse/device/session scope.
4. Local-time/local-sequence IDs and no global operation identity contract.
5. No server time, row versions, tombstones, remote cursors, inbox or outbox.
6. Local auth with process session; no remote token/revocation/RLS model.
7. Financial atomicity exists only inside one SQLite file.
8. Audit ordering/actor authority is local-only.
9. Backup/restore/wipe contracts assume one complete local dataset.
10. File/export/settings paths and UI integrations are platform-bound.
11. Android identity/signing/runtime acceptance is absent.
12. Trial/licensing is device-local and disconnected from future identity.

## 15. Risk Register

| ID | Severity | Category | Description | Evidence | Impact | Recommended timing | Rework risk |
| --- | --- | --- | --- | --- | --- | --- | --- |
| FIN-001 | R1 | Testability / financial correctness | Transfer double-count edge remains skipped | 1 skip in full suite; Phase 9A scenario | Direct accounting edge unproven | NOW — 108B | LOW |
| ARC-001 | R1 | Architecture | Global static repository access | 152 references / 43 files | Blocks clean local/remote composition and testing | BEFORE CLOUD | MEDIUM |
| ARC-002 | R1 | Architecture | No organization/warehouse/device scope | Schema/search inventory | No safe tenancy or multi-warehouse model | CLOUD FOUNDATION | HIGH |
| ARC-003 | R1 | Architecture | Local-time/sequence IDs | ID generator inventory | Cross-device collisions/ambiguous ordering | BEFORE CLOUD | HIGH |
| FIN-002 | R1 | Financial correctness / architecture | SQLite transaction cannot be replicated row-by-row safely | sale/purchase/ledger transaction graph | Double posting, divergent stock/COGS/closing | CLOUD FOUNDATION | HIGH |
| SEC-001 | R1 | Architecture / security | Local auth/session has no server/RLS/device revocation | auth source | Server data could be under-authorized | CLOUD FOUNDATION | HIGH |
| SYN-001 | R1 | Data integrity | No outbox/inbox/conflict/version/tombstone model | source inventory | Lost/duplicate/conflicting offline work | CLOUD FOUNDATION | HIGH |
| AUD-001 | R1 | Data integrity | Audit is locally timed/ordered | audit repositories | Weak multi-device attribution/order | CLOUD FOUNDATION | HIGH |
| REC-001 | R2 | Data integrity | Local backup/restore is not tenant/server recovery | v8 restore contract | Unsafe direct reuse in Cloud | BEFORE/DURING CLOUD | HIGH |
| REC-002 | R2 | Data integrity | Business identity file is outside DB rollback snapshot | restore + local file repository | Partial non-ledger restore state | BEFORE CLOUD | MEDIUM |
| SET-001 | R2 | Architecture | Settings/identity/theme use separate local file paths and ownership | settings repositories | Device replacement/sync ambiguity | DURING CLOUD | MEDIUM |
| PLT-001 | R2 | Architecture | Windows path joins and direct file/open/print coupling | export source | Android runtime failures | BEFORE ANDROID | MEDIUM |
| AND-001 | R1 | Delivery | Android placeholder ID/debug signing/no runtime acceptance | Gradle/manifest | Not distributable | ANDROID FOUNDATION | MEDIUM |
| DOC-001 | R2 | Documentation / delivery | Client docs still claim backup v3 and wrong path | client docs | Recovery/operator error if distributed | Before next customer delivery | MEDIUM |
| DLV-001 | R1 | Delivery | No genuine client A–H acceptance | 101G/107F | Cannot claim commercial readiness | Commercial candidate | LOW |
| DLV-002 | R2 | Delivery | 107H second-launch login not accepted | preserved 107H evidence | Trial package not customer-ready | Preserve; revisit after licensing decision | HIGH |
| SEC-002 | R2 | Security | Plaintext SQLite/backups and no finalized threat model | dependencies/file writes | Theft/media disclosure | CLOUD FOUNDATION | MEDIUM |
| OBS-001 | R2 | Infrastructure | Broad catches lack governed redacted telemetry | source scan | Slow diagnosis, hidden cause | DURING CLOUD | MEDIUM |
| PRD-001 | R3 | Technical debt | Five legacy product-read consumers remain | 6 calls / 5 infra consumers | Minor boundary inconsistency only | Owning Cloud refactors | LOW |
| UI-001 | R2 | UX | Full Android/touch/viewport acceptance absent | responsive inventory | Dense/overflowing mobile workflows | AFTER CLOUD / ANDROID FOUNDATION | HIGH |
| INV-001 | R2 | Feature / architecture | Human invoice numbering contract absent | PDF uses local record ID | Multi-device duplicates/unprofessional numbering | AFTER CLOUD contract | HIGH |

Zero R0 items are open.

## 16. Dependency Map

```text
FIN-001 direct accounting proof (108B)
  -> Cloud authority and operating-model freeze
     -> tenant / warehouse / identity / time contracts
        -> repository + command/query boundaries
           -> Supabase environments, schema and RLS
              -> auth/org vertical slice
              -> reference-data vertical slice
              -> server-authoritative financial command slice
                 -> durable outbox/inbox and conflict UX
                    -> staged local-to-cloud migration
                       -> Android runtime foundation
```

```text
Cloud document identity + numbering contract
  -> invoice DTO/version
     -> shared Arabic PDF renderer
        -> Windows print adapter
        -> Android share adapter
```

```text
Android runtime/navigation constraints
  -> responsive design-system completion
     -> screen-by-screen modernization
        -> Settings 2.0 responsive information architecture
```

Work that can proceed in parallel after contracts freeze:

- Supabase environment/secrets bootstrap and application-boundary test harness.
- Android platform capability inventory and invoice DTO design, but not runtime
  feature implementation before owning contracts.
- RLS policy design and legacy migration mapping after tenancy ownership freezes.
- PDF visual refinement and design-system primitives after invoice/responsive
  contracts freeze respectively.

## 17. Reordered Roadmap

### Wave 0 — Remaining correctness proof

```text
Phase ID: 108B
Title: Execute and Close the Transfer Double-Count Accounting Scenario
Goal: Turn the sole skipped accounting edge into a passing direct proof.
Why now: Financial correctness precedes architecture expansion.
Scope: Repair only the test fixture/auth setup; execute the unchanged assertion; run financial and full regressions.
Explicit non-goals: Production behavior, Cloud, schema, UI, refactoring.
Dependencies: Phase 108A inventory.
Expected production files: None.
Acceptance gates: 0 skipped for the scenario; no weakened assertion; analyzer/full suite/build pass; production diff empty.
Rollback/stop conditions: A real product defect is reproduced—document and stop rather than fix under test-only scope.
Rework avoided: Prevents carrying an ambiguous transfer invariant into server design.
```

### Wave 1 — Architecture preparation

```text
Phase ID: 108C
Title: Cloud Operating Model and Data Authority Decision Freeze
Goal: Owner-approve hybrid/offline policy, server authority, tenancy, multi-device writes, conflicts and licensing relationship.
Why now: Every Supabase schema and Android decision depends on it.
Scope: ADRs, threat model, authority matrix, stop conditions, no runtime change.
Explicit non-goals: Supabase project, packages, tables, auth implementation.
Dependencies: 108B.
Expected production files: None.
Acceptance gates: All open decisions in Section 9 have one explicit owner decision; contradictions with Phase 103 reconciled.
Rollback/stop conditions: Ownership or offline/write model remains undecided.
Rework avoided: Prevents building an unsafe SQLite-to-cloud mirror.
```

```text
Phase ID: 108D
Title: Application Command/Query Boundary and Composition-Root Freeze
Goal: Define injectable use cases and local/remote data-source boundaries for one vertical slice.
Why now: 152 static UI references block substitutable Cloud access.
Scope: Inventory, interface/test contract and migration sequence; optionally one no-behavior-change pilot.
Explicit non-goals: Mass screen migration, Supabase calls, schema changes.
Dependencies: 108C.
Expected production files: Only the approved pilot boundary if implementation is authorized.
Acceptance gates: Presentation has a proven route to commands/queries without direct Drift; parity tests pass.
Rollback/stop conditions: Boundary leaks transaction snapshots or platform APIs.
Rework avoided: One composition model serves Windows and Android.
```

```text
Phase ID: 108E
Title: Distributed Identity, Scope and Time Contract
Goal: Freeze organization/warehouse/device IDs, UUID operation IDs, versions, tombstones and time semantics.
Why now: Schema, RLS, idempotency and migration require stable identities.
Scope: Contracts, legacy mapping, timezone matrix and compatibility strategy.
Explicit non-goals: Database migrations or ID rewrites.
Dependencies: 108C.
Expected production files: None unless contract types are separately authorized.
Acceptance gates: Collision, clock rollback, legacy mapping and server-time examples are deterministic.
Rollback/stop conditions: Multi-warehouse or multi-device ownership remains ambiguous.
Rework avoided: Avoids irreversible key/schema churn.
```

```text
Phase ID: 108F
Title: Recovery, Trial and Licensing Boundary Freeze
Goal: Separate cache recovery, organization export/import, server backup and licensing/trial authority.
Why now: Current local restore and 107H must not leak into Cloud semantics.
Scope: Contract/disposition only, including 107H reuse/supersession decision.
Explicit non-goals: Restore rewrite, licensing server, new installer.
Dependencies: 108C and 108E.
Expected production files: None.
Acceptance gates: Each recovery operation has authority, scope, audit and rollback rules; 107H final disposition is explicit.
Rollback/stop conditions: Client data deletion/import authority is unresolved.
Rework avoided: Prevents syncing whole-dataset restore or rebuilding local trial twice.
```

### Wave 2 — Supabase foundation

```text
Phase ID: 108G
Title: Supabase Environment, Secrets and Security Bootstrap
Goal: Establish dev/test/prod strategy, local configuration boundary and CI-safe secret rules.
Why now: Infrastructure must exist before schema/runtime slices.
Scope: Project/environment configuration, no business tables.
Explicit non-goals: Production data, auth UI, synchronization.
Dependencies: 108C–108F.
Expected production files: Configuration abstractions only; no committed secrets.
Acceptance gates: Isolated environments, secret scan, rollback/delete procedure and connectivity test.
Rollback/stop conditions: Secrets enter Git or environments are not isolated.
Rework avoided: Safe foundation for every later slice.
```

```text
Phase ID: 108H
Title: Supabase Organization/Auth/RLS Vertical Slice
Goal: Prove one user joins one organization with server-enforced role access and revocable session.
Why now: All remote data needs authoritative identity and scope.
Scope: Minimal auth/org schema, RLS, session adapter and tests.
Explicit non-goals: Migrating local owner/employee data wholesale; financial writes.
Dependencies: 108G, identity/scope contracts.
Expected production files: Auth/session adapters and composition for the slice.
Acceptance gates: Cross-org negative controls, owner/employee authorization, logout/revoke, no service-role key in client.
Rollback/stop conditions: Any client-supplied org bypasses RLS.
Rework avoided: Security foundation precedes business tables.
```

```text
Phase ID: 108I
Title: Product Catalog Cloud Read Vertical Slice
Goal: Prove scoped/versioned catalog read through command/query boundaries with local cache fallback.
Why now: Catalog is low-risk and Product Read production consumers already share a narrow contract.
Scope: Products only, read path first; fold PRC-117/related fallback cleanup into the slice.
Explicit non-goals: Inventory, sale posting, broad sync engine.
Dependencies: 108D, 108E, 108H.
Expected production files: Supabase catalog adapter, cache mapping, composition and tests.
Acceptance gates: RLS, offline read, stale/error states, Windows parity, no production legacy product reads.
Rollback/stop conditions: Remote model leaks into UI or local cache becomes accidental authority.
Rework avoided: Validates architecture before financial mutation.
```

### Wave 3 — Cloud financial vertical migration

```text
Phase ID: 108J
Title: Server-Authoritative Financial Command Contract
Goal: Implement one atomic idempotent command slice (candidate: expense posting) end to end.
Why now: A smaller ledger-affecting command proves the safety model before sales/purchases.
Scope: Server transaction, idempotency/fingerprint/result, audit and local committed-state projection.
Explicit non-goals: All financial flows, generic sync magic.
Dependencies: 108H–108I and FIN-001 closed.
Expected production files: One command/use case, remote function/adapter, cache projection and tests.
Acceptance gates: Replay equality, changed-payload rejection, RLS, rollback, clock independence, offline-visible pending state.
Rollback/stop conditions: Any partial ledger commit or duplicate posting.
Rework avoided: Reusable command template for high-risk flows.
```

```text
Phase ID: 108K
Title: Durable Outbox/Inbox and Conflict-State Foundation
Goal: Make offline requests durable, observable and safely replayable.
Why now: Android and unreliable connectivity require it before broad writes.
Scope: Queue state machine, retry, cursor/inbox, user-visible pending/failure states.
Explicit non-goals: Automatic merge of financial ledgers.
Dependencies: 108J.
Expected production files: Local schema migration, sync services, query states and tests.
Acceptance gates: Crash/restart/replay, duplicate prevention, poison item isolation, logout/org switch safety.
Rollback/stop conditions: Queue can silently drop or cross organization scope.
Rework avoided: One offline model for Windows and Android.
```

```text
Phase ID: 108L
Title: Staged Local-to-Cloud Migration and Reconciliation Pilot
Goal: Import one controlled local dataset into an isolated organization and prove totals/relationships.
Why now: Migration safety must precede customer cutover.
Scope: Dry-run, mapping, hashes, duplicate controls, reconciliation and rollback.
Explicit non-goals: Automatic customer rollout or destructive local cleanup.
Dependencies: Required vertical slices and 108F recovery contract.
Expected production files: Migration tool/adapters only.
Acceptance gates: Exact inventory/ledger/profit totals, repeat-run idempotency, audit, isolated rollback.
Rollback/stop conditions: Any unexplained financial variance.
Rework avoided: Evidence-based migration before scale.
```

### Wave 4 — Android foundation

```text
Phase ID: 108M
Title: Android Product Identity, Signing and Platform-Capability Foundation
Goal: Produce a correctly identified signed internal Android build using shared Cloud contracts.
Why now: Data/auth/offline foundations are stable enough for runtime work.
Scope: Application ID, signing strategy, secure config/storage, lifecycle and capability interfaces.
Explicit non-goals: Full screen redesign or store release.
Dependencies: 108H, 108K and stable composition.
Expected production files: Android config and platform adapters.
Acceptance gates: Physical/emulated device launch, session, cache reopen, offline queue, no Windows regression.
Rollback/stop conditions: Secrets/signing keys exposed or platform forks domain logic.
Rework avoided: Platform mechanics before UI batches.
```

```text
Phase ID: 108N
Title: Android Navigation and Daily-Flow Acceptance
Goal: Accept login, dashboard, product, purchase and sale navigation/touch flows on representative devices.
Why now: Establishes real responsive constraints.
Scope: Shell/navigation and the minimum daily vertical slice.
Explicit non-goals: Every report/settings screen or visual polish.
Dependencies: 108M.
Expected production files: Shared shell/responsive components and selected screens.
Acceptance gates: RTL, text scale, rotation/resume, keyboard, touch targets and back navigation.
Rollback/stop conditions: Desktop navigation regresses or flows fork by platform.
Rework avoided: Real device constraints guide later design-system work.
```

### Wave 5 — Cross-platform print/PDF/share

```text
Phase ID: 108O
Title: Invoice Data, Numbering and Version Contract
Goal: Freeze organization-scoped human numbering and immutable invoice DTO/version.
Why now: Cloud ownership exists and both platforms need the same document truth.
Scope: Sales/purchase invoice identity, cancellation/reissue, branding and locale contract.
Explicit non-goals: New visual template or platform printing.
Dependencies: Cloud document identity and organization settings.
Expected production files: Contract types only if authorized.
Acceptance gates: Concurrent numbering, offline reservation policy, legacy mapping and Arabic examples.
Rollback/stop conditions: Legal/tax numbering authority remains undecided.
Rework avoided: Renderer and platform work target one stable contract.
```

```text
Phase ID: 108P
Title: Shared PDF Renderer with Windows Print and Android Share Adapters
Goal: Reuse/upgrade current Arabic PDFs behind platform capabilities.
Why now: Invoice contract is stable.
Scope: Sales/purchase invoice first, path cleanup, print/share adapters and visual/runtime tests.
Explicit non-goals: All reports/statements in one phase.
Dependencies: 108O and 108M.
Expected production files: Renderer, capability adapters and selected UI actions.
Acceptance gates: Golden/visual RTL PDF, Windows print, Android share, safe filenames, cancellation marking.
Rollback/stop conditions: Platform code enters domain/document DTO.
Rework avoided: One renderer, two delivery mechanisms.
```

### Wave 6 — Design System and UI modernization

```text
Phase ID: 108Q
Title: Cross-Platform Design-System and Responsive-State Completion
Goal: Add shared tables/forms/dialogs plus loading/offline/conflict/pending states proven on Windows and Android.
Why now: Runtime constraints and data states are known.
Scope: Components/tokens and reference screens only.
Explicit non-goals: Whole-app redesign.
Dependencies: 108N and Cloud state model.
Expected production files: Shared UI system and reference migrations.
Acceptance gates: RTL, text scale, keyboard/touch, compact/wide, semantic and golden tests.
Rollback/stop conditions: Component requires duplicated platform screens.
Rework avoided: Screen batches build once on stable primitives.
```

```text
Phase ID: 108R
Title: Risk-Ordered Screen Modernization Batches
Goal: Migrate remaining screens in small financial/daily/report/admin batches.
Why now: Design system is accepted.
Scope: One batch per atomic child phase with visual/runtime acceptance.
Explicit non-goals: Business-rule changes hidden inside visual work.
Dependencies: 108Q.
Expected production files: Owning screens only.
Acceptance gates: Per-batch parity, responsive/RTL/device tests and no financial diffs.
Rollback/stop conditions: A batch mixes unrelated domain behavior.
Rework avoided: Controlled incremental polish.
```

### Wave 7 — Settings 2.0

```text
Phase ID: 108S
Title: Settings Ownership and Versioned Contract
Goal: Classify device/user/organization/warehouse/commercial settings and migration rules.
Why now: Cloud, invoice and platform capabilities now exist.
Scope: Contract and one reference storage adapter.
Explicit non-goals: Building every settings page.
Dependencies: 108E, 108O and Android capabilities.
Expected production files: Settings contract/adapter only.
Acceptance gates: Scope/RLS, offline cache, defaults, version migration and forbidden accounting switches.
Rollback/stop conditions: A setting can alter posted ledger truth client-side.
Rework avoided: Prevents one unversioned settings blob.
```

```text
Phase ID: 108T
Title: Settings 2.0 Incremental Expansion
Goal: Add business identity, invoice/print, appearance, backup/cloud, sync/device and account sections by ownership.
Why now: Each backing contract is stable.
Scope: Small section-specific child phases.
Explicit non-goals: Licensing until commercial authority is frozen.
Dependencies: 108S and 108Q.
Expected production files: Settings UI and owning adapters.
Acceptance gates: Windows/Android parity, RLS, offline state and migration tests.
Rollback/stop conditions: Settings duplicate server business records.
Rework avoided: UI follows stable ownership.
```

### Wave 8 — Commercial and operational hardening

```text
Phase ID: 108U
Title: Licensing, Delivery, Documentation and Genuine Client Acceptance
Goal: Produce a signed customer candidate with one licensing contract and current recovery/install docs, then run A–H.
Why now: Architecture and product surfaces are stable enough not to invalidate evidence.
Scope: Licensing/trial disposition, signed Windows/Android delivery, telemetry/support, docs and named client acceptance.
Explicit non-goals: New business features.
Dependencies: Cloud/Android/printing/settings readiness.
Expected production files: Only the chosen licensing/update/operational adapters.
Acceptance gates: Security review, package hashes/signatures, reinstall/upgrade, recovery rehearsal, explicit client decision.
Rollback/stop conditions: 107H is reused as acceptance without rerunning against the final contract.
Rework avoided: Commercial evidence is generated once for the actual product.
```

## 18. Deferred Work

- 107H interactive retry: preserved because licensing/cloud may supersede it.
- Five infrastructure Product Read consumers: production already has zero legacy
  reads; migrate with owning repository/cache refactors.
- Client doc correction: must occur before any next customer delivery, but a
  full rewrite now would be invalidated by Cloud paths/recovery. Current stale
  docs must not be distributed meanwhile.
- Broad FK hardening: reassess in the Supabase schema rather than changing the
  local schema twice.
- Full screen redesign, Settings 2.0 and PDF polish: wait for Android/data/
  document contracts.
- Strong licensing/DRM: wait for identity, offline grace and commercial policy.
- Genuine client acceptance: meaningful only against a customer candidate.

## 19. Work That Should NOT Be Done Yet

- Do not add Supabase tables/packages before 108C–108E decisions.
- Do not mirror SQLite tables one-for-one into Supabase.
- Do not let clients independently post ledger/stock/COGS rows.
- Do not build a generic last-write-wins sync engine for financial records.
- Do not migrate every screen or Settings page before Android and Cloud states.
- Do not redesign invoices before number/DTO ownership freezes.
- Do not treat the inactive Firebase bootstrap as Cloud progress.
- Do not ship current client docs or 107H artifacts as customer-ready.
- Do not mass-convert the five remaining Product Read consumers in isolation.
- Do not change local trial behavior merely to obtain a 107H PASS.

## 20. Frozen Next Phase

### Phase 108B — Execute and Close the Transfer Double-Count Accounting Scenario

**Why this is next:** It is the sole skipped test in an otherwise green 2,418-
case run and directly concerns an accounting invariant. Closing direct financial
proof is lower risk and smaller than beginning Cloud architecture.

**Exact goal:** make the existing skipped transfer double-count scenario execute
and pass without changing or weakening its financial assertion.

**Scope:** inspect the skip reason; provide the valid authenticated fixture or
minimum test harness correction; run the focused financial suite, full suite,
analyzer, formatter and Windows build; record direct totals.

**Non-goals:** production fix, new accounting behavior, Cloud/Supabase, schema,
UI, Android, product-read migration, 107H.

**Dependencies:** Phase 108A evidence and current committed accounting contract.

**Acceptance criteria:**

1. The exact scenario is no longer skipped.
2. Its original transfer-exclusion/double-count assertion is unchanged in meaning.
3. If it exposes a production defect, Phase 108B stops and reports it; it does
   not silently expand into a fix.
4. Full suite has zero failures and this skip is removed.
5. Analyzer, formatter and Windows release build pass.
6. Production diff is empty unless a separately authorized correction phase is
   required after a reproduced defect.

After 108B, start 108C — Cloud Operating Model and Data Authority Decision Freeze.

## 21. Final Owner Decision Summary

- **Is the current system functionally stable?** Yes, for local single-device
  Windows scope; all current gates pass.
- **Is there a critical financial problem?** No R0 defect is proven. One direct
  transfer double-count scenario remains skipped and must be proven next.
- **Is there a blocker before Cloud?** Yes: authority/tenancy/identity/time/
  transaction decisions and repository boundaries—not missing local features.
- **Should 107H be closed now?** No. Choose H-D and preserve its artifacts.
- **First correct step toward Supabase?** After 108B, freeze the Cloud operating
  model and data authority; do not create tables first.
- **When does Android start?** After auth/scope, one Cloud read/write vertical
  slice and the durable offline model are accepted.
- **When does UI redesign start?** Shared responsive completion after Android
  runtime constraints and Cloud states are known; then small screen batches.
- **When does Settings 2.0 start?** Contract classification before/during Cloud;
  full UI expansion after Cloud, invoice and Android capabilities stabilize.
- **Exactly what is Phase 108B?** Execute and close the skipped transfer
  double-count accounting scenario, test-only unless it proves a real defect.

The strategic decision is to preserve proven local financial behavior while
building a server-authoritative, offline-capable Cloud architecture that both
Windows and Android can share.
