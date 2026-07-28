# Phase 103 — Target Cloud & Mobile Architecture Scope Freeze

Date frozen: 2026-07-28
Status: architecture contract; implementation starts no earlier than Phase 104.

## 1. Target shape

```text
Flutter UI (Windows / Android / future iOS)
  -> Presentation state / view models
    -> Application use cases (commands + queries)
      -> Domain policies and deterministic calculations
        -> Repository contracts
          -> Local SQLite data sources + durable outbox/inbox
          -> Remote API data source
            -> Auth/session/device boundary
            -> Server application command/query handlers
              -> Relational transactional store + private object storage
              -> Append-only audit + idempotency results
```

Widgets never select local versus remote storage and never call Drift, HTTP, a cloud SDK, or platform APIs directly. The application layer decides whether a query uses a local snapshot and whether a command is submitted immediately or persisted to the outbox.

## 2. Frozen layer boundaries

| Layer | Owns | Must not own |
| --- | --- | --- |
| Presentation | Layout, input, navigation, accessibility, localization, status/staleness display | SQL, HTTP, credentials, stock/accounting rules |
| Application | Use cases, command/query orchestration, authorization intent, transaction group, offline policy | Flutter widgets, concrete SQLite/API code |
| Domain | Inventory/accounting invariants, money/quantity types, valuation, cancellation/reversal, conflict classification | Drift, JSON transport, platform APIs, cloud SDKs |
| Repository contracts | Business-shaped reads/writes, expected versions, idempotency and error vocabulary | Provider-specific DTOs or direct client database access |
| Local data | SQLite mapping, local migrations, cache, outbox/inbox, sync cursor | Final authority for shared posted state |
| Remote data | API DTOs, authenticated transport, retries/acknowledgements | UI concerns and provider-specific semantics leaking upward |
| Server application | Authorization, idempotency, validation, atomic commands, audit, conflict responses | Trusting client totals, client organization scope, or device time |
| Infrastructure | Relational database, object storage, secrets, backup, monitoring | Domain decisions encoded only in vendor triggers without shared tests |

## 3. Server-authoritative model

`Server-Authoritative for Shared Business State` is frozen.

The server is final for organizations, branches, warehouses, user accounts, grants, devices, sessions, products, parties, stock movements, inventory valuation, COGS, sales, purchases, collections, payments, expenses, financial accounts/entries/transfers, closings, approvals, audit, sync acknowledgements, document numbers, and organization exports.

SQLite remains:

- the local operational cache;
- the offline working store;
- the durable outbox and applied-change inbox;
- a materialized view of the last acknowledged server state;
- the sole production store during the transitional Windows-only phases;
- never an independent final truth once more than one device is enabled.

Device-local truth is limited to preferences, capability state, encrypted session material, local file handles, UI drafts, and unsent operations clearly marked provisional.

## 4. Repository contracts

Existing repository abstractions are an asset, but Phase 104 must normalize them around explicit command/query semantics. The following future contracts are frozen by responsibility, not by exact Dart signature.

| Contract | Reads | Writes / atomic boundary | Offline and conflict contract |
| --- | --- | --- | --- |
| `ProductRepository` | Product by ID, scoped list/search, version | Create/update/activate with expected version | Local provisional create; version conflict/field review |
| `InventoryRepository` | Acknowledged balance, movements, pending effect | Stock command group only; no direct balance overwrite | Provisional preview; server validates stock/close and orders ledger |
| `SalesRepository` | Sales, lines, sync/result state | One sale command includes lines, stock, valuation, revenue/receivable and allocations | Global idempotency; rejection/ack replaces provisional result; no LWW |
| `PurchaseRepository` | Purchases and lines | One purchase command includes stock/value, payable/payment and evidence | Dependency-aware; server validation; no partial apply |
| `CustomerRepository` | Scoped customer/reference snapshot | Versioned reference-data command | Controlled merge or review |
| `SupplierRepository` | Scoped supplier/reference snapshot | Versioned reference-data command | Controlled merge or review |
| `FinancialAccountRepository` | Accounts, entries, balances, closings | Atomic append/reversal/transfer/closing commands | Server-only acceptance; serialization retry; no client balance overwrite |
| `AuditRepository` | Authorized filtered audit | Server appends; client can queue provisional intent | Server time/actor/device; immutable acknowledged entries |
| `UserAccountRepository` | Current account/grants, authorized administration | Invite/activate/disable/role/link commands | Server authority; revocation beats offline grace |
| `EmployeeRepository` | HR identity/profile/link | Create/update/transfer employee separately | Never auto-creates login; future HR conflict rules |
| `SyncRepository` | Queue/status/cursor/failures | Enqueue, claim, acknowledge, retry, quarantine | Durable state machine; no blind delete |
| `BackupRepository` | Device recovery metadata, exports/jobs | Device recovery, organization export request, restore authorization | Organization/hash/version bound; never mixed with normal sync |

