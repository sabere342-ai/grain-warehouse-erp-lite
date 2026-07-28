# Phase 103 — Owner Decisions & Non-Negotiable Contracts

Date frozen: 2026-07-28
Authority: explicit owner authorization in the Phase 103 request.
This document governs Phases 104–113 unless replaced by a later explicit owner-approved decision record.

## 1. Platform decisions

1. **Windows must remain supported.** Migration is incremental; Windows is never sacrificed to claim mobile readiness.
2. **Android-first pilot.** Android is the first controlled mobile target because the development environment is Windows and Android scaffolding exists.
3. **iOS-compatible architecture.** No Android-only rule enters domain, application, repository or transport contracts. Final iOS build/test occurs later on an approved macOS/Xcode environment.
4. **No hidden or deleted pages.** Every business capability remains mapped. Platform alternatives must be explicit and owner-approved.
5. **No placeholders presented as completed functionality.** An unavailable cloud/mobile capability is labeled unavailable or planned.

## 2. Data and authority decisions

1. **SQLite is retained** as the Windows transitional store and future device cache/offline working store/outbox.
2. **Server authoritative for shared state** after multi-device enablement.
3. SQLite is not deleted, converted in place, or treated as an independent truth when several devices operate.
4. Shared entities use organization scope; branch/warehouse scope is explicit where relevant. One default organization/branch/warehouse may simplify current-customer migration but may not hard-code a one-warehouse future.
5. Entity and operation identities become globally unique and application-owned. Local auto-increment/sequence/device time is not sufficient.
6. Server timestamps and organization timezone govern sensitive ordering/closing; client timestamps remain evidence/business intent.
7. Mutable reference data uses versions/tombstones; posted financial/inventory records use append/reversal semantics.

## 3. Architecture decisions

1. Presentation, application, domain, repository contracts, local sources, remote sources and platform capabilities are distinct boundaries.
2. Widgets do not call Drift, SQL, HTTP, provider SDKs, secure storage or platform file APIs directly.
3. Domain rules import no Flutter, SQLite, HTTP, Windows, Android, iOS or cloud SDK.
4. Remote access is through a provider-neutral command/query API. Direct client database writes are not accepted for financial commands.
5. Existing repository contracts are preserved as evidence/assets, then normalized in Phase 104 without behavior change.
6. Provider selection is `ProviderSelectionDeferred`; existing Firebase scaffolding is not a provider commitment.

## 4. Offline, sync and conflict decisions

1. Offline operations use a durable SQLite outbox with global operation/idempotency identity, payload version/fingerprint, actor/device, dependency, base version, retry and status evidence.
2. Idempotency is enforced by the server. Same key/same fingerprint returns the original result; same key/different fingerprint is rejected and audited.
3. Unknown timeout always retries/queries with the same key. A new key may not recreate the business operation.
4. Financial/inventory commands are atomic transaction groups. Partial stock/accounting application is prohibited.
5. Conflict strategy is per entity. Last-write-wins is prohibited for stock, valuation, COGS, balances, financial entries, closings, approvals and posted transactions.
6. Reference data may use optimistic version checks and controlled field merge/review.
7. Pending/provisional/stale/conflict/rejected states are visible to the operator.

## 5. Identity and authorization decisions

1. **`Employee != UserAccount`.** An employee can exist without login; account creation requires approved appointment/role/authorization.
2. Disabling an account does not delete employee history. User audit uses `userAccountId`; HR uses `employeeId`.
3. Devices and sessions are independently registered/listed/revocable. One/all-device logout and password reset are required.
4. Access tokens are short-lived; refresh sessions rotate and are securely stored. Exact durations are deferred to Phase 106 review.
5. Authorization is server-side and organization-scoped on every command/query. Hiding a button is never authorization.
6. Account/device revocation overrides offline grace for server acceptance. Pending work is reviewed, not silently discarded.
7. No recoverable plaintext password, token or secret enters source, ordinary SQLite, backup, log or fixture.

## 6. Accounting and inventory decisions

The cloud/mobile transition may not alter these contracts:

- moving weighted average;
- transaction-level immutable COGS;
- deterministic integer-qirsh monetary arithmetic and approved precision/residual rules;
- current negative-stock policy;
- correct sale/purchase cancellation and explicit reversals;
- stock restoration and valuation symmetry;
- collection/payment/advance/refund correctness;
- separated financial accounts and correct transfers;
- daily/period closing enforcement;
- complete audit evidence;
- truthful profitability accuracy/state.

