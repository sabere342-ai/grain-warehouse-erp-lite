# Phase 103 — Cloud & Mobile Readiness Architecture Audit

Date: 2026-07-28
Repository baseline: `d41e6afa510cfdffc6a743c2b116ad4f2b029457`
Scope: evidence-based audit only; no production behavior, schema, backup format, cloud resource, or customer-data change.

## 1. Executive finding

The application is a working Flutter/Windows desktop product with durable Drift/SQLite persistence and useful repository abstractions. It is not yet a multi-device or cloud system. Android scaffolding exists and a Release APK was built during verification, but no Android device runtime or workflow acceptance is claimed. iOS scaffolding is absent. The safest migration path is to preserve Windows and SQLite, introduce an application/data boundary, then add a server-authoritative command API and offline outbox in later phases.

The principal blockers are not Flutter itself. They are global repository wiring, direct local-database ownership, locally generated time-based identities, missing organization/branch/warehouse/device/session scope, local-only authentication, file-system assumptions, and desktop-shaped high-density workflows.

## 2. Audit method and reproducible evidence

The audit used repository searches over `lib/`, `android/`, `windows/`, `pubspec.yaml`, `.metadata`, routes, screen classes, repository contracts, Drift schema/migrations, file I/O, platform checks, date/time generation, fixed dimensions, dialogs, scrolling, navigation, and backup code.

Measured results:

| Evidence set | Result | Definition |
| --- | ---: | --- |
| Direct SQLite/Drift coupling | 18 source files | Files matching `FoundationDatabase`, `NativeDatabase`, `QueryExecutor`, direct SQL, or database transaction use; generated `.g.dart` excluded |
| Platform/file/Windows coupling | 23 source files | Files matching `dart:io`, `Platform`, `File`/`Directory`, application directories, file picker/open, printing/launching, or explicit Windows target behavior |
| `DateTime.now()` | 156 occurrences in 58 files | Generated files excluded |
| Feature files using global `AppRepositories` | 42 | Screens, shell, helpers, export/print surfaces |
| Screen classes | 42 | 41 public screen classes plus reachable private `_CustomerStatementScreen` |
| Android platform | Present | `.metadata` lists Android and `android/` has Gradle/app/manifest/launcher structure |
| iOS platform | Absent | No `ios/` directory; `.metadata` does not list iOS |
| Production schema | Drift schema version 15 | `lib/core/persistence/foundation_database.dart` |
| Backup format | Export v8; restore accepts v1–v8 | `backup_export.dart`, `backup_restore_preview.dart` |

Search notes:

- No production occurrence of `organizationId`, `branchId`, `warehouseId`, `deviceId`, `sessionId`, or tenant-equivalent scope was found.
- No `DataTable`/`PaginatedDataTable` is used in screen files; high-density reporting is instead implemented through many `Row` layouts and list/card structures.
- Mouse hover/right-click is not a functional dependency. The only keyboard shortcut found is Alt+Left in `DashboardShell`.
- `firebase_core` and a defensive bootstrap exist, but `firebase_options.dart` intentionally throws `UnsupportedError`; no cloud database, auth, API, or sync SDK is active.

## 3. Current architecture inventory

