# Phase 108F - First Read-Only UI Query Migration

## 1. Outcome

**BLOCKED_PHASE_108F_PRESERVED_PHASE_107H_WORK_PREVENTS_CLEAN_LOCAL_CLOSURE**

The Phase 108F implementation and verification recovery are complete and all
technical gates are green. No local commit was created because the mandatory
success contract also requires a clean final worktree. Twenty-three classified
Phase 107H evidence/tool files predated this phase as untracked work, do not
belong in the Phase 108F commit, and must not be deleted merely to claim
closure. Selective staging could isolate Phase 108F safely, but it could not
make the repository clean while preserving that work.

## 2. Repository identity and baseline

- Branch: `codex/phase-108e-application-boundary-central-composition-root`.
- Expected and actual initial `HEAD`:
  `deac34e7db2a5f6fd01f6fa7ff04020e308dfb6e`.
- Merge base with Phase 108E: the same full hash.
- Commits above Phase 108E: 0.
- No merge, rebase, reset, checkout, clean, stash, push, tag, or deployment was
  performed.

## 3. Scope classification

The intended Phase 108F scope contains the application query/result contract,
audit-log query handler, application boundary and composition wiring,
`ApplicationScope`, the audit controller and screen migration, bootstrap
wiring, relevant architecture/acceptance tests, historical guard repairs, the
analyzer exclusion for ignored scratch repositories, and this report.

The following were classified as residual Phase 107H work and left untouched
and uncommitted:

- 18 JSON evidence files under
  `docs/phase-107h/evidence/20260809-234238/`;
- 5 PowerShell tools under `tools/phase107h/`.

Neither directory exists in Phase 108E or in the Phase 107H commit tree
inspected during classification. They are unrelated local artifacts, not
Phase 108F implementation or verification repairs.

## 4. Selected query and behavior contract

`LoadAuditLogsQuery` is the first production read-only UI query slice. It has
no input, returns every `AuditLogReadModel` produced by the existing repository,
and uses `ApplicationQueryResult<List<AuditLogReadModel>>` with explicit local
SQLite/current-known-state metadata.

The migration preserves:

- the owner permission check in `AuditLogController`;
- repository ordering, membership, nullability, and empty-list behavior;
- fresh local SQLite reads with no new cache or network layer;
- exception identity through the handler;
- the controller's loading, cached-data, refresh-failure, retry, disposal, and
  Arabic UI error behavior;
- read-only behavior with no audit, accounting, inventory, auth, trial, schema,
  or other write side effect.

## 5. Dependency path and composition ownership

Previous path:

`AuditLogsScreen -> AppRepositories.auditLogRepository -> AuditLogController -> listAuditLogs()`

New path:

`AuditLogsScreen -> ApplicationScope -> ApplicationBoundary.queries.auditLogs -> LoadAuditLogsQueryHandler -> ApplicationDependencies.repositories.auditLogReadRepository -> existing production audit repository`

`main()` installs the boundary returned by
`AppCompositionRoot.initializeProduction()` in `ApplicationScope`. The
composition root creates the handler from the dependency bundle. The legacy
bridge captures the same `AppRepositories.auditLogRepository` instance, so no
second database, repository, or cache is created.

## 6. Legacy locator inventory

- `AppRepositories.*` in `lib/features` plus `lib/shared`: 152 references in 43
  files before; 151 references in 42 files after.
- All `AppRepositories.*` references under `lib`: 161 before and 161 after;
  the removed UI reference is balanced by the explicit composition bridge.
- Direct audit-screen access to `AppRepositories.auditLogRepository`: 1 before,
  0 after.

## 7. Historical guard recovery

The initial authoritative full suite reproduced 15 failures: 2,420 passed,
15 failed, and 0 skipped. Each failure was traced through history, blame, the
relevant phase commit, and the Phase 108E diff. All were stale structural
assumptions, not business regressions.

Twelve Phase 106 guard files were repaired:

- `phase106ab_backup_export_product_catalog_migration_test.dart`
- `phase106ad_migrate_backup_restore_empty_system_product_read_test.dart`
- `phase106af_migrate_business_data_wipe_current_counts_product_read_test.dart`
- `phase106ah_migrate_drift_inventory_product_lookup_read_test.dart`
- `phase106aj_migrate_drift_purchase_product_validation_reads_test.dart`
- `phase106ak_reaudit_freeze_next_product_read_migration_target_test.dart`
- `phase106al_negative_balance_approval_product_fingerprint_read_migration_test.dart`
- `phase106am_profitability_activation_product_read_migration_test.dart`
- `phase106q_next_product_read_migration_target_discovery_freeze_test.dart`
- `phase106t_next_product_read_migration_target_freeze_test.dart`
- `phase106u_sale_controller_product_catalog_read_migration_freeze_test.dart`
- `phase106v_sale_controller_product_catalog_runtime_integration_test.dart`

