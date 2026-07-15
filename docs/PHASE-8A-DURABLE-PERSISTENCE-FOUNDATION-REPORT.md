# Phase 8A — Durable Persistence Foundation

## Status

Implemented on `dc-u008-durable-persistence-foundation` from the locked Phase 7
baseline `a848792eb5e727617f667dea67d2519ae5ac901b`.

## Foundation delivered

- SQLite runtime through `sqlite3_flutter_libs` with Drift as the typed layer.
- Central `FoundationDatabase`, schema version `1`, and generated Drift code.
- Production database file `grain_warehouse_erp.sqlite3` in the platform
  application-support directory. The directory is created only when the
  production opener is explicitly called; app startup is unchanged.
- Isolated in-memory databases for unit tests and explicit temporary-file
  opening for close/reopen durability tests.
- One technical `foundation_probes` table. It proves creation, transactions,
  rollback, isolation, and reopen; it is not a business API or entity.
- `inTransaction` provides the Phase 8A transaction boundary. Exceptions are
  propagated and Drift rolls the whole transaction back.
- Migration version 1 uses `createAll`. Future versions must register one
  explicit migration step; missing steps fail without destructive recreation.
- Foreign keys are enabled. File-backed databases use SQLite WAL mode.

## Dependencies

- Runtime: `drift ^2.23.1`, `sqlite3_flutter_libs ^0.5.42`.
- Runtime path dependencies: `path ^1.9.0` and existing
  `path_provider ^2.1.5`.
- Development: `drift_dev ^2.23.1`, `build_runner ^2.4.13`.
- Versions are the newest set resolved together under Flutter 3.24.5 / Dart
  3.5.4; newer Drift codegen lines require newer analyzer/Dart constraints.

## Generation and verification

Generated code is reproducible with:

```text
dart run build_runner build --delete-conflicting-outputs
```

Required gates: focused Phase 8A tests twice, DC-U008 regression, discovered
Phase 4–7 regressions, transaction/backup/snapshot/repository tests, full
sequential suite, analyzer, diff check, and Windows release build.

Final evidence:

- Phase 8A focused runs: `8/8` and `8/8` passed.
- DC-U008 regression: `13/13` passed.
- Discovered Phase 4–7 suite: `56/56` passed.
- Related atomicity, snapshot, backup, and restore suite: `63/63` passed.
- Full sequential suite: `955/955` passed (previous baseline `947`; eight
  Phase 8A tests added).
- `flutter analyze`: no issues.
- `git diff --check`: passed.
- Repeated build_runner generation: passed with no hand edits to generated code.
- `flutter build windows --release`: passed; executable linked successfully.

## Explicit exclusions

- Existing repositories remain in-memory and do not import Drift.
- No customers, suppliers, products, inventory, financial, sales, or advances
  table was added.
- The application composition root and UI are unchanged.
- No business migration, cutover, deploy, or Phase 8B work was started.
