# Phase 106AB — Extend Product Catalog Timestamps and Migrate Backup Export

## Result and lineage

- Final result: `Outcome A — FULL SUCCESS`.
- Branch: `codex/phase-106ab-extend-product-catalog-timestamps-migrate-backup-export`.
- Starting HEAD: `6c04de68e38dcc499f704970e9c00b01fbccf0f1`.
- Final HEAD: the single commit containing this report. Its full hash is recorded in the final handoff after Git creates the commit. A commit cannot embed its own hash because changing this text would change that hash.
- Commit subject: `PHASE 106AB: extend product catalog timestamps and migrate backup export`.
- Required final lineage: exactly one commit after the starting HEAD.
- Required final worktree: clean.
- Remote operations: no push and no tag were performed.

## Scope and changed files

The production diff is limited to these four files:

- `lib/core/catalog/product_catalog_read_repository.dart`
- `lib/core/catalog/drift_product_catalog_read_repository.dart`
- `lib/core/backup/backup_export.dart`
- `lib/app/app_repositories.dart`

The contract expansion required mechanical updates to 44 test files, including the shared catalog test adapter and the dedicated Phase 106AB test. `tool/run_phase102j_synthetic_trial.dart` received the corresponding constructor update. This report is the only documentation addition. The final change therefore contains 50 files: 4 production, 44 test, 1 tool, and 1 documentation file. The authoritative file list is the final `git diff --name-status` from the baseline.

No UI, dependency, product write-side, transaction-boundary, generated-file, database-schema, schema-version, or migration change was made.

## Product catalog contract expansion

`ProductCatalogReadModel` retains its nine prior fields and adds exactly these two fields:

```dart
required DateTime createdAt,
required DateTime updatedAt,
```

Both are immutable, required, non-null `DateTime` values. No third field, serializer, backup-specific behavior, mutable state, or write-side behavior was added to the read contract.

`DriftProductCatalogReadRepository` selects and maps the values directly:

- `products.createdAt` → `ProductCatalogReadModel.createdAt`
- `products.updatedAt` → `ProductCatalogReadModel.updatedAt`

The adapter performs no fallback, synthesis, `DateTime.now()`, UTC/local conversion, normalization, rounding, precision truncation, or derivation between the two fields. Runtime coverage compares each mapped value with the corresponding value materialized by the genuine Drift row.

## Migrated consumer

- Frozen PRC: `PRC-101`.
- Consumer: `BackupExportService.createBackup`.
- File/method: `lib/core/backup/backup_export.dart` / `createBackup()`.
- Old read: `_productRepository.listProducts(includeInactive: true)`.
- New read: `_productCatalogReadRepository.listProductCatalog(includeInactive: true)`.
- Inclusion flag: remains exactly `includeInactive: true`.
- Dependency injection: `BackupExportService` now receives the narrow `ProductCatalogReadRepository`; production composition supplies the existing catalog repository.
- Legacy behavior: there is no `ProductRepository` dependency, fallback, dual read, or direct database access in the export service.
- Other production consumers migrated: none.

The repository-wide guard records 14 remaining legacy `listProducts` calls and 12 catalog `listProductCatalog` calls, the precise one-call transition from the Phase 106AA baseline.

## Backup preservation proof

The serialized product map retains exactly 11 keys in this order:

1. `id`
2. `name`
3. `code`
4. `unit`
5. `isActive`
6. `defaultSalePricePiastersPerKg`
7. `minimumSalePricePiastersPerKg`
8. `referenceCostPricePiastersPerKg`
9. `notes`
10. `createdAt`
11. `updatedAt`

The dedicated genuine-runtime comparison constructs the same SQLite product rows and compares the migrated export against a test-only legacy reference built with `DriftProductRepository`. It proves:

- active and inactive products are both included;
- old and new reads both order by `createdAt ASC`, then `id ASC`;
- the serializer preserves that repository order without a second reorder;
- all 11 keys, their insertion order, value types, and serialized JSON bytes are identical;
- null, empty-string, and whitespace-bearing values remain distinct and unchanged;
- price fields remain nullable integers in piasters per kilogram, with no scaling, floating-point conversion, or rounding;
- distinct `createdAt` and `updatedAt` values survive and are serialized through the unchanged UTC ISO-8601 serializer;
- the complete exported JSON and checksum match the legacy reference byte-for-byte;
- independently recomputing the checksum from the envelope-minus-checksum payload produces the exported checksum;
- an empty catalog produces a successful backup with an empty products list;
- catalog read failures propagate and do not create a partial successful backup;
- the real read path performs no product writes.

The exercised runtime path is:

```text
BackupExportService.createBackup
→ ProductCatalogReadRepository.listProductCatalog(includeInactive: true)
→ DriftProductCatalogReadRepository
→ Drift
→ in-memory SQLite products table
```

The backup archive structure, checksum algorithm, restore contract, and backup format/version remain unchanged. The verified backup version is `8`, and existing restore tests remain green.

## Tests and release gates

- Dedicated Phase 106AB tests: 5 passed, 0 failed.
- Product catalog staged tests: 36 passed, 0 failed.
- Existing backup/restore staged tests: 202 passed, 0 failed.
- Lineage-sensitive guards: all relevant Phase 105/106 guards passed; the final focused Phase 106V/106Z/106AA rerun had 38 passes and 0 failures.
- Full repository suite: 2,268 passed, 1 historical skip, 0 failed.
- Historical skip: unchanged credential-dependent negative-balance approval test in `test/phase9a_inflows_outflows_reports_test.dart`.
- Analyzer: `flutter analyze` completed with `No issues found`.
- Formatter: `dart format --output=none --set-exit-if-changed .` checked 407 files and changed 0.
- Diff validation: `git diff --check` passed.

## Freeze guards and historical lineage

Historical contract and scope assertions continue to inspect their original phase commits. Forward-looking caller inventories and the Phase 106AB allowlist were extended only for the new timestamp contract and PRC-101 transition. Dedicated guards freeze the two required `DateTime` fields, direct Drift columns, absence of conversion/fallback/dual-read logic, exact 11-field serialization, call-site counts, and the exact four-file production diff.

## Remaining risks and limitations

No functional blocker or known data-loss risk remains. SQLite/Drift materializes the existing stored timestamp representation before either repository sees it; the new adapter passes that materialized `DateTime` through directly, and genuine-runtime legacy-versus-catalog comparison proves identical backup bytes and checksum. The final commit hash and post-commit clean-worktree/one-commit evidence necessarily exist only after the commit object is created and are therefore recorded in the final handoff rather than self-referenced inside that commit.

## Commands executed

The staged verification used the repository's actual commands:

```powershell
flutter test <targeted product-catalog files>
flutter test <existing backup and restore files>
flutter test test\phase106ab_backup_export_product_catalog_migration_test.dart
flutter test <lineage-sensitive Phase 105 and Phase 106 files>
flutter test --reporter compact
dart format --output=none --set-exit-if-changed .
flutter analyze
git diff --check
```