Every write contract must accept or derive: organization context from the authenticated session, actor, device, operation/idempotency key, payload version, entity/command ID, client timestamp, expected/base version when relevant, and transaction group/dependencies when relevant.

Every result must expose: accepted/rejected/conflict status, stable server result ID, server timestamp, authoritative versions/document numbers, error code safe for the user, reconciliation totals when financial, and whether the local snapshot is stale/provisional.

## 5. Error vocabulary

Provider-neutral application errors are frozen:

- `unauthenticated`, `sessionExpired`, `deviceRevoked`, `accountDisabled`;
- `forbidden`, `organizationScopeViolation`, `warehouseScopeViolation`;
- `validationFailed`, `unsupportedPayloadVersion`;
- `duplicateAccepted`, `idempotencyPayloadMismatch`;
- `versionConflict`, `dependencyNotReady`, `closedPeriod`;
- `insufficientStock`, `negativeBalanceApprovalRequired`;
- `accountingInvariantViolation`, `reconciliationFailed`;
- `retryableNetwork`, `retryableServer`, `permanentFailure`.

Vendor error codes must be mapped at the infrastructure edge and must not reach domain/UI contracts directly.

## 6. Identity and scope model

Globally unique, opaque IDs are required. UUIDv7 is the preferred initial candidate because clients can create sortable unique IDs offline; UUIDv4 is an acceptable fallback. Human document numbers are separate, server-issued, immutable business references.

| Entity family | Organization | Branch | Warehouse | Actor/device | Version | Server time | Tombstone | Idempotency |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Organization/settings | Self | Optional | Optional | Yes | Yes | Yes | Soft archive | Writes |
| Product/customer/supplier | Required | Optional assignment | Optional | Yes | Yes | Yes | Yes | Create/update |
| Employee/UserAccount | Required | Assignment | Optional assignment | Yes | Yes | Yes | Disable/archive | Account commands |
| Device/session/grant | Required | Optional | Optional | Yes | Yes | Yes | Revoke state | Registration/session commands |
| Inventory movement/value event | Required | Required when enabled | Required | Yes | Append version/order | Yes | Reversal, not delete | Always |
| Sale/purchase/collection/payment/expense | Required | Required | Required where stock applies | Yes | Append/status version | Yes | Cancellation/reversal | Always |
| Financial account/entry/closing | Required | Optional account scope | N/A | Yes | Yes/append | Yes | Reversal/reopen | Always |
| Audit | Required | Context | Context | Required | Append order | Required | Never normal delete | Source operation |
| Attachment/export | Required | Context | Context | Required | Object version | Required | Retention state | Upload/request |

The transition creates one default organization, branch, and warehouse for the current owner so the existing single-device customer is not forced through complex setup. This convenience must not hard-code “one warehouse forever.”

## 7. `Employee != UserAccount`

This is non-negotiable:

- `Employee` is an employment/HR identity and can exist without login.
- `UserAccount` is an authentication/authorization identity and is created only after approved appointment, role selection, and formal authorization.
- An optional link connects them; it does not merge their lifecycles.
- Disabling/revoking an account does not delete the employee record.
- User activity/audit uses `userAccountId`; HR attendance/leave/payroll uses `employeeId`.
- Role changes and branch/department transfers are audited commands with independent effective dates.
- Future HR sync must not expose password/session state through employee records.

## 8. Authentication, sessions, and devices

The future model includes short-lived access tokens, rotating refresh sessions, secure platform storage, device registration, one/all-device logout, session listing, password reset, account disablement, grant refresh, and audit.

Frozen rules:

1. Authorization is server-side on every query and command; hidden UI is only convenience.
2. Organization scope comes from the authenticated membership/session, never trusted from a payload alone.
3. Device revocation blocks new sync. Pending financial operations remain locally visible and require authorized recovery/review; they are not silently discarded.
4. Offline session grace is a policy decision applied only to previously authorized, cached scope. High-risk actions may require online reauthentication.
5. Password change/account disablement invalidates refresh sessions. Cached access cannot grant new server acceptance.
6. Tokens, passwords and secrets never enter logs, backups, ordinary SQLite tables, or repository fixtures.
7. Reinstallation creates a new device identity; restoring another device's secure token is forbidden.

Exact token durations, grace duration, concurrent-device limit, MFA method, and password policy are deferred to Phase 106 security review.

## 9. Accounting and inventory execution authority

The following rules are unchanged and frozen: moving weighted average, transaction-level immutable COGS, deterministic integer-qirsh arithmetic/residual handling, current negative-stock policy, exact cancellation/reversal, stock restoration, collection/payment correctness, separated financial accounts, closings, audit, and truthful profitability states.

Execution placement:

- server: final validation, ordering, atomic mutation, document number, stock/value/account/close authority;
- shared deterministic domain logic: pure calculations used by server and client preview with identical golden tests;
- client: provisional preview only; it cannot declare a conflicting stock/accounting result final.

Posted financial/inventory events are append-oriented. Corrections are explicit linked reversals or approved adjustments. Last-write-wins and silent merge are prohibited.

Production remains `profitabilityNotActivated`. Phase 102J synthetic success is test evidence only.

## 10. Backup and files target

Four capabilities are distinct:

1. **Device recovery:** rebuild cache/outbox safely for one registered device.
2. **Organization export:** authorized portable export scoped to one organization, versioned and integrity-checked.
3. **Server backup:** automated database/object-storage backup with retention and monitoring.
4. **Disaster recovery:** rehearsed server restore with RPO/RTO and reconciliation.

Backup v1–v8 reading remains supported through an explicit legacy import boundary. Phase 103 does not change the format. A future import must bind organization, validate hash/version/relationships, prevent duplicate posting, audit actor/device/time, and stage before commit. Local restore is never sent through ordinary transaction sync.

Files use a `FileCapability`/`ObjectStorageRepository` abstraction. Windows may save/open/print; Android/iOS use share sheets, document providers and platform permissions. Shared code uses path APIs, not backslash literals.

## 11. Security baseline

TLS, secure token storage, server authorization, least privilege, default-deny organization isolation, input validation, rate limiting, append-only audit, managed secrets, redacted structured logs, encryption at rest where risk requires it, private object storage, signed time-limited downloads, upload validation/scanning, and non-recoverable password hashing are mandatory implementation gates.

No real token, URL, password, provider project, or secret is authorized by this scope freeze.

## 12. Provider-neutrality contract

Application and domain packages may not import Firebase, Supabase, Appwrite, PostgreSQL drivers, HTTP implementations, or cloud SDKs. Remote contracts use application DTOs and stable error semantics. Authentication, database, object storage, observability, background work, and messaging each have infrastructure adapters. Data export must be provider-independent and migrations version-controlled.

The final provider remains `ProviderSelectionDeferred` pending Phase 105 spikes and owner approval.

## 13. Frozen decisions before Phase 104

- Windows remains supported throughout migration.
- Android-first pilot; iOS-compatible architecture and later macOS build gate.
- SQLite is retained as offline cache/working store/outbox.
- Server is authoritative for shared business state.
- No production cloud migration or real customer data in development.
- Presentation, application, domain, repositories, local data and remote data are separate boundaries.
- Global IDs and idempotency are mandatory before multi-device financial writes.
- Conflict policy is per entity; financial/inventory state never uses LWW.
- Organization, branch, warehouse, actor, device, version and server-time scope are explicit where required.
- `Employee != UserAccount`.
- Accounting correctness precedes availability or UI convenience.
- No page is hidden/deleted to claim mobile readiness.
- No placeholder is represented as completed functionality.
- Backup capabilities are separated as device/org/server/DR.
- Production profitability remains not activated.
- No provider lock before evidence.

Any future change to these contracts requires a new owner-visible architecture decision record and cannot be smuggled into implementation.