| Area | Primary paths | Responsibility and dependencies | Platform/SQLite status | Reuse and migration risk | Recommendation |
| --- | --- | --- | --- | --- | --- |
| Flutter presentation | `lib/features/**`, `lib/shared/**` | Screens, dialogs, print previews, RTL/theme/layout; most obtain repositories from `AppRepositories` | Flutter-portable widgets; several file and dense-layout assumptions | Medium–high | Inject application services/view models; retain widgets while remediating layouts |
| App shell/routes | `lib/app/grain_warehouse_app.dart`, `routes.dart`, `features/dashboard/dashboard_shell.dart` | Material app, auth gate, three named routes, 16 shell destinations, push routes | Mostly portable; global singleton and keyboard shortcut | Medium | Keep shell, add mobile navigation state and session/device state |
| State/controllers | `lib/core/**/**_controller.dart`, inherited scopes | `ChangeNotifier` controllers and scopes | Mostly platform-independent; repositories injected inconsistently | Low–medium | Keep contracts; create composition root and use-case layer |
| Composition root | `lib/app/app_repositories.dart`, `lib/main.dart` | Opens one database and exposes global static repositories/services | Direct single SQLite instance; single-process assumption | High | Replace global access with injected `ApplicationContainer`; keep adapter during transition |
| Repository contracts | `lib/core/**/**_repository.dart` | Existing domain-oriented read/write interfaces and in-memory implementations | Contracts mostly portable; some include local snapshot/transaction mechanics | Medium | Normalize contracts into query/command semantics before remote implementation |
| Drift adapters | `lib/core/**/drift_*_repository.dart` | Durable mapping and transaction work | Direct SQLite/Drift | Medium–high | Retain as `Local*DataSource`; do not expose to presentation |
| Database/schema | `lib/core/persistence/*` | File resolution, NativeDatabase, WAL/foreign keys, schema 15/migrations | Direct `dart:io`, path provider, SQLite | High but retainable | Keep as device cache/offline store; add scoped IDs, versions, outbox later via migrations |
| Authentication | `lib/core/auth/*`, auth screens | Local account/password verification, owner/employee roles, one active in-process session | SQLite/local; no device/session/token model | High/security-critical | Introduce `UserAccount`, device, session and server authorization; keep `Employee` separate |
| Catalog/customers/suppliers | `lib/core/catalog`, `customers`, `suppliers` | Reference data and activation state | Repository contracts plus Drift; local time/sequence IDs | Medium | Versioned mutable entities with organization scope and tombstones |
| Inventory/valuation | `lib/core/inventory`, `inventory_valuation` | Movements, moving weighted average, activation state/events | Durable transactions; local database is authoritative today | Very high | Server-authoritative atomic commands; local deterministic preview/cache only |
| Sales/purchases | `lib/core/sales`, `purchases` | Documents, stock, accounts, COGS, cancellation | Cross-repository transactions; partial request IDs exist | Very high | One server transaction per command group with immutable result and idempotency |
| Customer/supplier accounts | `lib/core/customer_accounts`, `supplier_accounts` | Collections, payments, advances, refunds/reversals | JSON payload tables and local sequence state | Very high | Append-oriented server ledger; never last-write-wins |
| Financial accounts | `lib/core/financial_accounts` | Accounts, entries, transfers, closing, negative-balance approvals | Stateful local transaction semantics | Very high | Server-validated command handlers, serializable/locked invariants, append-only entries |
| Expenses | `lib/core/expenses` | Expense posting/classification | Request ID support but local time/ID | High | Server command with idempotency and account transaction |
| Reports/dashboard | `lib/core/reports`, `profitability`, `dashboard`, report screens | Derived local queries and presentation | Reads local repositories; 10 report screens import `dart:io` for exports | Medium | Cache server snapshots; clearly label staleness; sensitive truth remains server-derived |
| Audit | `lib/core/audit` | Local append-like audit records | Device-local and locally timed | High | Server append-only audit with actor/device/org/server time; local queue is provisional |
| AI actions | `lib/features/ai_assistant` | Read-only tool registry/report readers | Predominantly domain/report contracts | Medium | Keep read-only; route through authorized application queries, never direct remote credentials |
| Business identity/theme | `lib/core/business_identity`, `theme` | Local JSON/logo/theme files | `dart:io`, environment paths; no organization scope | Medium | Theme may remain device-local; business identity becomes organization reference data |
| Backup/restore/wipe | `lib/core/backup`, `features/backup` | JSON v8 export, v1–v8 restore, local file write, whole-business wipe | Local files and one local dataset | Critical | Split device cache recovery, organization export, server backup, and disaster recovery |
| PDF/print/share | `lib/features/exports`, `prints`, `core/sharing` | PDF/CSV output, opening files, printing, WhatsApp URL launch | Path/backslash/file/open/print behavior | Medium | Platform capability adapters; mobile share sheet; server export optional |
| Windows native/package | `windows/**` | Runner, plugins, installer, EXE branding | Windows-only by definition | Low if isolated | Preserve unchanged; do not place Windows code in domain/data contracts |

## 4. Direct SQLite/Drift coupling inventory

These 18 files form the measured coupling set. “Before backend” means before any remote source is allowed to process production-shaped commands.

