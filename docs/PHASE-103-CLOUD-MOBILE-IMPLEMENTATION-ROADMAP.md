# Phase 103 — Cloud & Mobile Implementation Roadmap

Date frozen: 2026-07-28
Sequence principle: preserve working Windows behavior, isolate risk, use synthetic data first, and never enable multi-device financial writes before identity, idempotency and accounting authority exist.

## 1. Dependency chain

```text
104 boundary
  -> 105 backend foundation
    -> 106 identity/devices/permissions
      -> 107 outbox/idempotency/conflict foundation
        -> 108 reference-data sync
          -> 109 inventory/transaction sync
            -> 110 responsive mobile remediation
              -> 111 controlled Android pilot
                -> 112 backup/restore/DR
                  -> 113 genuine pilot migration
```

Phase 110 can begin component-level work after 104, but mobile pilot acceptance cannot precede 109. Phase 112 design begins with 105; production restore readiness must close before 113.

## 2. Safety gates common to all phases

- Start from an identified clean commit on a dedicated branch.
- No real data until Phase 113 owner authorization.
- No secret in source, fixtures, logs, screenshots or documents.
- Windows full tests/analyzer/format/build remain green.
- Accounting, inventory, backup compatibility and production profitability state have explicit regression tests.
- Every schema/contract migration is versioned, restart-safe, rollback/recovery-tested and source-safe.
- No hidden/deleted page or placeholder represented as completed functionality.
- Security and organization isolation are tested server-side; UI permissions never count as authorization.

## 3. Phase plans

### Phase 104 — Data Access Boundary & Repository Separation

**Goal:** stop presentation/domain code from selecting or owning SQLite while preserving identical Windows behavior.

- Start point: Phase 103 frozen contracts and clean verification baseline.
- Expected layers/files: `lib/app` composition root; new application use cases; normalized repository contracts; local Drift data-source adapters; clock/ID/file capability interfaces; screens migrated from static `AppRepositories` access.
- Risks: accidental transaction-boundary changes, state lifetime changes, large refactor, test fixtures tied to globals.
- Tests: characterization for all repository operations; transaction/rollback/accounting/backup regressions; widget navigation; Windows release smoke.
- Start gate: Phase 103 Outcome A and owner acceptance of scope.
- Exit gate: no feature widget imports Drift/persistence; no business domain imports Flutter/platform/cloud; all current behavior and schema/backup format unchanged; global wiring isolated to composition root.
- Out of scope: backend, HTTP, cloud auth, outbox, schema tenant migration, mobile feature changes.

### Phase 105 — Cloud Backend Foundation

**Goal:** establish a synthetic development backend foundation and choose a provider through evidence.

- Start point: Phase 104 repository/application boundary.
- Expected layers/files: versioned API contracts/OpenAPI; server application skeleton; PostgreSQL reference schema/migrations; organization/branch/warehouse model; secrets/config templates; local emulator/dev environment; observability and threat-model updates.
- Risks: provider lock, RLS mistakes, premature direct-client writes, cost/region assumptions, secrets leakage.
- Tests: provider spikes from the option assessment; transaction/isolation/idempotency prototypes; organization isolation; migration up/down/recovery; latency/cost evidence.
- Start gate: approved synthetic-only environment and security review.
- Exit gate: owner-approved provider or explicitly bounded continuation, reproducible isolated environment, no production data, API/provider boundary contract tests, reference relational model and operations runbook.
- Out of scope: production environment, client sync, real users/data, public launch.

### Phase 106 — Identity, Users, Devices & Permissions

**Goal:** implement server identities without merging employee and login lifecycles.

- Start point: organization-aware backend foundation.
- Expected layers/files: `UserAccount`, external credential link, `Employee`, membership/grants, roles/permissions, device registry, sessions/refresh rotation/revocation, audit; secure-storage adapters.
- Risks: account takeover, cross-org grants, stale offline permission, insecure recovery, accidental Employee auto-account creation.
- Tests: invite/activation/disable/link; role/branch change; one/all-device logout; stolen/reinstalled device; password reset; revocation with pending queue; server-side permission denial; audit.
- Start gate: auth threat model, secure development secrets, owner decisions on MFA/session/grace.
- Exit gate: server authorization on all prototype endpoints, default-deny organization isolation, revocation and audit proven, Employee/UserAccount separation proven.
- Out of scope: payroll/attendance/leave; broad production onboarding; real staff accounts.