The repair pins historical cumulative production-diff assertions to the last
accepted Phase 107C endpoint,
`f521a97946d73829fef19f4f0d30a6d07b9f8051`, instead of comparing an old
Phase 106 baseline to the live worktree indefinitely. Fragile current-branch
name allowlists were replaced with ancestry assertions for the exact phase
commits. Exact path-set comparisons, current semantic/source assertions,
schema/generated-file checks, and all product invariants remain active.

Negative protection is retained: an unexpected file before the historical
endpoint still breaks the exact set, divergent history fails ancestry, and
current source/schema assertions still fail on forbidden behavior. The 12-file
guard set passed 115/115 tests.

## 8. Verification results

- Focused Phase 108F tests: 9 passed, 0 failed, 0 skipped.
- Related audit/UI/application tests: 46 passed, 0 failed, 0 skipped.
- Repaired historical guard files: 115 passed, 0 failed, 0 skipped.
- Final full default suite: 2,436 passed, 0 failed, 0 skipped in 3:06.
- Final full sequential suite: 2,436 passed, 0 failed, 0 skipped in 6:19.
- Formatter: 26 intended Dart files examined; 11 changed; successful.
- Analyzer: `No issues found` in 84.6 seconds.
- `git diff --check`: passed.
- Windows release build: passed in 1,222.1 seconds; artifact:
  `build/windows/x64/runner/Release/grain_warehouse_erp_lite.exe`.

The Windows build emitted only existing non-fatal Firebase CMake minimum-version
and MSVC multiple-`.voltbl` warnings. The Flutter batch wrapper initially hid a
sandbox denial while trying to access the SDK lockfile; the authorized direct
Flutter tool invocation completed the same release build successfully.

## 9. Analyzer verification repair

`analysis_options.yaml` now excludes `tmp/**`. The root analyzer originally
reported 4,057 issues exclusively from ignored historical repository copies
under `tmp/ld-*` and `tmp/roadmap108h-cloud-repositories`. The exclusion does
not omit tracked application, test, or tool source; it removes ignored scratch
repositories from the root verification surface. The subsequent root analysis
completed with zero issues.

## 10. Change inventory

Production/application files:

- `lib/main.dart`
- `lib/application/application_boundary.dart`
- `lib/application/application_dependencies.dart`
- `lib/application/queries/application_query.dart`
- `lib/application/queries/load_audit_logs_query.dart`
- `lib/composition/app_composition_root.dart`
- `lib/composition/application_scope.dart`
- `lib/composition/legacy_application_dependency_bridge.dart`
- `lib/core/audit/audit_log_controller.dart`
- `lib/features/audit/audit_logs_screen.dart`

Verification files:

- `analysis_options.yaml`
- the 12 guard files listed above
- `test/phase104g_genuine_runtime_audit_log_acceptance_architecture_freeze_test.dart`
- `test/phase104j_final_audit_log_repository_boundary_acceptance_test.dart`
- `test/phase89_settings_utilities_design_system_test.dart`
- `test/phase108f_first_read_only_ui_query_migration_test.dart`
- this report

No file was deleted.

## 11. Repository hygiene

- Dependency changes: none; `pubspec.yaml` and `pubspec.lock` are unchanged.
- Schema changes: none.
- Migration changes: none.
- Generated database changes: none.
- Platform source changes: none.
- Secrets or credentials in the intended Phase 108F diff: none found.
- `build/` and `tmp/` remain ignored.

## 12. Closure decision

All implementation, behavior, guard, test, analyzer, formatting, build, diff,
dependency, schema, and security gates pass. The only failed mandatory success
condition is final worktree cleanliness. Phase 108F can be isolated by explicit
staging, but the repository would remain dirty from preserved unrelated 107H
work. Because the governing prompt permits the success terminal only with a
clean final worktree and says not to commit when a mandatory closure gate
remains failing, no Phase 108F commit was created.

The planned commit message remains:

`Phase 108F: migrate audit log query to application boundary`

No push, tag, deployment, remote mutation, or history rewrite occurred.