| File / class | Use | Separation difficulty | Proposed boundary | Before backend? | Phase |
| --- | --- | --- | --- | --- | --- |
| `lib/app/app_repositories.dart` / `AppRepositories` | Owns database singleton and wires all Drift repositories | High | Composition root + injected application services | Yes | 104 |
| `core/persistence/database_opener.dart` | Resolves SQLite file and creates `NativeDatabase` with WAL/FK pragmas | Medium | `LocalDatabaseFactory` platform adapter | Yes | 104 |
| `core/persistence/foundation_database.dart` | Drift tables, schema 15, transaction runner | High | Local data source only | Boundary required | 104/107 |
| `core/persistence/migration_strategy.dart` | SQLite DDL/migrations and repository sequences | High | Local migration adapter | No schema change in 103 | 104+ |
| `core/auth/drift_auth_repository.dart` | Direct SQL and local account sequences | High | `LocalAuthDataSource`; later remote identity repository | Yes | 104/106 |
| `core/audit/drift_audit_log_repository.dart` | Transactions and sequence IDs | Medium | `LocalAuditDataSource` | Yes | 104/107 |
| `core/catalog/drift_product_repository.dart` | Drift transaction and local ID allocation | Medium | `LocalProductDataSource` | Yes | 104 |
| `core/customers/drift_customer_repository.dart` | Drift transaction and local ID allocation | Medium | `LocalCustomerDataSource` | Yes | 104 |
| `core/suppliers/drift_supplier_repository.dart` | Drift transaction and local ID allocation | Medium | `LocalSupplierDataSource` | Yes | 104 |
| `core/inventory/drift_inventory_repository.dart` | Movement transaction and local sequence | High | `LocalInventoryDataSource` behind command repository | Yes | 104/109 |
| `core/inventory_valuation/drift_inventory_valuation_repository.dart` | Valuation state/events and transactions | Critical | Local cache/preview adapter; server command is final | Yes | 104/109 |
| `core/purchases/drift_purchase_repository.dart` | Multi-repository purchase transaction | Critical | `PurchaseCommandService` + local provisional transaction | Yes | 104/109 |
| `core/sales/drift_sale_repository.dart` | Sale, stock, COGS and account transaction | Critical | `SalesCommandService` + local provisional transaction | Yes | 104/109 |
| `core/expenses/drift_expense_repository.dart` | Direct transaction, sequence and posting | High | `ExpenseCommandService` | Yes | 104/109 |
| `core/financial_accounts/drift_financial_account_repository.dart` | Durable financial state and entries | Critical | `FinancialCommandService` | Yes | 104/109 |
| `core/customer_accounts/drift_customer_account_repository.dart` | Direct SQL over payload tables/sequences | Critical | Customer-ledger local source | Yes | 104/109 |
| `core/supplier_accounts/drift_supplier_account_repository.dart` | Direct SQL over payload tables/sequences | Critical | Supplier-ledger local source | Yes | 104/109 |
| `core/financial_accounts/negative_balance_approval_request_repository.dart` | Drift-backed approval request state/transitions | High | Approval command/query repositories | Yes | 104/106 |

Generated `foundation_database.g.dart` is excluded from the count because it is derived code, not an independent coupling decision.

## 5. ID, time, and single-device assumptions

- Durable entities are text-keyed, but many IDs use device time plus a process or SQLite sequence, for example `prd-*`, `cus-*`, `sup-*`, `stk-*`, `pin-*`, `sal-*`, `fa-*`, `fae-*`, `aud-*`, and UI request IDs.
- `repository_sequences` is local to one SQLite file. It prevents some same-file collisions but cannot guarantee global identity across devices.
- Sales, purchases, expenses, transfers, and approval requests have partial request/idempotency fields. Coverage and semantics are inconsistent and keys are still commonly derived from local time.
- `DateTime.now()` is used in business effective dates, closings, audit, expiry, report defaults, identifiers, and UI request IDs. Device clock therefore affects both display and sensitive state.
- The current composition owns exactly one database and one visible in-process session. No device registry, refresh session, revocation, inbox/outbox, remote cursor, version column, server timestamp, or tombstone model exists.
- All business tables lack organization/branch/warehouse scope. `InventoryMovements` has a product but no warehouse. Multi-warehouse transfer is therefore not representable.

Required direction: globally unique client-generated entity/operation IDs (UUIDv7 or an owner-approved equivalent), server timestamps plus preserved client timestamps, organization scope on all shared rows, branch/warehouse scope where operationally relevant, and optimistic versions/tombstones on mutable reference data.

## 6. Platform and Windows/file coupling inventory

The measured set is 23 source files. This count is a source-file coupling metric, not 23 independent runtime failures.