### Phase 107 — Offline Outbox & Idempotent Sync Foundation

**Goal:** build durable, observable, idempotent command transport with synthetic non-financial commands first.

- Start point: stable application commands and authenticated device/session model.
- Expected layers/files: local outbox/inbox/cursor migrations; sync coordinator; connectivity/lifecycle adapters; remote API data source; idempotency result store; retry/lease/dependency/conflict state; sync-status UI.
- Risks: unknown-timeout duplicates, queue loss, two workers, payload drift, revoked device, clock skew.
- Tests: crash at every state transition; response loss; replay; same-key/different-payload; retry/jitter; dependency failure; pull cursor atomicity; reinstall/revoke; Windows/Android lifecycle.
- Start gate: frozen Phase 103 sync contract and server idempotency prototype.
- Exit gate: durable queue survives restart, every retry uses same key, acknowledgements/pull apply idempotently, visible failure states, no financial command enabled.
- Out of scope: production transaction sync, real data, background behavior not supported by platform policy.

### Phase 108 — Core Reference Data Sync

**Goal:** synchronize low-risk mutable reference data before financial ledgers.

- Start point: proven outbox/inbox and organization isolation.
- Expected areas: products, customers, suppliers, financial-account definitions, business identity/settings; versions/tombstones and conflict review.
- Risks: duplicate legacy IDs, name uniqueness changes, cross-org leakage, deletion conflict, logo/object mismatch.
- Tests: UUID mapping, expected-version conflict, safe field merge, tombstone propagation, offline create/edit, two-device convergence, legacy backup/import compatibility.
- Start gate: synthetic seed/migration mapping and owner-approved conflict fields.
- Exit gate: deterministic convergence across Windows/Android synthetic devices; no financial balance/movement writes; conflict UI truthful.
- Out of scope: sales, purchases, stock movements, payments, COGS, closings.

### Phase 109 — Inventory and Transaction Sync

**Goal:** move final financial/inventory command authority to the server without changing accounting rules.

- Start point: reference sync, identity, idempotency, server relational transactions, full accounting characterization suite.
- Expected areas: stock/valuation ledgers, sales, purchases, collections, payments, expenses, accounts/entries/transfers, approvals, cancellations/refunds, closings, server audit, reconciled local materialized views.
- Risks: duplicate or partial posting, divergent COGS, negative stock, closed-period bypass, out-of-order dependencies, rollback/restore mismatch.
- Tests: concurrent-device race matrix; complete moving-average/COGS suite; timeout/replay; cancellation/reversal; close/reopen; negative-balance approval; reconciliation; long offline queue; server/local comparison; performance.
- Start gate: owner/accounting acceptance of server command model and synthetic migration rehearsal.
- Exit gate: every financial command is atomic/idempotent/server-authoritative, local results reconcile, Windows single-device continuity and rollback plan proven, no production data.
- Out of scope: genuine production migration and uncontrolled devices.

### Phase 110 — Responsive Mobile UI Remediation

**Goal:** make every audited business capability usable on phone/touch without deleting or hiding pages.

- Start point: Phase 103 inventory; stable application APIs. P0 design may proceed earlier, acceptance follows Phase 109.
- Expected areas: shell/navigation, 15 redesign screens, 18 adjustment screens, full-screen high-risk workflows, responsive report cards/drill-downs, file/share/print capability adapters, offline/sync status.
- Risks: overflow, hidden actions, unsafe confirmations, numeric keyboard/locale errors, RTL regression, provisional values presented as final.
- Tests: 320/360/390/600/840 widths; Android back; touch targets; large text; RTL; Light/Dark; long Arabic/money; keyboard/mouse Windows parity; golden/widget tests.
- Start gate: owner-approved mobile UX wireframes and no-hidden-page mapping.
- Exit gate: all 42 screens classified `MobileReady` by test evidence or have an owner-approved truthful platform alternative; zero unexplained overflow; P0 workflows pass device tests.
- Out of scope: public store release, iOS final build, production data.