The server finally validates and commits these results. The client may calculate a deterministic preview but cannot independently finalize a conflicting stock/accounting state.

**Production remains `profitabilityNotActivated`.** Phase 102J synthetic success is not real inventory evidence and does not activate production profitability.

## 7. Backup, restore and file decisions

1. Device cache recovery, organization export, server backup and disaster recovery are separate products/workflows.
2. Current backup export v8 and restore support v1–v8 are unchanged in Phase 103.
3. Old backups retain an explicit compatibility/import path. No silent reinterpretation of dates, cost, organization or identity is permitted.
4. Restore/import requires version/hash/relationship/organization preflight, duplicate prevention, reconciliation and audit.
5. A device backup cannot overwrite central truth as a normal sync operation.
6. Windows file save/open/print remains; mobile gets capability-aware share/document/print alternatives.
7. Organization files are private, scoped, integrity-checked and access-controlled; public permanent URLs are not the default.

## 8. Security decisions

TLS, secure token storage, server-side authorization, default-deny organization isolation, least privilege, input validation, rate limiting, managed secrets, redacted logs, append-only audit, private object storage, file validation/scanning, encryption at rest where risk requires it, and tested backup/restore are mandatory gates.

No real secret, API key, password, token, cloud URL, paid account, production backend, or customer dataset is authorized in Phase 103.

## 9. Delivery and environment decisions

1. No production cloud migration yet.
2. No real data in development; synthetic fixtures only until explicit Phase 113 authorization.
3. No production backend, API, login, sync, database migration or cloud SDK addition in Phase 103.
4. No Android/iOS publication in Phase 103.
5. No Push or Tag in Phase 103.
6. No Force push, rebase/history rewrite, deletion of commits, or unauthorized merge.
7. Phase 104 is not started within Phase 103.

## 10. Provider decision

The reference target is a provider-neutral application API with a relational transactional store and PostgreSQL as the reference model. Managed PostgreSQL/custom API and Supabase-hosted PostgreSQL are the initial Phase 105 spike candidates. Firebase and Appwrite remain alternatives/ancillary candidates subject to proof.

The final provider, region, budget/support tier, legal/retention posture, authentication provider, RPO/RTO, object storage and monitoring vendors require later evidence and explicit authorization.

## 11. Mobile UI decision

The static audit found 42 reachable screen classes: 6 structurally mobile-ready, 18 needing responsive adjustment, 15 needing mobile redesign, and 3 blocked by backup/cloud authority semantics. This is a scope inventory, not device acceptance. Phase 110 must test all screens at phone/tablet widths, RTL, Light/Dark, large text, touch, long money values, Android back, and Windows keyboard/mouse parity.

Backup/restore/wipe cannot be exposed on mobile under misleading desktop semantics. Their business capabilities remain, but device recovery, organization export, server restore and cache wipe are separated first.

## 12. Deferred decisions register

| Decision | Required by | Owner/evidence gate |
| --- | --- | --- |
| Final cloud/provider/region/support tier | Phase 105 close | Synthetic spikes, latency/cost/export/security comparison |
| UUID version and legacy ID mapping details | Phase 105/108 | Migration rehearsal and relationship proof |
| MFA, password, token/session durations and offline grace | Phase 106 | Security threat model and operator needs |
| Device limit and revocation recovery | Phase 106 | Pilot operating model |
| Retry/backoff/retention/background policy | Phase 107 | Reliability/load/device tests |
| Mergeable reference-data fields | Phase 108 | Per-entity owner decision |
| Server isolation/locking and throughput targets | Phase 109 | Concurrency/accounting benchmarks |
| Mobile wireframes and platform alternatives | Phase 110 | Owner UX review; no hidden pages |
| Android signing/distribution channel | Phase 111 | Controlled pilot plan |
| RPO/RTO/backup retention/paid tier | Phase 112 | Business impact and restore drill plan |
| Genuine dataset, migration date and cutover | Phase 113 | Explicit dataset/environment/date authorization |

## 13. Change-control rule

A later implementation may refine names and internal mechanics but may not weaken organization isolation, server authority, idempotency, accounting correctness, Employee/UserAccount separation, Windows support, offline evidence, backup separation, mobile page coverage, or provider neutrality without a new explicit owner-approved decision record.