| Group | Files | Current classification | Required action |
| --- | --- | --- | --- |
| SQLite file | `core/persistence/database_opener.dart` | Works on Android with plugin support; needs lifecycle/storage testing; iOS unconfigured | Adapter |
| Local backup/restore | `backup_file_writer.dart`, `backup_restore_service.dart` | Semantics are device/desktop-specific | Mobile alternative + architecture decision |
| Business logo/files | `business_identity_repository.dart`, `business_identity_controller.dart` | `dart:io` and environment/application paths | Storage adapter; org-scoped remote asset later |
| Theme file | `theme_settings_repository.dart` | Device-local preference; portable with adapter | Keep device-local behind settings store |
| Exports | `financial_report_csv_exporter.dart`, `financial_report_pdf_builder.dart`, `pdf_export_service.dart` | Explicit backslash joins, local Documents/Exports, file open | Replace joins with `path`; mobile share/download adapter |
| Report screens | 10 financial report screens importing `dart:io` | Export/open integration mixed into presentation | Inject export capability; no domain impact |
| Settings | `features/settings/settings_screen.dart` | File picker; supported conceptually but needs mobile UX | Platform file-picker adapter |
| WhatsApp | `core/sharing/whatsapp_assisted_share_service.dart` | URL launcher-based assisted share | Mobile-specific share/intent adapter and fallback |
| Theme tokens | `core/theme/app_tokens.dart` | Explicit Windows visual-density target | Responsive platform policy, not domain constant |
| Firebase options | `core/firebase/firebase_options.dart` | Explicit platform switch; no real configuration | Remove platform policy from domain; provider decision deferred |

Additional native Windows code and installer files under `windows/**` are expected platform code and remain supported. They do not belong in shared domain contracts.

## 7. Android and iOS readiness

### Android

Android scaffolding is present and the Phase 103 Release APK build passed. Remaining build/runtime risks are:

1. the project compiles against Android SDK 34 while two plugins request SDK 35;
2. current Firebase options intentionally reject configuration (caught during bootstrap, so it is not a cloud implementation);
3. SQLite lifecycle, background/foreground behavior and file location have not been device-tested;
4. explicit backslashes can create incorrect Android paths even though compilation succeeds;
5. file opening, export, print, picker and WhatsApp behavior require capability tests;
6. dense financial/report/form layouts need the UI remediation recorded in the mobile inventory;
7. no secure credential store, offline outbox, device identity, server API, or organization scope exists.

### iOS

iOS cannot currently be built because `ios/` is absent and the Windows host cannot perform a genuine iOS build. The architecture must nevertheless remain compatible: no Android-only domain/data contract, platform capabilities behind interfaces, Apple lifecycle/secure storage/file share requirements in acceptance criteria, and a later macOS/Xcode build gate.

## 8. Multi-device and accounting risks

| Risk | Current evidence | Consequence | Required control |
| --- | --- | --- | --- |
| Duplicate posting | Some request IDs exist, but not universal and many are time-based | Duplicate sale/payment/stock/account entries | Server idempotency record with payload fingerprint and original response |
| Conflicting stock | Each SQLite file is authoritative locally | Two devices can both sell the same stock | Server atomic stock command; local result provisional |
| Conflicting COGS | Valuation state is local | Divergent moving-average state | Single ordered server valuation ledger; deterministic shared logic for preview |
| Closed-period violation | Device-local time and local closing state | Late/offline posting can bypass close | Server organization timezone and close validation |
| Cross-organization leakage | No organization scope | Future tenant mixing | Mandatory server-derived organization scope and row authorization |
| Lost local queue | No outbox | App deletion/crash loses unsubmitted operations | Durable outbox and owner-visible pending state |
| Audit ambiguity | Local actor/time only | Non-repudiation and ordering gaps | Server audit with actor/device/session/server time |
| Whole-dataset restore | Local v1–v8 restore assumes one business | Cross-tenant overwrite/duplicates | Split device recovery from org export/server restore; restore rehearsal and idempotency |

## 9. Simplified threat model

| Threat | Control contract |
| --- | --- |
| Stolen device / copied SQLite | OS secure storage, local encryption where justified, revocable device/session, minimal cached scope, no recoverable passwords |
| Token leakage | Short-lived access token, rotated refresh session, secure storage, revoke one/all devices, never log tokens |
| MITM / payload modification | TLS, certificate/platform validation, authenticated request, request hash/signature where justified, server validation |
| Replay / duplicate request | Organization-scoped idempotency key plus fingerprint and immutable stored result |
| Underprivileged employee | Server-side authorization on every command/query; UI hiding is not authorization |
| Device clock manipulation | Server receive/commit time; client time preserved only as evidence; organization timezone for business dates |
| Two-device concurrency | Database transaction/locking or serializable retry; optimistic versions for reference data |
| Old backup restore | Version/hash/org preflight, restore to isolated target, reconciliation, audit, duplicate protection |
| Cross-organization import | Organization identity binding and explicit authorized remap workflow; default deny |
| Malicious file | MIME/signature/size validation, malware scanning when remote, private object storage, signed short-lived access |
| Sensitive logs | Structured redaction, least retention, no secrets/financial payload dumps in telemetry |

