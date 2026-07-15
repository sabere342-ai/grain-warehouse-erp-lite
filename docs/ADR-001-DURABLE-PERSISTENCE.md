# ADR-001: Durable Persistence Architecture

- Status: Accepted
- Date: 2026-07-15
- Phase: 7 — Durable Persistence Architecture Decision
- Decision owner: Project owner
- Implementation phase: Phase 8 (not started)

## Context

Grain Warehouse ERP Lite is a Windows-first, offline, single-warehouse Flutter
application. Its repositories currently keep authoritative state in memory;
JSON backup/restore is an explicit transfer and recovery mechanism rather than
an operational datastore. Financial and stock workflows require integer money
and weight, append-only history, authentic approval binding, idempotent request
namespaces, atomic multi-repository mutations, and complete rollback.

The existing repository interfaces are a useful migration boundary, but
`RepositoryTransaction` currently rolls back captured in-memory snapshots. A
durable implementation must replace that process-local guarantee with one
database transaction covering every participating write. Real financial data
remains prohibited until crash recovery and backup/restore drills pass.

## Decision drivers

1. ACID transactions and enforced foreign keys for accounting integrity.
2. Reliable offline Windows operation without a separate service.
3. Typed Dart access, reviewable migrations, and deterministic tests.
4. Compatibility with existing repository interfaces and incremental rollout.
5. Local backup, restore, crash recovery, and future export/sync support.
6. Low operational burden for a single-device first release.

## Considered alternatives

### SQLite with Drift — selected

SQLite provides embedded ACID transactions, constraints, indexes, mature
recovery behavior, and a portable database file. Drift adds typed Dart queries,
schema-versioned migrations, transactions, test support, and Windows support.
The combination matches the current relational ledgers and cross-aggregate
atomicity needs while keeping the application offline and service-free.

Trade-offs: generated code and migration discipline add build complexity;
database access must stay behind repositories; large writes must avoid blocking
the UI isolate; SQLite is not itself a multi-device synchronization system.

### Direct SQLite bindings without Drift — rejected

This retains SQLite's durability but increases hand-written mapping and query
risk, weakens compile-time checks, and makes migrations and test fixtures more
laborious without a compensating project benefit.

### JSON files as the live store — rejected

JSON is retained for user-visible backup/export. It does not safely provide
multi-aggregate transactions, constraints, concurrent write serialization, or
crash-safe incremental updates without building a database engine in the app.

### Hive or Isar-style object stores — rejected

They simplify object persistence but are a weaker fit for relational integrity,
append-only financial ledgers, cross-aggregate constraints, auditable migrations,
and ad-hoc reconciliation queries. Adopting one would not remove the need for a
carefully designed transaction boundary.

### Firebase, Supabase, or a custom server — deferred

Cloud storage would prematurely introduce connectivity, tenancy, authentication,
conflict resolution, offline queues, and operational deployment. The roadmap
requires proving the local model first. A later sync layer may consume stable
local changes, but Phase 8 is not a cloud migration.

## Accepted architecture

- Use SQLite as the single local durable source of truth.
- Use Drift as the typed persistence and migration layer.
- Keep domain models and public repository interfaces independent of Drift.
- Provide persistent repository implementations through the existing app
  composition root; keep in-memory implementations for focused unit tests.
- Execute each logical multi-repository command in one shared database
  transaction. Nested repository calls must join that transaction.
- Store money in integer qirsh and weight in integer grams; never use floating
  point for accounting.
- Enforce stable IDs, foreign keys, uniqueness for idempotency keys and document
  numbers, and checks for valid amounts/directions where SQLite permits.
- Preserve original accounting/history rows. Corrections remain compensating
  entries or explicit reversal state.
- Keep JSON backup compatibility. Restore is validated before writes and then
  committed in one database transaction into an empty database.
- Configure and verify foreign keys, WAL/recovery behavior, and safe shutdown at
  database open rather than assuming platform defaults.

This ADR does not authorize packages, generated files, tables, migrations, or
production repository changes in Phase 7.

## Phase 8 transition plan

1. Inventory every aggregate, relation, counter, replay fingerprint, approval,
   audit record, and ordering rule; publish a schema/constraint map.
2. Add Drift and the SQLite Windows runtime, database lifecycle wiring, and an
   empty version-1 schema behind a feature-isolated composition boundary.
3. Implement shared transaction context and prove nested repository operations
   join one SQL transaction with fault injection at every important write.
4. Migrate read/write repositories in dependency order: reference data and
   identity; inventory; financial accounts/approvals/audit; customers and
   suppliers; sales/purchases/expenses; reports and backup services.
5. Run contract tests against both in-memory and persistent implementations
   during migration. Do not mix authoritative stores for one aggregate.
6. Add a one-time cutover for the supported source state. Export a verified JSON
   backup first, import atomically, verify counts/relationships/balances, then
   mark cutover complete. Never silently retry a partial import.
7. Complete crash-recovery, corrupt-file, disk-full, interrupted-migration,
   restore, wipe, and Windows packaging drills before enabling real data.

## Phase 8 acceptance criteria

- Schema and migration tests cover fresh creation and every supported upgrade.
- Foreign keys and unique/idempotency constraints are demonstrably active.
- Repository contract tests pass for persistent implementations.
- All compound business operations are atomic under injected failures.
- Replay and concurrent requests cannot create duplicate logical operations.
- Restart persistence preserves every aggregate, counter, approval, audit link,
  reversal link, and derived balance.
- Existing backup versions restore compatibly; a new durable backup round-trip
  preserves all data and rejects invalid relationships before writes.
- Interrupted writes and process termination recover without partial accounting
  or stock effects; integrity checks pass after restart.
- Transaction-safe wipe either commits completely or leaves all prior data.
- Full sequential tests, analyzer, diff check, and Windows release build pass.
- A documented backup/restore drill succeeds on a separate clean environment.
- No real financial data is authorized until all criteria are evidenced.

## Rollback and recovery strategy

- Before cutover, create and checksum a JSON backup and preserve the untouched
  pre-cutover application/data package.
- Schema migrations run transactionally where SQLite permits. Destructive
  migrations use create-copy-validate-swap inside a controlled transaction.
- On migration or validation failure, abort, retain the old database and backup,
  and keep persistent mode disabled; never downgrade or edit data in place.
- Application rollback is allowed only to a version compatible with the current
  schema. Otherwise restore the pre-cutover backup into the prior release.
- Feature flags may select an implementation only before cutover; they must not
  permit dual writes or divergent sources of truth.

## Risks and mitigations

- Migration defects: versioned fixtures, relationship/balance verification, and
  transactional migrations.
- Drift leakage into domain code: enforce repository and composition boundaries.
- UI stalls: measure operations and isolate bounded database work where needed.
- SQLite file loss/corruption: checksummed backups, integrity checks, recovery
  drills, and clear user-facing failure behavior.
- Future cloud sync mismatch: retain stable IDs, timestamps, request IDs, and
  append-only history; do not add sync semantics before their own ADR.

## Consequences

Phase 8 has a precise implementation target and evidence gate. The project gains
durability without changing its domain contract in Phase 7. Generated-code and
migration maintenance become explicit engineering costs. Cloud and multi-device
support remain separate future decisions.