### Phase 111 — Android Pilot

**Goal:** controlled Android operation for one synthetic/test organization and approved devices.

- Start point: server transaction sync and mobile UI acceptance.
- Expected areas: Android signing/flavors, secure storage, permissions, lifecycle/background policy, crash/monitoring, distribution runbook, controlled enrollment.
- Risks: device compromise, mobile network loss, background restrictions, store/signing leakage, unsupported plugin behavior.
- Tests: release build/install on representative physical devices; offline/online/restart/reinstall; file/share/print; revocation; long queue; battery/network; Windows coexistence.
- Start gate: isolated test backend, synthetic dataset, named operators/devices, incident/rollback plan.
- Exit gate: signed pilot acceptance, no critical sync/accounting/security defect, queue drained/reconciled, device revocation and support runbook proven.
- Out of scope: public Play release, unrestricted organizations, real production migration, iOS release.

### Phase 112 — Cloud Backup, Restore & Disaster Recovery

**Goal:** prove server backup, organization export, device recovery and disaster recovery as separate controlled capabilities.

- Start point: selected provider/operations model and stable server schema/object storage.
- Expected areas: automated backups/PITR or equivalent, object backup, export jobs, cache rehydration, restore tooling, integrity/reconciliation, RPO/RTO monitoring, runbooks.
- Risks: untested backup, missing objects/secrets, cross-org restore, duplicate transactions, excessive downtime, provider-only backup trap.
- Tests: scheduled/manual backup; isolated restore; point-in-time scenario; org export/import; device replacement; corruption and old v1–v8 import; duplicate prevention; access/audit.
- Start gate: owner-approved retention/RPO/RTO and paid-resource authorization where required.
- Exit gate: witnessed restore drill meets RPO/RTO and reconciliation; off-provider export exists; cross-org denial proven; runbook signed.
- Out of scope: live destructive restore without separate incident authorization.

### Phase 113 — Genuine Pilot Migration

**Goal:** migrate one explicitly approved real organization through a rehearsed, reversible rollout.

- Start point: Phases 104–112 closed, Android pilot accepted, provider/legal/security/DR decisions approved.
- Expected areas: read-only intake validation, migration mapper, legacy ID map, backups, reconciliation reports, controlled cutover/fallback, monitoring/support, acceptance evidence.
- Risks: data loss, duplicate posting, incorrect opening stock/value/COGS, downtime, privacy, operator confusion, rollback divergence.
- Tests: production-shaped rehearsal from a copied/authorized snapshot; row/relationship/hash/totals/valuation reconciliation; parallel read-only comparison; cutover and rollback drill; owner UAT.
- Start gate: explicit owner authorization naming dataset/environment/date, legal/privacy approval, complete pre-migration backup, support window and rollback threshold.
- Exit gate: owner acceptance, reconciled server/local totals, no unresolved critical issue, backup/restore evidence, controlled device roster and monitoring.
- Out of scope: additional organizations, public launch, automatic bulk migration, iOS launch unless separately approved.

## 4. Decision gates and deferred work

- Provider choice: resolve in Phase 105 after spikes; no resource creation is authorized by this roadmap.
- UUID flavor, session durations, offline grace, MFA and device limits: Phase 106.
- Retry timings, retention and background policy: Phase 107 reliability testing.
- Reference-data mergeable fields: Phase 108 owner decision.
- Server isolation/locking details and transaction throughput targets: Phase 109 evidence.
- Mobile wireframes and any genuine desktop-only alternative: Phase 110 owner acceptance.
- Android distribution/signing channel: Phase 111.
- RPO/RTO/retention/paid backup tier: Phase 112.
- Real dataset/cutover: Phase 113 explicit authorization only.

## 5. Lowest-risk next action

Begin only **Phase 104 — Data Access Boundary & Repository Separation** after Phase 103 closes. Preserve SQLite schema 15, backup v8/v1–v8 restore, Windows behavior, all pages and accounting/profitability rules. Do not add a backend during Phase 104.
