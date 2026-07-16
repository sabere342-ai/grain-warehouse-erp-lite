# DC-U008 Phase 8I Durable Audit Log Repository Implementation Report

## Result

`PASS_PHASE_8I_DURABLE_AUDIT_LOG_REPOSITORY_LOCAL_READY`

Branch: `dc-u008-durable-audit-log-repository`  
Baseline: `ed7c778d6b7eb091658bf323b2866d236759f717`  
Closure commit: the single commit containing this report; its resolved hash is
reported in the final Git evidence because a commit cannot contain its own hash.

## Scope completed

Phase 8I adds durable Drift persistence for the existing audit-log domain,
integrates it into production composition, backup/restore, owner wipe, and the
repository snapshot system, and retains the local implementation for explicit
non-production/test use.

## Contract discovered

The original repository exposes `listLogs()` and `record(AuditLogDraft)`. An
entry contains `id`, `timestamp`, `actionType`, Arabic `descriptionAr`, nullable
`referenceId`, and JSON-compatible `metadata`. IDs use
`aud-<timestamp-microseconds>-<sequence>`. Listing is newest-first. Blank action
or description is invalid; optional reference text is trimmed and normalized to
null. Restore requires an empty target and unique valid IDs. Wipe clears rows
and resets the local counter. Snapshots preserve rows and counter.

## Schema and migration

The schema advances additively from v8 to v9. The only new table is
`audit_logs`, with stable text primary key, timestamp, action type, Arabic
description, nullable reference ID, and metadata JSON. Indexes are
`audit_logs_timestamp_idx`, `audit_logs_action_idx`, and
`audit_logs_reference_idx`. The existing `repository_sequences` table is reused
under namespace `audit_logs`. A populated v8 fixture upgrades without losing
its existing probe data; fresh v9 creation and reopen are covered.

## Repository behavior

`DriftAuditLogRepository` uses the shared `FoundationDatabase`. Record and
sequence allocation execute in a Drift transaction. Sequence state survives
restart and is rebuilt from restored ID suffixes. Concurrent writes serialize
through Drift and retain unique IDs. Ordering is timestamp descending with ID
descending as a deterministic tie-breaker.

Metadata is canonical JSON: map keys are sorted recursively while null,
Boolean, numeric, string, list, nested-map, empty, and Arabic values retain
their JSON types. Unsupported values are rejected. Corrupt persisted metadata
throws a controlled `FormatException` rather than being fabricated.

Snapshots capture durable rows and restore both rows and the derived next
sequence through the repository's wipe/restore operations. Backup export now
includes metadata; restore accepts the existing audit fields plus metadata and
is guarded by the existing coordinated snapshot rollback. Owner wipe deletes
audit rows and its sequence namespace transactionally.

Production initialization installs `DriftAuditLogRepository` immediately after
opening the shared database. Services that were constructed early with the
local audit instance are rebuilt against the durable instance, preventing a
silent production fallback. Backup restore and wipe dependencies now use the
durable capability contract instead of the concrete local class.

## Verification evidence

- Focused Phase 8I run 1: 8/8 passed.
- Focused Phase 8I run 2: 8/8 passed.
- Targeted migration, Phase 8A-8H durability, audit/atomicity, financial and
  approval, backup/restore, and owner-wipe regressions: 109/109 passed.
- Full sequential suite: 1011/1011 passed.
- Full default-concurrency suite: 1011/1011 passed.
- `flutter analyze`: no issues.
- Windows release build: passed; executable produced. Existing CMake
  deprecation and MSVC LNK4078 warnings were non-fatal.
- Drift generation: first generation succeeded; second generation produced
  zero outputs. Generated-file SHA-256 was identical on both runs:
  `06C7CEE4C7807F3E2ABFF596AE5EE56FBBA16BB9399FF12CF32682D0CDFF324D`.
- `git diff --check`: passed.
- Database artifact audit: no SQLite/database runtime artifact is tracked or
  present in repository paths; only the pre-existing owner-wipe JSON evidence
  manifest matched the broad artifact scan. Production uses the one shared
  `FoundationDatabase`; no JSON/localStorage/second-database audit store was
  introduced.
- Scope audit: changes are limited to audit persistence, the v9 additive
  migration/generated Drift code, necessary composition and backup/wipe
  generalization, focused tests, current-schema assertions, and this report.

## Files changed

- `lib/core/audit/audit_log_repository.dart`: durable capability contract.
- `lib/core/audit/drift_audit_log_repository.dart`: durable implementation.
- `lib/core/persistence/foundation_database.dart`: v9 audit schema/indexes.
- `lib/core/persistence/foundation_database.g.dart`: generated Drift model.
- `lib/core/persistence/migration_strategy.dart`: additive v9 migration.
- `lib/app/app_repositories.dart`: production wiring and dependent rewiring.
- `lib/core/backup/backup_export.dart`: audit metadata export.
- `lib/core/backup/backup_restore_service.dart`: durable restore contract and metadata.
- `lib/core/backup/business_data_wipe_service.dart`: durable wipe contract.
- `test/phase8i_durable_audit_log_repository_test.dart`: focused Phase 8I suite.
- `test/phase8a_durable_persistence_foundation_test.dart`: current version assertion.
- `test/phase8f_durable_purchase_repository_test.dart`: current version assertion.
- `test/phase8g_durable_sale_repository_test.dart`: current version assertion.
- This report.

## Known limitations

The application-wide `RepositoryTransaction` abstraction remains the existing
snapshot/coordinated-rollback mechanism for mixed local and Drift repositories.
Phase 8I does not migrate the remaining local domains or redesign that approved
transaction architecture. JSON numbers follow Dart JSON decoding semantics.

## Explicit non-actions

No push, tag, merge, rebase, deploy, force operation, dependency/toolchain
upgrade, approval migration, auth redesign, customer/supplier account migration,
expense migration, UI work, or Phase 8J work was performed.

`BLOCKED_PHASE_8I_REMOTE_PUSH_APPROVAL`
