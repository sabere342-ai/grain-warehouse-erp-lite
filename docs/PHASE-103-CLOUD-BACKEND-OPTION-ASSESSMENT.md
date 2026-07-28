# Phase 103 — Cloud Backend Option Assessment

Assessment date: 2026-07-28
Decision: `ProviderSelectionDeferred`
No provider account, project, database, API, secret, deployment, or real-data transfer was created.

## 1. Workload-specific decision criteria

This ERP is not a generic CRUD application. The decisive requirements are atomic sale/purchase/payment groups, ordered inventory valuation and transaction-level COGS, financial closings, durable idempotency, append/reversal semantics, organization isolation, audit, offline outbox, Windows/Android/future-iOS parity, restore drills, exportability, and predictable operations from Egypt.

The provider must not force financial correctness into client-side last-write-wins behavior. Offline SDK convenience is useful only if final server commands still validate all accounting and stock invariants.

## 2. Official evidence used

All sources were accessed 2026-07-28. Dynamic pricing/regions must be rechecked at procurement.

- PostgreSQL 18 current documentation: [transaction isolation](https://www.postgresql.org/docs/current/transaction-iso.html), [row security](https://www.postgresql.org/docs/current/ddl-rowsecurity.html), and [backup/restore](https://www.postgresql.org/docs/current/backup.html). PostgreSQL documents Serializable behavior/retry requirements and default-deny row security when enabled without policies.
- Supabase: [Postgres database overview](https://supabase.com/docs/guides/database/overview), [row-level security](https://supabase.com/docs/guides/database/postgres/row-level-security), [Flutter integration](https://supabase.com/docs/guides/getting-started/quickstarts/flutter), [backups/PITR](https://supabase.com/docs/guides/platform/backups), and [available regions](https://supabase.com/docs/guides/platform/regions). Supabase is PostgreSQL-based; paid backup/PITR and region/retention terms are plan-dependent. The region list had European/Asian choices but no Egypt-specific region.
- Firebase/Cloud Firestore: [Flutter setup and supported platforms](https://firebase.google.com/docs/flutter/setup), [offline persistence](https://firebase.google.com/docs/firestore/manage-data/enable-offline), [transactions](https://firebase.google.com/docs/firestore/manage-data/transactions), and [locations](https://firebase.google.com/docs/firestore/locations). Firestore offline uses last-write-wins for repeated edits to one document, client transactions fail offline, and Windows Flutter plugins are listed as beta for relevant products as of the accessed page.
- Appwrite: [database overview](https://appwrite.io/docs/products/databases), [transactions](https://appwrite.io/docs/products/databases/transactions), [offline sync guidance](https://appwrite.io/docs/products/databases/offline), [cloud backups](https://appwrite.io/docs/products/databases/backups), and [self-hosted database choices](https://appwrite.io/docs/advanced/self-hosting/configuration/databases). Accessed self-hosting documentation identified Appwrite 1.9.x with MongoDB default and MariaDB alternative; backend selection is infrastructure-bound.

Repository-specific evidence:

- current storage is relational Drift/SQLite schema 15 with cross-domain transactions;
- backup export v8 and restore v1–v8 exist;
- `firebase_core: ^3.8.0` is already present, but no Firestore/Auth SDK or real options exist;
- `firebase_options.dart` intentionally throws; this scaffold is not a provider decision;
- no HTTP/API, sync, organization, device, session, remote version, or server audit implementation exists.

## 3. Options

### A. Provider-neutral custom application API + managed PostgreSQL

An application service exposes business commands/queries; clients never connect directly to the database. PostgreSQL supplies relational constraints, transactions, locking/Serializable where appropriate, unique idempotency records, row security as defense in depth, migrations and conventional export/backup tooling. Hosting, authentication, object storage, jobs and monitoring are selected separately or as managed services.

Strengths: best fit for atomic accounting/inventory, explicit command semantics, portability, audit, SQL reconciliation and provider migration. Weaknesses: highest backend engineering/operations burden; offline sync is application work; secure deployment and Egypt-region latency/support require a managed-host evaluation.

### B. Supabase-managed PostgreSQL platform

Supabase combines PostgreSQL, Auth, Storage, Realtime, APIs and Flutter libraries. It can host the same relational model and use RLS. Financial commands should still run through trusted server functions/application API, not arbitrary direct client table writes.

Strengths: relational fit, faster foundation, Flutter path, PostgreSQL portability, RLS and managed operational features. Weaknesses: offline outbox/conflict remains application work; direct-client RLS policy mistakes are high impact; platform Auth/Storage/Realtime coupling and plan-dependent backups/PITR create lock-in/cost considerations; no Egypt-specific region was evidenced.

### C. Firebase Auth + Cloud Firestore/Functions style platform

Strengths: mature mobile SDK, Android/Apple offline cache/sync, managed identity/operations, Middle East Firestore regions in current documentation. Weaknesses: document model and last-write-wins offline behavior do not naturally fit multi-entity accounting transactions; client transactions fail offline; complex relational reporting/reconciliation needs redesign or a separate SQL layer; Windows Flutter support for Firestore/Auth is currently beta according to the accessed official table. Vendor coupling and read/write billing require careful modeling.

Firestore is not rejected for ancillary capabilities, but it is not selected as the primary accounting source of truth in Phase 103.

### D. Appwrite cloud/self-hosted platform

Strengths: Auth/permissions/storage/functions, Flutter SDK, documented transactions/offline integration guidance, cloud or self-hosted choice. Weaknesses: offline sync guidance still requires a local store and conflict strategy; current self-hosted database backend choices differ from the desired PostgreSQL target; platform API abstraction and backup capabilities/plan vary; migration and deep financial transaction behavior need proof by spike.

## 4. Comparative assessment

Scale: 5 = strongest fit/easiest; 1 = weakest/highest risk. Scores are architectural judgments based on cited product capabilities and this repository, not benchmark results.

| Criterion | Custom API + PostgreSQL | Supabase/Postgres | Firebase/Firestore | Appwrite |
| --- | ---: | ---: | ---: | ---: |
| Relational/accounting fit | 5 | 5 | 2 | 3 |
| Atomic multi-entity transactions | 5 | 5 | 3 | 3 |
| Idempotent command control | 5 | 5 | 4 with Functions/custom code | 4 with Functions/custom code |
| Offline client convenience | 2 | 2 | 5 Android/Apple; Windows caveat | 3; integration required |
| Per-entity conflict control | 5 | 5 | 3; default offline LWW risk | 3 |
| Organization/row isolation | 5 with API/RLS | 5 with correct RLS/API | 4 with rules and design | 4 with permissions/design |
| Flutter integration | 3 | 5 | 5 mobile; Windows beta caveat | 4 |
| Windows parity | 5 via HTTP/local adapters | 5 via HTTP/Dart path | 2–3 for beta plugin path | 4 via API/SDK validation |
| Audit/reconciliation flexibility | 5 | 5 | 3 | 3 |
| Backup/export portability | 5 | 4; plan/storage caveats | 3; provider tooling/model | 3; plan/backend caveats |
| Vendor portability | 5 | 4 (Postgres helps) | 2 | 3 |
| Initial delivery speed | 2 | 4 | 4 | 4 |
| Operations burden | 2 self-managed / 4 managed | 4 | 5 | 4 cloud / 2 self-hosted |
| Egypt/region evidence | Host-dependent | Nearby EU options; no Egypt-specific region evidenced | Middle East regions evidenced | Must verify chosen cloud/host |
| Cost predictability | Infrastructure-based; sizing needed | Plan/add-on based | Usage/read-write based | Plan/hosting based |

## 5. Preliminary recommendation

Freeze the architecture around a **provider-neutral command/query API backed by a relational transactional store, with PostgreSQL as the reference database model**. This is a target pattern, not a vendor selection.

For Phase 105, evaluate two bounded implementations with synthetic data only:

1. managed PostgreSQL + custom API/application service;
2. Supabase-hosted PostgreSQL using server-side command functions/API and RLS defense in depth.

Firebase may be evaluated for identity, messaging, crash reporting or ancillary services only if cross-provider complexity is justified. Primary Firestore storage is not recommended for the accounting ledger without a proof that meets the same atomicity/reconciliation contracts. Appwrite remains an alternate spike, not the default shortlist.

## 6. Mandatory proof before provider selection

Using no customer data, each shortlisted approach must prove:

- one atomic multi-line sale with stock, moving-average valuation, immutable COGS, customer/account effects and audit;
- concurrent sales on the same stock with deterministic accept/reject and reconciliation;
- idempotent replay after an unknown timeout and same-key/different-payload rejection;
- closing-period rejection and authorized reversal;
- organization isolation tests at API and database-policy levels;
- device/session revocation and server-side permission refresh;
- offline outbox retry/pull on Windows and Android;
- export/restore to an isolated environment and duplicate prevention;
- measured latency from the intended Egyptian operating locations;
- Windows, Android and iOS-compatible client contract without provider SDK in domain/application layers;
- one-year and growth cost model including database, bandwidth, storage, backups/PITR, logs, functions and support;
- documented data-exit procedure and acceptable RPO/RTO.

## 7. Vendor-lock prevention

- Domain/application code imports no provider SDK.
- APIs and errors are versioned, provider-neutral and contract-tested.
- IDs are application-owned opaque UUIDs; provider row/document IDs are adapters only.
- Database migrations and reference SQL schema are version-controlled.
- Auth subjects map to application `UserAccount`; provider identity is an external credential link.
- Files have application metadata and exportable object keys/checksums.
- Outbox/idempotency/conflict state belongs to the application model.
- Organization exports contain business data/audit/metadata in documented portable formats.
- No final provider is implied by the existing Firebase scaffold or prior Supabase note.

## 8. Deferred owner/procurement decisions

- final provider and legal entity;
- managed versus self-hosted responsibility;
- data region and latency threshold;
- budget/support tier and billing currency/payment feasibility;
- Egyptian data-protection/accounting retention review;
- RPO/RTO, backup retention and secondary-region policy;
- authentication/MFA provider;
- object storage, monitoring and incident-response vendors.

These decisions do not block Phase 104 repository separation. They must be resolved before any real cloud resource or production data is authorized.