## 10. Answers to the 20 governing questions

1. Android now has a verified Release APK build, but operational readiness remains blocked by unverified device runtime/workflows and architecture gaps, not by Flutter itself.
2. iOS is blocked immediately by the missing platform project and required macOS toolchain; shared contracts must remain iOS-safe.
3. Windows/file bindings are enumerated in section 6 and isolated native runner/installer code.
4. SQLite bindings are the 18 files in section 4.
5. `AppRepositories`, one database, local sequences, local session, and local files assume one process/device.
6. All shared entities currently lack organization/branch/warehouse scope.
7. Phase 104 introduces application use cases and repository contracts between widgets and local/remote sources.
8. SQLite remains the offline working store/cache and gains a durable outbox; Windows behavior is preserved throughout.
9. Every write receives a global operation ID/idempotency key; the server stores and replays the original result.
10. Financial/inventory commands never use last-write-wins; reference data uses version checks and controlled merge/review.
11. The server is final for shared business state, identities, permissions, stock, valuation, accounting, closes, and audit.
12. Reference snapshots, authorized report snapshots, device preferences, and provisional/offline operations may be local.
13. Atomic server commands, deterministic valuation logic, append/reversal semantics, and reconciliation protect accounting.
14. Device recovery, organization export, server backup, and disaster recovery become four distinct capabilities.
15. `UserAccount`, `Device`, `Session`, role grants and audit identities are separate server-managed records.
16. `Employee != UserAccount`; an employee may exist without login and an account may be disabled without deleting HR history.
17. The mobile inventory freezes per-screen remediation without hiding or deleting any page.
18. Windows continues on the local adapter first, then uses the same application/API contracts incrementally.
19. Lowest risk order is boundary → backend foundation → identity → outbox → reference sync → transaction sync → UI → Android pilot → DR → real migration.
20. Frozen contracts are recorded in the target architecture and owner-decision documents; Phase 104 may not change them silently.

## 11. Audit conclusion

The evidence supports freezing a provider-neutral, server-authoritative, offline-capable target architecture. It does not support claiming cloud, multi-device, Android runtime, or iOS readiness today. No existing page is removed, no production profitability is activated, and no current accounting rule is changed by this audit.

## 12. Verification evidence

The following gates were run on 2026-07-28 after creating only the seven Phase 103 Markdown files:

| Gate | Result |
| --- | --- |
| `git diff --check` | Pass before and after verification |
| `flutter analyze --no-pub` | Pass — no issues found; analyzer reported 83.1 seconds |
| `dart format --output=none --set-exit-if-changed .` | The PATH wrapper timed out without output at 120 and 300 seconds. The same Dart 3.5.4 SDK executable was invoked directly with identical format arguments: pass, 362 files checked, 0 changed, 5.53 seconds. |
| `flutter test` | Pass — 1,910 tests, one existing skip, `All tests passed`, Exit 0, 174.1 seconds |
| Windows Release | Pass — `build/windows/x64/runner/Release/grain_warehouse_erp_lite.exe`, 784,384 bytes, modified 2026-07-28 18:45:35 local; build step 22.3 seconds. Non-fatal CMake deprecation and LNK4078 warnings recorded. |
| Android Release APK | Pass — `build/app/outputs/flutter-apk/app-release.apk`, 31,961,219 bytes, modified 2026-07-28 18:50:54 local; Gradle step 297.8 seconds, Exit 0. |
| Android warnings | Project compiles with SDK 34 while `flutter_plugin_android_lifecycle` and `sqlite3_flutter_libs` request SDK 35; SDK XML version mismatch warning. These are Phase 111 readiness gaps and were not changed in documentation-only Phase 103. |
| iOS build | Not run — iOS platform directory is absent and the host is Windows; no success is claimed. |

Flutter/Dart wrapper note: the unextended/PATH batch wrapper entered a CPU loop before starting Dart during formatter/Windows build attempts. Direct invocation of the bundled Dart SDK and `flutter_tools.snapshot` was used to execute the same tools. Windows and Android build tools required access to the Flutter SDK cache outside the restricted workspace sandbox; no source, cloud resource or customer data was changed.
